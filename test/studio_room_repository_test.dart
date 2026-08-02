import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/data/studio_room_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_room.dart';

import 'support/recording_api_client.dart';

void main() {
  group('StudioRoomRepositoryImpl', () {
    test('decodes owner page and sends bounded pagination query', () async {
      final api = RecordingApiClient(
        (request) => {
          'content': [_roomJson(owner: true)],
          'page': 0,
          'size': 10,
          'totalElements': 1,
          'totalPages': 1,
          'first': true,
          'last': true,
        },
      );
      final repository = StudioRoomRepositoryImpl(api);

      final result = await repository.listOwnerRooms(page: 0, size: 10);

      expect(result.isSuccess, isTrue);
      expect(result.data?.items.single.id, 'room-1');
      expect(result.data?.items.single.photos.single.mediaAssetId, 'media-1');
      expect(result.data?.items.single.todayReservationCount, 2);
      expect(result.data?.pageIndex, 0);
      expect(api.lastRequest.method, RecordedHttpMethod.get);
      expect(api.lastRequest.path, '/api/v1/user/studio-profiles/me/rooms');
      expect(api.lastRequest.query, {'page': 0, 'size': 10});
    });

    test(
      'create retries preserve caller idempotency key and exact payload',
      () async {
        final api = RecordingApiClient((_) => _roomJson(owner: true));
        final repository = StudioRoomRepositoryImpl(api);
        const draft = StudioRoomDraft(
          name: 'Prova Odası',
          shortDescription: 'Prova',
          capacity: 6,
          hourlyPriceMinor: 75000,
          currency: 'try',
          reservationApprovalRequired: true,
          features: ['Davul seti'],
          photoMediaIds: ['media-1'],
        );

        await repository.createRoom(draft, clientRequestId: 'request-1');
        await repository.createRoom(draft, clientRequestId: 'request-1');

        expect(api.requests, hasLength(2));
        expect(api.requests[0].body, api.requests[1].body);
        expect(api.requests[0].body, {
          'name': 'Prova Odası',
          'shortDescription': 'Prova',
          'capacity': 6,
          'hourlyPriceMinor': 75000,
          'currency': 'TRY',
          'reservationApprovalRequired': true,
          'features': ['Davul seti'],
          'photoMediaIds': ['media-1'],
          'clientRequestId': 'request-1',
        });
      },
    );

    test('update and archive carry optimistic version', () async {
      final api = RecordingApiClient((request) {
        if (request.method == RecordedHttpMethod.delete) return null;
        return _roomJson(owner: true);
      });
      final repository = StudioRoomRepositoryImpl(api);
      const draft = StudioRoomDraft(
        name: 'Kayıt Odası',
        shortDescription: null,
        capacity: 4,
        hourlyPriceMinor: null,
        currency: null,
        reservationApprovalRequired: false,
        features: [],
        photoMediaIds: [],
      );

      await repository.updateRoom('room-1', draft, expectedVersion: 7);
      await repository.archiveRoom('room-1', expectedVersion: 8);

      expect(
        api.requests.first.path,
        '/api/v1/user/studio-profiles/me/rooms/room-1',
      );
      expect((api.requests.first.body as Map)['expectedVersion'], 7);
      expect(api.requests.last.method, RecordedHttpMethod.delete);
      expect(api.requests.last.body, {'expectedVersion': 8});
    });

    test(
      'reservation payload uses local date/time and stable request id',
      () async {
        final api = RecordingApiClient((_) => _reservationJson());
        final repository = StudioRoomRepositoryImpl(api);

        final result = await repository.createReservation(
          roomId: 'room-1',
          date: DateTime(2026, 7, 24),
          startHour: 14,
          durationHours: 3,
          contactPhone: '0 555 111 22 33',
          clientRequestId: 'reservation-request-1',
        );

        expect(result.data?.localDate, '2026-07-24');
        expect(result.data?.localStartTime, '14:00:00');
        expect(api.lastRequest.path, '/api/v1/user/studio-reservations');
        expect(api.lastRequest.body, {
          'roomId': 'room-1',
          'date': '2026-07-24',
          'startTime': '14:00',
          'durationHours': 3,
          'contactPhone': '0 555 111 22 33',
          'clientRequestId': 'reservation-request-1',
        });
      },
    );

    test(
      'owner schedule decodes local wall time and manual occupancy',
      () async {
        final api = RecordingApiClient(
          (_) => {
            'room': _roomJson(owner: true),
            'zoneId': 'Europe/Istanbul',
            'todayLocalDate': '2026-07-24',
            'currentLocalTime': '10:30:00',
            'latestBookableLocalDateTime': '2027-07-24T10:30:00',
            'from': '2026-07-24',
            'to': '2026-07-28',
            'reservations': {
              'content': [_reservationJson()],
              'page': 0,
              'size': 100,
              'totalElements': 1,
              'totalPages': 1,
              'first': true,
              'last': true,
            },
            'occupancies': [
              {
                'id': 'block-1',
                'roomId': 'room-1',
                'clientRequestId': 'block-request-1',
                'type': 'MANUAL_BLOCK',
                'startsAt': '2026-07-24T15:00:00Z',
                'endsAt': '2026-07-24T17:00:00Z',
                'localDate': '2026-07-24',
                'localStartTime': '18:00:00',
                'localEndTime': '20:00:00',
                'active': true,
                'version': 3,
              },
            ],
          },
        );
        final repository = StudioRoomRepositoryImpl(api);

        final result = await repository.getOwnerSchedule(
          roomId: 'room-1',
          from: DateTime(2026, 7, 24),
          to: DateTime(2026, 7, 28),
        );

        expect(
          result.data?.reservations.items.single.localStartTime,
          '14:00:00',
        );
        expect(result.data?.occupancies.single.localStartTime, '18:00:00');
        expect(result.data?.occupancies.single.type.name, 'manualBlock');
        expect(result.data?.todayLocalDate, DateTime(2026, 7, 24));
        expect(result.data?.currentLocalTime, '10:30:00');
        expect(
          result.data?.latestBookableLocalDateTime,
          DateTime(2027, 7, 24, 10, 30),
        );
        expect(api.lastRequest.query?['size'], 100);
      },
    );

    test(
      'loads the signed-in user reservations for one room and date',
      () async {
        final api = RecordingApiClient(
          (_) => {
            'content': [_reservationJson()],
            'page': 0,
            'size': 100,
            'totalElements': 1,
            'totalPages': 1,
            'first': true,
            'last': true,
          },
        );
        final repository = StudioRoomRepositoryImpl(api);

        final result = await repository.listCustomerReservationsForRoomDate(
          roomId: 'room-1',
          date: DateTime(2026, 7, 24),
        );

        expect(result.data?.items.single.id, 'reservation-1');
        expect(
          api.lastRequest.path,
          '/api/v1/user/studio-reservations/rooms/room-1',
        );
        expect(api.lastRequest.query, {
          'date': '2026-07-24',
          'page': 0,
          'size': 100,
        });
      },
    );

    test('public availability remains free of reservation identity', () async {
      final api = RecordingApiClient(
        (_) => {
          'studioProfileId': 'studio-1',
          'roomId': 'room-1',
          'zoneId': 'Europe/Istanbul',
          'openingHour': 9,
          'closingHour': 23,
          'todayLocalDate': '2026-07-24',
          'currentLocalTime': '10:30:00',
          'latestBookableLocalDateTime': '2027-07-24T10:30:00',
          'from': '2026-07-24',
          'to': '2026-07-24',
          'unavailable': [
            {
              'startsAt': '2026-07-24T07:00:00Z',
              'endsAt': '2026-07-24T09:00:00Z',
              'localDate': '2026-07-24',
              'localStartTime': '10:00:00',
              'localEndTime': '12:00:00',
            },
          ],
        },
      );
      final repository = StudioRoomRepositoryImpl(api);

      final result = await repository.getPublicAvailability(
        studioProfileId: 'studio-1',
        roomId: 'room-1',
        from: DateTime(2026, 7, 24),
        to: DateTime(2026, 7, 24),
      );

      expect(result.data?.unavailable.single.localStartTime, '10:00:00');
      expect(result.data?.todayLocalDate, DateTime(2026, 7, 24));
      expect(result.data?.currentLocalTime, '10:30:00');
      expect(
        result.data?.latestBookableLocalDateTime,
        DateTime(2027, 7, 24, 10, 30),
      );
      expect(
        api.lastRequest.path,
        '/api/v1/public/studio-profiles/studio-1/rooms/room-1/availability',
      );
    });
  });
}

Map<String, Object?> _roomJson({required bool owner}) => {
  'id': 'room-1',
  'studioProfileId': 'studio-1',
  if (owner) 'clientRequestId': 'request-1',
  'slotIndex': 0,
  'name': 'Prova Odası',
  'shortDescription': 'Prova',
  'capacity': 6,
  'hourlyPriceMinor': 75000,
  'currency': 'TRY',
  'reservationApprovalRequired': true,
  'features': ['Davul seti'],
  'photos': [
    {
      if (owner) 'mediaAssetId': 'media-1',
      'url': 'https://cdn.example.test/room.jpg',
      'orderIndex': 0,
    },
  ],
  'todayLocalDate': '2026-07-24',
  'todayReservationCount': 2,
  'todayOccupiedHours': 3,
  'todayAvailableHours': 11,
  'todayAvailabilityStatus': 'PARTIALLY_AVAILABLE',
  'version': 7,
};

Map<String, Object?> _reservationJson() => {
  'id': 'reservation-1',
  'clientRequestId': 'reservation-request-1',
  'roomId': 'room-1',
  'requesterId': 'user-2',
  'requesterPublicCode': 'SC-ABC123',
  'requesterUsername': 'Deniz',
  'requesterAvatarUrl': 'https://cdn.example.test/avatar.jpg',
  'startsAt': '2026-07-24T11:00:00Z',
  'endsAt': '2026-07-24T14:00:00Z',
  'zoneId': 'Europe/Istanbul',
  'localDate': '2026-07-24',
  'localStartTime': '14:00:00',
  'localEndTime': '17:00:00',
  'status': 'PENDING_APPROVAL',
  'completed': false,
  'approvalRequired': true,
  'hourlyPriceMinor': 75000,
  'totalPriceMinor': 225000,
  'currency': 'TRY',
  'version': 1,
};
