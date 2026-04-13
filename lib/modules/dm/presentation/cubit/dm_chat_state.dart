import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/dm_message.dart';

enum DmChatStatus { idle, loading, success, failure }

class DmChatState {
  final DmChatStatus status;
  final List<DmMessage> messages;
  final bool sending;
  final AppError? error;
  final String? conversationId;

  const DmChatState({
    required this.status,
    required this.messages,
    required this.sending,
    required this.error,
    required this.conversationId,
  });

  const DmChatState.idle()
    : status = DmChatStatus.idle,
      messages = const <DmMessage>[],
      sending = false,
      error = null,
      conversationId = null;

  DmChatState copyWith({
    DmChatStatus? status,
    List<DmMessage>? messages,
    bool? sending,
    Object? error = copyWithUnset,
    Object? conversationId = copyWithUnset,
  }) {
    return DmChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
      conversationId: identical(conversationId, copyWithUnset)
          ? this.conversationId
          : conversationId as String?,
    );
  }
}
