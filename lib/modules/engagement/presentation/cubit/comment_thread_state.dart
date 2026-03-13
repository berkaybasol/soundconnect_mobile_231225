import '../../../../core/error/app_error.dart';
import '../../domain/entities/comment_item.dart';

class CommentThreadState {
  final bool loading;
  final bool submitting;
  final List<CommentItem> comments;
  final AppError? error;

  const CommentThreadState({
    required this.loading,
    required this.submitting,
    required this.comments,
    this.error,
  });

  const CommentThreadState.initial()
      : loading = false,
        submitting = false,
        comments = const [],
        error = null;

  CommentThreadState copyWith({
    bool? loading,
    bool? submitting,
    List<CommentItem>? comments,
    AppError? error,
  }) {
    return CommentThreadState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      comments: comments ?? this.comments,
      error: error ?? this.error,
    );
  }
}
