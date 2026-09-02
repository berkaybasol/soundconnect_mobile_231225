import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../tablegroup/domain/entities/table_group.dart';
import '../../../tablegroup/domain/table_group_repository.dart';

const int dmMusicJoinTablePageSize = 50;

const AppError _musicJoinTablesFallbackError = AppError(
  code: 'dm_music_join_tables_unknown',
  message: 'Masa listesi alınamadı',
);

/// Loads only the authenticated user's active tables from the server-scoped
/// endpoint. Pagination is followed defensively even though the product's
/// active-table invariant normally keeps this list very small.
Future<Result<List<TableGroup>>> loadDmMusicJoinTables(
  TableGroupRepository repository, {
  int pageSize = dmMusicJoinTablePageSize,
  int maxPages = 25,
  bool Function()? shouldCancel,
}) async {
  if (pageSize < 1 || maxPages < 1) {
    return const Result.failure(_musicJoinTablesFallbackError);
  }

  final tablesById = <String, TableGroup>{};
  for (var page = 0; page < maxPages; page += 1) {
    if (shouldCancel?.call() ?? false) {
      return const Result.failure(
        AppError(
          code: 'dm_music_join_tables_cancelled',
          message: 'Masa listesi yüklemesi iptal edildi',
        ),
      );
    }
    final result = await repository.listMyActiveTableGroups(
      page: page,
      size: pageSize,
    );
    final data = result.data;
    if (!result.isSuccess || data == null) {
      return Result.failure(result.error ?? _musicJoinTablesFallbackError);
    }

    for (final table in data.items) {
      tablesById[table.id] = table;
    }
    if (!data.hasNext) {
      final tables = tablesById.values.toList()
        ..sort((a, b) {
          final expiresComparison = (b.expiresAt?.millisecondsSinceEpoch ?? 0)
              .compareTo(a.expiresAt?.millisecondsSinceEpoch ?? 0);
          return expiresComparison != 0
              ? expiresComparison
              : a.id.compareTo(b.id);
        });
      return Result.success(List<TableGroup>.unmodifiable(tables));
    }
  }

  return const Result.failure(
    AppError(
      code: 'dm_music_join_tables_page_limit',
      message: 'Masa listesi tamamlanamadı',
    ),
  );
}

/// The table's description is its user-authored subject. Venue is only a
/// compatibility fallback for terminal/legacy rows without a description.
String dmMusicJoinTableTitle(TableGroup table) {
  final description = (table.description ?? '').trim();
  if (description.isNotEmpty) return description;

  final venueName = (table.venueName ?? '').trim();
  return venueName.isNotEmpty ? venueName : 'Müzik Birleştirir! masası';
}
