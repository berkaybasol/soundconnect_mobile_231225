import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/event_plan.dart';
import '../domain/entities/event_performer_request.dart';
import '../domain/entities/venue_event_item.dart';
import '../domain/event_plan_repository.dart';

class EventPlanRepositoryImpl implements EventPlanRepository {
  EventPlanRepositoryImpl(
    this.api, {
    required this.sessionKeyProvider,
    required this.tokenProvider,
    this.onChanged,
  });
  final ApiClient api;
  final String? Function() sessionKeyProvider, tokenProvider;
  final void Function()? onChanged;
  static const owner = '/api/v1/venue-owner/event-plans';
  static const performer = '/api/v1/user/event-plans';
  static const _sessionError = AppError(
    code: 'event_plan_session_changed',
    message: 'Oturum değişti. Planı yeniden aç.',
  );
  static const _invalid = AppError(
    code: 'event_plan_invalid',
    message: 'Plan bilgileri doğrulanamadı. Listeyi yenileyip tekrar dene.',
  );
  static const _uncertain = AppError(
    code: 'event_plan_unknown',
    message:
        'İşlem sonucu doğrulanamadı. Tekrar işlem yapmadan önce listeyi yenile.',
  );

  @override
  Future<Result<VenueEventDraft>> copySource(
    String eventId,
    String venueId,
  ) => _request(
    ApiHttpMethod.get,
    '/api/v1/venue-owner/events/${Uri.encodeComponent(eventId)}/copy-source',
    (raw) {
      final j = _object(raw);
      if (_text(j['venueId']) != venueId) {
        throw const FormatException('Wrong copy venue');
      }
      return decodeTemplate(j).toDraft(_date(j['eventDate']));
    },
  );

  Future<Result<T>> _request<T>(
    ApiHttpMethod method,
    String path,
    T Function(Object?) decode, {
    Object? body,
    Map<String, dynamic>? query,
    bool mutation = false,
  }) async {
    final session = sessionKeyProvider();
    final token = tokenProvider();
    bool current() =>
        session?.trim().isNotEmpty == true &&
        session == sessionKeyProvider() &&
        token == tokenProvider();
    if (!current()) return const Result.failure(_sessionError);
    try {
      final value = await api.request<T>(
        method,
        path,
        body: body,
        query: query,
        decoder: decode,
        requestContext: ApiRequestContext(
          expectedSessionKey: session,
          expectedToken: token,
        ),
      );
      if (!current()) return const Result.failure(_sessionError);
      if (mutation) {
        try {
          onChanged?.call();
        } catch (_) {
          /* committed */
        }
      }
      return Result.success(value);
    } on ApiException catch (error) {
      return Result.failure(current() ? error.error : _sessionError);
    } on FormatException {
      return Result.failure(current() ? _invalid : _sessionError);
    } catch (_) {
      return Result.failure(current() ? _uncertain : _sessionError);
    }
  }

  @override
  Future<Result<EventPlanPreview>> preview(
    EventPlanDefinition definition, {
    String? planId,
    int? expectedVersion,
  }) {
    if ((planId == null) != (expectedVersion == null) ||
        (planId != null && planId.trim().isEmpty) ||
        (expectedVersion != null && expectedVersion < 0)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.post,
      planId == null
          ? '$owner/preview'
          : '$owner/${Uri.encodeComponent(planId)}/preview',
      (raw) {
        final j = _object(raw);
        final dates = _list(j['dates']).map(_date).toList();
        final preserved =
            _list(
              planId == null && j['preservedDates'] == null
                  ? const []
                  : j['preservedDates'],
            ).map((raw) {
              final item = _object(raw);
              return EventPlanPreservedDate(
                scheduledDate: _date(item['scheduledDate']),
                eventDate: _date(item['eventDate']),
                status: _enum(item['status'], const [
                  'OVERRIDDEN',
                  'SKIPPED',
                  'CANCELLED',
                  'STARTED',
                ]),
              );
            }).toList();
        final preservedKeys = preserved
            .map((item) => item.scheduledDate)
            .toSet();
        final through = _date(j['throughDate']);
        if (dates.length > 28 ||
            dates.toSet().length != dates.length ||
            preservedKeys.length != preserved.length ||
            dates.any(preservedKeys.contains) ||
            (planId == null && preserved.isNotEmpty) ||
            dates.any(
              (d) =>
                  d.isAfter(through) ||
                  !definition.weekdays.contains(d.weekday) ||
                  d.isBefore(definition.startDate) ||
                  (definition.untilDate != null &&
                      d.isAfter(definition.untilDate!)) ||
                  definition.excludedDates.any(
                    (x) => eventPlanDate(x) == eventPlanDate(d),
                  ),
            )) {
          throw const FormatException('Preview scope disagrees');
        }
        return EventPlanPreview(
          dates: List.unmodifiable(dates),
          throughDate: through,
          hasMore: _bool(j['hasMore']),
          serverNow: _instant(j['serverNow']),
          preservedDates: List.unmodifiable(preserved),
        );
      },
      body: planId == null
          ? definition.toJson()
          : {
              'expectedVersion': expectedVersion,
              'definition': definition.toJson(),
            },
    );
  }

  @override
  Future<Result<EventPlan>> create(
    String clientRequestId,
    EventPlanDefinition definition,
  ) => _request(
    ApiHttpMethod.post,
    owner,
    (raw) {
      final plan = decodePlan(raw);
      if (plan.definition.venueId != definition.venueId) {
        throw const FormatException('Wrong venue');
      }
      return plan;
    },
    body: {
      'clientRequestId': clientRequestId,
      'definition': definition.toJson(),
    },
    mutation: true,
  );
  @override
  Future<Result<EventPlanPage<EventPlan>>> listOwner(
    String venueId, {
    int page = 0,
  }) => _page('$owner/venue/${Uri.encodeComponent(venueId)}', page, (raw) {
    final plan = decodePlan(raw);
    if (plan.definition.venueId != venueId) {
      throw const FormatException('Wrong venue');
    }
    return plan;
  });
  @override
  Future<Result<EventPlan>> getOwner(String planId) => _get(owner, planId);
  @override
  Future<Result<EventPlan>> getPerformer(String planId) =>
      _get(performer, planId);
  Future<Result<EventPlan>> _get(String base, String id) => _request(
    ApiHttpMethod.get,
    '$base/${Uri.encodeComponent(id)}',
    (raw) => _matching(raw, id),
  );
  @override
  Future<Result<EventPlan>> update(
    EventPlan plan,
    EventPlanDefinition definition,
  ) => _write(plan, ApiHttpMethod.put, '', {'definition': definition.toJson()});
  @override
  Future<Result<EventPlan>> stop(
    EventPlan plan, {
    required bool cancelFuture,
  }) =>
      _write(plan, ApiHttpMethod.post, '/stop', {'cancelFuture': cancelFuture});
  @override
  Future<Result<EventPlan>> editOccurrence(
    EventPlan plan,
    EventPlanOccurrence occurrence, {
    required DateTime eventDate,
    required EventPlanTemplate template,
  }) => _write(
    plan,
    ApiHttpMethod.put,
    '/occurrences/${eventPlanDate(occurrence.scheduledDate)}',
    {'eventDate': eventPlanDate(eventDate), 'template': template.toJson()},
  );
  @override
  Future<Result<EventPlan>> skipOccurrence(
    EventPlan plan,
    EventPlanOccurrence occurrence,
  ) => _write(
    plan,
    ApiHttpMethod.post,
    '/occurrences/${eventPlanDate(occurrence.scheduledDate)}/skip',
    {},
  );
  @override
  Future<Result<EventPlan>> decide(
    EventPlan plan,
    String decision, {
    bool? showOnProfile,
  }) {
    if (!const ['ACCEPT', 'REJECT', 'WITHDRAW'].contains(decision) ||
        (decision == 'ACCEPT'
            ? showOnProfile == null
            : showOnProfile != null)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _write(plan, ApiHttpMethod.post, '/decision', {
      'decision': decision,
      'showOnProfile': showOnProfile,
    }, base: performer);
  }

  Future<Result<EventPlan>> _write(
    EventPlan plan,
    ApiHttpMethod method,
    String suffix,
    Map<String, Object?> fields, {
    String base = owner,
  }) => _request(
    method,
    '$base/${Uri.encodeComponent(plan.id)}$suffix',
    (raw) {
      final updated = _matching(raw, plan.id);
      if (updated.version < plan.version) {
        throw const FormatException('Old version');
      }
      return updated;
    },
    body: {'expectedVersion': plan.version, ...fields},
    mutation: true,
  );

  @override
  Future<Result<EventPlanPage<EventPlanOccurrence>>> occurrences(
    String planId, {
    int page = 0,
  }) => _page('$owner/${Uri.encodeComponent(planId)}/occurrences', page, (raw) {
    final j = _object(raw);
    final status = _enum(j['status'], const [
      'GENERATED',
      'OVERRIDDEN',
      'SKIPPED',
      'CANCELLED',
    ]);
    final id = _optional(j['eventId']);
    final event = j['event'] == null
        ? null
        : VenueOwnerEventItem.fromJson(_object(j['event']));
    if (event != null && event.id != id) {
      throw const FormatException('Occurrence identity disagrees');
    }
    return EventPlanOccurrence(
      scheduledDate: _date(j['scheduledDate']),
      eventDate: _date(j['eventDate']),
      status: status,
      eventId: id,
      event: event,
      template: j['template'] == null ? null : decodeTemplate(j['template']),
    );
  });
  @override
  Future<Result<EventPlanPage<EventPlan>>> listPerformer(
    EventPerformerTargetType type,
    String targetId, {
    int page = 0,
  }) => _page(performer, page, (raw) {
    final p = decodePlan(raw);
    final t = p.definition.template;
    if ((type == EventPerformerTargetType.band
            ? t.bandId
            : t.musicianProfileId) !=
        targetId) {
      throw const FormatException('Wrong performer');
    }
    return p;
  }, query: {'targetType': type.wireValue, 'targetId': targetId});

  Future<Result<EventPlanPage<T>>> _page<T>(
    String path,
    int page,
    T Function(Object?) decoder, {
    Map<String, dynamic>? query,
  }) {
    if (page < 0 || page > 100) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(ApiHttpMethod.get, path, (raw) {
      final j = _object(raw);
      final number = _int(j['page'] ?? j['number']);
      final size = _int(j['size']);
      final count = _int(j['totalElements']);
      final pages = _int(j['totalPages']);
      final content = _list(j['content']);
      final last = _bool(j['last']);
      if (number != page ||
          size != 20 ||
          pages != (count / size).ceil() ||
          content.length > (count - page * size).clamp(0, size) ||
          last != (page + 1 >= pages) ||
          (j['number'] != null && _int(j['number']) != page)) {
        throw const FormatException('Invalid paging');
      }
      final items = content.map(decoder).toList();
      final keys = items
          .map(
            (item) => item is EventPlan
                ? item.id
                : item is EventPlanOccurrence
                ? eventPlanDate(item.scheduledDate)
                : item,
          )
          .toSet();
      if (keys.length != items.length) {
        throw const FormatException('Duplicate page identities');
      }
      return EventPlanPage(
        items: List.unmodifiable(items),
        page: page,
        hasNext: !last,
      );
    }, query: {...?query, 'page': page, 'size': 20});
  }

  static EventPlan _matching(Object? raw, String id) {
    final plan = decodePlan(raw);
    if (plan.id != id) throw const FormatException('Wrong plan');
    return plan;
  }

  static EventPlan decodePlan(Object? raw) {
    final j = _object(raw);
    final definition = _object(j['definition']);
    final weekdays = _list(definition['weekdays']).map(_int).toList();
    if (weekdays.isEmpty ||
        weekdays.any((d) => d < 1 || d > 7) ||
        weekdays.toSet().length != weekdays.length) {
      throw const FormatException('Invalid weekdays');
    }
    final start = _date(definition['startDate']);
    final until = definition['untilDate'] == null
        ? null
        : _date(definition['untilDate']);
    if (until != null && until.isBefore(start)) {
      throw const FormatException('Invalid range');
    }
    return EventPlan(
      id: _text(j['id']),
      version: _int(j['version']),
      definition: EventPlanDefinition(
        venueId: _text(definition['venueId']),
        startDate: start,
        untilDate: until,
        weekdays: weekdays,
        excludedDates: _list(definition['excludedDates']).map(_date),
        template: decodeTemplate(definition['template']),
      ),
      venueName: _text(j['venueName']),
      performerName: _optional(j['performerName']) ?? '',
      posterUrl: _optional(j['posterUrl']),
      status: _enum(j['status'], const ['ACTIVE', 'STOPPED', 'COMPLETED']),
      consentStatus: _enum(j['consentStatus'], const [
        'NOT_REQUIRED',
        'PENDING',
        'ACCEPTED',
        'REJECTED',
        'WITHDRAWN',
      ]),
      showOnProfile: _bool(j['showOnProfile']),
      generatedThrough: j['generatedThrough'] == null
          ? null
          : _date(j['generatedThrough']),
      serverNow: _instant(j['serverNow']),
      decisionAllowed: _bool(j['decisionAllowed']),
      withdrawAllowed: _bool(j['withdrawAllowed']),
    );
  }

  static EventPlanTemplate decodeTemplate(Object? raw) {
    final j = _object(raw);
    final musician = _optional(j['musicianProfileId']);
    final band = _optional(j['bandId']);
    final manual = _optional(j['manualPerformerName']);
    if ([musician, band, manual].whereType<String>().length > 1) {
      throw const FormatException('Ambiguous performer');
    }
    return EventPlanTemplate(
      title: _text(j['title']),
      description: _optional(j['description']) ?? '',
      startTime: _time(j['startTime']),
      endTime: j['endTime'] == null ? null : _time(j['endTime']),
      posterImage: _optional(j['posterImage']),
      musicianProfileId: musician,
      bandId: band,
      manualPerformerName: manual,
    );
  }

  static Map<String, dynamic> _object(Object? v) {
    if (v is! Map<String, dynamic>) {
      throw const FormatException('Expected object');
    }
    return v;
  }

  static List _list(Object? v) {
    if (v is! List) throw const FormatException('Expected list');
    return v;
  }

  static String _text(Object? v) {
    if (v is! String || v.trim().isEmpty) {
      throw const FormatException('Expected text');
    }
    return v.trim();
  }

  static String? _optional(Object? v) => v == null || v == '' ? null : _text(v);
  static String _enum(Object? v, List<String> allowed) {
    final text = _text(v);
    if (!allowed.contains(text)) throw const FormatException('Unknown state');
    return text;
  }

  static int _int(Object? v) {
    if (v is! int || v < 0 || v > 9007199254740991) {
      throw const FormatException('Invalid integer');
    }
    return v;
  }

  static bool _bool(Object? v) {
    if (v is! bool) throw const FormatException('Invalid boolean');
    return v;
  }

  static DateTime _date(Object? v) {
    final text = _text(v);
    final value = DateTime.tryParse(text);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
        value == null ||
        eventPlanDate(value) != text) {
      throw const FormatException('Invalid date');
    }
    return value;
  }

  static DateTime _instant(Object? v) {
    final text = _text(v);
    final value = DateTime.tryParse(text);
    if (value == null || !value.isUtc) {
      throw const FormatException('Unzoned instant');
    }
    return value;
  }

  static String _time(Object? v) {
    final text = _text(v);
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$').hasMatch(text)) {
      throw const FormatException('Invalid time');
    }
    return text;
  }
}
