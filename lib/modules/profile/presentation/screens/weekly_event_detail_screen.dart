import 'package:flutter/material.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/event_performer_identity.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/event_poster_fallback.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../auth/presentation/widgets/registration_options_sheet.dart';
import '../../../analytics/presentation/widgets/analytics_tracking.dart';
import '../../../analytics/data/analytics_tracker.dart';
import '../../../analytics/presentation/screens/venue_analytics_screen.dart';
import '../../../analytics/presentation/widgets/venue_analytics_reporting_scope.dart';
import '../../../event_audience/presentation/widgets/event_audience_controls.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/domain/comment_age.dart';
import '../../../engagement/domain/entities/comment_item.dart';
import '../../../engagement/domain/entities/comment_text.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../../engagement/presentation/widgets/comment_author_identity.dart';
import '../../../engagement/presentation/widgets/comment_like_button.dart';
import '../../../engagement/presentation/widgets/comment_like_memory.dart';
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

part 'weekly_event_detail_screen_sections.dart';
part 'weekly_event_detail_screen_actions.dart';
part 'weekly_event_detail_screen_meta_widgets.dart';
part 'weekly_event_detail_screen_comment_tile.dart';
part 'weekly_event_detail_screen_comment_access.dart';
part 'weekly_event_detail_screen_comments.dart';
part 'weekly_event_detail_screen_comment_chrome.dart';
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

class _WeeklyEventDetailScreenState extends State<WeeklyEventDetailScreen>
    with WidgetsBindingObserver {
  final TextEditingController _commentController = TextEditingController();
  final CommentThreadCubit _commentCubit = CommentThreadCubit(
    serviceLocator<EngagementRepository>(),
    sessions: serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null,
  );
  final EngagementRepository _engagementRepository =
      serviceLocator<EngagementRepository>();
  final VenueEventRepository _venueEventRepository =
      serviceLocator<VenueEventRepository>();
  MusicianProfile? _artistProfile;
  BandProfile? _bandProfile;
  VenuePublicProfile? _venueProfile;
  bool _analyticsEventVerified = false;
  late final EventShareService _eventShareService =
      widget.shareService ?? PlatformEventShareService();
  String? _loadedDescription;
  bool _isSharing = false;
  bool _isShowingPerformerInfo = false;
  bool _isOpeningArtistProfile = false;
  final Map<String, List<CommentItem>> _repliesByCommentId =
      <String, List<CommentItem>>{};
  final Set<String> _loadedReplyParents = <String>{};
  final Set<String> _expandedReplyParents = <String>{};
  final Map<String, bool> _replyHasMore = <String, bool>{};
  final Set<String> _loadingReplyParents = <String>{};
  final Map<String, int> _replyPages = <String, int>{};
  final Map<String, int> _replyTotals = <String, int>{};
  final Set<String> _replyErrors = <String>{};
  final Map<String, int> _replyRequestVersions = <String, int>{};
  final Map<String, CommentItem> _replyRootSnapshots = <String, CommentItem>{};
  AuthSessionManager? _commentSessionManager;
  final _commentLikeMemory = CommentLikeMemory();
  AuthSession? _commentSession;
  int _commentIdentityRevision = 0;
  bool _openingCommentAuth = false;
  bool _showingReply = false;
  ModalRoute<dynamic>? _replyRoute;
  ModalRoute<dynamic>? _deleteCommentRoute;
  bool _confirmingCommentDelete = false;

  bool get _canComment =>
      _commentSessionManager?.session.isAuthenticated == true &&
      _commentSessionManager?.session.isActive == true &&
      _commentSessionManager?.session.requiresListenerProfileChoice != true;

  bool _isCurrentCommentSession(AuthSession? expected) =>
      mounted &&
      expected?.isAuthenticated == true &&
      _canComment &&
      identical(expected, _commentSessionManager!.session);

  void _onCommentSessionChanged() {
    if (!mounted) return;
    final next = _commentSessionManager?.session;
    final identityChanged = !identical(next, _commentSession);
    setState(() {
      _commentSession = next;
      if (identityChanged) {
        _commentLikeMemory.clear();
        _commentIdentityRevision++;
        _commentController.clear();
        _repliesByCommentId.clear();
        _loadedReplyParents.clear();
        _expandedReplyParents.clear();
        _replyHasMore.clear();
        _loadingReplyParents.clear();
        _replyPages.clear();
        _replyTotals.clear();
        _replyErrors.clear();
        _replyRequestVersions.clear();
        _replyRootSnapshots.clear();
      }
    });
    if (identityChanged) {
      _dismissReplyRoute();
    }
  }

  Future<void> _openCommentAuth(String route) async {
    if (!mounted ||
        _canComment ||
        _openingCommentAuth ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _openingCommentAuth = true);
    try {
      if (route == AppRoutes.register) {
        await openRegistrationOptions(context);
      } else {
        await Navigator.of(context).pushNamed(route);
      }
    } finally {
      if (mounted) setState(() => _openingCommentAuth = false);
    }
  }

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (serviceLocator.isRegistered<AuthSessionManager>()) {
      _commentSessionManager = serviceLocator<AuthSessionManager>();
      _commentSession = _commentSessionManager!.session;
      _commentSessionManager!.addListener(_onCommentSessionChanged);
    }
    _loadProfileContext();
    _loadComments();
  }

  @override
  void didUpdateWidget(covariant WeeklyEventDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id == widget.event.id) return;
    _commentController.clear();
    _dismissReplyRoute();
    _resetReplyThreads();
    _loadComments(clearExisting: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _resetReplyThreads();
      _loadComments(clearExisting: true);
    }
  }

  @override
  void dispose() {
    _commentLikeMemory.clear();
    WidgetsBinding.instance.removeObserver(this);
    _dismissReplyRoute();
    _commentSessionManager?.removeListener(_onCommentSessionChanged);
    _commentCubit.close();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final commentSession = _commentSessionManager?.session;
    final performerName = _eventPerformerDisplayName(event.artistName);
    final location = [event.city, event.district, event.neighborhood]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value != '-')
        .join(' / ');

    final page = Scaffold(
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
                          _ProfileIdentityRow(
                            performer: _MetaChip(
                              key: const Key('event-performer-profile-chip'),
                              singleLine: true,
                              centerContent: true,
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
                                      _hasNamedEventPerformer(performerName)
                                  ? _showPerformerVerificationInfo
                                  : null,
                            ),
                            venue: _MetaChip(
                              key: const Key('event-venue-profile-chip'),
                              singleLine: true,
                              centerContent: true,
                              icon: Icons.storefront_outlined,
                              text: event.venueName.trim().isEmpty
                                  ? 'Mekân'
                                  : '@${event.venueName.trim()}',
                              imageUrl: _venueProfile?.profilePictureUrl,
                              onTap: event.venueId?.trim().isNotEmpty == true
                                  ? _openVenueProfile
                                  : null,
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
                  SliverToBoxAdapter(
                    child: EventAudienceControls(
                      eventId: event.id,
                      eventTitle: event.title,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      endedNoticeBuilder: (_) => const _EventEndedNotice(),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_analyticsEventVerified &&
                              _venueProfile != null &&
                              VenueAnalyticsReportingScope.of(context).enabled)
                            VenueAnalyticsLink(
                              venueId: _venueProfile!.venueId,
                              venueName: _venueProfile!.venueName,
                              eventId: event.id,
                              eventTitle: event.title,
                              ownerUserId: _venueProfile!.ownerUserId,
                            ),
                          BlocBuilder<CommentThreadCubit, CommentThreadState>(
                            bloc: _commentCubit,
                            builder: (context, state) =>
                                _EventCommentsHeading(state: state),
                          ),
                        ],
                      ),
                    ),
                  ),
                  BlocConsumer<CommentThreadCubit, CommentThreadState>(
                    bloc: _commentCubit,
                    listener: (context, state) =>
                        _pruneReplyThreads(_commentCubit.state.comments),
                    builder: (context, state) => _commentSliver(state),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 14)),
                ],
              ),
            ),
            _EventCommentComposerSurface(
              child: !_canComment
                  ? _EventCommentGuestPrompt(
                      onLogin: _openingCommentAuth
                          ? null
                          : () => _openCommentAuth(AppRoutes.login),
                      onRegister: _openingCommentAuth
                          ? null
                          : () => _openCommentAuth(AppRoutes.register),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _EventCommentInputFrame(
                            child: TextField(
                              key: const Key('event-comment-input'),
                              controller: _commentController,
                              maxLength: 500,
                              onChanged: (_) => setState(() {}),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) =>
                                  _addComment(commentSession, event.id),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                errorText:
                                    CommentText.length(
                                          _commentController.text,
                                        ) >
                                        CommentText.maxLength
                                    ? 'Yorumunu biraz kısalt.'
                                    : null,
                                hintText: 'Yorum yaz...',
                                hintStyle: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                prefixIcon: Icon(
                                  Icons.mode_comment_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 16,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        BlocBuilder<CommentThreadCubit, CommentThreadState>(
                          bloc: _commentCubit,
                          builder: (context, state) => Material(
                            key: const Key('event-comment-send'),
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap:
                                  state.submitting ||
                                      !CommentText.isValid(
                                        _commentController.text,
                                      )
                                  ? null
                                  : () => _addComment(commentSession, event.id),
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
    return TrackEventDetailView(
      eventId: event.id,
      enabled:
          _analyticsEventVerified &&
          (_venueProfile == null ||
              _venueProfile!.ownerUserId != commentSession?.userId),
      child: page,
    );
  }
}
