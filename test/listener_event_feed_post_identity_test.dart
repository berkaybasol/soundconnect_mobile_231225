import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_event_feed_controller.dart';

import 'support/event_audience_fakes.dart';

void main() {
  test(
    'public feed preserves publication identity independently from event',
    () async {
      final repository = _Repository();
      final sessions = AudienceTestSessions(audienceSession());
      final controller = _controller(repository, sessions);
      addTearDown(controller.dispose);
      addTearDown(sessions.dispose);
      addTearDown(repository.signal.dispose);
      await controller.reload();
      expect(controller.rows.single.event.id, audienceEventId);
      expect(controller.rows.single.postId, audiencePostId);
    },
  );

  test(
    'republishing the same event replaces the action identity on refresh',
    () async {
      final repository = _Repository();
      final sessions = AudienceTestSessions(audienceSession());
      final controller = _controller(repository, sessions);
      addTearDown(controller.dispose);
      addTearDown(sessions.dispose);
      addTearDown(repository.signal.dispose);
      await controller.reload();
      final oldRow = controller.rows.single;
      const nextPostId = '9a3e023b-2105-4daa-ad04-87a3281c18f0';
      final pending = Completer<Result<EventAudiencePage<EventAudiencePost>>>();
      repository.read = () => pending.future;
      repository.signal.value++;
      expect(controller.rows, isEmpty);
      expect(controller.loading, isTrue);
      pending.complete(Result.success(_page([_post(nextPostId)])));
      await Future<void>.delayed(Duration.zero);
      expect(controller.rows.single.event.id, oldRow.event.id);
      expect(controller.rows.single.postId, nextPostId);
      expect(controller.rows.single.postId, isNot(oldRow.postId));
    },
  );

  test(
    'private plan retains nullable publication identity without inventing one',
    () async {
      final repository = _Repository();
      final sessions = AudienceTestSessions(audienceSession());
      final controller = _controller(repository, sessions, privatePlans: true);
      addTearDown(controller.dispose);
      addTearDown(sessions.dispose);
      addTearDown(repository.signal.dispose);
      await controller.reload();
      expect(controller.rows.single.postId, isNull);
      expect(controller.rows.single.intent, EventAudienceStatus.going);
      repository.published = true;
      await controller.reload();
      expect(controller.rows.single.postId, audiencePostId);
      expect(controller.rows.single.privateState!.postId, audiencePostId);
    },
  );

  test(
    'old publication cannot return after new-account page completes',
    () async {
      final repository = _Repository();
      final sessions = AudienceTestSessions(audienceSession());
      final controller = _controller(repository, sessions);
      addTearDown(controller.dispose);
      addTearDown(sessions.dispose);
      addTearDown(repository.signal.dispose);
      final first = Completer<Result<EventAudiencePage<EventAudiencePost>>>();
      repository.read = () => first.future;
      final loading = controller.reload();
      repository.read = () async => Result.success(_page([]));
      sessions.replace(audienceSession(user: 'another-viewer'));
      await Future<void>.delayed(Duration.zero);
      first.complete(Result.success(_page([_post(audiencePostId)])));
      await loading;
      expect(controller.rows, isEmpty);
      expect(controller.loading, isFalse);
    },
  );
}

ListenerEventFeedController _controller(
  _Repository repository,
  AudienceTestSessions sessions, {
  bool privatePlans = false,
}) => ListenerEventFeedController(
  repository: repository,
  sessions: sessions,
  listenerProfileId: 'profile',
  privatePlans: privatePlans,
);

EventAudiencePost _post(String postId) => EventAudiencePost(
  eventId: audienceEventId,
  postId: postId,
  intent: EventAudienceStatus.going,
  note: 'Görüşürüz',
  publishedAt: DateTime.utc(2026, 9, 9),
  eventEnded: false,
  event: audienceState().event!,
);

EventAudiencePage<T> _page<T>(List<T> items) => EventAudiencePage(
  items: items,
  page: 0,
  size: 20,
  totalElements: items.length,
  totalPages: items.isEmpty ? 0 : 1,
  hasNext: false,
);

class _Repository extends Fake implements EventAudienceRepository {
  final signal = ValueNotifier(0);
  bool published = false;
  Future<Result<EventAudiencePage<EventAudiencePost>>> Function()? read;

  @override
  ValueListenable<int> get changes => signal;

  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) =>
      read?.call() ??
      Future.value(Result.success(_page([_post(audiencePostId)])));

  @override
  Future<Result<EventAudiencePage<EventAudienceState>>> listMine({
    required String expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.upcoming,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    _page([
      audienceState(intent: EventAudienceStatus.going, published: published),
    ]),
  );
}
