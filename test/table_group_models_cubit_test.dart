import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_create_request.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_message_model.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_model.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_message.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_participant.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_create_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_create_state.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_list_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_list_state.dart';

void main() {
  group('table group models', () {
    test('parses aliases, locations, participant states, and counts', () {
      final model = TableGroupModel.fromJson(<String, dynamic>{
        'id': 17,
        'ownerId': 'owner-1',
        'owner_name': 'Ada',
        'ownerAvatarUrl': 'avatar.jpg',
        'maxPersonCount': 6.8,
        'genderPrefs': <Object?>['FEMALE', 4],
        'ageMin': 21,
        'expiresAt': '2026-07-13T22:00:00Z',
        'participants': <Object?>[
          <String, dynamic>{
            'userId': 'u-1',
            'status': 'accepted',
            'displayName': 'Deniz',
            'avatarUrl': 'deniz.jpg',
          },
          <String, dynamic>{'userId': 'u-2', 'status': 'REJECTED'},
          <String, dynamic>{'userId': 'u-3', 'status': 'unexpected'},
          'ignored',
        ],
        'city': <String, dynamic>{'id': '34', 'name': 'Istanbul'},
        'district': <String, dynamic>{'id': 'kadikoy', 'name': 'Kadikoy'},
      });

      expect(model.id, '17');
      expect(model.ownerUsername, 'Ada');
      expect(model.ownerProfileImageUrl, 'avatar.jpg');
      expect(model.maxPersonCount, 6);
      expect(model.genderPrefs, <String>['FEMALE', '4']);
      expect(model.ageMax, 99);
      expect(model.expiresAt, DateTime.utc(2026, 7, 13, 22));
      expect(model.city.name, 'Istanbul');
      expect(model.district?.id, 'kadikoy');
      expect(model.neighborhood, isNull);
      expect(model.participants, hasLength(3));
      expect(
        model.participants[0].status,
        TableGroupParticipantStatus.accepted,
      );
      expect(model.participants[0].username, 'Deniz');
      expect(
        model.participants[1].status,
        TableGroupParticipantStatus.rejected,
      );
      expect(model.participants[2].status, TableGroupParticipantStatus.pending);
      expect(model.acceptedCount, 1);
    });

    test(
      'supplies stable defaults for missing location and malformed dates',
      () {
        final model = TableGroupModel.fromJson(<String, dynamic>{
          'expiresAt': 'bad-date',
          'participants': const <Object?>[],
        });
        final message = TableGroupMessageModel.fromJson(<String, dynamic>{
          'messageId': 4,
          'sentAt': '',
          'deletedAt': 'invalid',
        });

        expect(model.city.id, isEmpty);
        expect(model.city.name, 'Bilinmiyor');
        expect(model.expiresAt, isNull);
        expect(model.status, 'ACTIVE');
        expect(message.messageId, '4');
        expect(message.messageType, 'TEXT');
        expect(message.sentAt, isNull);
        expect(message.deletedAt, isNull);
      },
    );

    test(
      'create request retains nullable filters and exact expiry instant',
      () {
        final expiry = DateTime.utc(2026, 7, 14, 1, 2, 3);
        final request = TableGroupCreateRequest(
          venueId: null,
          venueName: 'Open air',
          maxPersonCount: 5,
          genderPrefs: const <String>['ALL'],
          ageMin: 18,
          ageMax: 35,
          expiresAt: expiry,
          cityId: '34',
          districtId: null,
          neighborhoodId: 'n-1',
        );

        expect(request.toJson(), <String, dynamic>{
          'venueId': null,
          'venueName': 'Open air',
          'maxPersonCount': 5,
          'genderPrefs': <String>['ALL'],
          'ageMin': 18,
          'ageMax': 35,
          'expiresAt': '2026-07-14T01:02:03.000Z',
          'cityId': '34',
          'districtId': null,
          'neighborhoodId': 'n-1',
        });
      },
    );
  });

  group('TableGroupRepositoryImpl', () {
    test(
      'uses active path and omits null location filters from query',
      () async {
        final apiClient = _TableGroupApiClientFake((method, path, query, body) {
          return <String, dynamic>{
            'number': 4,
            'hasNext': true,
            'content': <Object?>[
              <String, dynamic>{
                'id': 'g-1',
                'city': <String, dynamic>{'id': 'city-1', 'name': 'City'},
              },
            ],
          };
        });
        final repository = TableGroupRepositoryImpl(apiClient);

        final result = await repository.listActiveTableGroups(
          cityId: 'city-1',
          districtId: null,
          neighborhoodId: 'neighborhood-1',
          page: 4,
          size: 9,
        );

        expect(result.data?.items.single.id, 'g-1');
        expect(result.data?.nextCursor, '5');
        expect(apiClient.lastMethod, 'GET');
        expect(apiClient.lastPath, TableGroupEndpoints.active);
        expect(apiClient.lastQuery, <String, dynamic>{
          'cityId': 'city-1',
          'neighborhoodId': 'neighborhood-1',
          'page': 4,
          'size': 9,
        });
      },
    );

    test(
      'trims join note and serializes chat message body over POST',
      () async {
        final apiClient = _TableGroupApiClientFake((method, path, query, body) {
          if (path == TableGroupEndpoints.chatMessages('g-1')) {
            return <String, dynamic>{
              'messageId': 'm-1',
              'tableGroupId': 'g-1',
              'content': 'Hello',
            };
          }
          return null;
        });
        final repository = TableGroupRepositoryImpl(apiClient);

        await repository.joinTableGroup(tableGroupId: 'g-1', note: '  Hi  ');
        expect(apiClient.lastMethod, 'POST');
        expect(apiClient.lastPath, TableGroupEndpoints.join('g-1'));
        expect(apiClient.lastBody, <String, dynamic>{'note': 'Hi'});

        final sent = await repository.sendChatMessage(
          tableGroupId: 'g-1',
          content: 'Hello',
          messageType: 'TEXT',
        );
        expect(sent.data?.messageId, 'm-1');
        expect(apiClient.lastMethod, 'POST');
        expect(apiClient.lastPath, TableGroupEndpoints.chatMessages('g-1'));
        expect(apiClient.lastBody, <String, dynamic>{
          'content': 'Hello',
          'messageType': 'TEXT',
        });
      },
    );

    test(
      'preserves typed errors and maps unexpected create payloads',
      () async {
        const error = AppError(code: '409', message: 'Conflict');
        final typedRepository = TableGroupRepositoryImpl(
          _TableGroupApiClientFake(
            (_, __, ___, ____) => throw ApiException(error),
          ),
        );
        final unknownRepository = TableGroupRepositoryImpl(
          _TableGroupApiClientFake((_, __, ___, ____) => 'invalid-group'),
        );
        final request = TableGroupCreateRequest(
          venueId: null,
          venueName: 'Cafe',
          maxPersonCount: 4,
          genderPrefs: const <String>[],
          ageMin: 18,
          ageMax: 99,
          expiresAt: DateTime.utc(2026, 7, 14),
          cityId: 'city-1',
          districtId: null,
          neighborhoodId: null,
        );

        final typedResult = await typedRepository.getDetail('g-1');
        final unknownResult = await unknownRepository.createTableGroup(request);

        expect(typedResult.error, same(error));
        expect(unknownResult.error?.code, 'table_group_create_unknown');
      },
    );
  });

  group('TableGroupListCubit', () {
    test('initializes filters, reloads hierarchy, and paginates', () async {
      final tableRepository = _TableGroupRepositoryFake(
        pages: <int, Result<Page<TableGroup>>>{
          0: Result.success(
            Page<TableGroup>(items: <TableGroup>[_group('g-1')], hasNext: true),
          ),
          1: Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('g-2')],
              hasNext: false,
            ),
          ),
        },
      );
      final locationRepository = _LocationRepositoryFake();
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locationRepository,
      );
      addTearDown(cubit.close);

      await cubit.initialize();
      await cubit.setDistrict('district-1');
      await cubit.setNeighborhood('neighborhood-1');
      await cubit.loadMore();

      expect(cubit.state.status, TableGroupListStatus.idle);
      expect(cubit.state.selectedCityId, 'city-1');
      expect(cubit.state.selectedDistrictId, 'district-1');
      expect(cubit.state.selectedNeighborhoodId, 'neighborhood-1');
      expect(cubit.state.neighborhoods.single.id, 'neighborhood-1');
      expect(cubit.state.items.map((item) => item.id), <String>['g-1', 'g-2']);
      expect(cubit.state.page, 1);
      expect(cubit.state.hasNext, isFalse);
      expect(tableRepository.lastCityId, 'city-1');
      expect(tableRepository.lastDistrictId, 'district-1');
      expect(tableRepository.lastNeighborhoodId, 'neighborhood-1');
      expect(tableRepository.requestedPages.last, 1);
    });

    test('clearing city resets dependent selections and results', () async {
      final cubit = TableGroupListCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: _LocationRepositoryFake(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.setCity(null);

      expect(cubit.state.selectedCityId, isNull);
      expect(cubit.state.selectedDistrictId, isNull);
      expect(cubit.state.selectedNeighborhoodId, isNull);
      expect(cubit.state.districts, isEmpty);
      expect(cubit.state.neighborhoods, isEmpty);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.page, 0);
    });

    test('join failure clears in-flight id and exposes typed error', () async {
      const error = AppError(code: 'full', message: 'Group is full');
      final tableRepository = _TableGroupRepositoryFake(
        joinResult: const Result.failure(error),
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: _LocationRepositoryFake(),
      );
      addTearDown(cubit.close);

      final joined = await cubit.joinTableGroup(
        tableGroupId: 'g-1',
        note: 'Hello',
      );

      expect(joined, isFalse);
      expect(cubit.state.joiningIds, isEmpty);
      expect(cubit.state.status, TableGroupListStatus.failure);
      expect(cubit.state.error, same(error));
      expect(tableRepository.lastJoinNote, 'Hello');
    });
  });

  group('TableGroupCreateCubit', () {
    test(
      'loads locations and transitions across failed and successful submit',
      () async {
        const error = AppError(code: 'invalid', message: 'Invalid');
        final repository = _TableGroupRepositoryFake(
          createResult: const Result.failure(error),
        );
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: repository,
          locationRepository: _LocationRepositoryFake(),
        );
        addTearDown(cubit.close);
        final request = TableGroupCreateRequest(
          venueId: null,
          venueName: 'Cafe',
          maxPersonCount: 4,
          genderPrefs: const <String>[],
          ageMin: 18,
          ageMax: 99,
          expiresAt: DateTime.utc(2026, 7, 14),
          cityId: 'city-1',
          districtId: null,
          neighborhoodId: null,
        );

        await cubit.loadCities();
        final failed = await cubit.createTableGroup(request);

        expect(failed, isFalse);
        expect(cubit.state.status, TableGroupCreateStatus.failure);
        expect(cubit.state.error, same(error));

        repository.createResult = Result.success(_group('created'));
        final succeeded = await cubit.createTableGroup(request);

        expect(cubit.state.cities.single.id, 'city-1');
        expect(succeeded, isTrue);
        expect(cubit.state.status, TableGroupCreateStatus.success);
        expect(cubit.state.error, isNull);
      },
    );
  });
}

TableGroup _group(String id) {
  return TableGroup(
    id: id,
    ownerId: 'owner',
    ownerUsername: 'Owner',
    ownerProfileImageUrl: null,
    venueId: null,
    venueName: null,
    maxPersonCount: 4,
    genderPrefs: const <String>[],
    ageMin: 18,
    ageMax: 99,
    expiresAt: null,
    status: 'ACTIVE',
    participants: const <TableGroupParticipant>[],
    city: const TableGroupLocation(id: 'city-1', name: 'City'),
    district: null,
    neighborhood: null,
  );
}

class _LocationRepositoryFake implements LocationRepository {
  Result<List<City>> cities = const Result.success(<City>[
    City(id: 'city-1', name: 'City'),
  ]);
  Result<List<District>> districts = const Result.success(<District>[
    District(id: 'district-1', name: 'District', cityId: 'city-1'),
  ]);
  Result<List<Neighborhood>> neighborhoods = const Result.success(
    <Neighborhood>[
      Neighborhood(
        id: 'neighborhood-1',
        name: 'Neighborhood',
        districtId: 'district-1',
      ),
    ],
  );

  @override
  Future<Result<List<City>>> getCities() async => cities;

  @override
  Future<Result<List<District>>> getDistricts(String cityId) async => districts;

  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(
    String districtId,
  ) async => neighborhoods;
}

class _TableGroupRepositoryFake implements TableGroupRepository {
  _TableGroupRepositoryFake({
    this.pages = const <int, Result<Page<TableGroup>>>{},
    this.joinResult = const Result.success(null),
    Result<TableGroup>? createResult,
  }) : createResult = createResult ?? Result.success(_group('created'));

  final Map<int, Result<Page<TableGroup>>> pages;
  final Result<void> joinResult;
  Result<TableGroup> createResult;
  final List<int> requestedPages = <int>[];
  String? lastCityId;
  String? lastDistrictId;
  String? lastNeighborhoodId;
  String? lastJoinNote;

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    lastCityId = cityId;
    lastDistrictId = districtId;
    lastNeighborhoodId = neighborhoodId;
    return pages[page] ??
        const Result.success(Page<TableGroup>(items: [], hasNext: false));
  }

  @override
  Future<Result<TableGroup>> createTableGroup(
    TableGroupCreateRequest request,
  ) async => createResult;

  @override
  Future<Result<void>> joinTableGroup({
    required String tableGroupId,
    String? note,
  }) async {
    lastJoinNote = note;
    return joinResult;
  }

  @override
  Future<Result<void>> approveJoinRequest({
    required String tableGroupId,
    required String participantId,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> cancelTableGroup({required String tableGroupId}) async =>
      const Result.success(null);

  @override
  Future<Result<TableGroup>> getDetail(String tableGroupId) async =>
      Result.success(_group(tableGroupId));

  @override
  Future<Result<Page<TableGroupMessage>>> getChatMessages({
    required String tableGroupId,
    int page = 0,
    int size = 30,
  }) async =>
      const Result.success(Page<TableGroupMessage>(items: [], hasNext: false));

  @override
  Future<Result<int>> getUnreadBadge({required String tableGroupId}) async =>
      const Result.success(0);

  @override
  Future<Result<void>> kickParticipant({
    required String tableGroupId,
    required String participantId,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> leaveTableGroup({required String tableGroupId}) async =>
      const Result.success(null);

  @override
  Future<Result<void>> rejectJoinRequest({
    required String tableGroupId,
    required String participantId,
  }) async => const Result.success(null);

  @override
  Future<Result<TableGroupMessage>> sendChatMessage({
    required String tableGroupId,
    required String content,
    String messageType = 'TEXT',
  }) async => Result.success(
    TableGroupMessage(
      messageId: 'message-1',
      tableGroupId: tableGroupId,
      senderId: 'owner',
      content: content,
      messageType: messageType,
      sentAt: null,
      deletedAt: null,
    ),
  );
}

class _TableGroupApiClientFake extends ApiClient {
  _TableGroupApiClientFake(this.handler);

  final FutureOr<Object?> Function(
    String method,
    String path,
    Map<String, dynamic>? query,
    Object? body,
  )
  handler;
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Object? lastBody;

  Future<T> _execute<T>(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    lastMethod = method;
    lastPath = path;
    lastQuery = query;
    lastBody = body;
    final payload = await handler(method, path, query, body);
    return decoder == null ? payload as T : decoder(payload);
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) => _execute('GET', path, query: query, decoder: decoder);

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('POST', path, body: body, decoder: decoder);

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('PUT', path, body: body, decoder: decoder);

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('DELETE', path, body: body, decoder: decoder);

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _execute('PATCH', path, body: body, decoder: decoder);
}
