import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';

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
    Object? error = copyWithUnset,
  }) {
    return FollowCountState(
      status: status ?? this.status,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}
