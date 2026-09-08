import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/access_policy.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../location/domain/location_repository.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../../tablegroup/presentation/screens/table_group_route_args.dart';
import '../../domain/event_discovery_search_repository.dart';
import '../../domain/venue_suggestion_repository.dart';
import 'guest_event_home_screen.dart';

class EventDiscoveryArgs {
  const EventDiscoveryArgs({this.bottomBarStageMode = StageMode.mainstage});
  final StageMode bottomBarStageMode;
}

/// Authenticated navigation chrome around the exact same public discovery
/// implementation. Guest launch/rollback and event-card rendering stay intact.
class MemberEventDiscoveryScreen extends StatefulWidget {
  const MemberEventDiscoveryScreen({
    super.key,
    this.args = const EventDiscoveryArgs(),
    this.sessions,
    this.locationRepository,
    this.searchRepository,
    this.suggestionRepository,
    this.bottomNavigationBar,
    this.now,
    this.watchClock = true,
  });

  final EventDiscoveryArgs args;
  final AuthSessionManager? sessions;
  final LocationRepository? locationRepository;
  final EventDiscoverySearchRepository? searchRepository;
  final VenueSuggestionRepository? suggestionRepository;
  final Widget? bottomNavigationBar;
  final DateTime Function()? now;
  final bool watchClock;

  @override
  State<MemberEventDiscoveryScreen> createState() => _MemberDiscoveryState();
}

class _MemberDiscoveryState extends State<MemberEventDiscoveryScreen> {
  late AuthSessionManager _sessions;
  bool _openingTables = false;

  @override
  void initState() {
    super.initState();
    _sessions = widget.sessions ?? serviceLocator<AuthSessionManager>();
    _sessions.addListener(_sessionChanged);
  }

  @override
  void didUpdateWidget(covariant MemberEventDiscoveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions != widget.sessions) {
      _sessions.removeListener(_sessionChanged);
      _sessions = widget.sessions ?? serviceLocator<AuthSessionManager>();
      _sessions.addListener(_sessionChanged);
    }
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  bool _allowed(AuthSession session) =>
      session.isAuthenticated &&
      session.isActive &&
      session.userId?.trim().isNotEmpty == true &&
      !session.requiresListenerProfileChoice;

  StageMode _stage(AuthSession session) =>
      widget.args.bottomBarStageMode == StageMode.backstage &&
          AccessPolicy.canAccessBackstage(session.roles)
      ? StageMode.backstage
      : StageMode.mainstage;

  @override
  Widget build(BuildContext context) {
    final session = _sessions.session;
    if (!_allowed(session)) {
      // The root session observer/route guard owns the actual sign-in or
      // onboarding redirect. Never leave stale member actions tappable while
      // that next-frame navigation is pending.
      return const Scaffold(body: SizedBox.expand());
    }
    final stage = _stage(session);
    return GuestEventDiscoveryScreen(
      locationRepository: widget.locationRepository,
      searchRepository: widget.searchRepository,
      suggestionRepository: widget.suggestionRepository,
      now: widget.now,
      watchClock: widget.watchClock,
      showGuestFooter: false,
      tableHint: AccessPolicy.canCreateOrJoinTableGroups(session.roles)
          ? 'Masa açmak için\ndokunun'
          : 'Masaları görmek için\ndokunun',
      bottomNavigationBar:
          widget.bottomNavigationBar ??
          ProfilePublicBottomBar(
            currentIndex: stage == StageMode.mainstage ? 0 : 2,
            stageMode: stage,
          ),
      onTableTap: () => unawaited(_openTables(session, stage)),
    );
  }

  Future<void> _openTables(AuthSession expected, StageMode stage) async {
    if (!mounted ||
        _openingTables ||
        !_allowed(_sessions.session) ||
        !identical(_sessions.session, expected) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _openingTables = true);
    try {
      await Navigator.of(context).pushNamed<void>(
        AppRoutes.tableGroupList,
        arguments: TableGroupListArgs(bottomBarStageMode: stage),
      );
    } finally {
      if (mounted) setState(() => _openingTables = false);
    }
  }

  @override
  void dispose() {
    _sessions.removeListener(_sessionChanged);
    super.dispose();
  }
}
