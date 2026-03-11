import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/follow_repository.dart';
import 'follow_count_state.dart';

class FollowCountCubit extends Cubit<FollowCountState> {
  final FollowRepository _repository;

  FollowCountCubit(this._repository) : super(const FollowCountState.idle());

  Future<void> loadCounts(String userId) async {
    emit(state.copyWith(status: FollowCountStatus.loading));
    final followersResult = await _repository.getFollowersCount(userId);
    final followingResult = await _repository.getFollowingCount(userId);

    final followersCount = followersResult.data ?? 0;
    final followingCount = followingResult.data ?? 0;

    if (followersResult.isSuccess && followingResult.isSuccess) {
      emit(state.copyWith(
        status: FollowCountStatus.success,
        followersCount: followersCount,
        followingCount: followingCount,
      ));
      return;
    }

    emit(state.copyWith(
      status: FollowCountStatus.failure,
      followersCount: followersCount,
      followingCount: followingCount,
      error: followersResult.error ?? followingResult.error,
    ));
  }
}
