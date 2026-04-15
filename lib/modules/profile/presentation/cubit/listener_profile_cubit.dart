import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/listener_profile_repository.dart';
import 'listener_profile_state.dart';

class ListenerProfileCubit extends Cubit<ListenerProfileState> {
  final ListenerProfileRepository _repository;

  ListenerProfileCubit(this._repository)
    : super(const ListenerProfileState.idle());

  Future<void> loadMyProfile() async {
    emit(state.copyWith(status: ListenerProfileStatus.loading, error: null));
    final result = await _repository.getMyProfile();
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: ListenerProfileStatus.success,
          profile: result.data,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: ListenerProfileStatus.failure,
        error: result.error,
      ),
    );
  }
}
