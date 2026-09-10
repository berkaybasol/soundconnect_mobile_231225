import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late _Events events;
  late _Shares shares;
  late AudienceTestSessions sessions;

  setUp(() {
    events = _Events();
    shares = _Shares();
    sessions = AudienceTestSessions(audienceSession(user: 'owner'));
  });

  tearDown(() async {
    events.signal.dispose();
    shares.signal.dispose();
    sessions.dispose();
    await serviceLocator.reset();
  });

  Future<void> mount(
    WidgetTester tester, {
    bool owner = false,
    bool visible = true,
    ValueNotifier<int>? refresh,
    Future<void> Function(VenueEventDetail)? openEvent,
    Future<void> Function(String)? openSource,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenerProfileTheme(
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ListenerProfilePostsSection(
                listenerProfileId: 'profile',
                username: 'owner',
                ownerUserId: owner ? 'owner' : null,
                profileContentVisible: visible,
                eventsRepository: events,
                overthinkingRepository: shares,
                sessions: sessions,
                refreshSignal: refresh,
                onOpenEvent: openEvent,
                onOpenSource: openSource,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<String> visibleOrder(WidgetTester tester) => tester
      .widgetList<Widget>(
        find.byWidgetPredicate(
          (widget) =>
              widget is ListenerEventPostCard ||
              widget is ListenerOverthinkingShareCard,
        ),
      )
      .map(
        (widget) => switch (widget) {
          ListenerEventPostCard() => widget.event.id,
          ListenerOverthinkingShareCard() => widget.share!.shareId,
          _ => throw StateError('Unexpected card'),
        },
      )
      .toList();

  Future<void> next(WidgetTester tester) async {
    final more = find.byKey(const Key('listener-profile-posts-more'));
    expect(more, findsOneWidget);
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'actual event and Overthinking cards share one publication-time order',
    (tester) async {
      events.items = [_event('event-new', 8), _event('event-old', 3)];
      shares.items = [_share('share-newest', 10), _share('share-middle', 5)];
      await mount(tester);
      await tester.pumpAndSettle();
      expect(visibleOrder(tester), [
        'share-newest',
        'event-new',
        'share-middle',
        'event-old',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a newer event precedes an older Overthinking publication', (
    tester,
  ) async {
    events.items = [_event('event-newest', 12)];
    shares.items = [_share('share-older', 9)];
    await mount(tester);
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), ['event-newest', 'share-older']);
  });

  testWidgets('new publication moves above both types on profile refresh', (
    tester,
  ) async {
    final refresh = ValueNotifier(0);
    addTearDown(refresh.dispose);
    events.items = [_event('event', 8)];
    shares.items = [_share('share-old', 3)];
    await mount(tester, refresh: refresh);
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), ['event', 'share-old']);
    shares.items = [_share('share-new', 11), ...shares.items];
    refresh.value++;
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), ['share-new', 'event', 'share-old']);
  });

  testWidgets('repository publication signals rebuild the mixed timeline', (
    tester,
  ) async {
    events.items = [_event('event', 5)];
    shares.items = [_share('share', 6)];
    await mount(tester);
    await tester.pumpAndSettle();
    events.items = [_event('event-latest', 14), ...events.items];
    events.signal.value++;
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), ['event-latest', 'share', 'event']);
    shares.items = [_share('share-latest', 16), ...shares.items];
    shares.signal.value++;
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), [
      'share-latest',
      'event-latest',
      'share',
      'event',
    ]);
  });

  testWidgets(
    'global pagination exposes a complete newest-first prefix across source boundaries',
    (tester) async {
      events.items = [
        for (var hour = 18; hour >= 2; hour -= 2) _event('event-$hour', hour),
      ];
      shares.items = [
        for (var hour = 17; hour >= 1; hour -= 2) _share('share-$hour', hour),
      ];
      final expected = [
        for (var hour = 18; hour >= 1; hour--)
          hour.isEven ? 'event-$hour' : 'share-$hour',
      ];
      await mount(tester);
      await tester.pumpAndSettle();
      expect(visibleOrder(tester), expected.take(6).toList());
      await next(tester);
      expect(visibleOrder(tester), expected.take(12).toList());
      await next(tester);
      expect(visibleOrder(tester), expected);
      expect(visibleOrder(tester).toSet().length, 18);
      expect(
        find.byKey(const Key('listener-profile-posts-more')),
        findsNothing,
      );
      expect(events.pages, contains(1));
      expect(shares.pages, contains(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ['event', 'Overthinking']) {
    testWidgets('one-kind $kind history still paginates chronologically', (
      tester,
    ) async {
      final ids = [for (var hour = 9; hour > 0; hour--) '$kind-$hour'];
      if (kind == 'event') {
        events.items = [
          for (var hour = 9; hour > 0; hour--) _event('$kind-$hour', hour),
        ];
      } else {
        shares.items = [
          for (var hour = 9; hour > 0; hour--) _share('$kind-$hour', hour),
        ];
      }
      await mount(tester);
      await tester.pumpAndSettle();
      expect(visibleOrder(tester), ids.take(6).toList());
      await next(tester);
      expect(visibleOrder(tester), ids);
      expect(
        find.byKey(const Key('listener-profile-posts-more')),
        findsNothing,
      );
    });
  }

  testWidgets('a failed source cannot present an incomplete sorted prefix', (
    tester,
  ) async {
    events.items = [_event('event-old', 2)];
    shares.items = [_share('share-new', 14)];
    shares.failure = true;
    await mount(tester);
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), isEmpty);
    final retry = find.byKey(const Key('listener-profile-posts-retry'));
    expect(retry, findsOneWidget);
    shares.failure = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), ['share-new', 'event-old']);
  });

  testWidgets('late old-session source cannot overwrite fresh viewer data', (
    tester,
  ) async {
    final pending = Completer<Result<Page<OverthinkingProfileShare>>>();
    shares.pending = pending;
    events.items = [_event('old-event', 2)];
    await mount(tester);
    expect(visibleOrder(tester), isEmpty);
    shares.pending = null;
    shares.items = [_share('new-session-share', 8)];
    events.items = [_event('new-session-event', 10)];
    final nextSession = audienceSession(user: 'visitor', token: 'fresh');
    sessions.replace(nextSession);
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), ['new-session-event', 'new-session-share']);
    pending.complete(
      Result.success(Page(items: [_share('stale-share', 23)], hasNext: false)),
    );
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), ['new-session-event', 'new-session-share']);
    expect(identical(shares.readSessions.last, nextSession), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public cards retain distinct event and original-post routes', (
    tester,
  ) async {
    final opened = <String>[];
    events.items = [_event('event', 8)];
    shares.items = [_share('publication', 10)];
    await mount(
      tester,
      openEvent: (event) async => opened.add(event.id),
      openSource: (postId) async => opened.add(postId),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Paylaşım seçenekleri'), findsNothing);
    final source = find.byKey(
      const Key('listener-overthinking-open-publication'),
    );
    await tester.ensureVisible(source);
    await tester.pumpAndSettle();
    await tester.tap(source);
    await tester.pumpAndSettle();
    final event = find.byKey(const Key('listener-event-open-event'));
    await tester.ensureVisible(event);
    await tester.pumpAndSettle();
    await tester.tap(event);
    await tester.pumpAndSettle();
    expect(opened, ['source-publication', 'event']);
  });

  for (final kind in ['event', 'Overthinking']) {
    testWidgets('owner $kind removal deletes only that exact publication', (
      tester,
    ) async {
      events.items = [_event('event', 8)];
      shares.items = [_share('publication', 10)];
      await mount(tester, owner: true);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Paylaşım seçenekleri'), findsNWidgets(2));
      final menu = find.byKey(
        Key(
          kind == 'event'
              ? 'listener-event-menu-event'
              : 'listener-overthinking-remove-publication',
        ),
      );
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paylaşımı sil'));
      await tester.pumpAndSettle();
      expect(events.deleted, isEmpty);
      expect(shares.deleted, isEmpty);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(visibleOrder(tester), ['publication', 'event']);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paylaşımı sil'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          Key(
            kind == 'event'
                ? 'listener-event-post-delete-confirm'
                : 'listener-overthinking-remove-confirm',
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (kind == 'event') {
        expect(events.deleted, [('event-publication-event', 'owner')]);
        expect(shares.deleted, isEmpty);
        expect(visibleOrder(tester), ['publication']);
      } else {
        expect(shares.deleted, ['publication']);
        expect(events.deleted, isEmpty);
        expect(visibleOrder(tester), ['event']);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('hidden profile content makes neither source request', (
    tester,
  ) async {
    events.items = [_event('event', 8)];
    shares.items = [_share('publication', 10)];
    await mount(tester, visible: false);
    await tester.pumpAndSettle();
    expect(visibleOrder(tester), isEmpty);
    expect(events.pages, isEmpty);
    expect(shares.pages, isEmpty);
  });
}

EventAudiencePost _event(String id, int hour) => EventAudiencePost(
  eventId: id,
  postId: 'event-publication-$id',
  intent: EventAudienceStatus.going,
  note: 'Etkinlik paylaşım notu',
  publishedAt: DateTime.utc(2026, 9, 10, hour),
  eventEnded: false,
  event: VenueEventDetail(
    id: id,
    shareUrl: null,
    posterImage: null,
    performerName: 'Sanatçı',
    musicianProfileId: null,
    title: id,
    // The event's own scheduled time must never determine share ordering.
    eventDate: DateTime.utc(2028, 1, 1, 23 - hour),
    venueName: 'Sahne',
  ),
);

OverthinkingProfileShare _share(String id, int hour) =>
    OverthinkingProfileShare(
      shareId: id,
      note: 'Overthinking paylaşım notu',
      publishedAt: DateTime.utc(2026, 9, 10, hour),
      post: OverthinkingPostModel.fromJson({
        'id': 'source-$id',
        'title': id,
        'content': 'Bu hissi anlatmak için birkaç satır yazmak istedim.',
        'anonymous': true,
        'visibilityType': 'ANONYMOUS',
        'canViewAuthor': false,
        // Re-sharing an old source must use the new publication timestamp.
        'createdAt': DateTime.utc(2025, 1, 1, 23 - hour).toIso8601String(),
        'likeCount': 2,
        'commentCount': 1,
      }),
    );

class _Events extends Fake implements EventAudienceRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  List<EventAudiencePost> items = [];
  final pages = <int>[];
  final deleted = <(String, String)>[];

  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    final selected = items.skip(page * size).take(size).toList();
    return Result.success(
      EventAudiencePage(
        items: selected,
        page: page,
        size: size,
        totalElements: items.length,
        totalPages: (items.length / size).ceil(),
        hasNext: (page + 1) * size < items.length,
      ),
    );
  }

  @override
  Future<Result<EventAudienceState>> getIntent({
    required String eventId,
    required String expectedSessionKey,
  }) async => Result.success(audienceState(eventId: eventId));

  @override
  Future<Result<EventAudienceState>> deletePost({
    required String postId,
    required String expectedSessionKey,
  }) async {
    deleted.add((postId, expectedSessionKey));
    items = items.where((item) => item.postId != postId).toList();
    signal.value++;
    return Result.success(audienceState());
  }
}

class _Shares extends Fake implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  List<OverthinkingProfileShare> items = [];
  final pages = <int>[];
  final readSessions = <AuthSession>[];
  final deleted = <String>[];
  bool failure = false;
  Completer<Result<Page<OverthinkingProfileShare>>>? pending;

  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    readSessions.add(expectedSession);
    if (pending != null) return pending!.future;
    if (failure) {
      return const Result.failure(
        AppError(code: 'NETWORK', message: 'Paylaşımlar yüklenemedi.'),
      );
    }
    return Result.success(
      Page(
        items: items.skip(page * size).take(size).toList(),
        hasNext: (page + 1) * size < items.length,
        totalElements: items.length,
      ),
    );
  }

  @override
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  }) async {
    deleted.add(shareId);
    items = items.where((item) => item.shareId != shareId).toList();
    signal.value++;
    return const Result.success(null);
  }
}
