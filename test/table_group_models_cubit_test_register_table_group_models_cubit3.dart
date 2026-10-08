part of 'table_group_models_cubit_test.dart';

void _registerTableGroupModelsCubit3() {
  group('table group models', () {
    test('fixture parser isolates aliases and tolerant defaults', () {
      final model = TableGroupModel.fromFixtureJson(<String, dynamic>{
        'id': 17,
        'ownerId': 'owner-1',
        'owner_name': 'Ada',
        'ownerAvatarUrl': 'avatar.jpg',
        'description': '  Akustik bir tanışma masası.  ',
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
      expect(model.description, 'Akustik bir tanışma masası.');
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
        final model = TableGroupModel.fromFixtureJson(<String, dynamic>{
          'expiresAt': 'bad-date',
          'description': '   ',
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
        expect(model.description, isNull);
        expect(model.status, 'ACTIVE');
        expect(message.messageId, '4');
        expect(message.messageType, 'TEXT');
        expect(message.sentAt, isNull);
        expect(message.deletedAt, isNull);
      },
    );

    test(
      'create request retains nullable filters and exact meeting instant',
      () {
        final meetingAt = DateTime.utc(2026, 7, 14, 1, 2, 3);
        final request = TableGroupCreateRequest(
          venueId: null,
          venueName: 'Open air',
          description: '  Açık havada tanışma masası.  ',
          maxPersonCount: 5,
          genderPrefs: const <String>['ALL'],
          ageMin: 18,
          ageMax: 35,
          meetingAt: meetingAt,
          cityId: '34',
          districtId: null,
          neighborhoodId: 'n-1',
        );

        expect(request.toJson(), <String, dynamic>{
          'venueId': null,
          'venueName': 'Open air',
          'description': 'Açık havada tanışma masası.',
          'maxPersonCount': 5,
          'genderPrefs': <String>['ALL'],
          'ageMin': 18,
          'ageMax': 35,
          'meetingAt': '2026-07-14T01:02:03.000Z',
          'cityId': '34',
          'districtId': null,
          'neighborhoodId': 'n-1',
        });
      },
    );

    test('create request accepts zero or one venue identity', () {
      final custom = _createRequest(venueName: '  Serbest Mekân  ');
      final noVenue = _createRequest(venueName: null);
      final blankVenue = _createRequest(venueName: '   ');
      final registered = TableGroupCreateRequest(
        venueId: ' venue-1 ',
        venueName: null,
        description: 'Kayıtlı mekân masası',
        maxPersonCount: 4,
        genderPrefs: const <String>['OTHER'],
        ageMin: 18,
        ageMax: 35,
        meetingAt: DateTime.utc(2026, 7, 14),
        cityId: 'city-1',
        districtId: 'district-1',
        neighborhoodId: 'neighborhood-1',
      );
      final ambiguous = TableGroupCreateRequest(
        venueId: 'venue-1',
        venueName: 'Serbest Mekân',
        description: 'Belirsiz mekân masası',
        maxPersonCount: 4,
        genderPrefs: const <String>['OTHER'],
        ageMin: 18,
        ageMax: 35,
        meetingAt: DateTime.utc(2026, 7, 14),
        cityId: 'city-1',
        districtId: null,
        neighborhoodId: null,
      );

      expect(custom.hasValidVenueIdentity, isTrue);
      expect(custom.toJson()['venueId'], isNull);
      expect(custom.toJson()['venueName'], 'Serbest Mekân');
      expect(registered.hasValidVenueIdentity, isTrue);
      expect(registered.toJson()['venueId'], 'venue-1');
      expect(registered.toJson()['venueName'], isNull);
      expect(noVenue.hasValidVenueIdentity, isTrue);
      expect(noVenue.toJson()['venueId'], isNull);
      expect(noVenue.toJson()['venueName'], isNull);
      expect(blankVenue.hasValidVenueIdentity, isTrue);
      expect(blankVenue.toJson()['venueName'], isNull);
      expect(ambiguous.hasValidVenueIdentity, isFalse);
      expect(custom.hasValidDescription, isTrue);
      expect(
        _createRequest(
          description: List<String>.filled(
            TableGroupCreateRequest.maxDescriptionLength,
            'a',
          ).join(),
        ).hasValidDescription,
        isTrue,
      );
      expect(_createRequest(description: '   ').hasValidDescription, isFalse);
      expect(
        _createRequest(
          description: List<String>.filled(
            TableGroupCreateRequest.maxDescriptionLength + 1,
            'a',
          ).join(),
        ).hasValidDescription,
        isFalse,
      );
      expect(
        _createRequest(
          description: List<String>.filled(
            TableGroupCreateRequest.maxDescriptionLength,
            '😀',
          ).join(),
        ).hasValidDescription,
        isTrue,
      );
      expect(
        _createRequest(
          description: List<String>.filled(
            TableGroupCreateRequest.maxDescriptionLength + 1,
            '😀',
          ).join(),
        ).hasValidDescription,
        isFalse,
      );
    });

    test('wire boundary requires canonical fields and explicit date zones', () {
      expect(parseTableGroupWireDate('2026-07-14T01:02:03'), isNull);
      expect(
        parseTableGroupWireDate('2026-07-14T04:02:03+03:00'),
        DateTime.utc(2026, 7, 14, 1, 2, 3),
      );
      expect(parseTableGroupWireDate('2026-02-30T04:02:03Z'), isNull);

      final model = TableGroupModel.fromWireJson(
        _tableGroupWireJson(
          meetingAt: '2026-07-14T04:02:03+03:00',
          expiresAt: '2026-07-15T01:02:03Z',
          participants: <Object?>[
            <String, dynamic>{
              'userId': 'u-1',
              'joinedAt': '2026-07-14T04:02:03+03:00',
              'status': 'ACCEPTED',
              'joinNote': null,
              'username': 'Deniz',
              'profilePictureUrl': null,
              'visibilityMode': 'GHOST',
            },
          ],
        )..['ownerVisibilityMode'] = 'GHOST',
      );

      expect(model.expiresAt, DateTime.utc(2026, 7, 15, 1, 2, 3));
      expect(model.meetingAt, DateTime.utc(2026, 7, 14, 1, 2, 3));
      expect(
        model.participants.single.joinedAt,
        DateTime.utc(2026, 7, 14, 1, 2, 3),
      );
      expect(model.ownerVisibilityMode, ListenerVisibilityMode.ghost);
      expect(model.isOwnerGhost, isTrue);
      expect(model.participants.single.isGhost, isTrue);

      final missingMeetingAt = _tableGroupWireJson()..remove('meetingAt');
      expect(
        () => TableGroupModel.fromWireJson(missingMeetingAt),
        throwsFormatException,
      );
      expect(
        () => TableGroupModel.fromWireJson(
          _tableGroupWireJson(meetingAt: '2026-07-14T04:02:03'),
        ),
        throwsFormatException,
      );
      final aliasedOwner = _tableGroupWireJson()
        ..remove('ownerUsername')
        ..['owner_name'] = 'Ada';
      expect(
        () => TableGroupModel.fromWireJson(aliasedOwner),
        throwsFormatException,
      );
      final missingCapacity = _tableGroupWireJson()..remove('maxPersonCount');
      expect(
        () => TableGroupModel.fromWireJson(missingCapacity),
        throwsFormatException,
      );
      final missingStartAt = _tableGroupWireJson()..remove('startAt');
      expect(
        () => TableGroupModel.fromWireJson(missingStartAt),
        throwsFormatException,
      );
      expect(
        () => TableGroupModel.fromWireJson(
          _tableGroupWireJson()..['startAt'] = '2026-07-14T01:02:03',
        ),
        throwsFormatException,
      );
      expect(
        () => TableGroupModel.fromWireJson(
          _tableGroupWireJson()..['description'] = null,
        ),
        throwsFormatException,
      );
      expect(
        TableGroupModel.fromWireJson(
          _tableGroupWireJson()
            ..['status'] = 'INACTIVE'
            ..['description'] = null,
        ).description,
        isNull,
      );
      expect(
        () => TableGroupModel.fromWireJson(
          _tableGroupWireJson()..remove('description'),
        ),
        throwsFormatException,
      );
      expect(
        () => TableGroupModel.fromWireJson(
          _tableGroupWireJson()..['ownerVisibilityMode'] = 'FUTURE_MODE',
        ),
        throwsFormatException,
      );

      final request = TableGroupCreateRequest(
        venueId: null,
        venueName: 'Cafe',
        description: 'Saat ve tarih dönüşüm testi',
        maxPersonCount: 4,
        genderPrefs: const <String>[],
        ageMin: 18,
        ageMax: 99,
        meetingAt: DateTime.parse('2026-07-14T04:02:03+03:00'),
        cityId: 'city-1',
        districtId: null,
        neighborhoodId: null,
      );

      expect(request.toJson()['meetingAt'], '2026-07-14T01:02:03.000Z');
      expect(request.toJson().containsKey('expiresAt'), isFalse);
    });

    test('wire TEXT messages require canonical string identities and key', () {
      Map<String, dynamic> messageJson() => <String, dynamic>{
        'messageId': 'message-1',
        'tableGroupId': 'group-1',
        'senderId': 'sender-1',
        'clientMessageId': 'client-1',
        'content': 'Merhaba',
        'messageType': 'TEXT',
        'sentAt': '2026-07-14T20:00:00Z',
      };

      expect(
        TableGroupMessageModel.fromWireJson(messageJson()).clientMessageId,
        'client-1',
      );
      expect(
        () => TableGroupMessageModel.fromWireJson(
          messageJson()..remove('clientMessageId'),
        ),
        throwsFormatException,
      );
      expect(
        () => TableGroupMessageModel.fromWireJson(
          messageJson()..['clientMessageId'] = 7,
        ),
        throwsFormatException,
      );
      expect(
        () => TableGroupMessageModel.fromWireJson(
          messageJson()..['messageType'] = 'text',
        ),
        throwsFormatException,
      );
      expect(
        () => TableGroupMessageModel.fromWireJson(
          messageJson()..['messageId'] = 1,
        ),
        throwsFormatException,
      );
    });
  });

  group('table group venue options', () {
    test('strictly decodes complete registered venue metadata', () {
      final option = TableGroupVenueOptionModel.fromJson(
        _venueOptionJson(
          id: 'venue-1',
          name: 'Jazz Cafe',
          profilePictureUrl: '  https://cdn.example/venue.webp  ',
        ),
      );

      expect(option.id, 'venue-1');
      expect(option.name, 'Jazz Cafe');
      expect(option.profilePictureUrl, 'https://cdn.example/venue.webp');
      expect(option.address, 'Moda Caddesi 1');
      expect(option.locationSummary, 'Caferağa, Kadıköy, İstanbul');
      expect(
        TableGroupVenueOptionModel.fromJson(
          _venueOptionJson(id: 'venue-2', name: 'No Photo')
            ..remove('profilePictureUrl'),
        ).profilePictureUrl,
        isNull,
      );
      expect(
        TableGroupVenueOptionModel.fromJson(
          _venueOptionJson(
            id: 'venue-3',
            name: 'Blank Photo',
            profilePictureUrl: '   ',
          ),
        ).profilePictureUrl,
        isNull,
      );
      expect(
        () => TableGroupVenueOptionModel.fromJson(
          _venueOptionJson(id: 'venue-1', name: 'Jazz Cafe')
            ..remove('districtId'),
        ),
        throwsFormatException,
      );
    });

    test('trims query, caps eight, and deduplicates results by id', () async {
      final apiClient = _TableGroupApiClientFake((method, path, query, body) {
        return <Object?>[
          _venueOptionJson(id: 'venue-1', name: 'Same Name'),
          _venueOptionJson(id: 'venue-1', name: 'Duplicate Must Not Replace'),
          _venueOptionJson(
            id: 'venue-2',
            name: 'Same Name',
            address: 'Başka Sokak 2',
          ),
        ];
      });
      final repository = TableGroupVenueOptionRepositoryImpl(apiClient);

      final result = await repository.search(query: '  Same Name  ', limit: 99);

      expect(result.data?.map((option) => option.id), <String>[
        'venue-1',
        'venue-2',
      ]);
      expect(result.data?.first.name, 'Same Name');
      expect(apiClient.lastPath, TableGroupEndpoints.venueOptions);
      expect(apiClient.lastQuery, <String, dynamic>{
        'q': 'Same Name',
        'limit': 8,
      });
    });

    test('does not transport queries outside the 2..64 contract', () async {
      final apiClient = _TableGroupApiClientFake(
        (_, __, ___, ____) => throw StateError('must not call transport'),
      );
      final repository = TableGroupVenueOptionRepositoryImpl(apiClient);

      final short = await repository.search(query: ' a ');
      final long = await repository.search(
        query: List<String>.filled(65, 'x').join(),
      );

      expect(short.data, isEmpty);
      expect(long.data, isEmpty);
      expect(apiClient.lastMethod, isNull);
    });
  });

  group('table group meeting-time policy', () {
    test('uses today for a future time and tomorrow for a past time', () {
      final now = DateTime.utc(2026, 8, 17, 18, 30, 20);

      expect(
        resolveTableGroupMeetingAt(now: now, hour: 20, minute: 15),
        DateTime.utc(2026, 8, 17, 20, 15),
      );
      expect(
        resolveTableGroupMeetingAt(now: now, hour: 18, minute: 15),
        DateTime.utc(2026, 8, 18, 18, 15),
      );
    });

    test('never exceeds the backend maximum lifetime', () {
      final now = DateTime.utc(2026, 8, 17, 23, 59, 59, 999);
      final meetingAt = resolveTableGroupMeetingAt(
        now: now,
        hour: 23,
        minute: 59,
      );

      expect(meetingAt.isAfter(now), isTrue);
      expect(meetingAt.difference(now) <= tableGroupMaximumMeetingLead, isTrue);
    });

    test('formats today, tomorrow, and later calendar days explicitly', () {
      final now = DateTime(2026, 8, 17, 23, 30);

      expect(
        formatTableGroupMeetingAt(DateTime(2026, 8, 17, 23, 45), now: now),
        'Bugün 23:45',
      );
      expect(
        formatTableGroupMeetingAt(DateTime(2026, 8, 18, 22), now: now),
        'Yarın 22:00',
      );
      expect(
        formatTableGroupMeetingAt(DateTime(2026, 8, 20, 9, 5), now: now),
        '20.08.2026 09:05',
      );
      expect(formatTableGroupMeetingAt(null, now: now), '--:--');
    });

    test('local-day refresh re-arms from the clock and is disposal-safe', () {
      var now = DateTime(2026, 9, 2, 23, 59, 59);
      var refreshes = 0;
      final timers = <_ManualDayTimer>[];
      final delays = <Duration>[];
      final scheduler = TableGroupLocalDayRefreshScheduler(
        now: () => now,
        onRefresh: () => refreshes += 1,
        timerFactory: (delay, callback) {
          delays.add(delay);
          final timer = _ManualDayTimer(callback);
          timers.add(timer);
          return timer;
        },
      );

      scheduler.start();
      expect(delays, <Duration>[const Duration(seconds: 1)]);

      now = DateTime(2026, 9, 3, 12);
      scheduler.reschedule(refresh: true);
      expect(timers.first.isActive, isFalse);
      expect(refreshes, 1);
      expect(delays, <Duration>[
        const Duration(seconds: 1),
        const Duration(hours: 12),
      ]);

      now = DateTime(2026, 9, 4);
      timers.last.fire();
      expect(refreshes, 2);
      expect(delays.last, const Duration(days: 1));

      scheduler.dispose();
      expect(timers.last.isActive, isFalse);
      timers.last.fire();
      expect(refreshes, 2);
    });
  });

  group('table group chat timeline', () {
    test(
      'merges newest-first pages into a deduplicated chronological view',
      () {
        final pageZero = <TableGroupMessage>[
          _message('m-4', minute: 4, content: 'four'),
          _message('m-3', minute: 3, content: 'three'),
        ];
        final initial = mergeTableGroupMessagesChronologically(
          incoming: pageZero,
        );
        final merged = mergeTableGroupMessagesChronologically(
          existing: initial,
          incoming: <TableGroupMessage>[
            _message('m-2', minute: 2, content: 'two'),
            _message('m-3', minute: 3, content: 'three from REST'),
            _message('m-1', minute: 1, content: 'one'),
          ],
        );

        expect(merged.map((message) => message.messageId), <String>[
          'm-1',
          'm-2',
          'm-3',
          'm-4',
        ]);
        expect(merged[2].content, 'three from REST');
        expect(
          () => merged.add(_message('m-5', minute: 5)),
          throwsUnsupportedError,
        );
      },
    );

    test('reconciles response and realtime copies by client message id', () {
      final optimisticCopy = TableGroupMessage(
        messageId: 'temporary-id',
        tableGroupId: 'g-1',
        senderId: 'u-1',
        clientMessageId: 'client-1',
        content: 'hello',
        messageType: 'TEXT',
        sentAt: DateTime.utc(2026, 7, 14),
        deletedAt: null,
      );
      final serverCopy = TableGroupMessage(
        messageId: 'server-id',
        tableGroupId: 'g-1',
        senderId: 'u-1',
        clientMessageId: 'client-1',
        content: 'hello',
        messageType: 'TEXT',
        sentAt: DateTime.utc(2026, 7, 14, 0, 1),
        deletedAt: null,
      );

      final merged = mergeTableGroupMessagesChronologically(
        existing: <TableGroupMessage>[optimisticCopy],
        incoming: <TableGroupMessage>[serverCopy],
      );

      expect(merged, hasLength(1));
      expect(merged.single.messageId, 'server-id');
    });
  });
}
