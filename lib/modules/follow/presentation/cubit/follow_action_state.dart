import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';

enum FollowActionStatus { idle, loading, success, failure }

class FollowActionState {
  final FollowActionStatus status;
  final bool isFollowing;
  final AppError? error;

  const FollowActionState({
    required this.status,
    required this.isFollowing,
    this.error,
  });

  const FollowActionState.idle()
    : status = FollowActionStatus.idle,
      isFollowing = false,
      error = null;

  FollowActionState copyWith({
    FollowActionStatus? status,
    bool? isFollowing,
    Object? error = copyWithUnset,
  }) {
    return FollowActionState(
      status: status ?? this.status,
      isFollowing: isFollowing ?? this.isFollowing,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
