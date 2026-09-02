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

void main() {
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
            },
          ],
        ),
      );

      expect(model.expiresAt, DateTime.utc(2026, 7, 15, 1, 2, 3));
      expect(model.meetingAt, DateTime.utc(2026, 7, 14, 1, 2, 3));
      expect(
        model.participants.single.joinedAt,
        DateTime.utc(2026, 7, 14, 1, 2, 3),
      );

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
          District(
            id: 'district-2',
            name: 'Created District',
            cityId: 'city-2',
          ),
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

    test(
      'failed loadMore retries the same page without losing items',
      () async {
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
        expect(
          tableRepository.listRequests.map((request) => request.page),
          <int>[0, 1, 1],
        );
        tableRepository.completeList(
          2,
          Result.success(
            Page<TableGroup>(
              items: <TableGroup>[_group('g-2')],
              hasNext: false,
            ),
          ),
        );
        await retry;

        expect(cubit.state.items.map((item) => item.id), <String>[
          'g-1',
          'g-2',
        ]);
        expect(cubit.state.page, 1);
        expect(cubit.state.error, isNull);
      },
    );

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
  });

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
