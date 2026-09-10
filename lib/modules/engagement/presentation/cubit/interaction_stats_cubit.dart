import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../domain/engagement_repository.dart';
import 'interaction_stats_state.dart';

class InteractionStatsCubit extends Cubit<InteractionStatsState> {
  InteractionStatsCubit(this._repository, {AuthSessionManager? sessions})
    : _sessions = sessions,
      super(const InteractionStatsState.initial()) {
    _session = sessions?.session;
    sessions?.addListener(_sessionChanged);
  }

  final EngagementRepository _repository;
  final AuthSessionManager? _sessions;
  AuthSession? _session;
  final Map<String, Object> _inFlight = {};
  final Map<String, (String, String)> _targets = {};
  static const _unknown = AppError(
    code: 'engagement_stats_unknown',
    message: 'Etkileşim durumu doğrulanamadı. Yeniden dene.',
  );

  bool get _allowed =>
      _sessions == null ||
      (_sessions.session.isAuthenticated &&
          _sessions.session.isActive &&
          !_sessions.session.requiresListenerProfileChoice &&
          _sessions.session.userId?.trim().isNotEmpty == true);

  bool _current(String key, Object operation, AuthSession? session) =>
      !isClosed &&
      identical(_inFlight[key], operation) &&
      (_sessions == null || identical(_sessions.session, session));

  void _sessionChanged() {
    if (isClosed || identical(_session, _sessions?.session)) return;
    _session = _sessions?.session;
    _inFlight.clear();
    emit(const InteractionStatsState.initial());
    if (_allowed) {
      for (final target in _targets.values.toList()) {
        unawaited(load(targetType: target.$1, targetId: target.$2));
      }
    }
  }

  void _put(String key, InteractionStatsItemState item) {
    emit(state.copyWith(items: Map.unmodifiable({...state.items, key: item})));
  }

  /// Seeds an authoritative batched viewer projection before the first read.
  void seed({
    required String targetType,
    required String targetId,
    required InteractionStatsItemState item,
  }) {
    if (isClosed || !_allowed) return;
    final key = '$targetType:$targetId';
    if (_inFlight.containsKey(key)) return;
    _targets[key] = (targetType, targetId);
    _put(key, item);
  }

  Future<void> load({
    required String targetType,
    required String targetId,
    bool force = false,
  }) async {
    if (isClosed || !_allowed) return;
    final key = '$targetType:$targetId';
    _targets[key] = (targetType, targetId);
    final current = state.items[key];
    if ((!force &&
            current != null &&
            !current.loading &&
            current.error == null) ||
        _inFlight.containsKey(key)) {
      return;
    }
    final operation = Object();
    final session = _sessions?.session;
    _inFlight[key] = operation;
    _put(
      key,
      (current ?? const InteractionStatsItemState.idle()).copyWith(
        loading: true,
        error: null,
      ),
    );
    try {
      final likeCount = await _repository.getLikeCount(
        targetType: targetType,
        targetId: targetId,
      );
      if (!_current(key, operation, session)) return;
      final comments = await _repository.listComments(
        targetType: targetType,
        targetId: targetId,
        page: 0,
        size: 1,
      );
      if (!_current(key, operation, session)) return;
      final liked = await _repository.isLiked(
        targetType: targetType,
        targetId: targetId,
      );
      if (!_current(key, operation, session)) return;
      final existing =
          state.items[key] ?? const InteractionStatsItemState.idle();
      _put(
        key,
        existing.copyWith(
          loading: false,
          likeCount: likeCount.isSuccess ? likeCount.data : null,
          commentCount: comments.isSuccess
              ? comments.data?.totalElements
              : null,
          isLiked: liked.isSuccess ? liked.data : null,
          hasLikeCount: likeCount.isSuccess && likeCount.data != null,
          hasCommentCount: comments.isSuccess && comments.data != null,
          error:
              likeCount.error ??
              comments.error ??
              liked.error ??
              (likeCount.data == null ||
                      comments.data == null ||
                      liked.data == null
                  ? _unknown
                  : null),
        ),
      );
    } catch (_) {
      if (_current(key, operation, session)) {
        _put(
          key,
          (state.items[key] ?? const InteractionStatsItemState.idle()).copyWith(
            loading: false,
            error: _unknown,
          ),
        );
      }
    } finally {
      if (identical(_inFlight[key], operation)) _inFlight.remove(key);
    }
  }

  Future<void> toggleLike({
    required String targetType,
    required String targetId,
  }) async {
    if (isClosed || !_allowed) return;
    final key = '$targetType:$targetId';
    if (_inFlight.containsKey(key)) return;
    final existing = state.items[key];
    // An initial/failed read or uncertain write cannot safely define a toggle.
    // The next tap reconciles the server state before another mutation.
    if (existing == null || existing.error != null) {
      await load(targetType: targetType, targetId: targetId, force: true);
      return;
    }
    final operation = Object();
    final session = _sessions?.session;
    _inFlight[key] = operation;
    _put(
      key,
      existing.copyWith(
        isLiked: !existing.isLiked,
        likeCount: (existing.likeCount + (existing.isLiked ? -1 : 1)).clamp(
          0,
          9007199254740991,
        ),
        loading: true,
        error: null,
      ),
    );
    bool confirmed = false;
    try {
      final result = existing.isLiked
          ? await _repository.unlike(targetType: targetType, targetId: targetId)
          : await _repository.like(targetType: targetType, targetId: targetId);
      if (!_current(key, operation, session)) return;
      confirmed = result.isSuccess;
      if (!confirmed) {
        _put(
          key,
          existing.copyWith(loading: false, error: result.error ?? _unknown),
        );
      }
    } catch (_) {
      if (_current(key, operation, session)) {
        _put(key, existing.copyWith(loading: false, error: _unknown));
      }
    } finally {
      if (identical(_inFlight[key], operation)) _inFlight.remove(key);
    }
    if (confirmed &&
        !isClosed &&
        (_sessions == null || identical(_sessions.session, session))) {
      await load(targetType: targetType, targetId: targetId, force: true);
    }
  }

  @override
  Future<void> close() {
    _sessions?.removeListener(_sessionChanged);
    _inFlight.clear();
    return super.close();
  }
}
