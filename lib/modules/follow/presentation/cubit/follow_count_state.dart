import '../../../../core/error/app_error.dart';

enum FollowCountStatus { idle, loading, success, failure }

class FollowCountState {
  final FollowCountStatus status;
  final int followersCount;
  final int followingCount;
  final AppError? error;

  const FollowCountState({
    required this.status,
    required this.followersCount,
    required this.followingCount,
    this.error,
  });

  const FollowCountState.idle()
      : status = FollowCountStatus.idle,
        followersCount = 0,
        followingCount = 0,
        error = null;

  FollowCountState copyWith({
    FollowCountStatus? status,
    int? followersCount,
    int? followingCount,
    AppError? error,
  }) {
    return FollowCountState(
      status: status ?? this.status,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      error: error ?? this.error,
    );
  }
}
