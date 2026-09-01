import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/table_group_venue_option.dart';
import '../domain/table_group_venue_option_repository.dart';
import 'models/table_group_venue_option_model.dart';
import 'table_group_endpoints.dart';

class TableGroupVenueOptionRepositoryImpl
    implements TableGroupVenueOptionRepository {
  const TableGroupVenueOptionRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<List<TableGroupVenueOption>>> search({
    required String query,
    int limit = 8,
  }) async {
    final normalizedQuery = query.trim();
    final normalizedLimit = limit.clamp(1, 8).toInt();
    if (normalizedQuery.length < 2 || normalizedQuery.length > 64) {
      return const Result<List<TableGroupVenueOption>>.success(
        <TableGroupVenueOption>[],
      );
    }
    try {
      final response = await _apiClient.get<List<TableGroupVenueOption>>(
        TableGroupEndpoints.venueOptions,
        query: <String, dynamic>{
          'q': normalizedQuery,
          'limit': normalizedLimit,
        },
        decoder: (json) {
          if (json is! List) {
            throw const FormatException('Invalid venue options response');
          }
          final byId = <String, TableGroupVenueOption>{};
          for (final item in json) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid venue option item');
            }
            final option = TableGroupVenueOptionModel.fromJson(item);
            byId.putIfAbsent(option.id, () => option);
            if (byId.length >= normalizedLimit) break;
          }
          return List<TableGroupVenueOption>.unmodifiable(byId.values);
        },
      );
      return Result<List<TableGroupVenueOption>>.success(response);
    } on ApiException catch (error) {
      return Result<List<TableGroupVenueOption>>.failure(error.error);
    } catch (_) {
      return const Result<List<TableGroupVenueOption>>.failure(
        AppError(
          code: 'table_group_venue_options_unknown',
          message: 'Kayıtlı mekânlar aranamadı.',
        ),
      );
    }
  }
}
