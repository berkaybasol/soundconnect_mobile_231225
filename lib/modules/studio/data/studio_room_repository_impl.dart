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
      decoder: (json) =>
          _decodePage(json, (item) => _decodeRoom(item, ownerView: true)),
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
      decoder: (json) => _decodeRoom(json, ownerView: true),
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
      decoder: (json) => _decodeRoom(json, ownerView: true),
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
      decoder: (json) => _decodeRoom(json, ownerView: true),
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
      decoder: (json) => _decodeReservation(json, ownerView: true),
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
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'studio_room_invalid_response',
          message: 'Stüdyo bilgileri beklenen biçimde alınamadı.',
        ),
      );
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

  static StudioRoom _decodeRoom(Object? raw, {bool ownerView = false}) {
    final json = _map(raw);
    final photos =
        _list(json['photos'])
            .map((item) {
              final photo = _map(item);
              return StudioRoomPhoto(
                mediaAssetId: _optionalString(
                  photo['mediaAssetId'],
                  'mediaAssetId',
                ),
                url: _requiredHttpUrl(photo, 'url'),
                orderIndex: _requiredInt(photo, 'orderIndex'),
              );
            })
            .toList(growable: false)
          ..sort((left, right) => left.orderIndex.compareTo(right.orderIndex));
    final capacity = _requiredInt(json, 'capacity');
    final minimumCapacity = _nullableInt(json['minimumCapacity']) ?? capacity;
    final hourlyPriceMinor = _nullableInt(json['hourlyPriceMinor']);
    final todayAvailableHours = _requiredInt(json, 'todayAvailableHours');
    final slotIndex = _requiredInt(json, 'slotIndex');
    final todayReservationCount = ownerView
        ? _requiredInt(json, 'todayReservationCount')
        : 0;
    final todayOccupiedHours = ownerView
        ? _requiredInt(json, 'todayOccupiedHours')
        : 0;
    final version = ownerView ? _requiredInt(json, 'version') : 0;
    final currency = _optionalString(json['currency'], 'currency');
    if (capacity < 1 ||
        capacity > 100 ||
        minimumCapacity < 1 ||
        minimumCapacity > capacity ||
        (hourlyPriceMinor != null &&
            (hourlyPriceMinor < 1 || hourlyPriceMinor > 100000000)) ||
        slotIndex < 0 ||
        slotIndex > 9 ||
        todayReservationCount < 0 ||
        todayOccupiedHours < 0 ||
        todayOccupiedHours > 14 ||
        todayAvailableHours < 0 ||
        todayAvailableHours > 14 ||
        version < 0 ||
        (hourlyPriceMinor != null &&
            (currency == null || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)))) {
      throw const FormatException('Room numeric fields are invalid');
    }
    return StudioRoom(
      id: _requiredString(json, 'id'),
      studioProfileId: _requiredString(json, 'studioProfileId'),
      clientRequestId: ownerView
          ? _requiredString(json, 'clientRequestId')
          : _optionalString(json['clientRequestId'], 'clientRequestId'),
      slotIndex: slotIndex,
      name: _requiredString(json, 'name'),
      shortDescription:
          _optionalString(json['shortDescription'], 'shortDescription') ?? '',
      capacity: capacity,
      minimumCapacity: minimumCapacity,
      hourlyPriceMinor: hourlyPriceMinor,
      currency: currency,
      reservationApprovalRequired: _requiredBool(
        json,
        'reservationApprovalRequired',
      ),
      pendingReservationApprovalRequired:
          json['pendingReservationApprovalRequired'] is bool
          ? json['pendingReservationApprovalRequired'] as bool
          : null,
      reservationApprovalPolicyEffectiveAt: _nullableDateTime(
        json['reservationApprovalPolicyEffectiveAt'],
      ),
      features: List<String>.unmodifiable(
        _list(json['features']).map((value) {
          if (value is! String || value.trim().isEmpty) {
            throw const FormatException(
              'Room features must contain only non-blank strings',
            );
          }
          return value.trim();
        }),
      ),
      photos: List<StudioRoomPhoto>.unmodifiable(photos),
      todayLocalDate: _dateValue(json['todayLocalDate']),
      todayReservationCount: todayReservationCount,
      todayOccupiedHours: todayOccupiedHours,
      todayAvailableHours: todayAvailableHours,
      todayAvailabilityStatus: _roomAvailabilityStatus(
        json['todayAvailabilityStatus'],
      ),
      version: version,
    );
  }

  static StudioReservation _decodeReservation(
    Object? raw, {
    bool ownerView = false,
  }) {
    final json = _map(raw);
    final startsAt = _instant(json['startsAt']);
    final endsAt = _instant(json['endsAt']);
    if (!endsAt.isAfter(startsAt)) {
      throw const FormatException('Reservation end must follow its start');
    }
    return StudioReservation(
      id: _requiredString(json, 'id'),
      clientRequestId: _requiredString(json, 'clientRequestId'),
      roomId: _requiredString(json, 'roomId'),
      studioProfileId: _optionalString(
        json['studioProfileId'],
        'studioProfileId',
      ),
      roomName: _optionalString(json['roomName'], 'roomName'),
      requesterId: ownerView
          ? _requiredString(json, 'requesterId')
          : _optionalString(json['requesterId'], 'requesterId'),
      requesterPublicCode: ownerView
          ? _requiredString(json, 'requesterPublicCode')
          : _optionalString(json['requesterPublicCode'], 'requesterPublicCode'),
      requesterPhone: _optionalString(json['requesterPhone'], 'requesterPhone'),
      requesterUsername: _optionalString(
        json['requesterUsername'],
        'requesterUsername',
      ),
      requesterAvatarUrl: _optionalHttpUrl(
        json['requesterAvatarUrl'],
        'requesterAvatarUrl',
      ),
      startsAt: startsAt,
      endsAt: endsAt,
      zoneId: _requiredString(json, 'zoneId'),
      localDate: _requiredLocalDate(json, 'localDate'),
      localStartTime: _requiredLocalTime(json, 'localStartTime'),
      localEndTime: _requiredLocalTime(json, 'localEndTime'),
      status: StudioReservationStatus.fromApi(json['status']),
      completed: _requiredBool(json, 'completed'),
      approvalRequired: _requiredBool(json, 'approvalRequired'),
      hourlyPriceMinor: _nullableInt(json['hourlyPriceMinor']),
      totalPriceMinor: _nullableInt(json['totalPriceMinor']),
      currency: _optionalString(json['currency'], 'currency'),
      version: _requiredInt(json, 'version'),
    );
  }

  static StudioOccupancy _decodeOccupancy(Object? raw) {
    final json = _map(raw);
    final startsAt = _instant(json['startsAt']);
    final endsAt = _instant(json['endsAt']);
    if (!endsAt.isAfter(startsAt)) {
      throw const FormatException('Occupancy end must follow its start');
    }
    return StudioOccupancy(
      id: _requiredString(json, 'id'),
      roomId: _requiredString(json, 'roomId'),
      reservationId: _optionalString(json['reservationId'], 'reservationId'),
      clientRequestId: _optionalString(
        json['clientRequestId'],
        'clientRequestId',
      ),
      type: StudioOccupancyType.fromApi(json['type']),
      startsAt: startsAt,
      endsAt: endsAt,
      localDate: _requiredLocalDate(json, 'localDate'),
      localStartTime: _requiredLocalTime(json, 'localStartTime'),
      localEndTime: _requiredLocalTime(json, 'localEndTime'),
      active: _requiredBool(json, 'active'),
      version: _requiredInt(json, 'version'),
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
    final openingHour = _requiredInt(json, 'openingHour');
    final closingHour = _requiredInt(json, 'closingHour');
    final from = _dateValue(json['from']);
    final to = _dateValue(json['to']);
    if (openingHour < 0 ||
        openingHour > 23 ||
        closingHour < 1 ||
        closingHour > 24 ||
        openingHour >= closingHour ||
        to.isBefore(from)) {
      throw const FormatException('Availability boundaries are invalid');
    }
    return StudioRoomAvailability(
      studioProfileId: _requiredString(json, 'studioProfileId'),
      roomId: _requiredString(json, 'roomId'),
      zoneId: _requiredString(json, 'zoneId'),
      openingHour: openingHour,
      closingHour: closingHour,
      todayLocalDate: todayLocalDate,
      currentLocalTime: currentLocalTime,
      latestBookableLocalDateTime: latestBookableLocalDateTime,
      from: from,
      to: to,
      unavailable: List<StudioUnavailableInterval>.unmodifiable(
        _list(json['unavailable']).map((item) {
          final interval = _map(item);
          final startsAt = _instant(interval['startsAt']);
          final endsAt = _instant(interval['endsAt']);
          if (!endsAt.isAfter(startsAt)) {
            throw const FormatException(
              'Unavailable interval end must follow its start',
            );
          }
          return StudioUnavailableInterval(
            startsAt: startsAt,
            endsAt: endsAt,
            localDate: _requiredLocalDate(interval, 'localDate'),
            localStartTime: _requiredLocalTime(interval, 'localStartTime'),
            localEndTime: _requiredLocalTime(interval, 'localEndTime'),
          );
        }),
      ),
    );
  }

  static StudioRoomSchedule _decodeSchedule(Object? raw) {
    final json = _map(raw);
    final room = _decodeRoom(json['room'], ownerView: true);
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
    final from = _dateValue(json['from']);
    final to = _dateValue(json['to']);
    if (to.isBefore(from)) {
      throw const FormatException('Schedule date range is invalid');
    }
    return StudioRoomSchedule(
      room: room,
      zoneId: _requiredString(json, 'zoneId'),
      todayLocalDate: todayLocalDate,
      currentLocalTime: currentLocalTime,
      latestBookableLocalDateTime: latestBookableLocalDateTime,
      from: from,
      to: to,
      reservations: _decodePage(
        json['reservations'],
        (item) => _decodeReservation(item, ownerView: true),
      ),
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
    final items = List<T>.unmodifiable(_list(json['content']).map(itemDecoder));
    final pageIndex = _requiredInt(
      json,
      json.containsKey('page') ? 'page' : 'number',
    );
    final pageSize = _requiredInt(json, 'size');
    final totalItems = _requiredInt(json, 'totalElements');
    final totalPages = _requiredInt(json, 'totalPages');
    final isFirst = _requiredBool(json, 'first');
    final isLast = _requiredBool(json, 'last');
    final expectedTotalPages = pageSize < 1 || totalItems == 0
        ? 0
        : (totalItems + pageSize - 1) ~/ pageSize;
    if (pageIndex < 0 ||
        pageSize < 1 ||
        totalItems < 0 ||
        totalPages < 0 ||
        (totalPages == 0 && totalItems != 0) ||
        totalPages != expectedTotalPages ||
        (totalPages > 0 && pageIndex >= totalPages && items.isNotEmpty) ||
        items.length > pageSize ||
        items.length > totalItems ||
        isFirst != (pageIndex == 0) ||
        isLast != (totalPages == 0 || pageIndex >= totalPages - 1)) {
      throw const FormatException('Page metadata is inconsistent');
    }
    return StudioPage<T>(
      items: items,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItems: totalItems,
      totalPages: totalPages,
      isFirst: isFirst,
      isLast: isLast,
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      if (value.keys.any((key) => key is! String)) {
        throw const FormatException('JSON object keys must be strings');
      }
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('Expected a JSON object');
  }

  static List<Object?> _list(Object? value) {
    if (value is List) return List<Object?>.from(value);
    throw const FormatException('Expected a JSON array');
  }

  static int? _nullableInt(Object? value) {
    if (value == null) return null;
    return _parseInt(value, 'value');
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    return _parseInt(json[key], key);
  }

  static int _parseInt(Object? value, String context) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.toInt()) {
      return value.toInt();
    }
    throw FormatException('Missing or invalid $context');
  }

  static bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw FormatException('Missing or invalid $key');
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! String) throw FormatException('Missing or invalid $key');
    final value = raw.trim();
    if (value.isEmpty) throw FormatException('Missing or invalid $key');
    return value;
  }

  static String? _optionalString(Object? raw, String context) {
    if (raw == null) return null;
    if (raw is! String) throw FormatException('Missing or invalid $context');
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  static DateTime _instant(Object? value) {
    if (value is! String) {
      throw const FormatException('Expected an instant string');
    }
    final text = value.trim();
    if (!RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(text)) {
      throw const FormatException('Expected an instant with a UTC offset');
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null) throw const FormatException('Invalid instant');
    return parsed.toUtc();
  }

  static DateTime? _nullableDateTime(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Expected a date-time string');
    }
    final text = value.trim();
    return text.isEmpty ? null : _instant(text);
  }

  static DateTime _dateValue(Object? value) {
    if (value is! String) {
      throw const FormatException('Expected an ISO local date string');
    }
    final text = value.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw const FormatException('Expected an ISO local date');
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null) throw const FormatException('Invalid local date');
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    if (_date(date) != text) throw const FormatException('Invalid local date');
    return date;
  }

  static DateTime _localDateTimeValue(Object? value) {
    if (value is! String) {
      throw const FormatException('Expected a local date-time string');
    }
    final text = value.trim();
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
    if (value is! String) {
      throw const FormatException('Missing or invalid todayAvailabilityStatus');
    }
    return switch (value.trim().toUpperCase()) {
      'AVAILABLE' => StudioRoomAvailabilityStatus.available,
      'PARTIALLY_AVAILABLE' => StudioRoomAvailabilityStatus.partiallyAvailable,
      'FULLY_BOOKED' => StudioRoomAvailabilityStatus.fullyBooked,
      _ => throw const FormatException(
        'Missing or invalid todayAvailabilityStatus',
      ),
    };
  }

  static String _requiredLocalDate(Map<String, dynamic> json, String key) {
    final value = _requiredString(json, key);
    _dateValue(value);
    return value;
  }

  static String _requiredLocalTime(Map<String, dynamic> json, String key) {
    final value = _requiredString(json, key);
    if (!RegExp(
      r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,9})?)?$',
    ).hasMatch(value)) {
      throw FormatException('Missing or invalid $key');
    }
    return value;
  }

  static String _requiredHttpUrl(Map<String, dynamic> json, String key) {
    final value = _requiredString(json, key);
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        RegExp(r'\s').hasMatch(value)) {
      throw FormatException('Missing or invalid $key');
    }
    return value;
  }

  static String? _optionalHttpUrl(Object? raw, String context) {
    final value = _optionalString(raw, context);
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        RegExp(r'\s').hasMatch(value)) {
      throw FormatException('Missing or invalid $context');
    }
    return value;
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
