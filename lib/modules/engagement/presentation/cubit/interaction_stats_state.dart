import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';

class InteractionStatsItemState {
  final bool loading;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final AppError? error;

  const InteractionStatsItemState({
    required this.loading,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    this.error,
  });

  const InteractionStatsItemState.idle()
    : loading = false,
      likeCount = 0,
      commentCount = 0,
      isLiked = false,
      error = null;

  InteractionStatsItemState copyWith({
    bool? loading,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    Object? error = copyWithUnset,
  }) {
    return InteractionStatsItemState(
      loading: loading ?? this.loading,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}

class InteractionStatsState {
  final Map<String, InteractionStatsItemState> items;

  const InteractionStatsState({required this.items});

  const InteractionStatsState.initial() : items = const {};

  InteractionStatsState copyWith({
    Map<String, InteractionStatsItemState>? items,
  }) {
    return InteractionStatsState(items: items ?? this.items);
  }
}
