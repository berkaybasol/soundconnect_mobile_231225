import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/dm_conversation_preview.dart';

enum DmConversationsStatus { idle, loading, success, failure }

class DmConversationsState {
  final DmConversationsStatus status;
  final List<DmConversationPreview> items;
  final AppError? error;
  final bool hasNext;
  final String? nextCursor;
  final bool loadingMore;
  final AppError? loadMoreError;

  const DmConversationsState({
    required this.status,
    required this.items,
    required this.error,
    this.hasNext = false,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  const DmConversationsState.idle()
    : status = DmConversationsStatus.idle,
      items = const <DmConversationPreview>[],
      error = null,
      hasNext = false,
      nextCursor = null,
      loadingMore = false,
      loadMoreError = null;

  DmConversationsState copyWith({
    DmConversationsStatus? status,
    List<DmConversationPreview>? items,
    Object? error = copyWithUnset,
    bool? hasNext,
    Object? nextCursor = copyWithUnset,
    bool? loadingMore,
    Object? loadMoreError = copyWithUnset,
  }) {
    return DmConversationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
      hasNext: hasNext ?? this.hasNext,
      nextCursor: identical(nextCursor, copyWithUnset)
          ? this.nextCursor
          : nextCursor as String?,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError: identical(loadMoreError, copyWithUnset)
          ? this.loadMoreError
          : loadMoreError as AppError?,
    );
  }
}
