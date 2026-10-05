part of 'table_group_models_cubit_test.dart';

void _registerTableGroupModelsCubit4() {
  group('TableGroupRepositoryImpl', () {
    test(
      'uses active path and omits null location filters from query',
      () async {
        final apiClient = _TableGroupApiClientFake((method, path, query, body) {
          return <String, dynamic>{
            'number': 4,
            'last': false,
            'totalElements': 41,
            'content': <Object?>[_tableGroupWireJson()],
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
        expect(result.data?.totalElements, 41);
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

    test('omits cityId for the global active-table feed', () async {
      final apiClient = _TableGroupApiClientFake((method, path, query, body) {
        return <String, dynamic>{
          'number': 0,
          'last': true,
          'content': const <Object?>[],
        };
      });
      final repository = TableGroupRepositoryImpl(apiClient);

      final result = await repository.listActiveTableGroups(
        cityId: null,
        page: 0,
        size: 20,
      );

      expect(result.isSuccess, isTrue);
      expect(apiClient.lastPath, TableGroupEndpoints.active);
      expect(apiClient.lastQuery, <String, dynamic>{'page': 0, 'size': 20});
    });

    test('uses the principal-scoped active-table endpoint', () async {
      final apiClient = _TableGroupApiClientFake((method, path, query, body) {
        return <String, dynamic>{
          'number': 2,
          'last': false,
          'totalElements': 151,
          'content': <Object?>[_tableGroupWireJson()],
        };
      });
      final repository = TableGroupRepositoryImpl(apiClient);

      final result = await repository.listMyActiveTableGroups(
        page: 2,
        size: 50,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.items.single.id, 'g-1');
      expect(result.data?.nextCursor, '3');
      expect(result.data?.totalElements, 151);
      expect(apiClient.lastMethod, 'GET');
      expect(apiClient.lastPath, TableGroupEndpoints.mine);
      expect(apiClient.lastQuery, <String, dynamic>{'page': 2, 'size': 50});
    });

    test(
      'trims join note and serializes chat message body over POST',
      () async {
        final apiClient = _TableGroupApiClientFake((method, path, query, body) {
          if (path == TableGroupEndpoints.chatMessages('g-1')) {
            return <String, dynamic>{
              'messageId': 'm-1',
              'tableGroupId': 'g-1',
              'senderId': 'owner',
              'clientMessageId': 'client-1',
              'content': 'Hello',
              'messageType': 'TEXT',
              'sentAt': '2026-07-14T00:01:00Z',
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
          clientMessageId: 'client-1',
        );
        expect(sent.data?.messageId, 'm-1');
        expect(sent.data?.clientMessageId, 'client-1');
        expect(apiClient.lastMethod, 'POST');
        expect(apiClient.lastPath, TableGroupEndpoints.chatMessages('g-1'));
        expect(apiClient.lastBody, <String, dynamic>{
          'content': 'Hello',
          'messageType': 'TEXT',
          'clientMessageId': 'client-1',
        });
      },
    );

    test('refuses a blank chat client id before network dispatch', () async {
      var networkCalls = 0;
      final repository = TableGroupRepositoryImpl(
        _TableGroupApiClientFake((method, path, query, body) {
          networkCalls += 1;
          return null;
        }),
      );

      final result = await repository.sendChatMessage(
        tableGroupId: 'g-1',
        content: 'Hello',
        clientMessageId: '   ',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'table_group_chat_client_message_id_invalid');
      expect(networkCalls, 0);
    });

    test('create body never accepts a band or acting-as identity', () async {
      final apiClient = _TableGroupApiClientFake((method, path, query, body) {
        return _tableGroupWireJson(ownerId: 'principal-user');
      });
      final repository = TableGroupRepositoryImpl(apiClient);

      final result = await repository.createTableGroup(_createRequest());

      expect(result.isSuccess, isTrue);
      expect(apiClient.lastPath, TableGroupEndpoints.create());
      final body = apiClient.lastBody! as Map<String, dynamic>;
      expect(body.containsKey('ownerId'), isFalse);
      expect(body.containsKey('bandId'), isFalse);
      expect(body.containsKey('actingAsType'), isFalse);
      expect(body.containsKey('actingAsId'), isFalse);
      expect(body['description'], 'Tanışma ve sohbet masası');
      expect(body.containsKey('expiresAt'), isFalse);
      expect(body['meetingAt'], isA<String>());
    });

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
          description: 'Repository create testi',
          maxPersonCount: 4,
          genderPrefs: const <String>[],
          ageMin: 18,
          ageMax: 99,
          meetingAt: DateTime.utc(2026, 7, 14),
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

    test(
      'normalizes newest-first chat pages and rejects cross-group messages',
      () async {
        var mismatched = false;
        final apiClient = _TableGroupApiClientFake((method, path, query, body) {
          return <String, dynamic>{
            'number': 0,
            'totalPages': 2,
            'content': <Object?>[
              <String, dynamic>{
                'messageId': 'm-2',
                'tableGroupId': mismatched ? 'other-group' : 'g-1',
                'senderId': 'u-1',
                'clientMessageId': 'client-m-2',
                'content': 'newest',
                'messageType': 'TEXT',
                'sentAt': '2026-07-14T00:02:00Z',
              },
              <String, dynamic>{
                'messageId': 'm-1',
                'tableGroupId': 'g-1',
                'senderId': 'u-2',
                'clientMessageId': 'client-m-1',
                'content': 'older',
                'messageType': 'TEXT',
                'sentAt': '2026-07-14T00:01:00Z',
              },
            ],
          };
        });
        final repository = TableGroupRepositoryImpl(apiClient);

        final page = await repository.getChatMessages(tableGroupId: 'g-1');

        expect(page.data?.hasNext, isTrue);
        expect(page.data?.items.map((message) => message.messageId), <String>[
          'm-1',
          'm-2',
        ]);
        expect(page.data?.items.last.sentAt?.isUtc, isTrue);

        mismatched = true;
        final invalid = await repository.getChatMessages(tableGroupId: 'g-1');
        expect(invalid.error?.code, 'table_group_chat_messages_unknown');
      },
    );
  });

  group('TableGroupListCubit', () {
    _registerTableGroupListCubit1();
    _registerTableGroupListCubit2();
  });
}
