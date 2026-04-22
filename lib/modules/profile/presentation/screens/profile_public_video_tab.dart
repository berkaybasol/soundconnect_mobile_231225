import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/media_asset.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'profile_count_row.dart';
import 'video_reel_screen.dart';

class ProfilePublicVideoTab extends StatelessWidget {
  final List<MediaAsset> items;

  ProfilePublicVideoTab({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Kullanici henuz video eklemedi.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(20),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final thumbnail = item.thumbnailUrl ?? item.playbackUrl;
        final fallbackLikeCount = 210 + (index * 9);
        final fallbackCommentCount = 44 + (index * 4);
        final targetType = 'MEDIA';
        final targetId = item.id;
        final statsState = context.watch<InteractionStatsCubit>().state;
        final statsKey = '$targetType:$targetId';
        if (targetId.isNotEmpty && !statsState.items.containsKey(statsKey)) {
          context.read<InteractionStatsCubit>().load(
            targetType: targetType,
            targetId: targetId,
          );
        }
        final stats = statsState.items[statsKey];
        final likeCount = stats?.likeCount ?? fallbackLikeCount;
        final commentCount = stats?.commentCount ?? fallbackCommentCount;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
            image: thumbnail != null
                ? DecorationImage(
                    image: NetworkImage(thumbnail),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(
                        value: context.read<InteractionStatsCubit>(),
                      ),
                      BlocProvider(
                        create: (_) => serviceLocator<CommentThreadCubit>(),
                      ),
                    ],
                    child: VideoReelScreen(
                      title: item.title ?? 'Video',
                      playbackUrl: (item.playbackUrl ?? item.sourceUrl ?? '')
                          .trim(),
                      sourceUrl: item.sourceUrl,
                      thumbnailUrl: thumbnail,
                      framePreset: null,
                      targetType: targetType,
                      targetId: item.id,
                      initialLikeCount: likeCount,
                      initialCommentCount: commentCount,
                    ),
                  ),
                ),
              );
            },
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: ProfileCountRow(
                    likeCount: likeCount,
                    commentCount: commentCount,
                    light: true,
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: AppColors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
