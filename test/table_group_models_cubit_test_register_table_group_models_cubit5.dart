part of 'table_group_models_cubit_test.dart';

void _registerTableGroupModelsCubit5() {
  group('TableGroupCreateCubit', () {
    test('starts without a venue and ignores hidden picker mutations', () {
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      );
      addTearDown(cubit.close);

      expect(cubit.state.venueMode, TableGroupVenueMode.none);
      cubit.venueTextChanged('Hidden venue');
      cubit.useCustomVenue('Hidden venue');
      cubit.selectRegisteredVenue(
        _venueOption(id: 'hidden', name: 'Hidden venue'),
      );

      expect(cubit.state.venueMode, TableGroupVenueMode.none);
      expect(cubit.state.venueQuery, isEmpty);
      expect(cubit.state.selectedVenue, isNull);
      expect(cubit.state.venueOptions, isEmpty);
    });

    test('forbidden identity cannot call the create repository', () async {
      final repository = _DeferredTableGroupRepository();
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: repository,
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: const _EmptyVenueOptionRepository(),
        canCreateOrJoin: () => false,
      );
      addTearDown(cubit.close);

      final created = await cubit.createTableGroup(_createRequest());

      expect(created, isFalse);
      expect(repository.createRequestCount, 0);
      expect(cubit.state.status, TableGroupCreateStatus.failure);
      expect(cubit.state.error?.code, 'table_group_personal_identity_required');
    });

    test(
      'rejects a hidden venue payload before calling the repository',
      () async {
        final repository = _TableGroupRepositoryFake();
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: repository,
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        );
        addTearDown(cubit.close);

        final created = await cubit.createTableGroup(
          _createRequest(venueName: 'Hidden Venue'),
        );

        expect(created, isFalse);
        expect(cubit.state.error?.code, 'table_group_venue_identity_invalid');
        expect(repository.lastCreateRequest, isNull);
      },
    );

    test(
      'exact matching text stays custom until an option is tapped',
      () async {
        final option = _venueOption(id: 'venue-a', name: 'Same Name');
        final venueRepository = _VenueOptionRepositoryFake(
          Result<List<TableGroupVenueOption>>.success(<TableGroupVenueOption>[
            option,
          ]),
        );
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: _TableGroupRepositoryFake(),
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: venueRepository,
          venueSearchDebounce: Duration.zero,
        );
        addTearDown(cubit.close);

        cubit.enableSpecificVenue();
        cubit.venueTextChanged('Same Name');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.venueMode, TableGroupVenueMode.custom);
        expect(cubit.state.selectedVenue, isNull);
        expect(cubit.state.venueOptions.single.id, 'venue-a');
        expect(venueRepository.queries, <String>['Same Name']);
        expect(venueRepository.limits, <int>[8]);
      },
    );

    test(
      'custom choice preserves manual location while registered detach clears it',
      () async {
        final locationRepository = _DeferredLocationRepository();
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: _TableGroupRepositoryFake(),
          locationRepository: locationRepository,
          venueOptionRepository: const _EmptyVenueOptionRepository(),
          venueSearchDebounce: Duration.zero,
        );
        addTearDown(cubit.close);

        final cities = cubit.loadCities();
        locationRepository.completeCities(0, const <City>[
          City(id: 'city-manual', name: 'Manual City'),
        ]);
        await cities;
        final districts = cubit.selectCity('city-manual');
        locationRepository.completeDistricts('city-manual', const <District>[
          District(
            id: 'district-manual',
            name: 'Manual District',
            cityId: 'city-manual',
          ),
        ]);
        await districts;
        final neighborhoods = cubit.selectDistrict('district-manual');
        locationRepository
            .completeNeighborhoods('district-manual', const <Neighborhood>[
              Neighborhood(
                id: 'neighborhood-manual',
                name: 'Manual Neighborhood',
                districtId: 'district-manual',
              ),
            ]);
        await neighborhoods;

        cubit.enableSpecificVenue();
        cubit.useCustomVenue('Manual Name');
        expect(cubit.state.cities.single.id, 'city-manual');
        expect(cubit.state.districts.single.id, 'district-manual');
        expect(cubit.state.neighborhoods.single.id, 'neighborhood-manual');

        cubit.disableSpecificVenue();
        expect(cubit.state.venueMode, TableGroupVenueMode.none);
        expect(cubit.state.cities.single.id, 'city-manual');
        expect(cubit.state.districts.single.id, 'district-manual');
        expect(cubit.state.neighborhoods.single.id, 'neighborhood-manual');

        cubit.enableSpecificVenue();
        cubit.selectRegisteredVenue(
          _venueOption(id: 'venue-a', name: 'Registered A'),
        );
        cubit.detachRegisteredVenue('Registered A');

        expect(cubit.state.venueMode, TableGroupVenueMode.custom);
        expect(cubit.state.selectedVenue, isNull);
        expect(cubit.state.cities, isEmpty);
        expect(cubit.state.districts, isEmpty);
        expect(cubit.state.neighborhoods, isEmpty);
        expect(cubit.state.status, TableGroupCreateStatus.loadingLocations);
      },
    );

    test(
      'disabling a registered venue clears derived location and reloads cities',
      () async {
        final locations = _DeferredLocationRepository();
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: _TableGroupRepositoryFake(),
          locationRepository: locations,
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        );
        addTearDown(cubit.close);

        cubit.enableSpecificVenue();
        cubit.selectRegisteredVenue(
          _venueOption(id: 'registered', name: 'Registered'),
        );
        cubit.disableSpecificVenue();

        expect(cubit.state.venueMode, TableGroupVenueMode.none);
        expect(cubit.state.selectedVenue, isNull);
        expect(cubit.state.cities, isEmpty);
        expect(cubit.state.districts, isEmpty);
        expect(cubit.state.neighborhoods, isEmpty);
        expect(cubit.state.status, TableGroupCreateStatus.loadingLocations);
        expect(locations.cityRequestCount, 1);

        locations.completeCities(0, const <City>[
          City(id: 'manual-city', name: 'Manual City'),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, TableGroupCreateStatus.idle);
        expect(cubit.state.cities.single.id, 'manual-city');
      },
    );

    test(
      'same-name A to B selection is atomic and keyed by venue id',
      () async {
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: _TableGroupRepositoryFake(),
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        );
        addTearDown(cubit.close);
        final states = <TableGroupCreateState>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);
        final a = _venueOption(id: 'venue-a', name: 'Duplicate Name');
        final b = _venueOption(
          id: 'venue-b',
          name: 'Duplicate Name',
          address: 'Other Address 2',
          cityId: 'city-2',
          districtId: 'district-2',
          neighborhoodId: 'neighborhood-2',
        );

        cubit.enableSpecificVenue();
        cubit.selectRegisteredVenue(a);
        await Future<void>.delayed(Duration.zero);
        states.clear();
        cubit.selectRegisteredVenue(b);
        await Future<void>.delayed(Duration.zero);

        expect(states, hasLength(1));
        expect(states.single.venueMode, TableGroupVenueMode.registered);
        expect(states.single.selectedVenue?.id, 'venue-b');
        expect(states.single.selectedVenue?.address, 'Other Address 2');
      },
    );

    test(
      'registered selection cancels a pending city load without staying busy',
      () async {
        final locations = _DeferredLocationRepository();
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: _TableGroupRepositoryFake(),
          locationRepository: locations,
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        );
        addTearDown(cubit.close);

        final pendingCities = cubit.loadCities();
        await Future<void>.delayed(Duration.zero);
        cubit.enableSpecificVenue();
        cubit.selectRegisteredVenue(
          _venueOption(id: 'registered', name: 'Registered'),
        );

        expect(cubit.state.status, TableGroupCreateStatus.idle);
        expect(cubit.state.error, isNull);
        expect(cubit.state.selectedVenue?.id, 'registered');
        locations.completeCities(0, const <City>[
          City(id: 'late-city', name: 'Late'),
        ]);
        await pendingCities;
        expect(cubit.state.selectedVenue?.id, 'registered');
        expect(cubit.state.cities, isEmpty);
      },
    );

    test('custom typing preserves the initial pending city load', () async {
      final locations = _DeferredLocationRepository();
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: locations,
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      );
      addTearDown(cubit.close);

      final pendingCities = cubit.loadCities();
      await Future<void>.delayed(Duration.zero);
      cubit.enableSpecificVenue();
      cubit.venueTextChanged('Custom venue');
      expect(cubit.state.status, TableGroupCreateStatus.loadingLocations);
      locations.completeCities(0, const <City>[
        City(id: 'city-1', name: 'City'),
      ]);
      await pendingCities;

      expect(cubit.state.status, TableGroupCreateStatus.idle);
      expect(cubit.state.cities.single.id, 'city-1');
      expect(cubit.state.venueMode, TableGroupVenueMode.custom);
    });

    test(
      'custom venue name edits preserve the manual location hierarchy',
      () async {
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: _TableGroupRepositoryFake(),
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        );
        addTearDown(cubit.close);

        await cubit.loadCities();
        await cubit.selectCity('city-1');
        await cubit.selectDistrict('district-1');
        cubit.enableSpecificVenue();
        cubit.venueTextChanged('Edited custom venue');

        expect(cubit.state.venueMode, TableGroupVenueMode.custom);
        expect(cubit.state.cities.single.id, 'city-1');
        expect(cubit.state.districts.single.id, 'district-1');
        expect(cubit.state.neighborhoods.single.id, 'neighborhood-1');
        expect(cubit.state.locationError, isNull);
      },
    );

    test('failed city loading remains visible and can be retried', () async {
      const locationError = AppError(
        code: 'cities_unavailable',
        message: 'Cities unavailable',
      );
      final locations = _LocationRepositoryFake()
        ..cities = const Result<List<City>>.failure(locationError);
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: locations,
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      );
      addTearDown(cubit.close);

      await cubit.loadCities();
      expect(cubit.state.status, TableGroupCreateStatus.idle);
      expect(cubit.state.locationError, same(locationError));
      expect(cubit.state.error, isNull);

      cubit.enableSpecificVenue();
      cubit.venueTextChanged('Custom venue');
      expect(cubit.state.locationError, same(locationError));

      locations.cities = const Result<List<City>>.success(<City>[
        City(id: 'city-recovered', name: 'Recovered City'),
      ]);
      await cubit.retryLocations();

      expect(cubit.state.locationError, isNull);
      expect(cubit.state.cities.single.id, 'city-recovered');
    });

    test('stale venue response cannot replace the latest query', () async {
      final venueRepository = _DeferredVenueOptionRepository();
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: venueRepository,
        venueSearchDebounce: Duration.zero,
      );
      addTearDown(cubit.close);

      cubit.enableSpecificVenue();
      cubit.venueTextChanged('Old Query');
      await Future<void>.delayed(Duration.zero);
      cubit.venueTextChanged('New Query');
      await Future<void>.delayed(Duration.zero);

      venueRepository.requests[1].completer.complete(
        Result<List<TableGroupVenueOption>>.success(<TableGroupVenueOption>[
          _venueOption(id: 'new', name: 'New Venue'),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      venueRepository.requests[0].completer.complete(
        Result<List<TableGroupVenueOption>>.success(<TableGroupVenueOption>[
          _venueOption(id: 'old', name: 'Old Venue'),
        ]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.venueQuery, 'New Query');
      expect(cubit.state.venueOptions.single.id, 'new');
    });

    test('disabling venue invalidates an in-flight search response', () async {
      final venueRepository = _DeferredVenueOptionRepository();
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: venueRepository,
        venueSearchDebounce: Duration.zero,
      );
      addTearDown(cubit.close);

      cubit.enableSpecificVenue();
      cubit.venueTextChanged('Pending Venue');
      await Future<void>.delayed(Duration.zero);
      expect(venueRepository.requests, hasLength(1));

      cubit.disableSpecificVenue();
      venueRepository.requests.single.completer.complete(
        Result<List<TableGroupVenueOption>>.success(<TableGroupVenueOption>[
          _venueOption(id: 'stale', name: 'Stale Venue'),
        ]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.venueMode, TableGroupVenueMode.none);
      expect(cubit.state.venueQuery, isEmpty);
      expect(cubit.state.venueOptions, isEmpty);
      expect(cubit.state.venueSearchLoading, isFalse);
      expect(cubit.state.venueSuggestionsVisible, isFalse);
    });

    test('venue search error remains inline and custom submit works', () async {
      const searchError = AppError(
        code: 'venue_search_failed',
        message: 'Search failed',
      );
      final tableRepository = _TableGroupRepositoryFake();
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: tableRepository,
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: _VenueOptionRepositoryFake(
          const Result<List<TableGroupVenueOption>>.failure(searchError),
        ),
        venueSearchDebounce: Duration.zero,
      );
      addTearDown(cubit.close);

      cubit.enableSpecificVenue();
      cubit.venueTextChanged('Custom Venue');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.venueMode, TableGroupVenueMode.custom);
      expect(cubit.state.venueSearchError, same(searchError));
      expect(cubit.state.status, TableGroupCreateStatus.idle);
      expect(cubit.state.error, isNull);

      final created = await cubit.createTableGroup(
        _createRequest(venueName: 'Custom Venue'),
      );
      expect(created, isTrue);
      expect(cubit.state.status, TableGroupCreateStatus.success);
    });

    test(
      'rejects an invalid description before calling the repository',
      () async {
        final repository = _TableGroupRepositoryFake();
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: repository,
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        );
        addTearDown(cubit.close);

        expect(
          await cubit.createTableGroup(_createRequest(description: '   ')),
          isFalse,
        );
        expect(cubit.state.error?.code, 'table_group_description_invalid');
        expect(repository.lastCreateRequest, isNull);

        final tooLong = List<String>.filled(
          TableGroupCreateRequest.maxDescriptionLength + 1,
          'a',
        ).join();
        expect(
          await cubit.createTableGroup(_createRequest(description: tooLong)),
          isFalse,
        );
        expect(cubit.state.error?.code, 'table_group_description_invalid');
        expect(repository.lastCreateRequest, isNull);
      },
    );

    test('forwards a create request without a specific venue', () async {
      final repository = _TableGroupRepositoryFake();
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: repository,
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      );
      addTearDown(cubit.close);

      final created = await cubit.createTableGroup(
        _createRequest(venueName: null),
      );

      expect(created, isTrue);
      expect(repository.lastCreateRequest?.venueId, isNull);
      expect(repository.lastCreateRequest?.venueName, isNull);
    });

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
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        );
        addTearDown(cubit.close);
        final request = _createRequest(description: 'Eşzamanlı istek testi');

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

    test(
      'discards obsolete city, district, and neighborhood results',
      () async {
        final locationRepository = _DeferredLocationRepository();
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: _TableGroupRepositoryFake(),
          locationRepository: locationRepository,
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        );
        addTearDown(cubit.close);

        final firstCities = cubit.loadCities();
        final secondCities = cubit.loadCities();
        await Future<void>.delayed(Duration.zero);
        locationRepository.completeCities(1, const <City>[
          City(id: 'city-2', name: 'Second'),
        ]);
        await secondCities;
        locationRepository.completeCities(0, const <City>[
          City(id: 'city-1', name: 'First'),
        ]);
        await firstCities;
        expect(cubit.state.cities.single.id, 'city-2');

        final firstDistricts = cubit.loadDistricts('city-1');
        final secondDistricts = cubit.loadDistricts('city-2');
        await Future<void>.delayed(Duration.zero);
        locationRepository.completeDistricts('city-2', const <District>[
          District(id: 'district-2', name: 'Second', cityId: 'city-2'),
        ]);
        await secondDistricts;
        locationRepository.completeDistricts('city-1', const <District>[
          District(id: 'district-1', name: 'First', cityId: 'city-1'),
        ]);
        await firstDistricts;
        expect(cubit.state.districts.single.id, 'district-2');

        final firstNeighborhoods = cubit.loadNeighborhoods('district-1');
        final secondNeighborhoods = cubit.loadNeighborhoods('district-2');
        await Future<void>.delayed(Duration.zero);
        locationRepository.completeNeighborhoods(
          'district-2',
          const <Neighborhood>[
            Neighborhood(id: 'n-2', name: 'Second', districtId: 'district-2'),
          ],
        );
        await secondNeighborhoods;
        locationRepository.completeNeighborhoods(
          'district-1',
          const <Neighborhood>[
            Neighborhood(id: 'n-1', name: 'First', districtId: 'district-1'),
          ],
        );
        await firstNeighborhoods;
        expect(cubit.state.neighborhoods.single.id, 'n-2');
      },
    );

    test(
      'rejects an overlapping create request without a second POST',
      () async {
        final repository = _DeferredTableGroupRepository();
        final cubit = TableGroupCreateCubit(
          tableGroupRepository: repository,
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        );
        addTearDown(cubit.close);
        final firstRequest = _createRequest(description: 'First');
        final secondRequest = _createRequest(description: 'Second');

        final first = cubit.createTableGroup(firstRequest);
        final second = await cubit.createTableGroup(secondRequest);
        await Future<void>.delayed(Duration.zero);
        expect(second, isFalse);
        expect(repository.createRequestCount, 1);
        repository.completeCreate(0, Result.success(_group('first')));

        expect(await first, isTrue);
        expect(cubit.state.status, TableGroupCreateStatus.success);
        expect(cubit.state.error, isNull);
      },
    );

    test('pending location response cannot unlock an active submit', () async {
      final locationRepository = _DeferredLocationRepository();
      final repository = _DeferredTableGroupRepository();
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: repository,
        locationRepository: locationRepository,
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      );
      addTearDown(cubit.close);

      final locations = cubit.loadDistricts('city-1');
      final create = cubit.createTableGroup(_createRequest());
      await Future<void>.delayed(Duration.zero);
      locationRepository.completeDistricts('city-1', const <District>[
        District(id: 'district-1', name: 'District', cityId: 'city-1'),
      ]);
      await locations;

      expect(cubit.state.status, TableGroupCreateStatus.submitting);
      repository.completeCreate(0, Result.success(_group('created')));
      expect(await create, isTrue);
      expect(cubit.state.status, TableGroupCreateStatus.success);
    });

    test('returns false when create finishes after cubit closure', () async {
      final repository = _DeferredTableGroupRepository();
      final cubit = TableGroupCreateCubit(
        tableGroupRepository: repository,
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      );

      final create = cubit.createTableGroup(_createRequest());
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      repository.completeCreate(0, Result.success(_group('late')));

      expect(await create, isFalse);
    });
  });

  testWidgets('create screen disables location inputs while loading', (
    tester,
  ) async {
    await serviceLocator.reset();
    final locationRepository = _DeferredLocationRepository();
    serviceLocator.registerFactory<TableGroupCreateCubit>(
      () => TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: locationRepository,
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      ),
    );
    addTearDown(serviceLocator.reset);

    await tester.pumpWidget(MaterialApp(home: TableGroupCreateScreen()));
    await tester.pump();

    final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdowns, hasLength(3));
    expect(dropdowns.every((dropdown) => dropdown.onChanged == null), isTrue);
    final submit = tester.widget<InkWell>(
      find.byKey(const Key('table_group_create_submit')),
    );
    expect(submit.onTap, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    locationRepository.completeCities(0, const <City>[]);
    await tester.pump();
  });
}
