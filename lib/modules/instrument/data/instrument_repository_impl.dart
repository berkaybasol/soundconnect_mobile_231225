import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/instrument_repository.dart';
import '../domain/entities/instrument.dart';
import 'instrument_endpoints.dart';
import 'models/instrument_model.dart';

class InstrumentRepositoryImpl implements InstrumentRepository {
  final ApiClient _apiClient;

  InstrumentRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<Instrument>>> getAll() async {
    try {
      final response = await _apiClient.get<List<Instrument>>(
        InstrumentEndpoints.list,
        decoder: (json) {
          final list = (json as List<dynamic>? ?? [])
              .map((item) => InstrumentModel.fromJson(
                    item as Map<String, dynamic>,
                  ))
              .toList();
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'instruments_unknown',
        message: 'Enstruman listesi alinamadi',
      ));
    }
  }
}
