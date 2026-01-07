import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/instrument_repository.dart';
import 'instrument_state.dart';

class InstrumentCubit extends Cubit<InstrumentState> {
  final InstrumentRepository _repository;

  InstrumentCubit(this._repository) : super(const InstrumentState.idle());

  Future<void> loadAll() async {
    emit(state.copyWith(status: InstrumentStatus.loading));
    final result = await _repository.getAll();
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(
        status: InstrumentStatus.success,
        instruments: result.data!,
      ));
      return;
    }
    emit(state.copyWith(
      status: InstrumentStatus.failure,
      error: result.error,
    ));
  }
}
