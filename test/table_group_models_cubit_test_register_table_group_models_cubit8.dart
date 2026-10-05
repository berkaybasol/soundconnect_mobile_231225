part of 'table_group_models_cubit_test.dart';

void _registerTableGroupModelsCubit8() {
  testWidgets(
    'search error keeps free custom venue and its manual location submittable',
    (tester) async {
      await serviceLocator.reset();
      const searchError = AppError(
        code: 'venue_search_failed',
        message: 'Kayıtlı mekân araması kullanılamıyor',
      );
      const submitError = AppError(code: 'stop_pop', message: 'Keep screen');
      final tableRepository = _TableGroupRepositoryFake(
        createResult: const Result<TableGroup>.failure(submitError),
      );
      late TableGroupCreateCubit cubit;
      serviceLocator.registerFactory<TableGroupCreateCubit>(
        () => cubit = TableGroupCreateCubit(
          tableGroupRepository: tableRepository,
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: _VenueOptionRepositoryFake(
            const Result<List<TableGroupVenueOption>>.failure(searchError),
          ),
          venueSearchDebounce: Duration.zero,
        ),
      );
      addTearDown(serviceLocator.reset);

      await tester.pumpWidget(MaterialApp(home: TableGroupCreateScreen()));
      await tester.pumpAndSettle();
      await _enableSpecificVenue(tester);
      final venueInput = find.byKey(const Key('table_group_venue_input'));
      await tester.ensureVisible(venueInput);
      await tester.enterText(venueInput, 'Free Name');
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('table_group_venue_search_error')),
        findsOneWidget,
      );
      expect(find.text('“Free Name” adını serbest kullan'), findsOneWidget);

      final city = find.byKey(const Key('table_group_custom_city'));
      await tester.ensureVisible(city);
      await tester.tap(city);
      await tester.pumpAndSettle();
      await tester.tap(find.text('City').last);
      await tester.pumpAndSettle();

      final district = find.byKey(const Key('table_group_custom_district'));
      await tester.ensureVisible(district);
      await tester.tap(district);
      await tester.pumpAndSettle();
      await tester.tap(find.text('District').last);
      await tester.pumpAndSettle();

      final neighborhood = find.byKey(
        const Key('table_group_custom_neighborhood'),
      );
      await tester.ensureVisible(neighborhood);
      await tester.tap(neighborhood);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neighborhood').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(venueInput);
      await tester.enterText(venueInput, 'Free Name corrected');
      await tester.pump();
      await tester.pump();

      final custom = find.byKey(const Key('table_group_use_custom_venue'));
      await tester.ensureVisible(custom);
      await tester.tap(custom);
      await tester.pump();
      expect(cubit.state.venueSearchError, isNull);
      expect(
        find.byKey(const Key('table_group_venue_search_results')),
        findsNothing,
      );
      expect(cubit.state.cities.single.id, 'city-1');
      expect(cubit.state.districts.single.id, 'district-1');

      final addFemale = find.byKey(const Key('table_group_seat_female-add'));
      await tester.ensureVisible(addFemale);
      await tester.tap(addFemale);
      await _enterTableGroupDescription(
        tester,
        'Serbest mekân için kısa masa açıklaması.',
      );
      final submit = find.byKey(const Key('table_group_create_submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      final request = tableRepository.lastCreateRequest!;
      expect(request.venueId, isNull);
      expect(request.venueName, 'Free Name corrected');
      expect(request.cityId, 'city-1');
      expect(request.districtId, 'district-1');
      expect(request.neighborhoodId, 'neighborhood-1');
      expect(request.description, 'Serbest mekân için kısa masa açıklaması.');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('location load failure has an inline retry path', (tester) async {
    await serviceLocator.reset();
    const locationError = AppError(
      code: 'cities_unavailable',
      message: 'Şehirler yüklenemedi',
    );
    final locations = _LocationRepositoryFake()
      ..cities = const Result<List<City>>.failure(locationError);
    late TableGroupCreateCubit cubit;
    serviceLocator.registerFactory<TableGroupCreateCubit>(
      () => cubit = TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: locations,
        venueOptionRepository: const _EmptyVenueOptionRepository(),
        venueSearchDebounce: Duration.zero,
      ),
    );
    addTearDown(serviceLocator.reset);

    await tester.pumpWidget(MaterialApp(home: TableGroupCreateScreen()));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('table_group_location_load_error')),
      findsOneWidget,
    );

    await _enableSpecificVenue(tester);
    final venueInput = find.byKey(const Key('table_group_venue_input'));
    await tester.ensureVisible(venueInput);
    await tester.enterText(venueInput, 'Retry Cafe');
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const Key('table_group_location_load_error')),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);

    locations.cities = const Result<List<City>>.success(<City>[
      City(id: 'city-recovered', name: 'Recovered City'),
    ]);
    final retry = find.byKey(const Key('table_group_retry_locations'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('table_group_location_load_error')),
      findsNothing,
    );
    expect(cubit.state.cities.single.name, 'Recovered City');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('venue picker fits 320dp with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await serviceLocator.reset();
    serviceLocator.registerFactory<TableGroupCreateCubit>(
      () => TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: _VenueOptionRepositoryFake(
          Result<List<TableGroupVenueOption>>.success(<TableGroupVenueOption>[
            _venueOption(
              id: 'responsive',
              name: 'Responsive Venue With A Very Long Display Name',
              address:
                  'A Very Long Address With Building, Floor, Door And Landmark Details',
              cityName: 'A Very Long City Name',
              districtName: 'A Very Long District Name',
              neighborhoodName: 'A Very Long Neighborhood Name',
            ),
          ]),
        ),
        venueSearchDebounce: Duration.zero,
      ),
    );
    addTearDown(serviceLocator.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: TableGroupCreateScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await _enableSpecificVenue(tester);
    final venueInput = find.byKey(const Key('table_group_venue_input'));
    await tester.ensureVisible(venueInput);
    await tester.enterText(venueInput, 'Responsive Venue');
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final info = find.byKey(const Key('table_group_venue_info-responsive'));
    await tester.ensureVisible(info);
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('table_group_venue_info_address')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('table_group_venue_info_close')));
    await tester.pumpAndSettle();

    final option = find.byKey(const Key('table_group_venue_option-responsive'));
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pump();
    expect(
      find.byKey(const Key('table_group_registered_venue_summary')),
      findsOneWidget,
    );
    final registeredClear = find.byKey(
      const Key('table_group_registered_venue_clear'),
    );
    expect(registeredClear, findsOneWidget);
    final clearSize = tester.getSize(registeredClear);
    expect(clearSize.width, greaterThanOrEqualTo(48));
    expect(clearSize.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
