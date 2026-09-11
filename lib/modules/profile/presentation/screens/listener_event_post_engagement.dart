import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_state.dart';

/// Stats live only as long as this publication's visible card. A replacement
/// publication of the same event gets a new scope and no retained like state.
class ListenerEventPostEngagement extends StatefulWidget {
  const ListenerEventPostEngagement({
    super.key,
    required this.postId,
    required this.repository,
    required this.sessions,
    required this.canInteract,
    required this.onError,
    this.onFailure,
    required this.builder,
    this.initialStats,
    this.projectionKey,
    this.targetType = 'EVENT_POST',
  });

  final String postId;
  final String targetType;
  final EngagementRepository repository;
  final AuthSessionManager sessions;
  final bool Function() canInteract;
  final ValueChanged<String> onError;
  final ValueChanged<AppError>? onFailure;
  final InteractionStatsItemState? initialStats;
  final Object? projectionKey;
  final Widget Function(
    InteractionStatsItemState stats,
    VoidCallback onLike,
    AsyncCallback refresh,
  )
  builder;

  @override
  State<ListenerEventPostEngagement> createState() =>
      _ListenerEventPostEngagementState();
}

class _ListenerEventPostEngagementState
    extends State<ListenerEventPostEngagement> {
  late InteractionStatsCubit _stats;
  String get _targetType => widget.targetType;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _stats = InteractionStatsCubit(
      widget.repository,
      sessions: widget.sessions,
    );
    final initial = widget.initialStats;
    if (initial != null) {
      _stats.seed(
        targetType: _targetType,
        targetId: widget.postId,
        item: initial,
      );
    }
    unawaited(_stats.load(targetType: _targetType, targetId: widget.postId));
  }

  @override
  void didUpdateWidget(covariant ListenerEventPostEngagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.targetType != widget.targetType ||
        oldWidget.projectionKey != widget.projectionKey ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.sessions, widget.sessions) ||
        oldWidget.initialStats?.likeCount != widget.initialStats?.likeCount ||
        oldWidget.initialStats?.commentCount !=
            widget.initialStats?.commentCount ||
        oldWidget.initialStats?.isLiked != widget.initialStats?.isLiked) {
      unawaited(_stats.close());
      _bind();
    }
  }

  Future<void> _toggleLike() async {
    if (!mounted || !widget.canInteract()) return;
    final stats = _stats;
    final session = widget.sessions.session;
    final postId = widget.postId;
    await stats.toggleLike(targetType: _targetType, targetId: postId);
    if (!mounted ||
        !identical(_stats, stats) ||
        !identical(widget.sessions.session, session) ||
        !widget.canInteract()) {
      return;
    }
    final error = stats.state.items['$_targetType:$postId']?.error;
    if (error != null) {
      widget.onError(error.message);
      widget.onFailure?.call(error);
    }
  }

  Future<void> _refresh() async {
    if (!mounted || !widget.canInteract()) return;
    final stats = _stats;
    final session = widget.sessions.session;
    final postId = widget.postId;
    final key = '$_targetType:$postId';
    // Queue the refresh: load(force: true) is ignored during an older request.
    if (stats.state.items[key]?.loading == true) {
      try {
        await stats.stream.firstWhere(
          (state) => state.items[key]?.loading != true,
        );
      } on StateError {
        // Removing the publication closes its cubit and ends this wait.
        return;
      }
    }
    if (!mounted ||
        stats.isClosed ||
        !identical(_stats, stats) ||
        !identical(widget.sessions.session, session) ||
        !widget.canInteract()) {
      return;
    }
    await stats.load(targetType: _targetType, targetId: postId, force: true);
  }

  @override
  void dispose() {
    unawaited(_stats.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<InteractionStatsCubit, InteractionStatsState>(
        bloc: _stats,
        builder: (context, state) => widget.builder(
          state.items['$_targetType:${widget.postId}'] ??
              const InteractionStatsItemState.idle(),
          () => unawaited(_toggleLike()),
          _refresh,
        ),
      );
}
