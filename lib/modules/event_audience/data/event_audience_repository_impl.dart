import 'package:flutter/foundation.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/event_performer_identity.dart';
import '../../profile/domain/entities/venue_event_detail.dart';
import '../domain/event_audience_repository.dart';

class EventAudienceRepositoryImpl implements EventAudienceRepository {
  EventAudienceRepositoryImpl(
    this._api, {
    required String? Function() sessionKeyProvider,
  }) : _sessionKeyProvider = sessionKeyProvider;

  final ApiClient _api;
  final String? Function() _sessionKeyProvider;
  final ValueNotifier<int> _changes = ValueNotifier(0);
  static const _base = '/api/v1/user/event-intents';
  static const _sessionError = AppError(
    code: 'event_audience_session_changed',
    message: 'Oturum değişti. Yeniden dene.',
  );
  static const _unavailable = AppError(
    code: 'event_audience_unavailable',
    message: 'Etkinlik seçimin şu anda yüklenemiyor. Yeniden dene.',
  );

  @override
  ValueListenable<int> get changes => _changes;

  void dispose() => _changes.dispose();

  bool _current(String? expected) =>
      expected?.trim().isNotEmpty == true &&
      expected!.trim() == _sessionKeyProvider()?.trim();

  Future<Result<T>> _read<T>(
    String? expected,
    Future<T> Function() action,
  ) async {
    if (!_current(expected)) return const Result.failure(_sessionError);
    try {
      final result = await action();
      return _current(expected)
          ? Result.success(result)
          : const Result.failure(_sessionError);
    } on ApiException catch (error) {
      return Result.failure(_current(expected) ? error.error : _sessionError);
    } catch (_) {
      return Result.failure(_current(expected) ? _unavailable : _sessionError);
    }
  }

  @override
  Future<Result<EventAudienceState>> getIntent({
    required String eventId,
    required String expectedSessionKey,
  }) => _read(expectedSessionKey, () async {
    final id = _id(eventId);
    return _api.request<EventAudienceState>(
      ApiHttpMethod.get,
      '$_base/$id',
      requestContext: ApiRequestContext(
        expectedSessionKey: expectedSessionKey.trim(),
      ),
      decoder: (raw) => _state(raw, expectedId: id),
    );
  });

  @override
  Future<Result<EventAudienceState>> setIntent({
    required String eventId,
    required EventAudienceStatus intent,
    required bool publishedOnProfile,
    required String? note,
    required int expectedVersion,
    required String expectedSessionKey,
  }) async {
    final result = await _read(expectedSessionKey, () async {
      final id = _id(eventId);
      final normalizedNote = note?.trim();
      final text = normalizedNote?.isEmpty == true ? null : normalizedNote;
      if (expectedVersion < 0 ||
          expectedVersion >= 9007199254740991 ||
          (text?.runes.length ?? 0) > 500 ||
          (!publishedOnProfile && text != null) ||
          (intent == EventAudienceStatus.none && publishedOnProfile)) {
        throw const FormatException('Invalid audience command');
      }
      // No automatic mutation retry: ambiguous writes must be read back first.
      return _api.request<EventAudienceState>(
        ApiHttpMethod.put,
        '$_base/$id',
        body: {
          'intent': intent.wireValue,
          'publishedOnProfile': publishedOnProfile,
          'note': text,
          'expectedVersion': expectedVersion,
        },
        requestContext: ApiRequestContext(
          expectedSessionKey: expectedSessionKey.trim(),
        ),
        decoder: (raw) {
          final state = _state(raw, expectedId: id);
          if (state.intent != intent ||
              state.publishedOnProfile != publishedOnProfile ||
              state.note != text ||
              (state.version != expectedVersion &&
                  state.version != expectedVersion + 1)) {
            throw const FormatException('Audience mutation not confirmed');
          }
          return state;
        },
      );
    });
    if (result.isSuccess) _changes.value++;
    return result;
  }

  @override
  Future<Result<EventAudiencePage<EventAudienceState>>> listMine({
    required String expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.upcoming,
    int page = 0,
    int size = 20,
  }) => _read(expectedSessionKey, () async {
    _pageRequest(page, size);
    return _api.request<EventAudiencePage<EventAudienceState>>(
      ApiHttpMethod.get,
      _base,
      query: {'period': period.wireValue, 'page': page, 'size': size},
      requestContext: ApiRequestContext(
        expectedSessionKey: expectedSessionKey.trim(),
      ),
      decoder: (raw) => _page(raw, page, size, (item) {
        final state = _state(item);
        if (state.intent == EventAudienceStatus.none) {
          throw const FormatException('Empty plan');
        }
        return state;
      }, (state) => state.eventId),
    );
  });

  @override
  Future<Result<EventAudienceState>> deletePost({
    required String postId,
    required String expectedSessionKey,
  }) async {
    final result = await _read(expectedSessionKey, () async {
      final id = _id(postId);
      // Address the publication itself so a stale card cannot remove a newer
      // publication of the same event. Do not retry an ambiguous deletion.
      return _api.request<EventAudienceState>(
        ApiHttpMethod.delete,
        '/api/v1/user/event-posts/$id',
        requestContext: ApiRequestContext(
          expectedSessionKey: expectedSessionKey.trim(),
        ),
        decoder: (raw) {
          final state = _state(raw);
          if (state.postId != null ||
              state.publishedOnProfile ||
              state.note != null ||
              state.version == 0) {
            throw const FormatException('Post deletion not confirmed');
          }
          return state;
        },
      );
    });
    if (result.isSuccess) _changes.value++;
    return result;
  }

  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) => _read(expectedSessionKey, () async {
    final id = _id(listenerProfileId);
    _pageRequest(page, size);
    return _api.request<EventAudiencePage<EventAudiencePost>>(
      ApiHttpMethod.get,
      '/api/v1/public/listener-profiles/$id/event-posts',
      query: {'period': period.wireValue, 'page': page, 'size': size},
      requestContext: ApiRequestContext(
        expectedSessionKey: expectedSessionKey!.trim(),
      ),
      decoder: (raw) => _page(raw, page, size, (item) {
        final json = _map(item);
        final eventId = _id(json['eventId']);
        final status = _status(json['intent']);
        if (status == EventAudienceStatus.none) {
          throw const FormatException('Empty publication');
        }
        return EventAudiencePost(
          eventId: eventId,
          postId: _id(json['postId']),
          intent: status,
          note: _note(json['note']),
          publishedAt: _instant(json['publishedAt']),
          eventEnded: _bool(json['eventEnded']),
          event: _event(json['event'], eventId),
        );
      }, (post) => post.postId),
    );
  });

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid object');
    }
    return raw;
  }

  static String _id(Object? raw) {
    if (raw is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(raw.trim()) ||
        raw.trim() == '00000000-0000-0000-0000-000000000000') {
      throw const FormatException('Invalid identity');
    }
    return raw.trim().toLowerCase();
  }

  static int _int(Object? value) {
    if (value is! int || value < 0 || value > 9007199254740991) {
      throw const FormatException('Invalid number');
    }
    return value;
  }

  static bool _bool(Object? value) {
    if (value is! bool) throw const FormatException('Invalid flag');
    return value;
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Invalid text');
    return value;
  }

  static String? _note(Object? value) {
    final text = _text(value);
    if ((text?.runes.length ?? 0) > 500) {
      throw const FormatException('Invalid note');
    }
    return text;
  }

  static DateTime _instant(Object? value) {
    if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw const FormatException('Invalid instant');
    }
    final instant = DateTime.tryParse(value);
    if (instant == null) throw const FormatException('Invalid instant');
    return instant;
  }

  static EventAudienceStatus _status(Object? raw) =>
      EventAudienceStatus.values.firstWhere(
        (status) => status.wireValue == raw,
        orElse: () => throw const FormatException('Invalid intent'),
      );

  static EventAudienceState _state(Object? raw, {String? expectedId}) {
    final json = _map(raw);
    if (!json.containsKey('postId') ||
        !json.containsKey('note') ||
        !json.containsKey('updatedAt') ||
        !json.containsKey('event')) {
      throw const FormatException('Incomplete audience state');
    }
    final id = _id(json['eventId']);
    final intent = _status(json['intent']);
    final published = _bool(json['publishedOnProfile']);
    final postId = json['postId'] == null ? null : _id(json['postId']);
    final note = _note(json['note']);
    final available = _bool(json['eventAvailable']);
    final ended = _bool(json['eventEnded']);
    final canSet = _bool(json['canSetIntent']);
    final canPublish = _bool(json['canPublish']);
    final visible = _bool(json['publicationVisible']);
    final event = json['event'] == null ? null : _event(json['event'], id);
    final version = _int(json['version']);
    final updated = json['updatedAt'] == null
        ? null
        : _instant(json['updatedAt']);
    if ((expectedId != null && id != expectedId) ||
        (published != (postId != null)) ||
        (available != (event != null)) ||
        (canSet && (!available || ended)) ||
        (canPublish && !canSet) ||
        (visible && (!published || !available)) ||
        (!published && note != null) ||
        (intent == EventAudienceStatus.none && (published || note != null)) ||
        (version > 0 && updated == null)) {
      throw const FormatException('Invalid audience state');
    }
    return EventAudienceState(
      eventId: id,
      postId: postId,
      intent: intent,
      publishedOnProfile: published,
      note: note,
      version: version,
      updatedAt: updated,
      eventAvailable: available,
      eventEnded: ended,
      canSetIntent: canSet,
      canPublish: canPublish,
      publicationVisible: visible,
      event: event,
    );
  }

  static VenueEventDetail _event(Object? raw, String expectedId) {
    final json = _map(raw);
    final id = _id(json['id']);
    final title = _text(json['title']);
    final dateText = _text(json['eventDate']);
    final date = DateTime.tryParse(dateText ?? '');
    if (id != expectedId ||
        title?.trim().isNotEmpty != true ||
        date == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateText!) ||
        date.toIso8601String().substring(0, 10) != dateText) {
      throw const FormatException('Invalid event projection');
    }
    final identity = EventPerformerIdentity.fromWire(
      performerType: json['performerType'],
      musicianProfileId: json['musicianProfileId'],
      bandId: json['bandId'],
    );
    return VenueEventDetail(
      id: id,
      title: title,
      eventDate: date,
      shareUrl: _text(json['shareUrl']),
      posterImage: _text(json['posterImage']),
      performerName: _text(json['performerName']),
      musicianProfileId: identity.musicianProfileId,
      bandId: identity.bandId,
      performerType: identity.performerType,
      description: _text(json['description']),
      startTime: _text(json['startTime']),
      endTime: _text(json['endTime']),
      venueId: _id(json['venueId']),
      venueName: _text(json['venueName']),
      venueCity: _text(json['venueCity']),
      venueDistrict: _text(json['venueDistrict']),
      venueNeighborhood: _text(json['venueNeighborhood']),
    );
  }

  static void _pageRequest(int page, int size) {
    if (page < 0 || page > 1000 || size < 1 || size > 50) {
      throw const FormatException('Invalid page request');
    }
  }

  static EventAudiencePage<T> _page<T>(
    Object? raw,
    int requestedPage,
    int requestedSize,
    T Function(Object?) decode,
    String Function(T) idOf,
  ) {
    final json = _map(raw);
    final page = _int(json['page']);
    final size = _int(json['size']);
    final total = _int(json['totalElements']);
    final pages = _int(json['totalPages']);
    final content = json['content'];
    final first = _bool(json['first']);
    final last = _bool(json['last']);
    if (page != requestedPage ||
        size != requestedSize ||
        (json.containsKey('number') && _int(json['number']) != page) ||
        content is! List ||
        content.length != (total - page * size).clamp(0, size) ||
        pages != (total / size).ceil() ||
        first != (page == 0) ||
        last != (page + 1 >= pages)) {
      throw const FormatException('Invalid audience page');
    }
    final ids = <String>{};
    final items = content
        .map((raw) {
          final item = decode(raw);
          if (!ids.add(idOf(item))) {
            throw const FormatException('Duplicate event');
          }
          return item;
        })
        .toList(growable: false);
    return EventAudiencePage(
      items: List.unmodifiable(items),
      page: page,
      size: size,
      totalElements: total,
      totalPages: pages,
      hasNext: !last && page < 1000,
    );
  }
}
