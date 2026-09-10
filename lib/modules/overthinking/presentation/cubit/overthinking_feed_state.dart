import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/overthinking_post.dart';
import '../../domain/overthinking_feed_sort.dart';

enum OverthinkingFeedStatus { idle, loading, loadingMore, failure }

class OverthinkingFeedState {
  final OverthinkingFeedStatus status;
  final List<OverthinkingPost> posts;
  final bool hasNext;
  final int page;
  final OverthinkingFeedSort sort;
  final bool submitting;
  final bool deleting;
  final Set<String> revealRequestingIds;
  final AppError? error;

  const OverthinkingFeedState({
    required this.status,
    required this.posts,
    required this.hasNext,
    required this.page,
    this.sort = OverthinkingFeedSort.newest,
    required this.submitting,
    required this.deleting,
    required this.revealRequestingIds,
    this.error,
  });

  const OverthinkingFeedState.initial()
    : status = OverthinkingFeedStatus.idle,
      posts = const [],
      hasNext = false,
      page = 0,
      sort = OverthinkingFeedSort.newest,
      submitting = false,
      deleting = false,
      revealRequestingIds = const <String>{},
      error = null;

  OverthinkingFeedState copyWith({
    OverthinkingFeedStatus? status,
    List<OverthinkingPost>? posts,
    bool? hasNext,
    int? page,
    OverthinkingFeedSort? sort,
    bool? submitting,
    bool? deleting,
    Set<String>? revealRequestingIds,
    Object? error = copyWithUnset,
  }) {
    return OverthinkingFeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      hasNext: hasNext ?? this.hasNext,
      page: page ?? this.page,
      sort: sort ?? this.sort,
      submitting: submitting ?? this.submitting,
      deleting: deleting ?? this.deleting,
      revealRequestingIds: revealRequestingIds ?? this.revealRequestingIds,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
