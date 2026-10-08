part of 'table_group_models_cubit_test.dart';

void _registerTableGroupModelsCubit6() {
  testWidgets('create description is required and bounded to 280 characters', (
    tester,
  ) async {
    await serviceLocator.reset();
    serviceLocator.registerFactory<TableGroupCreateCubit>(
      () => TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      ),
    );
    addTearDown(serviceLocator.reset);

    await tester.pumpWidget(MaterialApp(home: TableGroupCreateScreen()));
    await tester.pumpAndSettle();

    final description = find.byKey(const Key('table_group_description_input'));
    final field = tester.widget<TextField>(
      find.descendant(of: description, matching: find.byType(TextField)),
    );
    // The API limit is Unicode code points, so the field uses its own
    // formatter/counter instead of Flutter's grapheme-counting maxLength.
    expect(field.maxLength, isNull);
    expect(field.minLines, 3);
    expect(field.maxLines, 5);
    expect(find.text('0/280'), findsOneWidget);

    await tester.ensureVisible(description);
    await tester.enterText(description, '   ');
    final submit = find.byKey(const Key('table_group_create_submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Masa açıklaması zorunlu'), findsOneWidget);

    final tooLong = List<String>.filled(
      TableGroupCreateRequest.maxDescriptionLength + 1,
      'a',
    ).join();
    await tester.ensureVisible(description);
    await tester.enterText(description, tooLong);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: description, matching: find.byType(TextField)),
          )
          .controller
          ?.text
          .length,
      TableGroupCreateRequest.maxDescriptionLength,
    );
    expect(find.text('280/280'), findsOneWidget);

    const familyEmoji = '👨‍👩‍👦';
    expect(familyEmoji.runes.length, 5);
    final compoundEmojiOverflow = List<String>.filled(
      (TableGroupCreateRequest.maxDescriptionLength ~/ 5) + 1,
      familyEmoji,
    ).join();
    await tester.enterText(description, compoundEmojiOverflow);
    await tester.pump();
    final compoundEmojiValue = tester
        .widget<TextField>(
          find.descendant(of: description, matching: find.byType(TextField)),
        )
        .controller
        ?.text;
    expect(compoundEmojiValue?.runes.length, 280);
    expect(compoundEmojiValue, List<String>.filled(56, familyEmoji).join());
    expect(find.text('280/280'), findsOneWidget);

    final validWithBoundaryWhitespace =
        '  ${List<String>.filled(280, 'a').join()}  ';
    await tester.enterText(description, validWithBoundaryWhitespace);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: description, matching: find.byType(TextField)),
          )
          .controller
          ?.text,
      validWithBoundaryWhitespace,
    );
    expect(find.text('280/280'), findsOneWidget);

    final excessiveBoundaryWhitespace = List<String>.filled(10_000, ' ').join();
    await tester.enterText(description, excessiveBoundaryWhitespace);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: description, matching: find.byType(TextField)),
          )
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.text('0/280'), findsOneWidget);

    final excessiveTrailingWhitespace =
        '${List<String>.filled(280, 'a').join()}'
        '${List<String>.filled(10_000, ' ').join()}';
    await tester.enterText(description, excessiveTrailingWhitespace);
    await tester.pump();
    final canonicalizedPaste = tester
        .widget<TextField>(
          find.descendant(of: description, matching: find.byType(TextField)),
        )
        .controller
        ?.text;
    expect(canonicalizedPaste, List<String>.filled(280, 'a').join());
    expect(canonicalizedPaste?.runes.length, 280);
    expect(find.text('280/280'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'create retry preserves ambiguous failures then recovers from rejection',
    (tester) async {
      await serviceLocator.reset();
      var now = DateTime(2026, 8, 17, 22, 59, 59);
      const timeout = AppError(
        code: 'network_timeout',
        message: 'Teslim durumu bilinmiyor',
      );
      final repository = _TableGroupRepositoryFake(
        createResult: const Result<TableGroup>.failure(timeout),
      );
      serviceLocator.registerFactory<TableGroupCreateCubit>(
        () => TableGroupCreateCubit(
          tableGroupRepository: repository,
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: const _EmptyVenueOptionRepository(),
        ),
      );
      addTearDown(serviceLocator.reset);

      await tester.pumpWidget(
        MaterialApp(home: TableGroupCreateScreen(now: () => now)),
      );
      await tester.pumpAndSettle();

      final city = find.byKey(const Key('table_group_custom_city'));
      await tester.ensureVisible(city);
      await tester.tap(city);
      await tester.pumpAndSettle();
      await tester.tap(find.text('City').last);
      await tester.pumpAndSettle();

      final addFemale = find.byKey(const Key('table_group_seat_female-add'));
      await tester.ensureVisible(addFemale);
      await tester.tap(addFemale);
      await _enterTableGroupDescription(
        tester,
        'Yanıt kaybolsa da aynı masa isteği tekrar gönderilecek.',
      );
      final submit = find.byKey(const Key('table_group_create_submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.pump();

      expect(repository.createRequests, hasLength(1));
      final firstRequest = repository.createRequests.single;
      expect(firstRequest.meetingAt, DateTime(2026, 8, 17, 23));

      now = DateTime(2026, 8, 17, 23, 0, 1);
      repository.createResult = const Result<TableGroup>.failure(
        AppError(code: '409', message: 'Tanımsız conflict envelope'),
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.pump();

      expect(repository.createRequests, hasLength(2));
      expect(repository.createRequests.last, same(firstRequest));

      repository.createResult = const Result<TableGroup>.failure(
        AppError(code: '503', message: 'Sunucu yanıtı belirsiz'),
      );
      await tester.tap(submit);
      await tester.pump();
      await tester.pump();

      expect(repository.createRequests, hasLength(3));
      expect(repository.createRequests.last, same(firstRequest));
      expect(repository.createRequests.last.toJson(), firstRequest.toJson());

      repository.createResult = const Result<TableGroup>.failure(
        AppError(code: '9104', message: 'Buluşma saati geçmişte kaldı'),
      );
      await tester.tap(submit);
      await tester.pump();
      await tester.pump();

      expect(repository.createRequests, hasLength(4));
      expect(repository.createRequests.last, same(firstRequest));

      repository.createResult = const Result<TableGroup>.failure(timeout);
      await tester.tap(submit);
      await tester.pump();
      await tester.pump();

      expect(repository.createRequests, hasLength(5));
      final recoveredRequest = repository.createRequests.last;
      expect(recoveredRequest, isNot(same(firstRequest)));
      expect(recoveredRequest.meetingAt, DateTime(2026, 8, 18, 23));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('create preview refreshes its relative day after midnight', (
    tester,
  ) async {
    await serviceLocator.reset();
    var now = DateTime(2026, 9, 2, 23, 59, 59);
    serviceLocator.registerFactory<TableGroupCreateCubit>(
      () => TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      ),
    );
    addTearDown(serviceLocator.reset);

    await tester.pumpWidget(
      MaterialApp(home: TableGroupCreateScreen(now: () => now)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Yarın 23:00'), findsOneWidget);

    now = DateTime(2026, 9, 3, 0, 0, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Bugün 23:00'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 9, 3, 23, 30);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Yarın 23:00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    now = DateTime(2026, 9, 4);
    await tester.pump(const Duration(days: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'specific venue is opt-in and disabling it submits no hidden venue',
    (tester) async {
      await serviceLocator.reset();
      const submitError = AppError(code: 'keep_open', message: 'Keep open');
      final repository = _TableGroupRepositoryFake(
        createResult: const Result<TableGroup>.failure(submitError),
      );
      late TableGroupCreateCubit cubit;
      serviceLocator.registerFactory<TableGroupCreateCubit>(
        () => cubit = TableGroupCreateCubit(
          tableGroupRepository: repository,
          locationRepository: _LocationRepositoryFake(),
          venueOptionRepository: const _EmptyVenueOptionRepository(),
          venueSearchDebounce: Duration.zero,
        ),
      );
      addTearDown(serviceLocator.reset);

      await tester.pumpWidget(MaterialApp(home: TableGroupCreateScreen()));
      await tester.pumpAndSettle();

      final toggle = find.byKey(const Key('table_group_specific_venue_toggle'));
      expect(toggle, findsOneWidget);
      expect(cubit.state.venueMode, TableGroupVenueMode.none);
      expect(find.byKey(const Key('table_group_venue_input')), findsNothing);
      final city = find.byKey(const Key('table_group_custom_city'));
      expect(city, findsOneWidget);

      await tester.ensureVisible(city);
      await tester.tap(city);
      await tester.pumpAndSettle();
      await tester.tap(find.text('City').last);
      await tester.pumpAndSettle();

      await _enableSpecificVenue(tester);
      final venueInput = find.byKey(const Key('table_group_venue_input'));
      await tester.enterText(venueInput, 'Sonradan vazgeçilen mekân');
      await tester.pump();
      expect(cubit.state.venueMode, TableGroupVenueMode.custom);

      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(cubit.state.venueMode, TableGroupVenueMode.none);
      expect(cubit.state.venueQuery, isEmpty);
      expect(find.byKey(const Key('table_group_venue_input')), findsNothing);
      expect(
        tester.widget<DropdownButtonFormField<String>>(city).initialValue,
        'city-1',
      );

      final addFemale = find.byKey(const Key('table_group_seat_female-add'));
      await tester.ensureVisible(addFemale);
      await tester.tap(addFemale);
      await _enterTableGroupDescription(
        tester,
        'Mekânı henüz belli olmayan güzel bir buluşma.',
      );
      final submit = find.byKey(const Key('table_group_create_submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(repository.lastCreateRequest?.venueId, isNull);
      expect(repository.lastCreateRequest?.venueName, isNull);
      expect(repository.lastCreateRequest?.cityId, 'city-1');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('create keeps time picker compact without legacy guidance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await serviceLocator.reset();
    serviceLocator.registerFactory<TableGroupCreateCubit>(
      () => TableGroupCreateCubit(
        tableGroupRepository: _TableGroupRepositoryFake(),
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: const _EmptyVenueOptionRepository(),
      ),
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
        home: TableGroupCreateScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final timePicker = find.byKey(const Key('table_group_create_time'));
    await tester.ensureVisible(timePicker);
    await tester.pump();

    expect(timePicker, findsOneWidget);
    expect(find.byKey(const Key('table_group_meeting_guidance')), findsNothing);
    expect(find.text('Buluşma Tercihleri'), findsOneWidget);
    expect(find.text('Buluşma saati'), findsOneWidget);
    expect(find.text('Masan 24 saat boyunca açık kalır.'), findsOneWidget);
    expect(tester.getSize(timePicker).width, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('successful create pops a typed result for the created city', (
    tester,
  ) async {
    await serviceLocator.reset();
    const createdCityId = 'created-city';
    final tableRepository = _DeferredTableGroupRepository();
    final venueRepository = _VenueOptionRepositoryFake(
      Result<List<TableGroupVenueOption>>.success(<TableGroupVenueOption>[
        _venueOption(
          id: 'registered-venue',
          name: 'Registered Venue',
          cityId: createdCityId,
        ),
      ]),
    );
    serviceLocator.registerFactory<TableGroupCreateCubit>(
      () => TableGroupCreateCubit(
        tableGroupRepository: tableRepository,
        locationRepository: _LocationRepositoryFake(),
        venueOptionRepository: venueRepository,
      ),
    );
    addTearDown(serviceLocator.reset);
    TableGroupCreateResult? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              key: const Key('open_table_group_create'),
              onPressed: () async {
                final result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (_) => TableGroupCreateScreen(),
                  ),
                );
                if (result is TableGroupCreateResult) routeResult = result;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_table_group_create')));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open_table_group_create')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open_table_group_create')));
    await tester.pumpAndSettle();

    await _enableSpecificVenue(tester);
    final venueInput = find.byKey(const Key('table_group_venue_input'));
    await tester.ensureVisible(venueInput);
    await tester.enterText(venueInput, 'Registered Venue');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final venueOption = find.byKey(
      const Key('table_group_venue_option-registered-venue'),
    );
    await tester.ensureVisible(venueOption);
    await tester.tap(venueOption);
    await tester.pump();

    final addFemale = find.byKey(const Key('table_group_seat_female-add'));
    await tester.ensureVisible(addFemale);
    await tester.tap(addFemale);
    await _enterTableGroupDescription(
      tester,
      '  Konser öncesi tanışıp sohbet edeceğiz.  ',
    );
    final submit = find.byKey(const Key('table_group_create_submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);

    expect(tableRepository.createRequestCount, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      find.textContaining('Masana Mesajlar bölümünden ulaşabilirsin.'),
      findsNothing,
    );
    expect(find.byKey(const Key('table_group_create_submit')), findsOneWidget);
    expect(find.byKey(const Key('open_table_group_create')), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('table_group_create_back')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('table_group_create_time')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<InkWell>(find.byKey(const Key('table_group_seat_female-add')))
          .onTap,
      isNull,
    );
    expect(
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged,
      isNull,
    );

    tableRepository.completeCreate(
      0,
      Result.success(
        _group('created', cityId: createdCityId, cityName: 'Created City'),
      ),
    );
    await tester.pumpAndSettle();

    expect(routeResult?.cityId, createdCityId);
    expect(
      find.text('Masa oluşturuldu.\nMasana Mesajlar bölümünden ulaşabilirsin.'),
      findsOneWidget,
    );
    expect(tableRepository.lastCreateRequest?.cityId, createdCityId);
    expect(
      tableRepository.lastCreateRequest?.description,
      'Konser öncesi tanışıp sohbet edeceğiz.',
    );
    expect(find.byKey(const Key('open_table_group_create')), findsOneWidget);
  });

  testWidgets(
    'table list consumes create result and shows the created city tables',
    (tester) async {
      await serviceLocator.reset();
      final locations = _LocationRepositoryFake()
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
                    key: const Key('return_created_city'),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const TableGroupCreateResult(cityId: 'city-2')),
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
      await listCubit.setCity('city-1');
      await listCubit.setDistrict('district-1');
      await listCubit.setNeighborhood('neighborhood-1');
      await tester.pump();

      expect(
        find.byKey(const Key('table_group_description_title-old-table')),
        findsOneWidget,
      );
      expect(listCubit.state.selectedDistrictId, 'district-1');
      expect(listCubit.state.selectedNeighborhoodId, 'neighborhood-1');

      await tester.tap(find.byKey(const Key('table_group_create_fab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byKey(const Key('return_created_city')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(listCubit.state.selectedCityId, 'city-2');
      expect(listCubit.state.selectedDistrictId, isNull);
      expect(listCubit.state.selectedNeighborhoodId, isNull);
      expect(tableRepository.lastCityId, 'city-2');
      expect(tableRepository.lastDistrictId, isNull);
      expect(tableRepository.lastNeighborhoodId, isNull);
      expect(
        find.byKey(const Key('table_group_description_title-old-table')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('table_group_description_title-created-table')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
