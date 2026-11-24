import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/dm_message.dart';

enum DmChatStatus { idle, loading, loadingMore, success, failure }

class DmChatState {
  final DmChatStatus status;
  final List<DmMessage> messages;
  final bool sending;
  final AppError? error;
  final String? conversationId;
  final int page;
  final bool hasNext;
  final bool recipientDeleted;
  final bool interactionBlocked;
  final bool blockedByMe;
  final bool blockStatusKnown;

  const DmChatState({
    required this.status,
    required this.messages,
    required this.sending,
    required this.error,
    required this.conversationId,
    required this.page,
    required this.hasNext,
    this.recipientDeleted = false,
    this.interactionBlocked = false,
    this.blockedByMe = false,
    this.blockStatusKnown = true,
  });

  const DmChatState.idle()
    : status = DmChatStatus.idle,
      messages = const <DmMessage>[],
      sending = false,
      error = null,
      conversationId = null,
      page = 0,
      hasNext = false,
      recipientDeleted = false,
      interactionBlocked = false,
      blockedByMe = false,
      blockStatusKnown = true;

  DmChatState copyWith({
    DmChatStatus? status,
    List<DmMessage>? messages,
    bool? sending,
    Object? error = copyWithUnset,
    Object? conversationId = copyWithUnset,
    int? page,
    bool? hasNext,
    bool? recipientDeleted,
    bool? interactionBlocked,
    bool? blockedByMe,
    bool? blockStatusKnown,
  }) {
    return DmChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
      conversationId: identical(conversationId, copyWithUnset)
          ? this.conversationId
          : conversationId as String?,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      recipientDeleted: recipientDeleted ?? this.recipientDeleted,
      interactionBlocked: interactionBlocked ?? this.interactionBlocked,
      blockedByMe: blockedByMe ?? this.blockedByMe,
      blockStatusKnown: blockStatusKnown ?? this.blockStatusKnown,
    );
  }
}
