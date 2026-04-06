import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/domain/entities/comment_item.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/venue_event_repository.dart';
import '../../domain/venue_profile_repository.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/venue_public_profile.dart';
import 'musician_public_profile_screen.dart' as musician_public;
import 'profile_route_args.dart';
import 'venue_public_profile_screen.dart' as venue_public;

part 'weekly_event_detail_screen_sections.dart';
part 'weekly_event_detail_screen_actions.dart';
part 'weekly_event_detail_screen_meta_widgets.dart';
part 'weekly_event_detail_screen_comment_tile.dart';

class WeeklyCalendarEvent {
  final String id;
  final String title;
  final String artistName;
  final String? artistProfileId;
  final String venueName;
  final String? venueId;
  final String city;
  final String district;
  final String neighborhood;
  final String eventDate;
  final String startTime;
  final String endTime;
  final String? imageAssetPath;
  final String description;

  const WeeklyCalendarEvent({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artistProfileId,
    required this.venueName,
    required this.venueId,
    required this.city,
    required this.district,
    required this.neighborhood,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    this.imageAssetPath,
    required this.description,
  });
}

bool _isNetworkLikePath(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

class WeeklyEventDetailScreen extends StatefulWidget {
  final WeeklyCalendarEvent event;

  const WeeklyEventDetailScreen({super.key, required this.event});

  @override
  State<WeeklyEventDetailScreen> createState() =>
      _WeeklyEventDetailScreenState();
}

class _WeeklyEventDetailScreenState extends State<WeeklyEventDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final CommentThreadCubit _commentCubit = CommentThreadCubit(
    serviceLocator<EngagementRepository>(),
  );
  final EngagementRepository _engagementRepository =
      serviceLocator<EngagementRepository>();
  final VenueEventRepository _venueEventRepository =
      serviceLocator<VenueEventRepository>();
  MusicianProfile? _artistProfile;
  VenuePublicProfile? _venueProfile;
  String? _shareUrl;
  bool _isSharing = false;
  final Map<String, List<CommentItem>> _repliesByCommentId =
      <String, List<CommentItem>>{};
  final Set<String> _loadedReplyParents = <String>{};

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  @override
  void initState() {
    super.initState();
    _loadProfileContext();
  }

  @override
  void dispose() {
    _commentCubit.close();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      backgroundColor: AppColors.navBlueDeep,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeroHeader(
                      event: event,
                      onImageTap: _openPosterFullScreen,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaChip(
                            icon: Icons.music_note_outlined,
                            text: '@${event.artistName}',
                            imageUrl: _artistProfile?.profilePicture,
                            onTap:
                                event.artistProfileId?.trim().isNotEmpty == true
                                ? _openArtistProfile
                                : null,
                          ),
                          _MetaChip(
                            icon: Icons.storefront_outlined,
                            text: '@${event.venueName}',
                            imageUrl: _venueProfile?.profilePictureUrl,
                            onTap: event.venueId?.trim().isNotEmpty == true
                                ? _openVenueProfile
                                : null,
                          ),
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            text: event.eventDate,
                          ),
                          _MetaChip(
                            icon: Icons.schedule_outlined,
                            text: '${event.startTime} - ${event.endTime}',
                          ),
                          _MetaChip(
                            icon: Icons.place_outlined,
                            text:
                                '${event.city} / ${event.district} / ${event.neighborhood}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ActionButton(
                        icon: Icons.ios_share_outlined,
                        label: 'Paylas',
                        onPressed: _shareEvent,
                        isLoading: _isSharing,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Text(
                        event.description,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                      child: _SectionTitle(text: 'Sorular & Yorumlar'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: BlocConsumer<CommentThreadCubit, CommentThreadState>(
                      bloc: _commentCubit,
                      listener: (context, state) {
                        _syncReplies(state.comments);
                      },
                      builder: (context, state) {
                        if (state.loading && state.comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (state.comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                            child: Text(
                              'Henuz yorum yok. Ilk yorumu sen yaz.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          );
                        }
                        return Column(
                          children: List.generate(state.comments.length, (
                            index,
                          ) {
                            final comment = state.comments[index];
                            final replies =
                                _repliesByCommentId[comment.id] ??
                                const <CommentItem>[];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CommentTile(
                                comment: comment,
                                timeLabel: _timeLabel(comment.createdAt),
                                replies: replies,
                                replyTimeLabelBuilder: _timeLabel,
                                onReplyTap: () => _showReplySheet(index),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.navBlue,
                border: Border(
                  top: BorderSide(
                    color: AppColors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Yorum yaz...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: const Icon(
                          Icons.mode_comment_outlined,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BlocBuilder<CommentThreadCubit, CommentThreadState>(
                    bloc: _commentCubit,
                    builder: (context, state) => Material(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: state.submitting ? null : _addComment,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: state.submitting
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textPrimary,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: AppColors.textPrimary,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
