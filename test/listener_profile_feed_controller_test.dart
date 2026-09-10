import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_feed_controller.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late _Harness h;
  setUp(() => h = _Harness());
  tearDown(() => h.dispose());

  test(
    'revalidation preserves the loaded prefix and fails closed on revoked projections',
    () async {
      h.shares.items = [
        _share('s4', 4),
        _share('s3', 3),
        _share('s2', 2),
        _share('s1', 1),
      ];
      await h.feed.reload();
      await h.feed.next();
      final before = List.of(h.feed.entries);
      final pending = Completer<Result<Page<OverthinkingProfileShare>>>();
      h.shares.read = (page, size) => pending.future;
      final refreshing = h.feed.revalidate();
      expect(h.feed.loading, isTrue);
      expect(h.feed.entries, before);
      expect(
        h.feed.containsShare(h.sessions.session, before.last.share!),
        isFalse,
      );
      pending.complete(
        const Result.failure(AppError(code: '403', message: 'Hidden')),
      );
      await refreshing;
      expect(h.feed.entries, isEmpty);
      expect(h.feed.rows, isEmpty);
      expect(h.feed.hasNext, isFalse);
      expect(h.feed.error, 'Hidden');
    },
  );

  test(
    'revalidation replaces old identity projections across all loaded pages',
    () async {
      h.shares.items = [
        _share('s4', 4),
        _share('s3', 3),
        _share('s2', 2),
        _share('s1', 1),
      ];
      await h.feed.reload();
      await h.feed.next();
      final old = h.feed.entries.last.share!;
      h.shares.items = [
        _share('s4', 4),
        _share('s3', 3),
        _share('s2', 2),
        _share('s1', 1),
      ];
      await h.feed.revalidate();
      expect(h.feed.entries, hasLength(4));
      expect(h.feed.page, 1);
      expect(identical(h.feed.entries.last.share, old), isFalse);
      expect(h.feed.containsShare(h.sessions.session, old), isFalse);
      expect(h.feed.hasNext, isFalse);
    },
  );

  test(
    'appends one mixed publication timeline, preserving event row identity',
    () async {
      h.events.items = [_event('e9', 9), _event('e5', 5), _event('e1', 1)];
      h.shares.items = [_share('s10', 10), _share('s6', 6), _share('s2', 2)];
      await h.feed.reload();
      expect(h.keys, ['overthinking:s10', 'event:e9']);
      final firstEvent = h.feed.rows.single;
      expect(firstEvent.publishedAt, _time(9));
      await h.feed.next();
      expect(h.keys, [
        'overthinking:s10',
        'event:e9',
        'overthinking:s6',
        'event:e5',
      ]);
      expect(identical(h.feed.rows.first, firstEvent), isTrue);
      await h.feed.next();
      expect(h.keys, [
        'overthinking:s10',
        'event:e9',
        'overthinking:s6',
        'event:e5',
        'overthinking:s2',
        'event:e1',
      ]);
      expect(h.feed.hasNext, isFalse);
      expect(h.events.pages, [0, 1]);
      expect(h.shares.pages, [0, 1]);
      expect(h.events.periods, everyElement(EventAudiencePeriod.all));
    },
  );

  for (final eventsFirst in [false, true]) {
    test(
      'refills a skewed ${eventsFirst ? 'event' : 'Overthinking'} stream before exposing older other-type rows',
      () async {
        h.replaceFeed(pageSize: 6);
        if (eventsFirst) {
          h.events.items = List.generate(13, (i) => _event('e$i', 30 - i));
          h.shares.items = [_share('old', 1)];
        } else {
          h.shares.items = List.generate(13, (i) => _share('s$i', 30 - i));
          h.events.items = [_event('old', 1)];
        }
        await h.feed.reload();
        expect(h.keys.length, 6);
        expect(h.keys.any((key) => key.endsWith(':old')), isFalse);
        await h.feed.next();
        expect(h.keys.length, 12);
        expect(h.keys.any((key) => key.endsWith(':old')), isFalse);
        await h.feed.next();
        expect(h.keys.length, 14);
        expect(h.keys.last, '${eventsFirst ? 'overthinking' : 'event'}:old');
        expect(eventsFirst ? h.events.pages : h.shares.pages, [0, 1, 2]);
        expect(eventsFirst ? h.shares.pages : h.events.pages, [0]);
        expect(h.feed.hasNext, isFalse);
      },
    );
  }

  test(
    'equal timestamps preserve endpoint tie order across page boundaries',
    () async {
      h.replaceFeed(pageSize: 1);
      h.events.items = [
        _event('p-z', 7, eventId: 'event-a'),
        _event('p-a', 7, eventId: 'event-z'),
      ];
      h.shares.items = [_share('z', 7), _share('a', 7)];
      await h.feed.reload();
      while (h.feed.hasNext) {
        await h.feed.next();
      }
      expect(h.keys, [
        'event:p-z',
        'event:p-a',
        'overthinking:z',
        'overthinking:a',
      ]);
    },
  );

  test(
    'identical IDs in different types remain distinct publications',
    () async {
      h.events.items = [_event('same', 1)];
      h.shares.items = [_share('same', 2)];
      await h.feed.reload();
      expect(h.keys, ['overthinking:same', 'event:same']);
    },
  );

  test(
    'skips invalid event intents without truncating later source pages',
    () async {
      h.events.items = [
        _event('invalid-1', 20, intent: EventAudienceStatus.none),
        _event('invalid-2', 19, intent: EventAudienceStatus.none),
        _event('valid', 10),
      ];
      h.shares.items = [_share('older', 5)];
      await h.feed.reload();
      expect(h.keys, ['event:valid', 'overthinking:older']);
      expect(h.events.pages, [0, 1]);
    },
  );

  test(
    'initial source failure does not show an unproven partial timeline',
    () async {
      h.events.items = [_event('e', 10)];
      h.shares.read = (page, size) async => _failure();
      await h.feed.reload();
      expect(h.keys, isEmpty);
      expect(h.feed.error, isNotNull);
      expect(h.feed.loading, isFalse);
      h.shares.read = null;
      h.shares.items = [_share('s', 11)];
      await h.feed.retry();
      expect(h.keys, ['overthinking:s', 'event:e']);
      expect(h.events.pages, [0, 0]);
    },
  );

  test(
    'append failure preserves committed rows and retries the failed source without consuming the other buffer',
    () async {
      h.events.items = [_event('e10', 10), _event('e8', 8), _event('e6', 6)];
      h.shares.items = [_share('s9', 9), _share('s7', 7), _share('s5', 5)];
      await h.feed.reload();
      await h.feed.next();
      final committed = List.of(h.feed.entries);
      h.shares.read = (page, size) async => _failure();
      await h.feed.next();
      expect(h.feed.entries, committed);
      expect(h.feed.error, isNotNull);
      expect(h.feed.loadingMore, isFalse);
      h.shares.read = null;
      await h.feed.retry();
      expect(h.keys, [
        'event:e10',
        'overthinking:s9',
        'event:e8',
        'overthinking:s7',
        'event:e6',
        'overthinking:s5',
      ]);
      // Event page 1 was needed to prove that s7 could safely close the
      // previous visible page. Its e6 head stays buffered through this failed
      // append; retrying must not fetch that already committed cursor again.
      expect(h.events.pages, [0, 1]);
      expect(h.shares.pages, [0, 1, 1]);
      expect(identical(h.feed.entries.first, committed.first), isTrue);
    },
  );

  test(
    'privacy denial on append clears formerly visible publications',
    () async {
      h.events.items = List.generate(5, (i) => _event('e$i', 20 - i));
      await h.feed.reload();
      h.events.read = (page, size) async => _failure(code: '403');
      await h.feed.next();
      expect(h.keys, isEmpty);
      expect(h.feed.rows, isEmpty);
      expect(h.feed.hasNext, isFalse);
      h.events.read = null;
      await h.feed.retry();
      expect(h.keys, ['event:e0', 'event:e1']);
      expect(h.events.pages, [0, 1, 0]);
    },
  );

  test('both mutation signals revalidate both streams exactly once', () async {
    h.events.items = [_event('old', 1)];
    await h.feed.reload();
    h.shares.items = [_share('new', 9)];
    h.shares.signal.value++;
    expect(h.feed.loading, isTrue);
    await _settle();
    expect(h.keys, ['overthinking:new', 'event:old']);
    h.events.items = [_event('newer', 10), _event('old', 1)];
    h.events.signal.value++;
    await _settle();
    expect(h.keys, ['event:newer', 'overthinking:new']);
    expect(h.events.pages, [0, 0, 0]);
    expect(h.shares.pages, [0, 0, 0]);
  });

  test(
    'token replacement fences late response even for the same account',
    () async {
      final pending = Completer<Result<Page<OverthinkingProfileShare>>>();
      h.shares.read = (page, size) => pending.future;
      final oldSession = h.sessions.session;
      final oldLoad = h.feed.reload();
      h.shares.read = null;
      h.shares.items = [_share('fresh', 10)];
      h.sessions.replace(audienceSession(token: 'replacement'));
      await _settle();
      pending.complete(
        Result.success(Page(items: [_share('stale', 20)], hasNext: true)),
      );
      await oldLoad;
      expect(h.keys, ['overthinking:fresh']);
      expect(h.shares.expectedSessions.first, same(oldSession));
      expect(h.shares.expectedSessions.last, same(h.sessions.session));
      expect(h.shares.pages, [0, 0]);
    },
  );

  test(
    'same-session reload fences old page and prevents follow-up stale reads',
    () async {
      final pending = Completer<Result<EventAudiencePage<EventAudiencePost>>>();
      h.events.read = (page, size) => pending.future;
      final oldLoad = h.feed.reload();
      h.events.read = null;
      h.events.items = [_event('fresh', 5)];
      await h.feed.reload();
      pending.complete(
        Result.success(
          _eventPage(
            [_event('stale', 10, intent: EventAudienceStatus.none)],
            0,
            2,
            total: 4,
          ),
        ),
      );
      await oldLoad;
      expect(h.keys, ['event:fresh']);
      expect(h.events.pages, [0, 0]);
    },
  );

  test(
    'dispose fences late publication and emits no further notifications',
    () async {
      final pending = Completer<Result<Page<OverthinkingProfileShare>>>();
      h.shares.read = (page, size) => pending.future;
      final load = h.feed.reload();
      var notifications = 0;
      h.feed.addListener(() => notifications++);
      h.feed.dispose();
      h.feedDisposed = true;
      pending.complete(
        Result.success(Page(items: [_share('stale', 10)], hasNext: true)),
      );
      await load;
      expect(notifications, 0);
      expect(h.keys, isEmpty);
      h.events.signal.value++;
      h.shares.signal.value++;
      expect(h.shares.pages, [0]);
    },
  );

  test('repeated load-more taps share one append operation', () async {
    h.events.items = List.generate(4, (i) => _event('e$i', 20 - i));
    await h.feed.reload();
    final pending = Completer<Result<EventAudiencePage<EventAudiencePost>>>();
    h.events.read = (page, size) => pending.future;
    final first = h.feed.next();
    await h.feed.next();
    expect(h.feed.loadingMore, isTrue);
    expect(h.events.pages, [0, 1]);
    pending.complete(
      Result.success(
        _eventPage(h.events.items.skip(2).toList(), 1, 2, total: 4),
      ),
    );
    await first;
    expect(h.keys.length, 4);
  });

  test(
    'deleted exact publication cannot reappear; a republication can',
    () async {
      final old = _share('old-publication', 10);
      h.shares.items = [old, _share('older', 5), old];
      await h.feed.reload();
      expect(h.feed.containsShare(h.sessions.session, old), isTrue);
      h.feed.forgetShare(old.shareId);
      expect(h.feed.containsShare(h.sessions.session, old), isFalse);
      await h.feed.next();
      expect(h.keys, ['overthinking:older']);
      h.shares.items = [_share('new-publication', 20), old];
      await h.feed.reload();
      expect(h.keys, ['overthinking:new-publication']);
    },
  );

  test(
    'share callbacks require captured object and session; append retains identity',
    () async {
      final first = _share('first', 10);
      h.shares.items = [first, _share('second', 9), _share('third', 8)];
      await h.feed.reload();
      expect(
        h.feed.containsShare(h.sessions.session, _share('first', 10)),
        isFalse,
      );
      expect(h.feed.containsShare(audienceSession(), first), isFalse);
      await h.feed.next();
      expect(h.feed.containsShare(h.sessions.session, first), isTrue);
      final pending = Completer<Result<Page<OverthinkingProfileShare>>>();
      h.shares.read = (page, size) => pending.future;
      final load = h.feed.reload();
      expect(h.feed.containsShare(h.sessions.session, first), isFalse);
      pending.complete(const Result.success(Page(items: [], hasNext: false)));
      await load;
    },
  );

  test(
    'guest and mismatched owner do not load; other-role public viewer can read',
    () async {
      h.sessions.replace(const AuthSession.guest());
      await _settle();
      expect(h.feed.allowed, isFalse);
      expect(h.events.pages, isEmpty);
      h.sessions.replace(audienceSession(role: 'ROLE_MUSICIAN'));
      await _settle();
      expect(h.feed.allowed, isTrue);
      expect(h.events.pages, [0]);
      h.replaceFeed(ownerUserId: 'another-user');
      await h.feed.reload();
      expect(h.feed.allowed, isFalse);
      expect(h.events.pages, [0]);
    },
  );

  test('required listener profile choice blocks public timeline too', () async {
    h.sessions.replace(
      AuthSession.authenticated(
        token: 'token',
        userId: 'listener',
        username: 'listener',
        accountStatus: 'ACTIVE',
        roles: const ['ROLE_LISTENER'],
        permissions: const [],
        expiresAt: DateTime.utc(2100),
        isAdmin: false,
        requiresListenerProfileChoice: true,
      ),
    );
    await _settle();
    expect(h.feed.allowed, isFalse);
    expect(h.events.pages, isEmpty);
    expect(h.shares.pages, isEmpty);
  });

  test(
    'newer unseen append row resets both streams instead of breaking chronology',
    () async {
      h.events.items = [
        _event('old-head', 10),
        _event('old-tail', 8),
        _event('older', 6),
      ];
      await h.feed.reload();
      h.events.read = (page, size) async => Result.success(
        _eventPage(
          page == 0
              ? [_event('new-head', 30), _event('new-tail', 20)]
              : [_event('new-tail', 20), _event('old-tail', 8)],
          page,
          size,
          total: 4,
        ),
      );
      await h.feed.next();
      expect(h.keys, ['event:new-head', 'event:new-tail']);
      expect(h.feed.error, isNull);
      expect(h.events.pages, [0, 1, 0]);
      expect(h.shares.pages, [0, 0]);
    },
  );

  test('continuous source drift permits only one automatic restart', () async {
    h.events.read = (page, size) async => Result.success(
      _eventPage([_event('e$page', page == 0 ? 10 : 20)], page, size, total: 4),
    );
    await h.feed.reload();
    expect(h.keys, isEmpty);
    expect(h.feed.error, contains('güncellendi'));
    expect(h.feed.loading, isFalse);
    expect(h.events.pages, [0, 1, 0, 1]);
    expect(h.shares.pages, [0, 0]);
  });

  test('source page cap prevents an invalid request after page 1000', () async {
    h.replaceFeed(pageSize: 1);
    h.shares.read = (page, size) async => Result.success(
      Page(items: [_share('s$page', 2000 - page)], hasNext: true),
    );
    await h.feed.reload();
    while (h.feed.hasNext) {
      await h.feed.next();
    }
    expect(h.keys.length, 1001);
    expect(h.shares.pages.last, 1000);
  });
}

DateTime _time(int minute) =>
    DateTime.utc(2026, 9, 10).add(Duration(minutes: minute));

EventAudiencePost _event(
  String id,
  int minute, {
  String? eventId,
  EventAudienceStatus intent = EventAudienceStatus.going,
}) => EventAudiencePost(
  eventId: eventId ?? id,
  postId: id,
  intent: intent,
  note: null,
  publishedAt: _time(minute),
  eventEnded: false,
  event: audienceState(eventId: eventId ?? id).event!,
);

OverthinkingProfileShare _share(String id, int minute) =>
    OverthinkingProfileShare(
      shareId: id,
      note: null,
      publishedAt: _time(minute),
      post: OverthinkingPostModel.fromJson({
        'id': 'source-$id',
        'title': id,
        'content': 'İçinden geçenler.',
        'anonymous': true,
        'canViewAuthor': false,
        'visibilityType': 'ANONYMOUS',
      }),
    );

Result<T> _failure<T>({String code = 'NETWORK'}) =>
    Result.failure(AppError(code: code, message: 'Paylaşımlar yüklenemedi.'));

EventAudiencePage<EventAudiencePost> _eventPage(
  List<EventAudiencePost> items,
  int page,
  int size, {
  required int total,
}) => EventAudiencePage(
  items: items,
  page: page,
  size: size,
  totalElements: total,
  totalPages: (total / size).ceil(),
  hasNext: (page + 1) * size < total,
);

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
}

class _Harness {
  _Harness() {
    replaceFeed();
  }
  final events = _Events();
  final shares = _Shares();
  final sessions = AudienceTestSessions(audienceSession());
  late ListenerProfileFeedController feed;
  bool _initialized = false;
  bool feedDisposed = false;
  List<String> get keys => feed.entries.map((entry) => entry.key).toList();

  void replaceFeed({int pageSize = 2, String? ownerUserId}) {
    if (_initialized) feed.dispose();
    feed = ListenerProfileFeedController(
      eventsRepository: events,
      overthinkingRepository: shares,
      sessions: sessions,
      listenerProfileId: 'profile',
      ownerUserId: ownerUserId,
      pageSize: pageSize,
    );
    _initialized = true;
  }

  void dispose() {
    if (!feedDisposed) feed.dispose();
    sessions.dispose();
    events.signal.dispose();
    shares.signal.dispose();
  }
}

class _Events extends Fake implements EventAudienceRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  List<EventAudiencePost> items = [];
  final pages = <int>[];
  final periods = <EventAudiencePeriod>[];
  Future<Result<EventAudiencePage<EventAudiencePost>>> Function(
    int page,
    int size,
  )?
  read;
  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    periods.add(period);
    if (read != null) return read!(page, size);
    return Result.success(
      _eventPage(
        items.skip(page * size).take(size).toList(),
        page,
        size,
        total: items.length,
      ),
    );
  }
}

class _Shares extends Fake implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  List<OverthinkingProfileShare> items = [];
  final pages = <int>[];
  final expectedSessions = <AuthSession>[];
  Future<Result<Page<OverthinkingProfileShare>>> Function(int page, int size)?
  read;
  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    expectedSessions.add(expectedSession);
    if (read != null) return read!(page, size);
    return Result.success(
      Page(
        items: items.skip(page * size).take(size).toList(),
        hasNext: (page + 1) * size < items.length,
      ),
    );
  }
}
