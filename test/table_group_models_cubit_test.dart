import 'dart:async';
import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_create_request.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_message_model.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_model.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_venue_option_model.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_wire_date.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_venue_option_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_message.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_participant.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_venue_option.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_expiry_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_message_timeline.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_venue_option_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_create_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_create_state.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_list_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_list_state.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_create_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_list_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';

part 'table_group_models_cubit_test_register_table_group_list_cubit1.dart';
part 'table_group_models_cubit_test_register_table_group_list_cubit2.dart';
part 'table_group_models_cubit_test_register_table_group_models_cubit3.dart';
part 'table_group_models_cubit_test_register_table_group_models_cubit4.dart';
part 'table_group_models_cubit_test_register_table_group_models_cubit5.dart';
part 'table_group_models_cubit_test_register_table_group_models_cubit6.dart';
part 'table_group_models_cubit_test_register_table_group_models_cubit7.dart';
part 'table_group_models_cubit_test_register_table_group_models_cubit8.dart';

void main() {
  _registerTableGroupModelsCubit3();
  _registerTableGroupModelsCubit4();
  _registerTableGroupModelsCubit5();
  _registerTableGroupModelsCubit6();
  _registerTableGroupModelsCubit7();
  _registerTableGroupModelsCubit8();
}

Future<void> _enterTableGroupDescription(
  WidgetTester tester,
  String value,
) async {
  final field = find.byKey(const Key('table_group_description_input'));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _enableSpecificVenue(WidgetTester tester) async {
  final toggle = find.byKey(const Key('table_group_specific_venue_toggle'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pump();
  expect(find.byKey(const Key('table_group_venue_input')), findsOneWidget);
}

TableGroupCreateRequest _createRequest({
  String? venueId,
  String? venueName,
  String description = 'Tanışma ve sohbet masası',
}) {
  return TableGroupCreateRequest(
    venueId: venueId,
    venueName: venueName,
    description: description,
    maxPersonCount: 4,
    genderPrefs: const <String>['OTHER', 'OTHER', 'OTHER', 'OTHER'],
    ageMin: 19,
    ageMax: 99,
    meetingAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    cityId: 'city-1',
    districtId: null,
    neighborhoodId: null,
  );
}

Map<String, dynamic> _tableGroupWireJson({
  String id = 'g-1',
  String ownerId = 'owner-1',
  String startAt = '2026-07-14T00:00:00Z',
  String meetingAt = '2026-07-14T01:02:03Z',
  String expiresAt = '2026-07-15T00:00:00Z',
  List<Object?> participants = const <Object?>[],
}) => <String, dynamic>{
  'id': id,
  'ownerId': ownerId,
  'ownerUsername': 'Owner',
  'ownerProfileImageUrl': null,
  'venueId': null,
  'venueName': 'Cafe',
  'description': 'Tanışma ve sohbet masası',
  'maxPersonCount': 4,
  'genderPrefs': const <String>['OTHER'],
  'ageMin': 18,
  'ageMax': 99,
  'startAt': startAt,
  'meetingAt': meetingAt,
  'expiresAt': expiresAt,
  'status': 'ACTIVE',
  'participants': participants,
  'city': const <String, dynamic>{'id': 'city-1', 'name': 'City'},
  'district': null,
  'neighborhood': null,
};

Map<String, dynamic> _venueOptionJson({
  required String id,
  required String name,
  String? profilePictureUrl,
  String address = 'Moda Caddesi 1',
  String cityName = 'İstanbul',
  String districtName = 'Kadıköy',
  String neighborhoodName = 'Caferağa',
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'profilePictureUrl': profilePictureUrl,
  'address': address,
  'cityId': 'city-1',
  'cityName': cityName,
  'districtId': 'district-1',
  'districtName': districtName,
  'neighborhoodId': 'neighborhood-1',
  'neighborhoodName': neighborhoodName,
};

TableGroupVenueOption _venueOption({
  required String id,
  required String name,
  String? profilePictureUrl,
  String address = 'Moda Caddesi 1',
  String cityId = 'city-1',
  String cityName = 'İstanbul',
  String districtId = 'district-1',
  String districtName = 'Kadıköy',
  String neighborhoodId = 'neighborhood-1',
  String neighborhoodName = 'Caferağa',
}) => TableGroupVenueOptionModel.fromJson(<String, dynamic>{
  ..._venueOptionJson(
    id: id,
    name: name,
    profilePictureUrl: profilePictureUrl,
    address: address,
    cityName: cityName,
    districtName: districtName,
    neighborhoodName: neighborhoodName,
  ),
  'cityId': cityId,
  'districtId': districtId,
  'neighborhoodId': neighborhoodId,
});

TableGroup _group(
  String id, {
  String? venueName,
  String cityId = 'city-1',
  String cityName = 'City',
}) {
  return TableGroup(
    id: id,
    ownerId: 'owner',
    ownerUsername: 'Owner',
    ownerProfileImageUrl: null,
    venueId: null,
    venueName: venueName,
    maxPersonCount: 4,
    genderPrefs: const <String>[],
    ageMin: 18,
    ageMax: 99,
    expiresAt: null,
    status: 'ACTIVE',
    participants: const <TableGroupParticipant>[],
    city: TableGroupLocation(id: cityId, name: cityName),
    district: null,
    neighborhood: null,
  );
}

TableGroupMessage _message(
  String id, {
  required int minute,
  String content = 'message',
}) {
  return TableGroupMessage(
    messageId: id,
    tableGroupId: 'g-1',
    senderId: 'u-1',
    content: content,
    messageType: 'TEXT',
    sentAt: DateTime.utc(2026, 7, 14, 0, minute),
    deletedAt: null,
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

class _DelayedCitySwitchLocationRepository extends _LocationRepositoryFake {
  final Completer<Result<List<District>>> _createdCityDistricts =
      Completer<Result<List<District>>>();

  bool get createdCityDistrictsCompleted => _createdCityDistricts.isCompleted;

  void completeCreatedCityDistricts() {
    _createdCityDistricts.complete(
      const Result.success(<District>[
        District(
          id: 'created-district',
          name: 'Created District',
          cityId: 'city-2',
        ),
      ]),
    );
  }

  @override
  Future<Result<List<District>>> getDistricts(String cityId) {
    if (cityId == 'city-2') return _createdCityDistricts.future;
    return super.getDistricts(cityId);
  }
}

class _DelayedInitialDistrictLocationRepository
    extends _LocationRepositoryFake {
  final Completer<Result<List<District>>> _districts =
      Completer<Result<List<District>>>();

  bool get districtsCompleted => _districts.isCompleted;

  void completeDistricts() {
    _districts.complete(
      const Result.success(<District>[
        District(id: 'district-1', name: 'District', cityId: 'city-1'),
      ]),
    );
  }

  @override
  Future<Result<List<District>>> getDistricts(String cityId) {
    if (cityId == 'city-1') return _districts.future;
    return super.getDistricts(cityId);
  }
}

class _DelayedNeighborhoodLocationRepository extends _LocationRepositoryFake {
  final Completer<Result<List<Neighborhood>>> _neighborhoods =
      Completer<Result<List<Neighborhood>>>();

  void completeNeighborhoods() {
    _neighborhoods.complete(
      const Result.success(<Neighborhood>[
        Neighborhood(
          id: 'neighborhood-1',
          name: 'Neighborhood',
          districtId: 'district-1',
        ),
      ]),
    );
  }

  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(String districtId) {
    if (districtId == 'district-1') return _neighborhoods.future;
    return super.getNeighborhoods(districtId);
  }
}

class _FixedAuthSessionManager extends AuthSessionManager {
  _FixedAuthSessionManager(this._fixedSession)
    : super(
        tokenStore: _NoopTokenStore(),
        sessionStore: _NoopAuthSessionStore(),
      );

  final AuthSession _fixedSession;

  @override
  AuthSession get session => _fixedSession;
}

class _NoopTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String token) async {}
}

class _NoopAuthSessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSessionMetadata?> read() async => null;

  @override
  Future<void> write(AuthSessionMetadata metadata) async {}
}

class _NoopDmRepository implements DmRepository {
  @override
  Future<Result<int>> getUnreadCount() async => const Result.success(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyVenueOptionRepository implements TableGroupVenueOptionRepository {
  const _EmptyVenueOptionRepository();

  @override
  Future<Result<List<TableGroupVenueOption>>> search({
    required String query,
    int limit = 8,
  }) async => const Result<List<TableGroupVenueOption>>.success(
    <TableGroupVenueOption>[],
  );
}

class _VenueOptionRepositoryFake implements TableGroupVenueOptionRepository {
  _VenueOptionRepositoryFake(this.result);

  Result<List<TableGroupVenueOption>> result;
  final List<String> queries = <String>[];
  final List<int> limits = <int>[];

  @override
  Future<Result<List<TableGroupVenueOption>>> search({
    required String query,
    int limit = 8,
  }) async {
    queries.add(query);
    limits.add(limit);
    return result;
  }
}

class _DeferredVenueOptionRepository
    implements TableGroupVenueOptionRepository {
  final List<_DeferredVenueSearch> requests = <_DeferredVenueSearch>[];

  @override
  Future<Result<List<TableGroupVenueOption>>> search({
    required String query,
    int limit = 8,
  }) {
    final request = _DeferredVenueSearch(query: query, limit: limit);
    requests.add(request);
    return request.completer.future;
  }
}

class _DeferredVenueSearch {
  _DeferredVenueSearch({required this.query, required this.limit});

  final String query;
  final int limit;
  final Completer<Result<List<TableGroupVenueOption>>> completer =
      Completer<Result<List<TableGroupVenueOption>>>();
}

class _DeferredLocationRepository implements LocationRepository {
  final List<Completer<Result<List<City>>>> _cities =
      <Completer<Result<List<City>>>>[];
  final Map<String, Completer<Result<List<District>>>> _districts =
      <String, Completer<Result<List<District>>>>{};
  final Map<String, Completer<Result<List<Neighborhood>>>> _neighborhoods =
      <String, Completer<Result<List<Neighborhood>>>>{};

  int get cityRequestCount => _cities.length;

  void completeCities(int requestIndex, List<City> cities) {
    completeCitiesResult(requestIndex, Result.success(cities));
  }

  void completeCitiesResult(int requestIndex, Result<List<City>> result) {
    _cities[requestIndex].complete(result);
  }

  void completeDistricts(String cityId, List<District> districts) {
    (_districts[cityId] ??= Completer<Result<List<District>>>()).complete(
      Result.success(districts),
    );
  }

  void completeNeighborhoods(
    String districtId,
    List<Neighborhood> neighborhoods,
  ) {
    (_neighborhoods[districtId] ??= Completer<Result<List<Neighborhood>>>())
        .complete(Result.success(neighborhoods));
  }

  @override
  Future<Result<List<City>>> getCities() {
    final completer = Completer<Result<List<City>>>();
    _cities.add(completer);
    return completer.future;
  }

  @override
  Future<Result<List<District>>> getDistricts(String cityId) =>
      (_districts[cityId] ??= Completer<Result<List<District>>>()).future;

  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(String districtId) =>
      (_neighborhoods[districtId] ??= Completer<Result<List<Neighborhood>>>())
          .future;
}

class _DeferredTableGroupRepository extends _TableGroupRepositoryFake {
  final List<Completer<Result<TableGroup>>> _creates =
      <Completer<Result<TableGroup>>>[];
  Completer<Result<void>>? _join;

  int get createRequestCount => _creates.length;

  void completeCreate(int requestIndex, Result<TableGroup> result) {
    _creates[requestIndex].complete(result);
  }

  void completeJoin(Result<void> result) {
    _join?.complete(result);
  }

  @override
  Future<Result<TableGroup>> createTableGroup(TableGroupCreateRequest request) {
    lastCreateRequest = request;
    final completer = Completer<Result<TableGroup>>();
    _creates.add(completer);
    return completer.future;
  }

  @override
  Future<Result<void>> joinTableGroup({
    required String tableGroupId,
    String? note,
  }) {
    lastJoinNote = note;
    return (_join ??= Completer<Result<void>>()).future;
  }
}

class _DeferredListTableGroupRepository extends _TableGroupRepositoryFake {
  final List<_DeferredTableListRequest> listRequests =
      <_DeferredTableListRequest>[];

  void completeList(int requestIndex, Result<Page<TableGroup>> result) {
    listRequests[requestIndex].completer.complete(result);
  }

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) {
    final request = _DeferredTableListRequest(
      cityId: cityId,
      districtId: districtId,
      neighborhoodId: neighborhoodId,
      page: page,
      size: size,
    );
    listRequests.add(request);
    return request.completer.future;
  }
}

class _DeferredTableListRequest {
  _DeferredTableListRequest({
    required this.cityId,
    required this.districtId,
    required this.neighborhoodId,
    required this.page,
    required this.size,
  });

  final String? cityId;
  final String? districtId;
  final String? neighborhoodId;
  final int page;
  final int size;
  final Completer<Result<Page<TableGroup>>> completer =
      Completer<Result<Page<TableGroup>>>();
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
  final List<String?> requestedCityIds = <String?>[];
  String? lastCityId;
  String? lastDistrictId;
  String? lastNeighborhoodId;
  String? lastJoinNote;
  TableGroupCreateRequest? lastCreateRequest;
  final List<TableGroupCreateRequest> createRequests =
      <TableGroupCreateRequest>[];

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    requestedCityIds.add(cityId);
    lastCityId = cityId;
    lastDistrictId = districtId;
    lastNeighborhoodId = neighborhoodId;
    return pages[page] ??
        const Result.success(Page<TableGroup>(items: [], hasNext: false));
  }

  @override
  Future<Result<Page<TableGroup>>> listMyActiveTableGroups({
    int page = 0,
    int size = 50,
  }) => listActiveTableGroups(cityId: null, page: page, size: size);

  @override
  Future<Result<TableGroup>> createTableGroup(
    TableGroupCreateRequest request,
  ) async {
    lastCreateRequest = request;
    createRequests.add(request);
    return createResult;
  }

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
    required String clientMessageId,
  }) async => Result.success(
    TableGroupMessage(
      messageId: 'message-1',
      tableGroupId: tableGroupId,
      senderId: 'owner',
      clientMessageId: clientMessageId,
      content: content,
      messageType: 'TEXT',
      sentAt: null,
      deletedAt: null,
    ),
  );
}

class _CityAwareTableGroupRepository extends _TableGroupRepositoryFake {
  _CityAwareTableGroupRepository({required this.groupsByCity});

  final Map<String, List<TableGroup>> groupsByCity;

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    lastCityId = cityId;
    lastDistrictId = districtId;
    lastNeighborhoodId = neighborhoodId;
    return Result.success(
      Page<TableGroup>(
        items: page == 0
            ? cityId == null
                  ? <TableGroup>[
                      for (final groups in groupsByCity.values) ...groups,
                    ]
                  : groupsByCity[cityId] ?? const <TableGroup>[]
            : const <TableGroup>[],
        hasNext: false,
      ),
    );
  }
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

class _ManualDayTimer implements Timer {
  _ManualDayTimer(this._callback);

  final void Function() _callback;
  bool _isActive = true;
  int _tick = 0;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _tick;

  void fire() {
    if (!_isActive) return;
    _isActive = false;
    _tick += 1;
    _callback();
  }

  @override
  void cancel() {
    _isActive = false;
  }
}
