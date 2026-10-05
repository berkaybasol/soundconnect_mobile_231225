part of 'table_group_models_cubit_test.dart';

void _registerTableGroupListCubit2() {
  test('failed loadMore retries the same page without losing items', () async {
    const pageError = AppError(
      code: 'table_group_page_failed',
      message: 'Next page failed',
    );
    final tableRepository = _DeferredListTableGroupRepository();
    final cubit = TableGroupListCubit(
      tableGroupRepository: tableRepository,
      locationRepository: _LocationRepositoryFake(),
    );
    addTearDown(cubit.close);

    final initialize = cubit.initialize();
    await Future<void>.delayed(Duration.zero);
    tableRepository.completeList(
      0,
      Result.success(
        Page<TableGroup>(items: <TableGroup>[_group('g-1')], hasNext: true),
      ),
    );
    await initialize;

    final failedLoad = cubit.loadMore();
    await Future<void>.delayed(Duration.zero);
    tableRepository.completeList(1, const Result.failure(pageError));
    await failedLoad;

    expect(cubit.state.items.map((item) => item.id), <String>['g-1']);
    expect(cubit.state.page, 0);
    expect(cubit.state.hasNext, isTrue);
    expect(cubit.state.error, pageError);

    final retry = cubit.loadMore();
    await Future<void>.delayed(Duration.zero);
    expect(tableRepository.listRequests.map((request) => request.page), <int>[
      0,
      1,
      1,
    ]);
    tableRepository.completeList(
      2,
      Result.success(
        Page<TableGroup>(items: <TableGroup>[_group('g-2')], hasNext: false),
      ),
    );
    await retry;

    expect(cubit.state.items.map((item) => item.id), <String>['g-1', 'g-2']);
    expect(cubit.state.page, 1);
    expect(cubit.state.error, isNull);
  });

  test('filter change discards an obsolete in-flight next page', () async {
    final locationRepository = _LocationRepositoryFake()
      ..cities = const Result.success(<City>[
        City(id: 'city-1', name: 'First'),
        City(id: 'city-2', name: 'Second'),
      ])
      ..districts = const Result.success(<District>[]);
    final tableRepository = _DeferredListTableGroupRepository();
    final cubit = TableGroupListCubit(
      tableGroupRepository: tableRepository,
      locationRepository: locationRepository,
    );
    addTearDown(cubit.close);

    final initialize = cubit.initialize();
    await Future<void>.delayed(Duration.zero);
    tableRepository.completeList(
      0,
      Result.success(
        Page<TableGroup>(
          items: <TableGroup>[_group('global-first')],
          hasNext: true,
        ),
      ),
    );
    await initialize;

    final staleLoad = cubit.loadMore();
    await Future<void>.delayed(Duration.zero);
    final filterChange = cubit.setCity('city-2');
    await Future<void>.delayed(Duration.zero);

    expect(tableRepository.listRequests, hasLength(3));
    expect(tableRepository.listRequests[1].page, 1);
    expect(tableRepository.listRequests[1].cityId, isNull);
    expect(tableRepository.listRequests[2].page, 0);
    expect(tableRepository.listRequests[2].cityId, 'city-2');
    tableRepository.completeList(
      2,
      Result.success(
        Page<TableGroup>(
          items: <TableGroup>[_group('city-second')],
          hasNext: false,
        ),
      ),
    );
    await filterChange;
    tableRepository.completeList(
      1,
      Result.success(
        Page<TableGroup>(
          items: <TableGroup>[_group('stale-global-next')],
          hasNext: false,
        ),
      ),
    );
    await staleLoad;

    expect(cubit.state.selectedCityId, 'city-2');
    expect(cubit.state.items.map((item) => item.id), <String>['city-second']);
    expect(
      cubit.state.items.any((item) => item.id == 'stale-global-next'),
      isFalse,
    );
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

  test('forbidden identity cannot call the join repository', () async {
    final tableRepository = _DeferredTableGroupRepository();
    final cubit = TableGroupListCubit(
      tableGroupRepository: tableRepository,
      locationRepository: _LocationRepositoryFake(),
      canCreateOrJoin: () => false,
    );
    addTearDown(cubit.close);

    final joined = await cubit.joinTableGroup(
      tableGroupId: 'g-1',
      note: 'must-not-be-sent',
    );

    expect(joined, isFalse);
    expect(tableRepository.lastJoinNote, isNull);
    expect(cubit.state.joiningIds, isEmpty);
    expect(cubit.state.error?.code, 'table_group_personal_identity_required');
  });

  test('initialize and join complete safely after cubit closure', () async {
    final locationRepository = _DeferredLocationRepository();
    final tableRepository = _DeferredTableGroupRepository();
    final initializeCubit = TableGroupListCubit(
      tableGroupRepository: tableRepository,
      locationRepository: locationRepository,
    );
    final initialize = initializeCubit.initialize();
    await Future<void>.delayed(Duration.zero);
    await initializeCubit.close();
    locationRepository.completeCities(0, const <City>[
      City(id: 'late-city', name: 'Late'),
    ]);
    await initialize;

    final joinCubit = TableGroupListCubit(
      tableGroupRepository: tableRepository,
      locationRepository: _LocationRepositoryFake(),
    );
    final join = joinCubit.joinTableGroup(tableGroupId: 'g-1');
    await Future<void>.delayed(Duration.zero);
    await joinCubit.close();
    tableRepository.completeJoin(const Result.success(null));

    expect(await join, isFalse);
  });

  test('discards a late district response from an obsolete city', () async {
    final locationRepository = _DeferredLocationRepository();
    final tableRepository = _TableGroupRepositoryFake();
    final cubit = TableGroupListCubit(
      tableGroupRepository: tableRepository,
      locationRepository: locationRepository,
    );
    addTearDown(cubit.close);

    final firstChange = cubit.setCity('city-1');
    await Future<void>.delayed(Duration.zero);
    locationRepository.completeCities(0, const <City>[
      City(id: 'city-1', name: 'First'),
      City(id: 'city-2', name: 'Second'),
    ]);
    await Future<void>.delayed(Duration.zero);
    final secondChange = cubit.setCity('city-2');
    await Future<void>.delayed(Duration.zero);

    locationRepository.completeDistricts('city-2', const <District>[
      District(id: 'district-2', name: 'Second', cityId: 'city-2'),
    ]);
    await secondChange;
    locationRepository.completeDistricts('city-1', const <District>[
      District(id: 'district-1', name: 'First', cityId: 'city-1'),
    ]);
    await firstChange;

    expect(cubit.state.selectedCityId, 'city-2');
    expect(cubit.state.districts.single.id, 'district-2');
    expect(tableRepository.lastCityId, 'city-2');
  });
}
