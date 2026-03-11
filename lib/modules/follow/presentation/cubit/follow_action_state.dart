import '../../../../core/error/app_error.dart';

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
    AppError? error,
  }) {
    return FollowActionState(
      status: status ?? this.status,
      isFollowing: isFollowing ?? this.isFollowing,
      error: error ?? this.error,
    );
  }
}
