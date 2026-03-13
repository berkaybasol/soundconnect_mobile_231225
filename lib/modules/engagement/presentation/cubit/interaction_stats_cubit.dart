import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/engagement_repository.dart';
import 'interaction_stats_state.dart';

class InteractionStatsCubit extends Cubit<InteractionStatsState> {
  final EngagementRepository _repository;
  final Set<String> _inFlight = <String>{};

  InteractionStatsCubit(this._repository)
      : super(const InteractionStatsState.initial());

  String _key(String targetType, String targetId) => '$targetType:$targetId';

  Future<void> load({
    required String targetType,
    required String targetId,
    bool force = false,
  }) async {
    final key = _key(targetType, targetId);
    final current = state.items[key];
    if (!force && current != null && !current.loading) {
      return;
    }
    if (_inFlight.contains(key)) return;
    _inFlight.add(key);

    final next = Map<String, InteractionStatsItemState>.from(state.items);
    next[key] = (current ?? const InteractionStatsItemState.idle())
        .copyWith(loading: true, error: null);
    emit(state.copyWith(items: next));

    final likeCountResult = await _repository.getLikeCount(
      targetType: targetType,
      targetId: targetId,
    );
    final commentPageResult = await _repository.listComments(
      targetType: targetType,
      targetId: targetId,
      page: 0,
      size: 1,
    );
    final isLikedResult = await _repository.isLiked(
      targetType: targetType,
      targetId: targetId,
    );

    final merged = Map<String, InteractionStatsItemState>.from(state.items);
    final existing = merged[key] ?? const InteractionStatsItemState.idle();
    final likeCount = likeCountResult.isSuccess
        ? (likeCountResult.data ?? existing.likeCount)
        : existing.likeCount;
    final commentCount = commentPageResult.isSuccess
        ? (commentPageResult.data?.totalElements ?? existing.commentCount)
        : existing.commentCount;
    final isLiked = isLikedResult.isSuccess
        ? (isLikedResult.data ?? existing.isLiked)
        : existing.isLiked;

    final hardError = likeCountResult.error ?? commentPageResult.error;
    merged[key] = existing.copyWith(
      loading: false,
      likeCount: likeCount,
      commentCount: commentCount,
      isLiked: isLiked,
      error: hardError,
    );
    _inFlight.remove(key);
    emit(state.copyWith(items: merged));
  }

  Future<void> toggleLike({
    required String targetType,
    required String targetId,
  }) async {
    final key = _key(targetType, targetId);
    final existing = state.items[key] ?? const InteractionStatsItemState.idle();
    final next = Map<String, InteractionStatsItemState>.from(state.items);
    next[key] = existing.copyWith(
      isLiked: !existing.isLiked,
      likeCount: (existing.likeCount + (existing.isLiked ? -1 : 1)).clamp(0, 1 << 30),
      loading: true,
      error: null,
    );
    emit(state.copyWith(items: next));

    final result = existing.isLiked
        ? await _repository.unlike(targetType: targetType, targetId: targetId)
        : await _repository.like(targetType: targetType, targetId: targetId);

    if (!result.isSuccess) {
      final rollback = Map<String, InteractionStatsItemState>.from(state.items);
      rollback[key] = existing.copyWith(loading: false, error: result.error);
      emit(state.copyWith(items: rollback));
      return;
    }

    await load(targetType: targetType, targetId: targetId, force: true);
  }
}
