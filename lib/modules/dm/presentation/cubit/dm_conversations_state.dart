import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/dm_conversation_preview.dart';

enum DmConversationsStatus { idle, loading, success, failure }

class DmConversationsState {
  final DmConversationsStatus status;
  final List<DmConversationPreview> items;
  final AppError? error;

  const DmConversationsState({
    required this.status,
    required this.items,
    required this.error,
  });

  const DmConversationsState.idle()
    : status = DmConversationsStatus.idle,
      items = const <DmConversationPreview>[],
      error = null;

  DmConversationsState copyWith({
    DmConversationsStatus? status,
    List<DmConversationPreview>? items,
    Object? error = copyWithUnset,
  }) {
    return DmConversationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
