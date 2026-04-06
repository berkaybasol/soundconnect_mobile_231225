import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/media_asset.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'media_detail_screen.dart';

class ProfilePhotoGalleryTab extends StatelessWidget {
  final List<MediaAsset> items;
  final bool ownerMode;
  final Future<void> Function()? onAddPhoto;

  const ProfilePhotoGalleryTab({
    super.key,
    required this.items,
    required this.ownerMode,
    this.onAddPhoto,
  });

  void _openImage(BuildContext context, MediaAsset item) {
    final imageUrl = _imageUrlOf(item);
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

  String? _imageUrlOf(MediaAsset item) {
    final candidates = [item.sourceUrl, item.playbackUrl, item.thumbnailUrl];
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  Widget _buildUploadCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onAddPhoto,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0x1AFFFFFF), Color(0x1A8A5CFF), Color(0x1AFF7A3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.inputFill,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                items.isEmpty ? 'Henuz fotograf eklemediniz' : 'Fotograf ekle',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'SoundConnect uzerinden galeri fotografi yuklemek icin dokun.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = items
        .where((item) => _imageUrlOf(item) != null)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ownerMode) _buildUploadCard(),
        if (visibleItems.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(20, ownerMode ? 0 : 20, 20, 20),
            child: const Text(
              'Henuz fotograf eklenmedi.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        else
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.72,
            ),
            itemCount: visibleItems.length,
            itemBuilder: (context, index) {
              final item = visibleItems[index];
              final imageUrl = _imageUrlOf(item)!;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openImage(context, item),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textMuted,
                            size: 34,
                          ),
                        ),
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
