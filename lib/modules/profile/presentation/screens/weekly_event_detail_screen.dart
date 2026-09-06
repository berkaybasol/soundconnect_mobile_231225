import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/event_performer_identity.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/event_poster_fallback.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/domain/entities/comment_item.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../domain/band_repository.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/venue_event_repository.dart';
import '../../domain/venue_profile_repository.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/entities/venue_public_profile.dart';
import '../share/event_share_data.dart';
import '../share/event_share_service.dart';
import '../share/event_share_sheet.dart';
import 'band_profile_screen.dart';
import 'profile_route_args.dart';
import 'venue_public_profile_screen.dart' as venue_public;

part 'weekly_event_detail_screen_sections.dart';
part 'weekly_event_detail_screen_actions.dart';
part 'weekly_event_detail_screen_meta_widgets.dart';
part 'weekly_event_detail_screen_comment_tile.dart';
part 'weekly_event_detail_screen_verification.dart';

class WeeklyCalendarEvent {
  final String id;
  final String title;
  final String artistName;
  final String? artistProfileId;
  final String? bandProfileId;
  final String performerType;
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

  WeeklyCalendarEvent({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artistProfileId,
    this.bandProfileId,
    required this.performerType,
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

  EventPerformerIdentity get performerIdentity =>
      EventPerformerIdentity.fromWire(
        performerType: performerType,
        musicianProfileId: artistProfileId,
        bandId: bandProfileId,
      );

  String? get linkedArtistProfileId =>
      id.trim().isEmpty ? null : performerIdentity.musicianProfileId;

  String? get linkedBandProfileId =>
      id.trim().isEmpty ? null : performerIdentity.bandId;

  bool get hasLinkedPerformerProfile =>
      linkedArtistProfileId != null || linkedBandProfileId != null;

  bool get hasLinkedBandProfile => linkedBandProfileId != null;
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
  final EventShareService? shareService;

  WeeklyEventDetailScreen({super.key, required this.event, this.shareService});

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
  BandProfile? _bandProfile;
  VenuePublicProfile? _venueProfile;
  late final EventShareService _eventShareService =
      widget.shareService ?? PlatformEventShareService();
  String? _loadedDescription;
  bool _isSharing = false;
  bool _isShowingPerformerInfo = false;
  bool _isOpeningArtistProfile = false;
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
    final performerName = _eventPerformerDisplayName(event.artistName);
    final location = [event.city, event.district, event.neighborhood]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value != '-')
        .join(' / ');

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
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height:
                                (MediaQuery.textScalerOf(context).scale(12) *
                                            1.4 +
                                        16)
                                    .clamp(48.0, double.infinity)
                                    .toDouble(),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 45,
                                  child: _MetaChip(
                                    key: const Key(
                                      'event-performer-profile-chip',
                                    ),
                                    singleLine: true,
                                    centerContent:
                                        !event.hasLinkedPerformerProfile &&
                                        !_hasNamedEventPerformer(performerName),
                                    icon: Icons.music_note_outlined,
                                    text: performerName.isEmpty
                                        ? 'Sanatçı'
                                        : '${event.hasLinkedPerformerProfile ? '@' : ''}$performerName',
                                    imageUrl:
                                        _bandProfile?.profilePictureUrl ??
                                        _artistProfile?.profilePicture,
                                    onTap: event.hasLinkedPerformerProfile
                                        ? _openArtistProfile
                                        : null,
                                    onInfoTap:
                                        !event.hasLinkedPerformerProfile &&
                                            _hasNamedEventPerformer(
                                              performerName,
                                            )
                                        ? _showPerformerVerificationInfo
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 55,
                                  child: _MetaChip(
                                    key: const Key('event-venue-profile-chip'),
                                    singleLine: true,
                                    icon: Icons.storefront_outlined,
                                    text: event.venueName.trim().isEmpty
                                        ? 'Mekân'
                                        : '@${event.venueName.trim()}',
                                    imageUrl: _venueProfile?.profilePictureUrl,
                                    onTap:
                                        event.venueId?.trim().isNotEmpty == true
                                        ? _openVenueProfile
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            text: event.eventDate,
                          ),
                          if (_eventTimeRange(event).isNotEmpty)
                            _MetaChip(
                              icon: Icons.schedule_outlined,
                              text: _eventTimeRange(event),
                            ),
                          if (location.isNotEmpty)
                            _MetaChip(
                              icon: Icons.place_outlined,
                              text: location,
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _ActionButton(
                        key: const Key('event-share-action-button'),
                        icon: Icons.ios_share_outlined,
                        label: 'Paylaş',
                        onPressed: _shareEvent,
                        isLoading: _isSharing,
                      ),
                    ),
                  ),
                  if ((_loadedDescription ?? event.description)
                      .trim()
                      .isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Text(
                          (_loadedDescription ?? event.description).trim(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 22, 16, 8),
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
                          return Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (state.comments.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                            child: Text(
                              'Henüz yorum yok. İlk yorumu sen yaz.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
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
                                <CommentItem>[];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 10),
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
                  SliverToBoxAdapter(child: SizedBox(height: 14)),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Yorum yaz...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.mode_comment_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  BlocBuilder<CommentThreadCubit, CommentThreadState>(
                    bloc: _commentCubit,
                    builder: (context, state) => Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: state.submitting ? null : _addComment,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: state.submitting
                              ? Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
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
