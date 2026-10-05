import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/presentation/cubit/interaction_stats_state.dart';
import '../../../event_audience/domain/event_audience_repository.dart';
import '../../../event_audience/presentation/event_audience_controller.dart';
import '../../../overthinking/domain/overthinking_profile_share_repository.dart';
import '../../../tablegroup/domain/table_group_profile_share_repository.dart';
import '../../domain/entities/venue_event_detail.dart';
import '../cubit/listener_event_feed_controller.dart';
import '../cubit/listener_profile_feed_controller.dart';
import '../share/event_share_flow.dart';
import 'listener_event_post_card.dart';
import 'listener_event_post_comments_sheet.dart';
import 'listener_event_post_engagement.dart';
import 'listener_event_post_participation.dart';
import 'listener_event_post_note_editor.dart';
import 'listener_profile_theme.dart';
import 'listener_overthinking_posts.dart';
import 'listener_overthinking_share_tile.dart';
import 'listener_table_group_share_tile.dart';
import 'listener_share_delete_dialog.dart';
import 'weekly_event_detail_screen.dart';

part 'listener_event_posts_bind.dart';
part 'listener_event_posts_open_comments.dart';

/// The profile's public publications, ordered across all supported types.
class ListenerProfilePostsSection extends StatelessWidget {
  const ListenerProfilePostsSection({
    super.key,
    required this.listenerProfileId,
    required this.username,
    this.avatarUrl,
    this.ownerUserId,
    this.profileContentVisible = true,
    this.eventsRepository,
    this.overthinkingRepository,
    this.tableGroupRepository,
    this.onOpenTable,
    this.sessions,
    this.refreshSignal,
    this.onOpenEvent,
    this.onOpenSource,
    this.asSliver = false,
  });

  final String listenerProfileId;
  final String username;
  final String? avatarUrl;
  final String? ownerUserId;
  final bool profileContentVisible;
  final EventAudienceRepository? eventsRepository;
  final OverthinkingProfileShareRepository? overthinkingRepository;
  final TableGroupProfileShareRepository? tableGroupRepository;
  final Future<void> Function(String tableGroupId)? onOpenTable;
  final AuthSessionManager? sessions;
  final ValueListenable<int>? refreshSignal;
  final Future<void> Function(VenueEventDetail event)? onOpenEvent;
  final Future<void> Function(String postId)? onOpenSource;
  final bool asSliver;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (!profileContentVisible) {
      return asSliver ? const SliverToBoxAdapter() : const SizedBox.shrink();
    }
    final events = eventsRepository ?? _registered<EventAudienceRepository>();
    final shares =
        overthinkingRepository ??
        _registered<OverthinkingProfileShareRepository>();
    if (events == null) {
      final fallback = ListenerOverthinkingPostsSection(
        listenerProfileId: listenerProfileId,
        username: username,
        avatarUrl: avatarUrl,
        ownerUserId: ownerUserId,
        repository: shares,
        sessions: sessions,
        refreshSignal: refreshSignal,
        onOpenSource: onOpenSource,
      );
      return asSliver ? SliverToBoxAdapter(child: fallback) : fallback;
    }
    return _ListenerEventFeed(
      listenerProfileId: listenerProfileId,
      username: username,
      avatarUrl: avatarUrl,
      ownerUserId: ownerUserId,
      repository: events,
      overthinkingRepository: shares,
      tableGroupRepository:
          tableGroupRepository ??
          _registered<TableGroupProfileShareRepository>(),
      onOpenTable: onOpenTable,
      sessions: sessions,
      refreshSignal: refreshSignal,
      onOpenEvent: onOpenEvent,
      onOpenSource: onOpenSource,
      asSliver: asSliver,
    );
  }
}

class ListenerEventPostsSection extends StatelessWidget {
  const ListenerEventPostsSection({
    super.key,
    required this.listenerProfileId,
    required this.username,
    this.avatarUrl,
    this.ownerUserId,
    this.repository,
    this.sessions,
    this.refreshSignal,
    this.showHeading = false,
    this.onOpenEvent,
  });
  final String listenerProfileId;
  final String username;
  final String? avatarUrl;
  final String? ownerUserId;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;
  final ValueListenable<int>? refreshSignal;
  final bool showHeading;
  final Future<void> Function(VenueEventDetail event)? onOpenEvent;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _ListenerEventFeed(
      listenerProfileId: listenerProfileId,
      username: username,
      avatarUrl: avatarUrl,
      ownerUserId: ownerUserId,
      repository: repository,
      sessions: sessions,
      refreshSignal: refreshSignal,
      showHeading: showHeading,
      onOpenEvent: onOpenEvent,
    );
  }
}

class ListenerEventPlansButton extends StatelessWidget {
  const ListenerEventPlansButton({
    super.key,
    required this.listenerProfileId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.repository,
    this.sessions,
  });
  final String listenerProfileId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return GradientOutlineButton(
      key: const Key('listener-my-event-plans'),
      label: 'Planlarım',
      leading: const Icon(Icons.event_note_outlined, size: 19),
      backgroundColor: AppColors.legacy(const Color(0xFF101722)),
      onPressed: () {
        if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        final manager = sessions ?? _registered<AuthSessionManager>();
        if (manager == null ||
            manager.session.userId != userId ||
            !manager.session.isAuthenticated ||
            !manager.session.isActive ||
            !canUseEventAudience(manager.session) ||
            manager.session.requiresListenerProfileChoice ||
            !manager.session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER'])) {
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ListenerEventPlansScreen(
              listenerProfileId: listenerProfileId,
              userId: userId,
              username: username,
              avatarUrl: avatarUrl,
              repository: repository,
              sessions: manager,
            ),
          ),
        );
      },
    );
  }
}

class ListenerEventPlansScreen extends StatelessWidget {
  const ListenerEventPlansScreen({
    super.key,
    required this.listenerProfileId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.repository,
    this.sessions,
    this.onOpenEvent,
  });
  final String listenerProfileId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;
  final Future<void> Function(VenueEventDetail event)? onOpenEvent;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return ListenerProfileTheme(
      child: _ListenerEventFeed(
        listenerProfileId: listenerProfileId,
        username: username,
        avatarUrl: avatarUrl,
        ownerUserId: userId,
        repository: repository,
        sessions: sessions,
        privatePlans: true,
        fullPage: true,
        onOpenEvent: onOpenEvent,
      ),
    );
  }
}

class _ListenerEventFeed extends StatefulWidget {
  const _ListenerEventFeed({
    required this.listenerProfileId,
    required this.username,
    this.avatarUrl,
    this.ownerUserId,
    this.repository,
    this.sessions,
    this.refreshSignal,
    this.privatePlans = false,
    this.fullPage = false,
    this.showHeading = false,
    this.onOpenEvent,
    this.overthinkingRepository,
    this.tableGroupRepository,
    this.onOpenTable,
    this.onOpenSource,
    this.asSliver = false,
  });
  final String listenerProfileId;
  final String username;
  final String? avatarUrl;
  final String? ownerUserId;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;
  final ValueListenable<int>? refreshSignal;
  final bool privatePlans;
  final bool fullPage;
  final bool showHeading;
  final Future<void> Function(VenueEventDetail event)? onOpenEvent;
  final OverthinkingProfileShareRepository? overthinkingRepository;
  final TableGroupProfileShareRepository? tableGroupRepository;
  final Future<void> Function(String tableGroupId)? onOpenTable;
  final Future<void> Function(String postId)? onOpenSource;
  final bool asSliver;

  @override
  State<_ListenerEventFeed> createState() => _ListenerEventFeedState();
}

class _ListenerEventFeedState extends State<_ListenerEventFeed>
    with WidgetsBindingObserver {
  ListenerEventFeedController? _feed;
  bool _opening = false;
  DialogRoute<void>? _noteDialog;
  AuthSession? _noteSession;
  ListenerEventFeedRow? _noteRow;
  bool _noteSaving = false;
  DialogRoute<bool>? _deleteDialog;
  AuthSession? _deleteSession;
  String? _deletePostId;
  ValueNotifier<bool>? _commentsAvailable;
  AuthSession? _commentsSession;
  String? _commentsPostId;
  final Set<String> _visibleTableShares = {};
  Timer? _tableRefreshTimer;
  Object? _tableRefreshFlight;
  int _tableRefreshGeneration = 0;
  Duration _tableRefreshDelay = const Duration(seconds: 15);
  bool _foreground = true;
  bool _routeCurrent = false;
  bool _tickersEnabled = true;

  // Instance tear-offs keep add/removeListener identity across part helpers.
  void _refresh() => _refreshFeed();
  void _changed() => _feedChanged();

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.refreshSignal?.addListener(_refresh);
    _bind();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasVisible = _routeCurrent && _tickersEnabled;
    // Subscribe to route currency and inherited tab visibility. This also
    // suspends reads while a dialog, detail route, or another tab is showing.
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? false;
    _tickersEnabled = TickerMode.of(context);
    if (!_routeCurrent || !_tickersEnabled) {
      _cancelTableRefresh();
    } else {
      _scheduleTableRefresh(immediate: !wasVisible);
    }
  }

  @override
  void didUpdateWidget(covariant _ListenerEventFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_refresh);
      widget.refreshSignal?.addListener(_refresh);
    }
    if (oldWidget.listenerProfileId != widget.listenerProfileId ||
        oldWidget.ownerUserId != widget.ownerUserId ||
        oldWidget.overthinkingRepository != widget.overthinkingRepository ||
        oldWidget.tableGroupRepository != widget.tableGroupRepository ||
        oldWidget.repository != widget.repository ||
        oldWidget.sessions != widget.sessions) {
      _bind();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _cancelTableRefresh();
    if (_foreground && _routeCurrent && _tickersEnabled) {
      _refresh();
      _scheduleTableRefresh(immediate: true);
    }
  }

  @override
  void dispose() {
    _cancelTableRefresh();
    _dismissNoteDialog();
    _dismissDeleteDialog();
    _invalidateComments();
    WidgetsBinding.instance.removeObserver(this);
    widget.refreshSignal?.removeListener(_refresh);
    _feed?.removeListener(_changed);
    _feed?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final feed = _feed;
    final available = feed != null && feed.allowed;
    final body = !available
        ? widget.fullPage
              ? const Center(
                  child: Text(
                    'Planlarını görmek için kendi hesabına giriş yap.',
                  ),
                )
              : const SizedBox.shrink()
        : _body(feed);
    if (!widget.fullPage) {
      if (widget.asSliver &&
          !(available && feed is ListenerProfileFeedController)) {
        return SliverToBoxAdapter(child: body);
      }
      return body;
    }
    return Scaffold(
      backgroundColor: AppColors.legacy(const Color(0xFF070B13)),
      appBar: AppBar(
        title: Text(widget.privatePlans ? 'Planlarım' : 'Paylaşımlar'),
      ),
      body: body,
    );
  }

  void _updateView(VoidCallback change) => setState(change);
}

T? _registered<T extends Object>() =>
    serviceLocator.isRegistered<T>() ? serviceLocator<T>() : null;

/// A card contributes visibility to its owning feed's single refresh timer.
/// Cached sliver children do not generate requests while outside the viewport.
class _VisibleTablePublication extends StatefulWidget {
  const _VisibleTablePublication({
    required this.child,
    required this.onVisibilityChanged,
  });

  final Widget child;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  State<_VisibleTablePublication> createState() =>
      _VisibleTablePublicationState();
}

class _VisibleTablePublicationState extends State<_VisibleTablePublication> {
  final _detectorKey = UniqueKey();
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return VisibilityDetector(
      key: _detectorKey,
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0;
        if (_visible == visible) return;
        _visible = visible;
        widget.onVisibilityChanged(visible);
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    VisibilityDetectorController.instance.forget(_detectorKey);
    if (_visible) widget.onVisibilityChanged(false);
    super.dispose();
  }
}

class _PlanPeriodChoice extends StatelessWidget {
  const _PlanPeriodChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(colors: AppColors.brandGradient)
              : null,
          color: selected ? null : AppColors.legacy(const Color(0xFF293447)),
        ),
        child: Material(
          color: selected
              ? AppColors.legacy(const Color(0xFF101722))
              : AppColors.legacy(const Color(0xFF0B1220)),
          borderRadius: BorderRadius.circular(17),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? AppColors.legacy(Colors.white)
                        : AppColors.legacy(const Color(0xFFA0A9B6)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
