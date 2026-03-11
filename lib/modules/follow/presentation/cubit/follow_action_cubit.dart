import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/follow_repository.dart';
import 'follow_action_state.dart';

class FollowActionCubit extends Cubit<FollowActionState> {
  final FollowRepository _repository;

  FollowActionCubit(this._repository) : super(const FollowActionState.idle());

  Future<void> loadStatus({
    required String followerId,
    required String followingId,
  }) async {
    emit(state.copyWith(status: FollowActionStatus.loading));
    final result = await _repository.isFollowing(
      followerId: followerId,
      followingId: followingId,
    );
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: FollowActionStatus.success,
        isFollowing: result.data!,
      ));
      return;
    }
    emit(state.copyWith(
      status: FollowActionStatus.failure,
      error: result.error,
    ));
  }

  Future<void> toggleFollow({
    required String followerId,
    required String followingId,
  }) async {
    emit(state.copyWith(status: FollowActionStatus.loading));
    final isFollowing = state.isFollowing;
    final result = isFollowing
        ? await _repository.unfollow(
            followerId: followerId,
            followingId: followingId,
          )
        : await _repository.follow(
            followerId: followerId,
            followingId: followingId,
          );

    if (result.isSuccess) {
      emit(state.copyWith(
        status: FollowActionStatus.success,
        isFollowing: !isFollowing,
      ));
      return;
    }

    emit(state.copyWith(
      status: FollowActionStatus.failure,
      error: result.error,
    ));
  }
}
