part of 'table_group_models_cubit_test.dart';

void _registerTableGroupModelsCubit7() {
  testWidgets('table list preserves the global feed after a create result', (
    tester,
  ) async {
    await serviceLocator.reset();
    final locations = _LocationRepositoryFake()
      ..cities = const Result.success(<City>[
        City(id: 'city-1', name: 'Old City'),
        City(id: 'city-2', name: 'Created Table City'),
      ]);
    final groupsByCity = <String, List<TableGroup>>{
      'city-1': <TableGroup>[_group('old-table', venueName: 'Old City Venue')],
    };
    final tableRepository = _CityAwareTableGroupRepository(
      groupsByCity: groupsByCity,
    );
    late TableGroupListCubit listCubit;
    serviceLocator.registerFactory<TableGroupListCubit>(
      () => listCubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      ),
    );
    serviceLocator.registerSingleton<AuthSessionManager>(
      _FixedAuthSessionManager(
        AuthSession.authenticated(
          token: 'test-token',
          userId: 'test-user',
          username: 'test-user',
          accountStatus: 'ACTIVE',
          roles: const <String>['ROLE_MUSICIAN'],
          permissions: const <String>[],
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          isAdmin: false,
        ),
      ),
      dispose: (manager) => manager.dispose(),
    );
    final tokenStore = _NoopTokenStore();
    serviceLocator.registerSingleton<TokenStore>(tokenStore);
    serviceLocator.registerSingleton<DmBadgeCubit>(
      DmBadgeCubit(_NoopDmRepository(), tokenStore),
      dispose: (cubit) => cubit.close(),
    );
    addTearDown(serviceLocator.reset);

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name != AppRoutes.tableGroupCreate) return null;
          return MaterialPageRoute<Object?>(
            settings: settings,
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('return_created_city_globally'),
                  onPressed: () {
                    groupsByCity['city-2'] = <TableGroup>[
                      _group(
                        'created-table',
                        venueName: 'Created City Venue',
                        cityId: 'city-2',
                        cityName: 'Created Table City',
                      ),
                    ];
                    Navigator.of(
                      context,
                    ).pop(const TableGroupCreateResult(cityId: 'city-2'));
                  },
                  child: const Text('Return created city'),
                ),
              ),
            ),
          );
        },
        home: TableGroupListScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(listCubit.state.selectedCityId, isNull);
    expect(
      find.byKey(const Key('table_group_description_title-old-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('table_group_description_title-created-table')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('table_group_create_fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const Key('return_created_city_globally')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(listCubit.state.selectedCityId, isNull);
    expect(tableRepository.lastCityId, isNull);
    expect(
      find.byKey(const Key('table_group_description_title-old-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('table_group_description_title-created-table')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('global filter is truthful and clear restores all cities', (
    tester,
  ) async {
    await serviceLocator.reset();
    final locations = _LocationRepositoryFake()
      ..cities = const Result.success(<City>[
        City(id: 'city-1', name: 'First City'),
        City(id: 'city-2', name: 'Second City'),
      ]);
    final tableRepository = _CityAwareTableGroupRepository(
      groupsByCity: <String, List<TableGroup>>{
        'city-1': <TableGroup>[_group('first-table', venueName: 'First Venue')],
        'city-2': <TableGroup>[
          _group(
            'second-table',
            venueName: 'Second Venue',
            cityId: 'city-2',
            cityName: 'Second City',
          ),
        ],
      },
    );
    late TableGroupListCubit listCubit;
    serviceLocator.registerFactory<TableGroupListCubit>(
      () => listCubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      ),
    );
    serviceLocator.registerSingleton<AuthSessionManager>(
      _FixedAuthSessionManager(
        AuthSession.authenticated(
          token: 'test-token',
          userId: 'test-user',
          username: 'test-user',
          accountStatus: 'ACTIVE',
          roles: const <String>['ROLE_MUSICIAN'],
          permissions: const <String>[],
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          isAdmin: false,
        ),
      ),
      dispose: (manager) => manager.dispose(),
    );
    final tokenStore = _NoopTokenStore();
    serviceLocator.registerSingleton<TokenStore>(tokenStore);
    serviceLocator.registerSingleton<DmBadgeCubit>(
      DmBadgeCubit(_NoopDmRepository(), tokenStore),
      dispose: (cubit) => cubit.close(),
    );
    addTearDown(serviceLocator.reset);

    await tester.pumpWidget(MaterialApp(home: TableGroupListScreen()));
    await tester.pump();
    await tester.pump();

    expect(listCubit.state.selectedCityId, isNull);
    expect(find.byKey(const Key('table_group_section_title')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('table_group_count_label')))
          .data,
      '2 masa',
    );
    expect(find.byKey(const Key('table_group_filter_label')), findsNothing);
    expect(find.text('Filtreler:'), findsNothing);
    expect(find.byKey(const Key('table_group_clear_filters')), findsNothing);
    expect(
      find.byKey(const Key('table_group_description_title-first-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('table_group_description_title-second-table')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('table_group_open_filters')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Tüm şehirler'), findsOneWidget);
    final cityDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('table_group_filter_city')),
    );
    expect(cityDropdown.initialValue, '__all_cities__');
    expect(cityDropdown.onChanged, isNotNull);
    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const Key('table_group_filter_district')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const Key('table_group_filter_neighborhood')),
          )
          .onChanged,
      isNull,
    );

    cityDropdown.onChanged!('city-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(listCubit.state.selectedCityId, 'city-1');
    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const Key('table_group_filter_district')),
          )
          .onChanged,
      isNotNull,
    );

    await tester.tap(find.text('Kapat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester
          .widget<Text>(find.byKey(const Key('table_group_filter_label')))
          .data,
      'First City',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('table_group_count_label')))
          .data,
      '1 masa',
    );
    expect(find.byKey(const Key('table_group_clear_filters')), findsOneWidget);
    final clearFilterSize = tester.getSize(
      find.byKey(const Key('table_group_clear_filters')),
    );
    expect(clearFilterSize.width, greaterThanOrEqualTo(48));
    expect(clearFilterSize.height, greaterThanOrEqualTo(48));
    expect(
      find.byKey(const Key('table_group_description_title-first-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('table_group_description_title-second-table')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('table_group_clear_filters')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(listCubit.state.selectedCityId, isNull);
    expect(tableRepository.lastCityId, isNull);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('table_group_count_label')))
          .data,
      '2 masa',
    );
    expect(find.byKey(const Key('table_group_filter_label')), findsNothing);
    expect(find.byKey(const Key('table_group_clear_filters')), findsNothing);
    expect(
      find.byKey(const Key('table_group_description_title-first-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('table_group_description_title-second-table')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('long location filter stays accessible at 320dp and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await serviceLocator.reset();
    const longCityName =
        'İçinde Çok Uzun Bir Yerleşim Açıklaması Bulunan Şehir Adı';
    final locations = _LocationRepositoryFake()
      ..cities = const Result.success(<City>[
        City(id: 'city-long', name: longCityName),
      ]);
    final tableRepository = _CityAwareTableGroupRepository(
      groupsByCity: <String, List<TableGroup>>{
        'city-long': const <TableGroup>[],
      },
    );
    late TableGroupListCubit listCubit;
    serviceLocator.registerFactory<TableGroupListCubit>(
      () => listCubit = TableGroupListCubit(
        tableGroupRepository: tableRepository,
        locationRepository: locations,
      ),
    );
    serviceLocator.registerSingleton<AuthSessionManager>(
      _FixedAuthSessionManager(
        AuthSession.authenticated(
          token: 'test-token',
          userId: 'test-user',
          username: 'test-user',
          accountStatus: 'ACTIVE',
          roles: const <String>['ROLE_MUSICIAN'],
          permissions: const <String>[],
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          isAdmin: false,
        ),
      ),
      dispose: (manager) => manager.dispose(),
    );
    final tokenStore = _NoopTokenStore();
    serviceLocator.registerSingleton<TokenStore>(tokenStore);
    serviceLocator.registerSingleton<DmBadgeCubit>(
      DmBadgeCubit(_NoopDmRepository(), tokenStore),
      dispose: (cubit) => cubit.close(),
    );
    addTearDown(serviceLocator.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: TableGroupListScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await listCubit.setCity('city-long');
    await tester.pump();

    final label = tester.widget<Text>(
      find.byKey(const Key('table_group_filter_label')),
    );
    expect(label.data, longCityName);
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    final clearSize = tester.getSize(
      find.byKey(const Key('table_group_clear_filters')),
    );
    expect(clearSize.width, greaterThanOrEqualTo(48));
    expect(clearSize.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('table_group_open_filters')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('table_group_filter_city')), findsOneWidget);
    expect(
      find.byKey(const Key('table_group_filter_district')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('table_group_filter_neighborhood')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'create picker disambiguates same-locality duplicates and locks selection',
    (tester) async {
      await serviceLocator.reset();
      const submitError = AppError(code: 'stop_pop', message: 'Keep screen');
      final tableRepository = _DeferredTableGroupRepository();
      final venueRepository = _VenueOptionRepositoryFake(
        Result<List<TableGroupVenueOption>>.success(<TableGroupVenueOption>[
          _venueOption(
            id: 'venue-a',
            name: 'Duplicate Name',
            profilePictureUrl: 'not-a-network-url',
          ),
          _venueOption(
            id: 'venue-b',
            name: 'Duplicate Name',
            address: 'Other Address 2',
          ),
        ]),
      );
      late TableGroupCreateCubit cubit;
      serviceLocator.registerFactory<TableGroupCreateCubit>(
        () => cubit = TableGroupCreateCubit(
          tableGroupRepository: tableRepository,
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: venueRepository,
        ),
      );
      addTearDown(serviceLocator.reset);

      await tester.pumpWidget(MaterialApp(home: TableGroupCreateScreen()));
      await tester.pumpAndSettle();
      await _enableSpecificVenue(tester);
      final venueInput = find.byKey(const Key('table_group_venue_input'));
      await tester.ensureVisible(venueInput);
      await tester.enterText(venueInput, 'Duplicate Name');
      await tester.pump(const Duration(milliseconds: 299));
      expect(
        find.byKey(const Key('table_group_venue_option-venue-a')),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      final venueField = tester.widget<TextField>(
        find.descendant(of: venueInput, matching: find.byType(TextField)),
      );
      expect(venueField.maxLength, 64);
      expect(venueField.decoration?.counterText, '');
      expect(find.text('14/64'), findsNothing);
      expect(cubit.state.venueMode, TableGroupVenueMode.custom);
      expect(cubit.state.selectedVenue, isNull);
      expect(
        find.byKey(const Key('table_group_venue_option-venue-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_venue_option-venue-b')),
        findsOneWidget,
      );
      expect(find.text('Caferağa, Kadıköy, İstanbul'), findsNWidgets(2));
      expect(find.text('Moda Caddesi 1'), findsNothing);
      expect(find.text('Other Address 2'), findsNothing);
      expect(find.text("SoundConnect'te kayıtlı"), findsNothing);
      final venueImage = tester.widget<AppCachedNetworkImage>(
        find.byKey(const Key('table_group_venue_image-venue-a')),
      );
      expect(venueImage.imageUrl, 'not-a-network-url');
      expect(
        find.descendant(
          of: find.byKey(const Key('table_group_venue_avatar-venue-a')),
          matching: find.byIcon(Icons.storefront_rounded),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('table_group_custom_city')), findsOneWidget);

      final infoA = find.byKey(const Key('table_group_venue_info-venue-a'));
      expect(
        tester.getSemantics(infoA).tooltip,
        'Duplicate Name hakkında bilgi',
      );
      await tester.ensureVisible(infoA);
      await tester.tap(infoA);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('table_group_venue_info_dialog')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Bu mekânı seçmen yalnızca masanın buluşma konumunu belirtir. '
          'Mekâna bildirim gönderilmez ve rezervasyon oluşturulmaz.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_venue_info_name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_venue_info_location')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('table_group_venue_info_address')),
            )
            .data,
        'Moda Caddesi 1',
      );
      expect(cubit.state.selectedVenue, isNull);
      await tester.tap(find.byKey(const Key('table_group_venue_info_close')));
      await tester.pumpAndSettle();

      final infoB = find.byKey(const Key('table_group_venue_info-venue-b'));
      await tester.ensureVisible(infoB);
      await tester.tap(infoB);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('table_group_venue_info_address')),
            )
            .data,
        'Other Address 2',
      );
      expect(cubit.state.selectedVenue, isNull);
      await tester.tap(find.byKey(const Key('table_group_venue_info_close')));
      await tester.pumpAndSettle();

      final venueB = find.byKey(const Key('table_group_venue_option-venue-b'));
      await tester.ensureVisible(venueB);
      await tester.tap(venueB);
      await tester.pump();

      expect(cubit.state.selectedVenue?.id, 'venue-b');
      final registeredSummary = find.byKey(
        const Key('table_group_registered_venue_summary'),
      );
      expect(registeredSummary, findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: venueInput, matching: find.byType(TextField)),
            )
            .readOnly,
        isTrue,
      );
      final selectedColorScheme = Theme.of(
        tester.element(registeredSummary),
      ).colorScheme;
      final selectedMaterial = tester.widget<Material>(registeredSummary);
      expect(
        selectedMaterial.color,
        selectedColorScheme.surfaceContainerHighest,
      );
      expect(
        selectedMaterial.color,
        isNot(selectedColorScheme.primaryContainer),
      );
      expect(
        find.byKey(const Key('table_group_locked_venue_location')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_selected_venue_info')),
        findsOneWidget,
      );
      expect(find.text('Caferağa, Kadıköy, İstanbul'), findsOneWidget);
      expect(find.text('Other Address 2'), findsNothing);
      expect(find.text("SoundConnect'te kayıtlı"), findsNothing);
      expect(find.byKey(const Key('table_group_custom_city')), findsNothing);
      expect(
        tester
            .getSemantics(
              find.byKey(
                const ValueKey<String>('table_group_venue_semantics-venue-b'),
              ),
            )
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );

      final registeredClear = find.byKey(
        const Key('table_group_registered_venue_clear'),
      );
      expect(registeredClear, findsOneWidget);
      expect(
        tester.getSemantics(registeredClear).tooltip,
        'Mekân seçimini kaldır',
      );
      final clearSize = tester.getSize(registeredClear);
      expect(clearSize.width, greaterThanOrEqualTo(48));
      expect(clearSize.height, greaterThanOrEqualTo(48));

      await tester.ensureVisible(registeredClear);
      await tester.tap(registeredClear);
      await tester.pumpAndSettle();

      expect(cubit.state.venueMode, TableGroupVenueMode.custom);
      expect(cubit.state.selectedVenue, isNull);
      expect(
        tester.widget<TextFormField>(venueInput).controller?.text,
        isEmpty,
      );
      expect(registeredSummary, findsNothing);
      expect(registeredClear, findsNothing);
      expect(find.byKey(const Key('table_group_custom_city')), findsOneWidget);

      await tester.enterText(venueInput, 'Duplicate Name');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(venueRepository.queries, <String>[
        'Duplicate Name',
        'Duplicate Name',
      ]);
      expect(venueB, findsOneWidget);
      await tester.ensureVisible(venueB);
      await tester.tap(venueB);
      await tester.pump();

      expect(cubit.state.venueMode, TableGroupVenueMode.registered);
      expect(cubit.state.selectedVenue?.id, 'venue-b');
      expect(registeredSummary, findsOneWidget);
      expect(registeredClear, findsOneWidget);

      final addFemale = find.byKey(const Key('table_group_seat_female-add'));
      await tester.ensureVisible(addFemale);
      await tester.tap(addFemale);
      await _enterTableGroupDescription(
        tester,
        'Kayıtlı mekânda yeni insanlarla tanışma masası.',
      );
      final submit = find.byKey(const Key('table_group_create_submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(cubit.state.status, TableGroupCreateStatus.submitting);
      final venueToggle = find.byKey(
        const Key('table_group_specific_venue_toggle'),
      );
      expect(tester.widget<InkWell>(venueToggle).onTap, isNull);
      final selectedInfo = find.byKey(
        const Key('table_group_selected_venue_info'),
      );
      expect(tester.widget<IconButton>(selectedInfo).onPressed, isNull);
      expect(tester.widget<IconButton>(registeredClear).onPressed, isNull);
      await tester.tap(selectedInfo, warnIfMissed: false);
      await tester.pump();
      expect(
        find.byKey(const Key('table_group_venue_info_dialog')),
        findsNothing,
      );
      tableRepository.completeCreate(
        0,
        const Result<TableGroup>.failure(submitError),
      );
      await tester.pump();

      final request = tableRepository.lastCreateRequest!;
      expect(request.venueId, 'venue-b');
      expect(request.venueName, isNull);
      expect(request.cityId, 'city-1');
      expect(request.districtId, 'district-1');
      expect(request.neighborhoodId, 'neighborhood-1');
      expect(
        request.description,
        'Kayıtlı mekânda yeni insanlarla tanışma masası.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
