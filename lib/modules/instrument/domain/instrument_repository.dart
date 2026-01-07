import '../../../core/error/result.dart';
import 'entities/instrument.dart';

abstract class InstrumentRepository {
  Future<Result<List<Instrument>>> getAll();
}
