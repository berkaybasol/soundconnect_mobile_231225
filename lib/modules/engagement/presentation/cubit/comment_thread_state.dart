import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/comment_item.dart';

class CommentThreadState {
  final bool loading;
  final bool submitting;
  final List<CommentItem> comments;
  final AppError? error;
  final AppError? reloadError;
  final bool loadingMore;
  final int totalElements;
  final bool hasMore;
  final CommentItem? lastCreated;
  final String? deletingCommentId;

  const CommentThreadState({
    required this.loading,
    required this.submitting,
    required this.comments,
    this.error,
    this.reloadError,
    this.loadingMore = false,
    this.totalElements = 0,
    this.hasMore = false,
    this.lastCreated,
    this.deletingCommentId,
  });

  const CommentThreadState.initial()
    : loading = false,
      submitting = false,
      comments = const [],
      error = null,
      reloadError = null,
      loadingMore = false,
      totalElements = 0,
      hasMore = false,
      lastCreated = null,
      deletingCommentId = null;

  CommentThreadState copyWith({
    bool? loading,
    bool? submitting,
    List<CommentItem>? comments,
    Object? error = copyWithUnset,
    Object? reloadError = copyWithUnset,
    bool? loadingMore,
    int? totalElements,
    bool? hasMore,
    Object? lastCreated = copyWithUnset,
    Object? deletingCommentId = copyWithUnset,
  }) {
    return CommentThreadState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      comments: comments ?? this.comments,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
      reloadError: identical(reloadError, copyWithUnset)
          ? this.reloadError
          : reloadError as AppError?,
      loadingMore: loadingMore ?? this.loadingMore,
      totalElements: totalElements ?? this.totalElements,
      hasMore: hasMore ?? this.hasMore,
      lastCreated: identical(lastCreated, copyWithUnset)
          ? this.lastCreated
          : lastCreated as CommentItem?,
      deletingCommentId: identical(deletingCommentId, copyWithUnset)
          ? this.deletingCommentId
          : deletingCommentId as String?,
    );
  }
}
