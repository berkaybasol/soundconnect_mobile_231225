part of 'table_group_models_cubit_test.dart';

void _registerTableGroupListCubit1() {
  test('initializes filters, reloads hierarchy, and paginates', () async {
    final tableRepository = _TableGroupRepositoryFake(
      pages: <int, Result<Page<TableGroup>>>{
        0: Result.success(
          Page<TableGroup>(
            items: <TableGroup>[_group('g-1')],
            hasNext: true,
            totalElements: 2,
          ),
        ),
        1: Result.success(
          Page<TableGroup>(
            items: <TableGroup>[_group('g-2')],
            hasNext: false,
            totalElements: 2,
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
    await cubit.setCity('city-1');
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
    expect(cubit.state.totalElements, 2);
    expect(tableRepository.lastCityId, 'city-1');
    expect(tableRepository.lastDistrictId, 'district-1');
    expect(tableRepository.lastNeighborhoodId, 'neighborhood-1');
    expect(tableRepository.requestedPages.last, 1);
  });

  test(
    'clearing city resets dependent selections and reloads globally',
    () async {
      final tableRepository = _TableGroupRepositoryFake(
        pages: <int, Result<Page<TableGroup>>>{
          0: Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('global-table')],
              hasNext: false,
            ),
          ),
        },
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: _LocationRepositoryFake(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.setCity('city-1');
      await cubit.setDistrict('district-1');
      await cubit.setNeighborhood('neighborhood-1');

      await cubit.setCity(null);

      expect(cubit.state.selectedCityId, isNull);
      expect(cubit.state.selectedDistrictId, isNull);
      expect(cubit.state.selectedNeighborhoodId, isNull);
      expect(cubit.state.districts, isEmpty);
      expect(cubit.state.neighborhoods, isEmpty);
      expect(cubit.state.items.single.id, 'global-table');
      expect(cubit.state.page, 0);
      expect(tableRepository.lastCityId, isNull);
      expect(tableRepository.lastDistrictId, isNull);
      expect(tableRepository.lastNeighborhoodId, isNull);
    },
  );

  test(
    'reselecting the current city clears stale dependent filters and reloads city-wide',
    () async {
      final tableRepository = _TableGroupRepositoryFake();
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: _LocationRepositoryFake(),
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.setDistrict('district-1');
      await cubit.setNeighborhood('neighborhood-1');

      await cubit.setCity('city-1');

      expect(cubit.state.selectedCityId, 'city-1');
      expect(cubit.state.selectedDistrictId, isNull);
      expect(cubit.state.selectedNeighborhoodId, isNull);
      expect(tableRepository.lastCityId, 'city-1');
      expect(tableRepository.lastDistrictId, isNull);
      expect(tableRepository.lastNeighborhoodId, isNull);
    },
  );

  test(
    'switching to a created table city clears stale dependent filters and reloads city-wide',
    () async {
      final locations = _LocationRepositoryFake()
        ..cities = const Result.success(<City>[
          City(id: 'city-1', name: 'First City'),
          City(id: 'city-2', name: 'Created Table City'),
        ]);
      final tableRepository = _TableGroupRepositoryFake();
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.setDistrict('district-1');
      await cubit.setNeighborhood('neighborhood-1');

      await cubit.setCity('city-2');

      expect(cubit.state.selectedCityId, 'city-2');
      expect(cubit.state.selectedDistrictId, isNull);
      expect(cubit.state.selectedNeighborhoodId, isNull);
      expect(tableRepository.lastCityId, 'city-2');
      expect(tableRepository.lastDistrictId, isNull);
      expect(tableRepository.lastNeighborhoodId, isNull);
    },
  );

  test(
    'city switch clears stale tables and reloads without waiting for district metadata',
    () async {
      final locations = _DelayedCitySwitchLocationRepository()
        ..cities = const Result.success(<City>[
          City(id: 'city-1', name: 'Old City'),
          City(id: 'city-2', name: 'Created Table City'),
        ]);
      final tableRepository = _CityAwareTableGroupRepository(
        groupsByCity: <String, List<TableGroup>>{
          'city-1': <TableGroup>[
            _group('old-table', venueName: 'Old City Venue'),
          ],
          'city-2': <TableGroup>[
            _group(
              'created-table',
              venueName: 'Created City Venue',
              cityId: 'city-2',
              cityName: 'Created Table City',
            ),
          ],
        },
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      await cubit.setCity('city-1');
      expect(cubit.state.items.single.id, 'old-table');

      final emitted = <TableGroupListState>[];
      final subscription = cubit.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      final citySwitch = cubit.setCity('city-2');
      await Future<void>.delayed(Duration.zero);

      expect(emitted.first.status, TableGroupListStatus.loading);
      expect(emitted.first.items, isEmpty);
      expect(tableRepository.lastCityId, 'city-2');
      expect(cubit.state.items.single.id, 'created-table');
      expect(locations.createdCityDistrictsCompleted, isFalse);

      locations.completeCreatedCityDistricts();
      await citySwitch;
    },
  );

  test(
    'create city during pending initialize preserves city metadata and shows its tables',
    () async {
      final locations = _DeferredLocationRepository();
      final tableRepository = _CityAwareTableGroupRepository(
        groupsByCity: <String, List<TableGroup>>{
          'city-2': <TableGroup>[
            _group(
              'created-table',
              venueName: 'Created City Venue',
              cityId: 'city-2',
              cityName: 'Created Table City',
            ),
          ],
        },
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      );
      addTearDown(cubit.close);

      final initialize = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      final citySwitch = cubit.setCity('city-2');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.selectedCityId, 'city-2');
      expect(cubit.state.items.single.id, 'created-table');
      expect(locations.cityRequestCount, 1);

      await cubit.setDistrict(null);

      locations.completeCities(0, const <City>[
        City(id: 'city-1', name: 'Old City'),
        City(id: 'city-2', name: 'Created Table City'),
      ]);
      locations.completeDistricts('city-2', const <District>[
        District(id: 'district-2', name: 'Created District', cityId: 'city-2'),
      ]);
      await Future.wait<void>(<Future<void>>[initialize, citySwitch]);

      expect(cubit.state.selectedCityId, 'city-2');
      expect(cubit.state.cities.map((city) => city.id), <String>[
        'city-1',
        'city-2',
      ]);
      expect(cubit.state.districts.single.id, 'district-2');
      expect(cubit.state.items.single.id, 'created-table');
      expect(cubit.state.status, TableGroupListStatus.idle);
    },
  );

  test(
    'initialize shows global tables without waiting for city metadata',
    () async {
      final locations = _DeferredLocationRepository();
      final tableRepository = _TableGroupRepositoryFake(
        pages: <int, Result<Page<TableGroup>>>{
          0: Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('initial-table')],
              hasNext: false,
            ),
          ),
        },
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      );
      addTearDown(cubit.close);

      final initialize = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.items.single.id, 'initial-table');
      expect(cubit.state.selectedCityId, isNull);
      expect(tableRepository.lastCityId, isNull);
      expect(locations.cityRequestCount, 1);

      locations.completeCities(0, const <City>[
        City(id: 'city-1', name: 'City'),
      ]);
      await initialize;

      expect(cubit.state.cities.single.id, 'city-1');
      expect(cubit.state.districts, isEmpty);
      expect(cubit.state.status, TableGroupListStatus.idle);
    },
  );

  test(
    'clearing district while its catalog loads keeps the late catalog result',
    () async {
      final locations = _DelayedInitialDistrictLocationRepository();
      final cubit = TableGroupListCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: locations,
      );
      addTearDown(cubit.close);

      await cubit.initialize();
      final cityChange = cubit.setCity('city-1');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await cubit.setDistrict(null);
      locations.completeDistricts();
      await cityChange;

      expect(cubit.state.selectedCityId, 'city-1');
      expect(cubit.state.selectedDistrictId, isNull);
      expect(cubit.state.districts.single.id, 'district-1');
    },
  );

  test(
    'clearing neighborhood while its catalog loads keeps the late catalog result',
    () async {
      final locations = _DelayedNeighborhoodLocationRepository();
      final tableRepository = _TableGroupRepositoryFake(
        pages: <int, Result<Page<TableGroup>>>{
          0: Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('district-table')],
              hasNext: false,
            ),
          ),
        },
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      );
      addTearDown(cubit.close);
      await cubit.initialize();

      final districtChange = cubit.setDistrict('district-1');
      await Future<void>.delayed(Duration.zero);
      await cubit.setNeighborhood(null);

      locations.completeNeighborhoods();
      await districtChange;

      expect(cubit.state.selectedDistrictId, 'district-1');
      expect(cubit.state.selectedNeighborhoodId, isNull);
      expect(cubit.state.neighborhoods.single.id, 'neighborhood-1');
      expect(cubit.state.items.single.id, 'district-table');
      expect(tableRepository.lastDistrictId, 'district-1');
      expect(tableRepository.lastNeighborhoodId, isNull);
    },
  );

  test('late list response cannot overwrite a newer city result', () async {
    final locations = _LocationRepositoryFake()
      ..cities = const Result.success(<City>[
        City(id: 'city-1', name: 'Old City'),
        City(id: 'city-2', name: 'New City'),
      ]);
    final tableRepository = _DeferredListTableGroupRepository();
    final cubit = TableGroupListCubit(
      tableGroupRepository: tableRepository,
      locationRepository: locations,
    );
    addTearDown(cubit.close);

    final oldCity = cubit.setCity('city-1');
    await Future<void>.delayed(Duration.zero);
    final newCity = cubit.setCity('city-2');
    await Future<void>.delayed(Duration.zero);

    expect(tableRepository.listRequests, hasLength(2));
    expect(tableRepository.listRequests[0].cityId, 'city-1');
    expect(tableRepository.listRequests[1].cityId, 'city-2');

    tableRepository.completeList(
      1,
      Result.success(
        Page<TableGroup>(
          items: <TableGroup>[
            _group('new-table', cityId: 'city-2', cityName: 'New City'),
          ],
          hasNext: false,
        ),
      ),
    );
    await newCity;
    tableRepository.completeList(
      0,
      Result.success(
        Page<TableGroup>(
          items: <TableGroup>[_group('old-table')],
          hasNext: false,
        ),
      ),
    );
    await oldCity;

    expect(cubit.state.selectedCityId, 'city-2');
    expect(cubit.state.items.single.id, 'new-table');
    expect(cubit.state.status, TableGroupListStatus.idle);
  });

  test(
    'late global response cannot overwrite a selected city result',
    () async {
      final locations = _LocationRepositoryFake()
        ..cities = const Result.success(<City>[
          City(id: 'city-2', name: 'New City'),
        ]);
      final tableRepository = _DeferredListTableGroupRepository();
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      );
      addTearDown(cubit.close);

      final initialize = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      final citySwitch = cubit.setCity('city-2');
      await Future<void>.delayed(Duration.zero);

      expect(tableRepository.listRequests, hasLength(2));
      expect(tableRepository.listRequests[0].cityId, isNull);
      expect(tableRepository.listRequests[1].cityId, 'city-2');

      tableRepository.completeList(
        1,
        Result.success(
          Page<TableGroup>(
            items: <TableGroup>[
              _group('city-table', cityId: 'city-2', cityName: 'New City'),
            ],
            hasNext: false,
          ),
        ),
      );
      await citySwitch;
      tableRepository.completeList(
        0,
        Result.success(
          Page<TableGroup>(
            items: <TableGroup>[_group('global-table')],
            hasNext: false,
          ),
        ),
      );
      await initialize;

      expect(cubit.state.selectedCityId, 'city-2');
      expect(cubit.state.items.single.id, 'city-table');
      expect(cubit.state.status, TableGroupListStatus.idle);
    },
  );

  test('global tables remain visible when city metadata fails', () async {
    const cityError = AppError(
      code: 'cities_unavailable',
      message: 'Cities unavailable',
    );
    final locationRepository = _LocationRepositoryFake()
      ..cities = const Result.failure(cityError);
    final tableRepository = _TableGroupRepositoryFake(
      pages: <int, Result<Page<TableGroup>>>{
        0: Result.success(
          Page<TableGroup>(
            items: <TableGroup>[_group('global-result')],
            hasNext: false,
          ),
        ),
      },
    );
    final cubit = TableGroupListCubit(
      tableGroupRepository: tableRepository,
      locationRepository: locationRepository,
    );
    addTearDown(cubit.close);

    await cubit.initialize();

    expect(cubit.state.selectedCityId, isNull);
    expect(cubit.state.items.single.id, 'global-result');
    expect(cubit.state.status, TableGroupListStatus.failure);
    expect(cubit.state.error, same(cityError));
    expect(tableRepository.lastCityId, isNull);
  });

  test(
    'refresh retries failed city metadata without delaying global tables',
    () async {
      const cityError = AppError(
        code: 'cities_unavailable',
        message: 'Cities unavailable',
      );
      final locations = _DeferredLocationRepository();
      final tableRepository = _TableGroupRepositoryFake(
        pages: <int, Result<Page<TableGroup>>>{
          0: Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('global-result')],
              hasNext: false,
            ),
          ),
        },
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      );
      addTearDown(cubit.close);

      final initialize = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.items.single.id, 'global-result');
      locations.completeCitiesResult(
        0,
        const Result<List<City>>.failure(cityError),
      );
      await initialize;
      expect(cubit.state.error, same(cityError));

      var refreshCompleted = false;
      final refresh = cubit.refresh().whenComplete(() {
        refreshCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);

      expect(locations.cityRequestCount, 2);
      expect(tableRepository.requestedCityIds, <String?>[null, null]);
      expect(cubit.state.items.single.id, 'global-result');
      expect(cubit.state.status, TableGroupListStatus.idle);
      expect(refreshCompleted, isFalse);

      locations.completeCities(1, const <City>[
        City(id: 'city-1', name: 'Recovered City'),
      ]);
      await refresh;

      expect(refreshCompleted, isTrue);
      expect(cubit.state.cities.single.name, 'Recovered City');
      expect(cubit.state.selectedCityId, isNull);
      expect(cubit.state.status, TableGroupListStatus.idle);
      expect(cubit.state.error, isNull);
    },
  );

  test(
    'loads selected city results even when district metadata fails',
    () async {
      const districtError = AppError(
        code: 'districts_unavailable',
        message: 'Districts unavailable',
      );
      final locationRepository = _LocationRepositoryFake()
        ..districts = const Result.failure(districtError);
      final tableRepository = _TableGroupRepositoryFake(
        pages: <int, Result<Page<TableGroup>>>{
          0: Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('city-result')],
              hasNext: false,
            ),
          ),
        },
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locationRepository,
      );
      addTearDown(cubit.close);
      final surfacedErrors = <AppError?>[];
      final subscription = cubit.stream.listen((state) {
        if (state.status == TableGroupListStatus.failure) {
          surfacedErrors.add(state.error);
        }
      });
      addTearDown(subscription.cancel);

      await cubit.initialize();
      await cubit.setCity('city-1');
      await Future<void>.delayed(Duration.zero);

      expect(surfacedErrors, contains(same(districtError)));
      expect(cubit.state.items.single.id, 'city-result');
      expect(cubit.state.status, TableGroupListStatus.failure);
      expect(cubit.state.error, same(districtError));
      expect(tableRepository.lastCityId, 'city-1');
    },
  );

  test(
    'loads district results and retains neighborhood metadata error',
    () async {
      const neighborhoodError = AppError(
        code: 'neighborhoods_unavailable',
        message: 'Neighborhoods unavailable',
      );
      final locationRepository = _LocationRepositoryFake();
      final tableRepository = _TableGroupRepositoryFake(
        pages: <int, Result<Page<TableGroup>>>{
          0: Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('district-result')],
              hasNext: false,
            ),
          ),
        },
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locationRepository,
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      locationRepository.neighborhoods = const Result.failure(
        neighborhoodError,
      );

      await cubit.setDistrict('district-1');

      expect(cubit.state.items.single.id, 'district-result');
      expect(cubit.state.status, TableGroupListStatus.failure);
      expect(cubit.state.error, same(neighborhoodError));
      expect(tableRepository.lastDistrictId, 'district-1');
      expect(tableRepository.lastNeighborhoodId, isNull);
    },
  );

  test(
    'global loadMore keeps null city and deduplicates overlapping pages',
    () async {
      final tableRepository = _TableGroupRepositoryFake(
        pages: <int, Result<Page<TableGroup>>>{
          0: Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('g-1'), _group('g-2')],
              hasNext: true,
            ),
          ),
          1: Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('g-2'), _group('g-3')],
              hasNext: false,
            ),
          ),
        },
      );
      final cubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: _LocationRepositoryFake(),
      );
      addTearDown(cubit.close);

      await cubit.initialize();
      await cubit.loadMore();

      expect(cubit.state.items.map((item) => item.id), <String>[
        'g-1',
        'g-2',
        'g-3',
      ]);
      expect(cubit.state.page, 1);
      expect(cubit.state.hasNext, isFalse);
      expect(tableRepository.lastCityId, isNull);
      expect(tableRepository.requestedCityIds, <String?>[null, null]);
    },
  );

  test('concurrent loadMore calls share one next-page request', () async {
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

    final firstLoad = cubit.loadMore();
    await Future<void>.delayed(Duration.zero);
    final duplicateLoad = cubit.loadMore();
    await Future<void>.delayed(Duration.zero);

    expect(tableRepository.listRequests, hasLength(2));
    expect(tableRepository.listRequests.last.page, 1);
    tableRepository.completeList(
      1,
      Result.success(
        Page<TableGroup>(items: <TableGroup>[_group('g-2')], hasNext: false),
      ),
    );
    await Future.wait(<Future<void>>[firstLoad, duplicateLoad]);

    expect(cubit.state.items.map((item) => item.id), <String>['g-1', 'g-2']);
    expect(cubit.state.page, 1);
  });
}
