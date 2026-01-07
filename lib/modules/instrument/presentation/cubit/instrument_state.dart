import '../../../../core/error/app_error.dart';
import '../../domain/entities/instrument.dart';

enum InstrumentStatus { idle, loading, success, failure }

class InstrumentState {
  final InstrumentStatus status;
  final List<Instrument> instruments;
  final AppError? error;

  const InstrumentState({
    required this.status,
    required this.instruments,
    this.error,
  });

  const InstrumentState.idle()
      : status = InstrumentStatus.idle,
        instruments = const [],
        error = null;

  InstrumentState copyWith({
    InstrumentStatus? status,
    List<Instrument>? instruments,
    AppError? error,
  }) {
    return InstrumentState(
      status: status ?? this.status,
      instruments: instruments ?? this.instruments,
      error: error ?? this.error,
    );
  }
}
