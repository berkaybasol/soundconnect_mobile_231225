import 'dart:async';

import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/event_performer_identity.dart';
import '../domain/entities/musician_calendar.dart';
import '../domain/entities/venue_event_detail.dart';
import '../domain/musician_calendar_repository.dart';

class MusicianCalendarRepositoryImpl
    implements MusicianCalendarRepository, MusicianCalendarSettingsReader {
  MusicianCalendarRepositoryImpl(
    this._api, {
    required String? Function() sessionKeyProvider,
    String? targetBandId,
    void Function()? onSettingsConfirmed,
  }) : _sessionKeyProvider = sessionKeyProvider,
       _targetBandId = targetBandId?.trim(),
       _onSettingsConfirmed = onSettingsConfirmed {
    if (_targetBandId != null && _targetBandId.isEmpty) {
      throw ArgumentError.value(
        targetBandId,
        'targetBandId',
        'Must not be blank.',
      );
    }
  }

  final String? _targetBandId;
  final void Function()? _onSettingsConfirmed;
  String get _settingsPath => _targetBandId == null
      ? '/api/v1/user/musician-profiles/me/calendar-settings'
      : '/api/v1/user/bands/${Uri.encodeComponent(_targetBandId)}/calendar-settings';
  final ApiClient _api;
  final String? Function() _sessionKeyProvider;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void invalidate() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> dispose() => _changes.close();

  String? _session() {
    final value = _sessionKeyProvider()?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  @override
  Future<Result<MusicianCalendarSettings>> getSettings() =>
      _settingsRequest(ApiHttpMethod.get);

  @override
  Future<Result<MusicianCalendarSettings>> readSettingsWithoutNotification() =>
      _settingsRequest(ApiHttpMethod.get, notifyConfirmation: false);

  @override
  Future<Result<MusicianCalendarSettings>> updateSettings({
    required bool visible,
    required int version,
  }) {
    if (version < 0) {
      return Future.value(const Result.failure(_invalidRequest));
    }
    return _settingsRequest(
      ApiHttpMethod.put,
      body: {'visible': visible, 'version': version},
    );
  }

  Future<Result<MusicianCalendarSettings>> _settingsRequest(
    ApiHttpMethod method, {
    Map<String, Object>? body,
    bool notifyConfirmation = true,
  }) async {
    final session = _session();
    if (session == null) return const Result.failure(_sessionChanged);
    try {
      final settings = await _api.request<MusicianCalendarSettings>(
        method,
        _settingsPath,
        body: body,
        requestContext: ApiRequestContext(expectedSessionKey: session),
        decoder: (raw) {
          final json = _object(raw);
          final visible = _boolean(json['visible']);
          final version = _integer(json['version']);
          if (version < 0) throw const FormatException('Invalid version.');
          return MusicianCalendarSettings(visible: visible, version: version);
        },
      );
      if (session != _session()) return const Result.failure(_sessionChanged);
      if (method == ApiHttpMethod.put) {
        if (settings.visible != body!['visible'] ||
            settings.version < (body['version'] as int)) {
          throw const FormatException('Settings update was not confirmed.');
        }
      }
      // Reconciliation reads also propagate a hide that committed before its
      // write response was lost, or a setting changed on another device.
      // A band preference can also remove events from active members' personal
      // calendars. The factory forwards this confirmation to the shared refresh
      // source; plain invalidate() never calls it, avoiding a feedback loop.
      if (notifyConfirmation) {
        final onSettingsConfirmed = _onSettingsConfirmed;
        if (onSettingsConfirmed == null) {
          invalidate();
        } else {
          onSettingsConfirmed();
        }
      }
      return Result.success(settings);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(_invalidResponse);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'musician_calendar_settings_unavailable',
          message: 'Takvim tercihin güncellenemedi. Tekrar deneyebilirsin.',
        ),
      );
    }
  }

  @override
  Future<Result<MusicianCalendarPage>> getCalendar({
    required String profileId,
    required DateTime startDate,
    required DateTime endDate,
    int page = 0,
    int size = 20,
  }) async {
    final id = profileId.trim();
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    final days = end.difference(start).inDays;
    if (id.isEmpty ||
        (_targetBandId != null && id != _targetBandId) ||
        start.year < 1 ||
        end.year > 9999 ||
        days < 0 ||
        days > 30 ||
        page < 0 ||
        page > 100 ||
        size < 1 ||
        size > 50) {
      return const Result.failure(_invalidRequest);
    }
    try {
      final result = await _api.get<MusicianCalendarPage>(
        '/api/v1/public/${_targetBandId == null ? 'musician-profiles' : 'bands'}/${Uri.encodeComponent(id)}/calendar',
        query: {
          'startDate': _wireDate(start),
          'endDate': _wireDate(end),
          'page': page,
          'size': size,
        },
        decoder: (raw) {
          final json = _object(raw);
          final visible = _boolean(json['visible']);
          final hasNext = _boolean(json['hasNext']);
          final rawEvents = json['events'];
          if (_requiredString(json['profileId']) != id ||
              _requiredString(json['startDate']) != _wireDate(start) ||
              _requiredString(json['endDate']) != _wireDate(end) ||
              _integer(json['page']) != page ||
              _integer(json['size']) != size ||
              rawEvents is! List ||
              rawEvents.length > size ||
              (!visible && (rawEvents.isNotEmpty || hasNext))) {
            throw const FormatException('Calendar response disagrees.');
          }
          final events = rawEvents
              .map((rawEvent) {
                final item = _object(rawEvent);
                final identity = EventPerformerIdentity.fromWire(
                  performerType: _requiredString(item['performerType']),
                  musicianProfileId: _optionalString(item['musicianProfileId']),
                  bandId: _optionalString(item['bandId']),
                );
                final dateText = _requiredString(item['eventDate']);
                final date = DateTime.tryParse(dateText);
                // Pre-reciprocal responses have no origin field. An explicit
                // non-venue origin must not re-enable rolled-back event types.
                final origin = item['eventOrigin'];
                if ((identity.musicianProfileId == null &&
                        identity.bandId == null) ||
                    (_targetBandId == null
                        ? identity.musicianProfileId != null &&
                              identity.musicianProfileId != id
                        : identity.bandId != id ||
                              identity.musicianProfileId != null) ||
                    (origin != null && origin != 'VENUE') ||
                    date == null ||
                    _wireDate(date) != dateText ||
                    _dateOnly(date).isBefore(start) ||
                    _dateOnly(date).isAfter(end)) {
                  throw const FormatException(
                    'Invalid calendar performer/date.',
                  );
                }
                return VenueEventDetail(
                  id: _requiredString(item['id']),
                  shareUrl: _optionalString(item['shareUrl']),
                  posterImage: _optionalString(item['posterImage']),
                  performerName: _requiredString(item['performerName']),
                  musicianProfileId: identity.musicianProfileId,
                  bandId: identity.bandId,
                  performerType: identity.performerType,
                  title: _requiredString(item['title']),
                  description: _optionalString(item['description']),
                  eventDate: date,
                  startTime: _time(item['startTime']),
                  endTime: item['endTime'] == null
                      ? null
                      : _time(item['endTime']),
                  venueId: _requiredString(item['venueId']),
                  venueName: _requiredString(item['venueName']),
                  venueCity: _optionalString(item['venueCity']),
                  venueDistrict: _optionalString(item['venueDistrict']),
                  venueNeighborhood: _optionalString(item['venueNeighborhood']),
                );
              })
              .toList(growable: false);
          if (events.map((event) => event.id).toSet().length != events.length) {
            throw const FormatException('Duplicate calendar event.');
          }
          return MusicianCalendarPage(
            profileId: id,
            visible: visible,
            startDate: start,
            endDate: end,
            events: events,
            page: page,
            size: size,
            hasNext: hasNext,
          );
        },
      );
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } on FormatException {
      return const Result.failure(_invalidResponse);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'musician_calendar_unavailable',
          message: 'Haftalık takvim getirilemedi.',
        ),
      );
    }
  }

  static Map<String, dynamic> _object(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Expected an object.');
    }
    return raw;
  }

  static bool _boolean(Object? raw) {
    if (raw is! bool) throw const FormatException('Expected a boolean.');
    return raw;
  }

  static int _integer(Object? raw) {
    if (raw is! int) throw const FormatException('Expected an integer.');
    return raw;
  }

  static String _requiredString(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('Expected a nonempty string.');
    }
    return raw.trim();
  }

  static String? _optionalString(Object? raw) {
    if (raw == null) return null;
    if (raw is! String) throw const FormatException('Expected a string.');
    return raw.trim().isEmpty ? null : raw.trim();
  }

  static String _time(Object? raw) {
    final value = _requiredString(raw);
    if (!RegExp(
      r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,9})?)?$',
    ).hasMatch(value)) {
      throw const FormatException('Invalid time.');
    }
    return value;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
  static String _wireDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static const _invalidRequest = AppError(
    code: 'musician_calendar_invalid_request',
    message: 'Takvim isteği geçersiz. Sayfayı yenileyip tekrar dene.',
  );
  static const _invalidResponse = AppError(
    code: 'musician_calendar_invalid_response',
    message: 'Takvim bilgileri doğrulanamadı. Tekrar deneyebilirsin.',
  );
  static const _sessionChanged = AppError(
    code: 'musician_calendar_session_changed',
    message: 'Oturum değişti. Ayarları yeniden açıp tekrar dene.',
  );
}
