import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../domain/entities/media_asset.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'media_detail_screen.dart';
import 'profile_image_url_resolver.dart';

class ProfilePhotoGalleryTab extends StatelessWidget {
  final List<MediaAsset> items;
  final bool ownerMode;
  final Future<void> Function()? onAddPhoto;
  final bool uploading;
  final double uploadProgress;
  final String? uploadStatusLabel;

  ProfilePhotoGalleryTab({
    super.key,
    required this.items,
    required this.ownerMode,
    this.onAddPhoto,
    this.uploading = false,
    this.uploadProgress = 0,
    this.uploadStatusLabel,
  });

  void _openImage(BuildContext context, MediaAsset item) {
    final imageUrl = resolveMediaDetailImageUrl(item);
    if (imageUrl == null) return;
    const targetType = 'MEDIA';
    final targetId = item.id.trim();
    final stats = targetId.isEmpty
        ? null
        : context
              .read<InteractionStatsCubit>()
              .state
              .items['$targetType:$targetId'];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<InteractionStatsCubit>()),
            BlocProvider(create: (_) => serviceLocator<CommentThreadCubit>()),
          ],
          child: MediaDetailScreen(
            title: (item.title?.trim().isNotEmpty ?? false)
                ? item.title!.trim()
                : 'Fotograf',
            isVideo: false,
            isImage: true,
            imageUrl: imageUrl,
            targetType: targetType,
            targetId: targetId,
            likeCount: stats?.likeCount ?? 0,
            commentCount: stats?.commentCount ?? 0,
          ),
        ),
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: uploading ? null : onAddPhoto,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [Color(0x1AFFFFFF), Color(0x1A8A5CFF), Color(0x1AFF7A3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: uploading
                    ? Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          value: uploadProgress > 0 ? uploadProgress : null,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 28,
                      ),
              ),
              SizedBox(height: 10),
              Text(
                uploading
                    ? uploadStatusLabel ??
                          'Fotograf yukleniyor %${(uploadProgress * 100).round()}'
                    : items.isEmpty
                    ? 'Henuz fotograf eklemediniz'
                    : 'Fotograf ekle',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                uploading
                    ? 'Dosyayi guvenle hazirlarken bu ekranda kalabilirsin.'
                    : 'SoundConnect uzerinden galeri fotografi yuklemek icin dokun.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              if (uploading) ...[
                SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: uploadProgress > 0 ? uploadProgress : null,
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = items
        .where((item) => resolveMediaPreviewImageUrl(item) != null)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ownerMode) _buildUploadCard(context),
        if (visibleItems.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(20, ownerMode ? 0 : 20, 20, 20),
            child: Text(
              'Henuz fotograf eklenmedi.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          GridView.builder(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.72,
            ),
            itemCount: visibleItems.length,
            itemBuilder: (context, index) {
              final item = visibleItems[index];
              final imageUrl = resolveMediaPreviewImageUrl(item)!;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openImage(context, item),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final pixelRatio = MediaQuery.devicePixelRatioOf(
                            context,
                          );
                          final cacheWidth = (constraints.maxWidth * pixelRatio)
                              .round()
                              .clamp(1, 1200)
                              .toInt();
                          return AppCachedNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            cacheWidth: cacheWidth,
                            errorBuilder: (context) => Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                size: 34,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
