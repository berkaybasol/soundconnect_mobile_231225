import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/studio_reservation.dart';
import '../domain/entities/studio_page.dart';
import '../domain/entities/studio_room.dart';
import '../domain/studio_booking_policy.dart';
import '../domain/studio_room_repository.dart';

class StudioRoomRepositoryImpl implements StudioRoomRepository {
  StudioRoomRepositoryImpl(this._apiClient);

  static const _ownerRooms = '/api/v1/user/studio-profiles/me/rooms';
  static const _customerReservations = '/api/v1/user/studio-reservations';

  final ApiClient _apiClient;

  @override
  Future<Result<StudioPage<StudioRoom>>> listOwnerRooms({
    int page = 0,
    int size = 10,
  }) => _guard(
    () => _apiClient.get<StudioPage<StudioRoom>>(
      _ownerRooms,
      query: {'page': page, 'size': size},
      decoder: (json) => _decodePage(json, _decodeRoom),
    ),
    'Odalar getirilemedi.',
  );

  @override
  Future<Result<StudioPage<StudioRoom>>> listPublicRooms(
    String studioProfileId, {
    int page = 0,
    int size = 10,
  }) => _guard(
    () => _apiClient.get<StudioPage<StudioRoom>>(
      '/api/v1/public/studio-profiles/$studioProfileId/rooms',
      query: {'page': page, 'size': size},
      decoder: (json) => _decodePage(json, _decodeRoom),
    ),
    'Stüdyo odaları getirilemedi.',
  );

  @override
  Future<Result<StudioRoom>> getOwnerRoom(String roomId) => _guard(
    () => _apiClient.get<StudioRoom>(
      '$_ownerRooms/$roomId',
      decoder: _decodeRoom,
    ),
    'Oda getirilemedi.',
  );

  @override
  Future<Result<StudioRoom>> getPublicRoom(
    String studioProfileId,
    String roomId,
  ) => _guard(
    () => _apiClient.get<StudioRoom>(
      '/api/v1/public/studio-profiles/$studioProfileId/rooms/$roomId',
      decoder: _decodeRoom,
    ),
    'Oda getirilemedi.',
  );

  @override
  Future<Result<StudioRoom>> createRoom(
    StudioRoomDraft draft, {
    required String clientRequestId,
  }) => _guard(
    () => _apiClient.post<StudioRoom>(
      _ownerRooms,
      body: _roomBody(draft)..['clientRequestId'] = clientRequestId,
      decoder: _decodeRoom,
    ),
    'Oda oluşturulamadı.',
  );

  @override
  Future<Result<StudioRoom>> updateRoom(
    String roomId,
    StudioRoomDraft draft, {
    required int expectedVersion,
  }) => _guard(
    () => _apiClient.put<StudioRoom>(
      '$_ownerRooms/$roomId',
      body: _roomBody(draft)..['expectedVersion'] = expectedVersion,
      decoder: _decodeRoom,
    ),
    'Oda güncellenemedi.',
  );

  @override
  Future<Result<void>> archiveRoom(
    String roomId, {
    required int expectedVersion,
  }) async {
    try {
      await _apiClient.delete<Object?>(
        '$_ownerRooms/$roomId',
        body: {'expectedVersion': expectedVersion},
      );
      return const Result<void>.success(null);
    } on ApiException catch (error) {
      return Result<void>.failure(error.error);
    } catch (_) {
      return const Result<void>.failure(
        AppError(code: 'studio_room_unknown', message: 'Oda silinemedi.'),
      );
    }
  }

  @override
  Future<Result<StudioRoomAvailability>> getPublicAvailability({
    required String studioProfileId,
    required String roomId,
    required DateTime from,
    required DateTime to,
  }) => _guard(
    () => _apiClient.get<StudioRoomAvailability>(
      '/api/v1/public/studio-profiles/$studioProfileId/rooms/$roomId/availability',
      query: {'from': _date(from), 'to': _date(to)},
      decoder: _decodeAvailability,
    ),
    'Oda müsaitliği getirilemedi.',
  );

  @override
  Future<Result<StudioRoomSchedule>> getOwnerSchedule({
    required String roomId,
    required DateTime from,
    required DateTime to,
    int page = 0,
    int size = 100,
  }) => _guard(
    () => _apiClient.get<StudioRoomSchedule>(
      '$_ownerRooms/$roomId/schedule',
      query: {'from': _date(from), 'to': _date(to), 'page': page, 'size': size},
      decoder: _decodeSchedule,
    ),
    'Rezervasyon takvimi getirilemedi.',
  );

  @override
  Future<Result<StudioReservation>> createReservation({
    required String roomId,
    required DateTime date,
    required int startHour,
    required int durationHours,
    required String contactPhone,
    required String clientRequestId,
  }) => _guard(
    () => _apiClient.post<StudioReservation>(
      _customerReservations,
      body: {
        'roomId': roomId,
        'date': _date(date),
        'startTime': _hour(startHour),
        'durationHours': durationHours,
        'contactPhone': contactPhone,
        'clientRequestId': clientRequestId,
      },
      decoder: _decodeReservation,
    ),
    'Rezervasyon oluşturulamadı.',
  );

  @override
  Future<Result<StudioPage<StudioReservation>>>
  listCustomerReservationsForRoomDate({
    required String roomId,
    required DateTime date,
    int page = 0,
    int size = 100,
  }) => _guard(
    () => _apiClient.get<StudioPage<StudioReservation>>(
      '$_customerReservations/rooms/$roomId',
      query: {'date': _date(date), 'page': page, 'size': size},
      decoder: (json) => _decodePage(json, _decodeReservation),
    ),
    'Rezervasyonların getirilemedi.',
  );

  @override
  Future<Result<StudioReservation>> approveReservation({
    required String roomId,
    required String reservationId,
    required int expectedVersion,
  }) => _reservationOwnerAction(
    roomId: roomId,
    reservationId: reservationId,
    action: 'approve',
    expectedVersion: expectedVersion,
  );

  @override
  Future<Result<StudioReservation>> rejectReservation({
    required String roomId,
    required String reservationId,
    required int expectedVersion,
  }) => _reservationOwnerAction(
    roomId: roomId,
    reservationId: reservationId,
    action: 'reject',
    expectedVersion: expectedVersion,
  );

  @override
  Future<Result<StudioReservation>> cancelOwnerReservation({
    required String roomId,
    required String reservationId,
    required int expectedVersion,
  }) => _reservationOwnerAction(
    roomId: roomId,
    reservationId: reservationId,
    action: 'cancel',
    expectedVersion: expectedVersion,
  );

  @override
  Future<Result<StudioReservation>> cancelCustomerReservation({
    required String reservationId,
    required int expectedVersion,
  }) => _guard(
    () => _apiClient.post<StudioReservation>(
      '$_customerReservations/$reservationId/cancel',
      body: {'expectedVersion': expectedVersion},
      decoder: _decodeReservation,
    ),
    'Rezervasyon iptal edilemedi.',
  );

  @override
  Future<Result<StudioOccupancy>> createManualBlock({
    required String roomId,
    required DateTime date,
    required int startHour,
    required int durationHours,
    required String clientRequestId,
  }) => _guard(
    () => _apiClient.post<StudioOccupancy>(
      '$_ownerRooms/$roomId/blocks',
      body: {
        'date': _date(date),
        'startTime': _hour(startHour),
        'durationHours': durationHours,
        'clientRequestId': clientRequestId,
      },
      decoder: _decodeOccupancy,
    ),
    'Saat aralığı dolu olarak işaretlenemedi.',
  );

  @override
  Future<Result<StudioOccupancy>> releaseManualBlock({
    required String roomId,
    required String blockId,
    required int expectedVersion,
    String? reason,
  }) => _guard(
    () => _apiClient.delete<StudioOccupancy>(
      '$_ownerRooms/$roomId/blocks/$blockId',
      body: {
        'expectedVersion': expectedVersion,
        if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
      },
      decoder: _decodeOccupancy,
    ),
    'Manuel doluluk kaldırılamadı.',
  );

  Future<Result<StudioReservation>> _reservationOwnerAction({
    required String roomId,
    required String reservationId,
    required String action,
    required int expectedVersion,
  }) => _guard(
    () => _apiClient.post<StudioReservation>(
      '$_ownerRooms/$roomId/reservations/$reservationId/$action',
      body: {'expectedVersion': expectedVersion},
      decoder: _decodeReservation,
    ),
    'Rezervasyon işlemi tamamlanamadı.',
  );

  Future<Result<T>> _guard<T>(
    Future<T> Function() request,
    String fallbackMessage,
  ) async {
    try {
      return Result.success(await request());
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return Result.failure(
        AppError(code: 'studio_room_unknown', message: fallbackMessage),
      );
    }
  }

  static Map<String, Object?> _roomBody(StudioRoomDraft draft) => {
    'name': draft.name.trim(),
    'shortDescription': _nullable(draft.shortDescription),
    'capacity': draft.capacity,
    if (draft.minimumCapacity != null) 'minimumCapacity': draft.minimumCapacity,
    'hourlyPriceMinor': draft.hourlyPriceMinor,
    'currency': draft.hourlyPriceMinor == null
        ? null
        : (draft.currency?.trim().toUpperCase() ?? 'TRY'),
    'reservationApprovalRequired': draft.reservationApprovalRequired,
    'features': draft.features,
    'photoMediaIds': draft.photoMediaIds,
  };

  static StudioRoom _decodeRoom(Object? raw) {
    final json = _map(raw);
    final photos =
        _list(json['photos'])
            .map((item) {
              final photo = _map(item);
              return StudioRoomPhoto(
                mediaAssetId: _nullable(photo['mediaAssetId']?.toString()),
                url: photo['url']?.toString() ?? '',
                orderIndex: _int(photo['orderIndex']),
              );
            })
            .where((photo) => photo.url.trim().isNotEmpty)
            .toList(growable: false)
          ..sort((left, right) => left.orderIndex.compareTo(right.orderIndex));
    return StudioRoom(
      id: json['id']?.toString() ?? '',
      studioProfileId: json['studioProfileId']?.toString() ?? '',
      clientRequestId: _nullable(json['clientRequestId']?.toString()),
      slotIndex: _int(json['slotIndex']),
      name: json['name']?.toString() ?? '',
      shortDescription: json['shortDescription']?.toString() ?? '',
      capacity: _int(json['capacity']),
      minimumCapacity: _nullableInt(json['minimumCapacity']),
      hourlyPriceMinor: _nullableInt(json['hourlyPriceMinor']),
      currency: _nullable(json['currency']?.toString()),
      reservationApprovalRequired: json['reservationApprovalRequired'] == true,
      pendingReservationApprovalRequired:
          json['pendingReservationApprovalRequired'] is bool
          ? json['pendingReservationApprovalRequired'] as bool
          : null,
      reservationApprovalPolicyEffectiveAt: _nullableDateTime(
        json['reservationApprovalPolicyEffectiveAt'],
      ),
      features: List<String>.unmodifiable(
        _list(json['features'])
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty),
      ),
      photos: List<StudioRoomPhoto>.unmodifiable(photos),
      todayLocalDate: _dateValue(json['todayLocalDate']),
      todayReservationCount: _int(json['todayReservationCount']),
      todayOccupiedHours: _int(json['todayOccupiedHours']),
      todayAvailableHours: _requiredInt(json, 'todayAvailableHours'),
      todayAvailabilityStatus: _roomAvailabilityStatus(
        json['todayAvailabilityStatus'],
      ),
      version: _int(json['version']),
    );
  }

  static StudioReservation _decodeReservation(Object? raw) {
    final json = _map(raw);
    return StudioReservation(
      id: json['id']?.toString() ?? '',
      clientRequestId: json['clientRequestId']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      studioProfileId: _nullable(json['studioProfileId']?.toString()),
      roomName: _nullable(json['roomName']?.toString()),
      requesterId: _nullable(json['requesterId']?.toString()),
      requesterPublicCode: _nullable(json['requesterPublicCode']?.toString()),
      requesterPhone: _nullable(json['requesterPhone']?.toString()),
      requesterUsername: _nullable(json['requesterUsername']?.toString()),
      requesterAvatarUrl: _nullable(json['requesterAvatarUrl']?.toString()),
      startsAt: _instant(json['startsAt']),
      endsAt: _instant(json['endsAt']),
      zoneId: json['zoneId']?.toString() ?? 'Europe/Istanbul',
      localDate: _nullable(json['localDate']?.toString()),
      localStartTime: _nullable(json['localStartTime']?.toString()),
      localEndTime: _nullable(json['localEndTime']?.toString()),
      status: StudioReservationStatus.fromApi(json['status']),
      completed: json['completed'] == true,
      approvalRequired: json['approvalRequired'] == true,
      hourlyPriceMinor: _nullableInt(json['hourlyPriceMinor']),
      totalPriceMinor: _nullableInt(json['totalPriceMinor']),
      currency: _nullable(json['currency']?.toString()),
      version: _int(json['version']),
    );
  }

  static StudioOccupancy _decodeOccupancy(Object? raw) {
    final json = _map(raw);
    return StudioOccupancy(
      id: json['id']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      reservationId: _nullable(json['reservationId']?.toString()),
      clientRequestId: _nullable(json['clientRequestId']?.toString()),
      type: StudioOccupancyType.fromApi(json['type']),
      startsAt: _instant(json['startsAt']),
      endsAt: _instant(json['endsAt']),
      localDate: _nullable(json['localDate']?.toString()),
      localStartTime: _nullable(json['localStartTime']?.toString()),
      localEndTime: _nullable(json['localEndTime']?.toString()),
      active: json['active'] == true,
      version: _int(json['version']),
    );
  }

  static StudioRoomAvailability _decodeAvailability(Object? raw) {
    final json = _map(raw);
    final todayLocalDate = _dateValue(json['todayLocalDate']);
    final currentLocalTime = _requiredString(json, 'currentLocalTime');
    final latestBookableLocalDateTime = _localDateTimeValue(
      json['latestBookableLocalDateTime'],
    );
    StudioBookingCalendarPolicy(
      todayLocalDate: todayLocalDate,
      currentLocalTime: currentLocalTime,
      latestBookableLocalDateTime: latestBookableLocalDateTime,
    );
    return StudioRoomAvailability(
      studioProfileId: json['studioProfileId']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      zoneId: _requiredString(json, 'zoneId'),
      openingHour: _int(json['openingHour'], fallback: 9),
      closingHour: _int(json['closingHour'], fallback: 23),
      todayLocalDate: todayLocalDate,
      currentLocalTime: currentLocalTime,
      latestBookableLocalDateTime: latestBookableLocalDateTime,
      from: _dateValue(json['from']),
      to: _dateValue(json['to']),
      unavailable: List<StudioUnavailableInterval>.unmodifiable(
        _list(json['unavailable']).map((item) {
          final interval = _map(item);
          return StudioUnavailableInterval(
            startsAt: _instant(interval['startsAt']),
            endsAt: _instant(interval['endsAt']),
            localDate: _nullable(interval['localDate']?.toString()),
            localStartTime: _nullable(interval['localStartTime']?.toString()),
            localEndTime: _nullable(interval['localEndTime']?.toString()),
          );
        }),
      ),
    );
  }

  static StudioRoomSchedule _decodeSchedule(Object? raw) {
    final json = _map(raw);
    final room = _decodeRoom(json['room']);
    final todayLocalDate = _dateValue(json['todayLocalDate']);
    final currentLocalTime = _requiredString(json, 'currentLocalTime');
    final latestBookableLocalDateTime = _localDateTimeValue(
      json['latestBookableLocalDateTime'],
    );
    StudioBookingCalendarPolicy(
      todayLocalDate: todayLocalDate,
      currentLocalTime: currentLocalTime,
      latestBookableLocalDateTime: latestBookableLocalDateTime,
    );
    if (_date(room.todayLocalDate) != _date(todayLocalDate)) {
      throw const FormatException('Room and schedule studio dates disagree');
    }
    return StudioRoomSchedule(
      room: room,
      zoneId: _requiredString(json, 'zoneId'),
      todayLocalDate: todayLocalDate,
      currentLocalTime: currentLocalTime,
      latestBookableLocalDateTime: latestBookableLocalDateTime,
      from: _dateValue(json['from']),
      to: _dateValue(json['to']),
      reservations: _decodePage(json['reservations'], _decodeReservation),
      occupancies: List<StudioOccupancy>.unmodifiable(
        _list(json['occupancies']).map(_decodeOccupancy),
      ),
    );
  }

  static StudioPage<T> _decodePage<T>(
    Object? raw,
    T Function(Object? raw) itemDecoder,
  ) {
    final json = _map(raw);
    return StudioPage<T>(
      items: List<T>.unmodifiable(_list(json['content']).map(itemDecoder)),
      pageIndex: _int(json['page'] ?? json['number']),
      pageSize: _int(json['size']),
      totalItems: _int(json['totalElements']),
      totalPages: _int(json['totalPages']),
      isFirst: json['first'] == true,
      isLast: json['last'] == true,
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw const FormatException('Expected a JSON object');
  }

  static List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];

  static int _int(Object? value, {int fallback = 0}) => switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => int.tryParse(value?.toString() ?? '') ?? fallback,
  };

  static int? _nullableInt(Object? value) => value == null ? null : _int(value);

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) throw FormatException('Missing or invalid $key');
    return parsed;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) throw FormatException('Missing or invalid $key');
    return value;
  }

  static DateTime _instant(Object? value) =>
      DateTime.parse(value?.toString() ?? '').toUtc();

  static DateTime? _nullableDateTime(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.parse(text);
  }

  static DateTime _dateValue(Object? value) {
    final parsed = DateTime.parse(value?.toString() ?? '');
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime _localDateTimeValue(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(text)) {
      throw const FormatException('Expected an offset-free local date-time');
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null) throw const FormatException('Invalid local date-time');
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static StudioRoomAvailabilityStatus _roomAvailabilityStatus(Object? value) {
    return switch (value?.toString().trim().toUpperCase()) {
      'AVAILABLE' => StudioRoomAvailabilityStatus.available,
      'PARTIALLY_AVAILABLE' => StudioRoomAvailabilityStatus.partiallyAvailable,
      'FULLY_BOOKED' => StudioRoomAvailabilityStatus.fullyBooked,
      _ => throw const FormatException(
        'Missing or invalid todayAvailabilityStatus',
      ),
    };
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _hour(int value) => '${value.toString().padLeft(2, '0')}:00';

  static String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

bool isStudioStaleError(AppError? error) => error?.code == '9804';

bool isStudioReservationConflict(AppError? error) =>
    error?.code == '9811' || error?.code == '409';
