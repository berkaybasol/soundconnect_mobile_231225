import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_music_join_tables.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';

void main() {
  group('Müzik Birleştirir masa listesi', () {
    test('kart başlığında mekan yerine açıklamayı kullanır', () {
      final table = _table(
        id: 'table-1',
        description: '  Biseylerrr  ',
        venueName: 'scankara',
      );

      expect(dmMusicJoinTableTitle(table), 'Biseylerrr');
      expect(
        dmMusicJoinTableTitle(
          _table(id: 'legacy', description: ' ', venueName: 'scankara'),
        ),
        'scankara',
      );
      expect(
        dmMusicJoinTableTitle(
          _table(id: 'fallback', description: null, venueName: null),
        ),
        'Müzik Birleştirir! masası',
      );
    });

    test('şehir akışını taramadan kullanıcıya özel sayfaları yükler', () async {
      final repository = _MineTableRepository(<int, Page<TableGroup>>{
        0: Page<TableGroup>(
          items: <TableGroup>[
            _table(
              id: 'older',
              description: 'Eski masa',
              expiresAt: DateTime.utc(2026, 9, 2, 20),
            ),
          ],
          hasNext: true,
        ),
        1: Page<TableGroup>(
          items: <TableGroup>[
            _table(
              id: 'newer',
              description: 'Yeni masa',
              expiresAt: DateTime.utc(2026, 9, 2, 22),
            ),
          ],
          hasNext: false,
        ),
      });

      final result = await loadDmMusicJoinTables(repository);

      expect(result.isSuccess, isTrue);
      expect(result.data?.map((table) => table.id), <String>['newer', 'older']);
      expect(repository.mineRequests, <(int, int)>[(0, 50), (1, 50)]);
      expect(repository.activeFeedRequests, 0);
    });

    test('sonraki sayfa hatasını eksik liste olarak gizlemez', () async {
      const pageError = AppError(
        code: 'network_timeout',
        message: 'Bağlantı zaman aşımına uğradı',
      );
      final repository = _MineTableRepository(
        <int, Page<TableGroup>>{
          0: Page<TableGroup>(
            items: <TableGroup>[
              _table(id: 'partial', description: 'Eksik kalacak masa'),
            ],
            hasNext: true,
          ),
        },
        errors: const <int, AppError>{1: pageError},
      );

      final result = await loadDmMusicJoinTables(repository);

      expect(result.isSuccess, isFalse);
      expect(result.error, same(pageError));
      expect(result.data, isNull);
      expect(repository.mineRequests, <(int, int)>[(0, 50), (1, 50)]);
    });
  });
}

class _MineTableRepository extends Fake implements TableGroupRepository {
  _MineTableRepository(this.pages, {this.errors = const <int, AppError>{}});

  final Map<int, Page<TableGroup>> pages;
  final Map<int, AppError> errors;
  final List<(int, int)> mineRequests = <(int, int)>[];
  int activeFeedRequests = 0;

  @override
  Future<Result<Page<TableGroup>>> listMyActiveTableGroups({
    int page = 0,
    int size = 50,
  }) async {
    mineRequests.add((page, size));
    final error = errors[page];
    if (error != null) return Result.failure(error);
    return Result.success(
      pages[page] ?? const Page<TableGroup>(items: [], hasNext: false),
    );
  }

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    activeFeedRequests += 1;
    return const Result.success(Page<TableGroup>(items: [], hasNext: false));
  }
}

TableGroup _table({
  required String id,
  String? description,
  String? venueName,
  DateTime? expiresAt,
}) {
  return TableGroup(
    id: id,
    ownerId: 'owner-1',
    ownerUsername: 'bugrasahin',
    ownerProfileImageUrl: null,
    venueId: null,
    venueName: venueName,
    description: description,
    maxPersonCount: 4,
    genderPrefs: const <String>['MALE', 'FEMALE', 'OTHER', 'OTHER'],
    ageMin: 19,
    ageMax: 99,
    meetingAt: DateTime.utc(2026, 9, 2, 18),
    expiresAt: expiresAt ?? DateTime.utc(2026, 9, 3),
    status: 'ACTIVE',
    participants: const [],
    city: const TableGroupLocation(id: 'city-1', name: 'Ankara'),
    district: null,
    neighborhood: null,
  );
}
