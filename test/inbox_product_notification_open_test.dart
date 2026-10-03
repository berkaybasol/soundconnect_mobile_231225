import 'dart:async';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_commands.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_page.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_actor.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_application.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_job.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_listing.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_review.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_actor_reviews_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_discovery_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_incoming_applications_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_jobs_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_my_applications_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_actor_reviews_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_incoming_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_listing_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_my_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/instrument_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/entities/instrument.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/inbox_product_notification_open.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_reveal_request.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_incoming_unread_status.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_manage_screen.dart';
import 'support/recording_api_client.dart';
import 'support/event_audience_fakes.dart';
import 'support/collab_test_support.dart';

const user = '70000000-0000-4000-8000-000000000001';
const notice = '50000000-0000-4000-8000-000000000001';
const listingId = '30000000-0000-4000-8000-000000000001';
const requestId = '40000000-0000-4000-8000-000000000001';
const jobId = '20000000-0000-4000-8000-000000000001';
const reviewId = '10000000-0000-4000-8000-000000000001';
const failure = AppError(code: 'OFFLINE', message: 'Private diagnostic');
AppNotification row(String type) => AppNotification(
  id: notice,
  recipientId: user,
  type: type,
  title: 'Exact',
  message: '',
  read: false,
  createdAt: null,
  payload: {
    'module': type.startsWith('COLLAB') ? 'COLLAB' : 'OVERTHINKING',
    'action': type.substring(type.startsWith('COLLAB') ? 7 : 13),
    if (type.startsWith('COLLAB')) 'listingId': listingId,
    if (type.contains('APPLICATION_')) 'applicationId': requestId,
    if (type.contains('JOB_') || type.contains('REVIEW_') || type == 'COLLAB_APPLICATION_ACCEPTED') 'jobId': jobId,
    if (type.contains('REVIEW_')) 'reviewId': reviewId,
    if (type.contains('REPORT_')) ...{
      'reportId': requestId,
      'decision': 'REMOVE_LISTING',
    },
    if (type.startsWith('OVERTHINKING')) ...{
      'postId': listingId,
      'revealRequestId': requestId,
      'requestStatus': type.endsWith('RECEIVED') ? 'PENDING' : type.endsWith('APPROVED') ? 'APPROVED' : 'REJECTED',
      'sourceEventId': '60000000-0000-4000-8000-000000000001',
      'identityVersion': 1,
    },
  },
);
Map<String, dynamic> wire(AppNotification n) => {
  'id': n.id,
  'recipientId': n.recipientId,
  'type': n.type,
  'read': n.read,
  'payload': n.payload,
};
void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());
  for (final replacement in [false, true]) {
    testWidgets('R28 controller close replacement=$replacement keeps explicit ACK recovery', (t) async {
      final h = _Harness(row('COLLAB_APPLICATION_WITHDRAWN'))..native = true..ackFailures = 2;
      await h.mount(t); await t.pumpAndSettle();
      final marker = find.byWidgetPredicate((w) => w is NotificationTargetReady && w.ready).first;
      final messenger = ScaffoldMessenger.of(t.element(marker));
      expect(find.text('Tekrar dene'), findsOneWidget);
      messenger.removeCurrentSnackBar();
      if (replacement) {
        messenger.showSnackBar(const SnackBar(content: Text('Other product feedback'), duration: Duration(milliseconds: 500)));
      }
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 1)); await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 20)); await t.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(h.acks, [notice]); expect(h.notices.state.unreadCount, 2);
      final domainCalls = h.domain.calls;
      await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
      expect(h.acks, [notice, notice]);
      expect(find.text('Tekrar dene'), findsOneWidget);
      await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
      expect(h.acks, [notice, notice, notice]);
      expect(h.notices.state.unreadCount, 1);
      expect(h.notices.state.items.where((n) => n.id != notice).every((n) => !n.read), isTrue);
      expect(h.domain.calls, domainCalls);
      expect(h.api.requests.where((r) => !r.path.endsWith('/read')).length, 1);
      expect(find.text('Tekrar dene'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink()); await h.dispose();
    });
  }
  for (final type in ['COLLAB_APPLICATION_WITHDRAWN', 'COLLAB_APPLICATION_REJECTED', 'COLLAB_APPLICATION_ACCEPTED', 'COLLAB_REVIEW_RECEIVED']) {
    testWidgets('R28 $type real cached row outside viewport suspends explicit retry', (t) async {
      final h = _Harness(row(type))..native = true..ackFailures = 1;
      h.domain.listCount = 20;
      await h.mount(t); await t.pumpAndSettle();
      final marker = find.byWidgetPredicate((w) => w is NotificationTargetReady && w.ready, skipOffstage: false).first;
      final element = t.element(marker);
      final scroll = Scrollable.of(element).position;
      final original = scroll.pixels;
      final viewportTop = t.getRect(find.byType(CustomScrollView)).top;
      final offset = t.getRect(marker).bottom - viewportTop + 80;
      final staleAction = t.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
      final domainCalls = h.domain.calls;
      scroll.jumpTo(original + offset);
      await t.pumpAndSettle();
      expect(element.mounted, isTrue, reason: 'negative case must retain the cached exact row');
      expect(t.getRect(marker).bottom, lessThan(viewportTop));
      expect(find.text('Tekrar dene'), findsNothing);
      staleAction(); await t.pumpAndSettle();
      expect(h.acks, [notice]); expect(h.notices.state.unreadCount, 2);
      scroll.jumpTo(original); await t.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(h.acks, [notice]); expect(h.domain.calls, domainCalls);
      await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
      expect(h.acks, [notice, notice]); expect(h.notices.state.unreadCount, 1);
      expect(h.domain.calls, domainCalls);
      expect(h.api.requests.where((r) => !r.path.endsWith('/read')).length, 1);
      await t.pumpWidget(const SizedBox.shrink()); await h.dispose();
    });
  }
  testWidgets('R28 long exact application can be visibly read after target scroll', (t) async {
    final h = _Harness(row('COLLAB_APPLICATION_WITHDRAWN'))..native = true..ackFailures = 1;
    h.domain..listCount = 8..targetIndex = 4..longApplication = true;
    await h.mount(t); await t.pumpAndSettle();
    final marker = find.byWidgetPredicate((w) => w is NotificationTargetReady && w.ready).first;
    expect(t.getSize(marker).height, greaterThan(t.getSize(find.byType(CustomScrollView)).height));
    expect(h.acks, [notice]);
    expect(find.text('Tekrar dene'), findsOneWidget);
    await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
    expect(h.acks, [notice, notice]);
    await t.pumpWidget(const SizedBox.shrink()); await h.dispose();
  });
  testWidgets('R28 same route messenger replacement and rebuild keep one retry', (t) async {
    final h = _Harness(row('COLLAB_APPLICATION_WITHDRAWN'))..ackFailures = 1;
    await h.mount(t); await t.pumpAndSettle();
    final domainCalls = h.domain.calls;
    h.messenger.value = GlobalKey<ScaffoldMessengerState>();
    await t.pumpAndSettle();
    t.element(find.byType(CollabIncomingApplicationsScreen)).markNeedsBuild();
    await t.pumpAndSettle(); await t.pump(const Duration(seconds: 20));
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(h.acks, [notice]); expect(h.domain.calls, domainCalls);
    await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
    expect(h.acks, [notice, notice]); expect(h.notices.state.unreadCount, 1);
    expect(h.api.requests.where((r) => !r.path.endsWith('/read')).length, 1);
  });
  for (final hidden in ['background', 'covered', 'session', 'disposed', 'scroll', 'scroll-return-same-frame']) {
    testWidgets('R28 ACK single flight late success after $hidden cannot project', (t) async {
      final h = _Harness(row('COLLAB_APPLICATION_WITHDRAWN'))..native = true..ackFailures = 1;
      h.domain.listCount = 20;
      await h.mount(t); await t.pumpAndSettle();
      final domainCalls = h.domain.calls;
      final action = t.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
      final marker = find.byWidgetPredicate((w) => w is NotificationTargetReady && w.ready, skipOffstage: false).first;
      final scroll = Scrollable.of(t.element(marker)).position;
      final original = scroll.pixels;
      final offset = t.getRect(marker).bottom - t.getRect(find.byType(CustomScrollView)).top + 80;
      h.ackPending = Completer<void>();
      action(); action(); await t.pumpAndSettle();
      expect(h.acks, [notice, notice]);
      if (hidden == 'background') t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      if (hidden == 'covered') unawaited(h.navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Cover')))));
      if (hidden == 'session') h.sessions.replace(audienceSession(user: '70000000-0000-4000-8000-000000000002', role: 'ROLE_MUSICIAN'));
      if (hidden == 'disposed') await t.pumpWidget(const SizedBox.shrink());
      if (hidden.startsWith('scroll')) {
        scroll.jumpTo(original + offset);
        if (hidden.endsWith('same-frame')) scroll.jumpTo(original);
      }
      h.ackPending!.complete(); await t.pumpAndSettle();
      expect(h.notices.state.items.every((n) => !n.read), isTrue);
      expect(h.notices.state.unreadCount, 2);
      action(); await t.pumpAndSettle(); expect(h.acks, [notice, notice]);
      if (hidden == 'session' || hidden == 'disposed') {
        expect(find.text('Tekrar dene'), findsNothing);
      } else {
        if (hidden == 'background') t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        if (hidden == 'covered') h.navigator.currentState!.pop();
        if (hidden == 'scroll') scroll.jumpTo(original);
        await t.pumpAndSettle();
        expect(find.text('Tekrar dene'), findsOneWidget);
        expect(h.acks, [notice, notice]);
        h.ackPending = null;
        await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
        expect(h.acks, [notice, notice, notice]); expect(h.notices.state.unreadCount, 1);
        expect(h.notices.state.items.singleWhere((n) => n.id != notice).read, isFalse);
      }
      expect(h.domain.calls, domainCalls);
      expect(h.api.requests.where((r) => !r.path.endsWith('/read')).length, 1);
    });
  }
  testWidgets('R28 retired queued retry does not close replacement product feedback', (t) async {
    final h = _Harness(row('COLLAB_APPLICATION_WITHDRAWN'))..native = true..ackFailures = 1;
    await h.mount(t); await t.pumpAndSettle();
    final messenger = h.messenger.value.currentState!;
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Product feedback'), persist: true));
    await t.pumpAndSettle(); // retry is now queued behind unrelated feedback
    unawaited(h.navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Cover')))));
    await t.pumpAndSettle();
    expect(find.text('Product feedback'), findsOneWidget);
    messenger.removeCurrentSnackBar(); await t.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsNothing);
    h.navigator.currentState!.pop(); await t.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
    expect(h.acks, [notice, notice]);
  });
  testWidgets('real Collab product opens while exact ACK remains pending', (
    t,
  ) async {
    final h = _Harness(row('COLLAB_APPLICATION_RECEIVED'));
    h.ackPending = Completer<void>();
    await h.mount(t);
    await t.pumpAndSettle();
    expect(find.byType(CollabIncomingApplicationsScreen), findsOneWidget);
    expect(h.acks, [notice]);
    expect(h.notices.state.items.where((n) => n.read), isEmpty);
    expect(h.notices.state.unreadCount, 2);
    h.ackPending!.complete();
    await t.pumpAndSettle();
    expect(
      h.notices.state.items.singleWhere((n) => n.id == notice).read,
      isTrue,
    );
    expect(
      h.notices.state.items.singleWhere((n) => n.id != notice).read,
      isFalse,
    );
    expect(h.notices.state.unreadCount, 1);
    h.navigator.currentState!.pop();
    await t.pumpAndSettle();
    expect(find.text('Original product'), findsOneWidget);
    expect(h.acks, [notice]);
    await t.pumpWidget(const SizedBox.shrink());
    await h.dispose();
  });
  for (final type in NotificationTargetRepository.inboxProductTypes) {
    test(
      '$type fresh exact owned lookup and scoped ACK use captured token',
      () async {
        final sessions = AudienceTestSessions(
          audienceSession(user: user, role: 'ROLE_MUSICIAN'),
        );
        final n = row(type);
        final api = RecordingApiClient(
          (r) => r.path.endsWith('/read') ? null : wire(n),
        );
        final repo = NotificationTargetRepository(api, sessions);
        final resolved = await repo.resolveInboxProduct(n, sessions.session);
        expect(resolved.data?.type, type);
        expect(
          api.requests.single.requestContext?.expectedToken,
          sessions.session.token,
        );
        expect(
          (await repo.acknowledge(resolved.data!, sessions.session)).isSuccess,
          isTrue,
        );
        expect(
          api.requests.last.path,
          '/api/v1/user/notifications/$notice/read',
        );
        sessions.dispose();
      },
    );
    testWidgets(
      '$type generic lookup failure stays on product with retry and no read',
      (t) async {
        final h = _Harness(row(type))..offline = true;
        await h.mount(t);
        await t.pumpAndSettle();
        expect(find.text('Original product'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Tekrar dene'), findsOneWidget);
        expect(find.text('Private diagnostic'), findsNothing);
        expect(h.acks, isEmpty);
        expect(h.observer.pushes, 1);
        await t.pumpWidget(const SizedBox.shrink());
        await h.dispose();
      },
    );
  }
  for (final type in NotificationTargetRepository.inboxProductTypes.where(
    (t) => t.startsWith('COLLAB_'),
  )) {
    testWidgets(
      '$type opens exact real product without discovery or jobs detour',
      (t) async {
        final h = _Harness(row(type));
        await h.mount(t);
        await t.pumpAndSettle();
        final Type expected = type == 'COLLAB_REPORT_RESOLVED'
            ? CollabDiscoveryScreen
            : type == 'COLLAB_REVIEW_RECEIVED'
            ? CollabActorReviewsScreen
            : type == 'COLLAB_APPLICATION_RECEIVED' ||
                  type == 'COLLAB_APPLICATION_WITHDRAWN'
            ? CollabIncomingApplicationsScreen
            : type.startsWith('COLLAB_LISTING_')
            ? CollabListingDetailScreen
            : CollabMyApplicationsScreen;
        expect(find.byType(expected), findsOneWidget);
        expect(h.observer.pushes, 2);
        if (expected != CollabDiscoveryScreen) {
          expect(
            find.byType(CollabDiscoveryScreen, skipOffstage: false),
            findsNothing,
          );
        }
        if (expected == CollabActorReviewsScreen) {
          expect(
            find.byType(CollabMyApplicationsScreen, skipOffstage: false),
            findsNothing,
          );
          expect(
            t
                .widget<CollabActorReviewsScreen>(find.byType(expected))
                .initialReviewId,
            reviewId,
          );
        }
        expect(h.acks, [notice]);
        expect(h.notices.state.unreadCount, 1);
        h.navigator.currentState!.pop();
        await t.pumpAndSettle();
        expect(find.text('Original product'), findsOneWidget);
        expect(find.text('Bildirim'), findsNothing);
        await t.pumpWidget(const SizedBox.shrink());
        await h.dispose();
      },
    );
  }
  for (final type in PushTarget.collabTypes) {
    testWidgets('$type native identity only resolves exact product and one Back', (t) async {
      final h = _Harness(row(type))..native = true;
      await h.mount(t);
      await t.pumpAndSettle();
      expect(h.api.requests.first.path, '/api/v1/user/notifications/$notice/collab-target');
      expect(h.acks, [notice]);
      expect(h.notices.state.unreadCount, 1);
      if (type == 'COLLAB_APPLICATION_ACCEPTED') {
        final page = t.widget<CollabMyApplicationsScreen>(find.byType(CollabMyApplicationsScreen));
        expect(page.initialSection, CollabApplicationsSection.jobs);
        expect(page.initialJobId, jobId);
      }
      if (type == 'COLLAB_REVIEW_RECEIVED') {
        final page = t.widget<CollabActorReviewsScreen>(find.byType(CollabActorReviewsScreen));
        expect(page.actor.actorId, venueActor.actorId);
        expect(page.initialReviewId, reviewId);
      }
      h.navigator.currentState!.pop();
      await t.pumpAndSettle();
      expect(find.text('Original product'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink()); await h.dispose();
    });
  }
  testWidgets('native and inbox same selection share pending future and lookup', (t) async {
    final h = _Harness(row('COLLAB_APPLICATION_RECEIVED'))..native = true;
    h.lookupPending = Completer<void>();
    await h.mount(t); await t.pump();
    final first = h.openFuture;
    h.native = false;
    final second = h.open();
    expect(identical(first, second), isTrue);
    expect(h.api.requests.length, 1);
    h.lookupPending!.complete(); await t.pumpAndSettle();
    expect(h.acks, [notice]); expect(h.observer.pushes, 2);
    await t.pumpWidget(const SizedBox.shrink()); await h.dispose();
  });
  testWidgets('native DISMISS paints exact report message before ACK', (t) async {
    final source = row('COLLAB_REPORT_RESOLVED');
    final selected = AppNotification(id: source.id, recipientId: source.recipientId,
      type: source.type, title: '', message: '', read: false, createdAt: null,
      payload: {...source.payload, 'decision': 'DISMISS'});
    final h = _Harness(selected)..native = true;
    await h.mount(t); await t.pumpAndSettle();
    expect(find.byType(CollabDiscoveryScreen), findsOneWidget);
    expect(find.text('Bildirimin incelendi.'), findsOneWidget);
    expect(find.text('Bildirdiğin ilan kaldırıldı.'), findsNothing);
    expect(h.acks, [notice]);
    await t.pumpWidget(const SizedBox.shrink()); await h.dispose();
  });
  testWidgets('native target error retries fresh only on explicit action', (t) async {
    final h = _Harness(row('COLLAB_APPLICATION_ACCEPTED'))..native = true..offline = true;
    await h.mount(t); await t.pumpAndSettle();
    expect(h.acks, isEmpty); expect(h.api.requests.length, 1);
    h.offline = false;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle(); expect(h.api.requests.length, 1);
    await t.pump(const Duration(seconds: 20));
    await t.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
    expect(h.api.requests.where((r) => !r.path.endsWith('/read')).length, 2);
    expect(h.acks, [notice]);
    await t.pumpWidget(const SizedBox.shrink()); await h.dispose();
  });
  testWidgets('native visible ACK failure retry does not repeat target or domain GET', (t) async {
    final h = _Harness(row('COLLAB_APPLICATION_RECEIVED'))..native = true..ackFailures = 1;
    await h.mount(t); await t.pumpAndSettle();
    expect(h.acks, [notice]); expect(h.notices.state.unreadCount, 2);
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();
    expect(find.text('Okundu bilgisi kaydedilemedi.'), findsOneWidget);
    final calls = h.domain.calls;
    await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
    expect(h.domain.calls, calls);
    expect(h.api.requests.where((r) => !r.path.endsWith('/read')).length, 1);
    expect(h.acks, [notice, notice]); expect(h.notices.state.unreadCount, 1);
    await t.pumpWidget(const SizedBox.shrink()); await h.dispose();
  });
  for (final hidden in ['background', 'covered', 'session', 'disposed']) {
    testWidgets('native result completed while $hidden cannot navigate or read', (t) async {
      final h = _Harness(row('COLLAB_APPLICATION_RECEIVED'))..native = true;
      h.lookupPending = Completer<void>();
      await h.mount(t); await t.pump();
      if (hidden == 'background') t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      if (hidden == 'covered') unawaited(h.navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Cover')))));
      if (hidden == 'session') h.sessions.replace(audienceSession(user: '70000000-0000-4000-8000-000000000002', role: 'ROLE_MUSICIAN'));
      if (hidden == 'disposed') await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      h.lookupPending!.complete(); await t.pumpAndSettle();
      expect(h.acks, isEmpty); expect(h.domain.calls, 0);
      if (hidden == 'background' || hidden == 'covered') {
        if (hidden == 'background') t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        if (hidden == 'covered') h.navigator.currentState!.pop();
        await t.pumpAndSettle();
        expect(h.api.requests.length, 1); expect(h.acks, isEmpty);
        await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
        expect(h.acks, [notice]);
        expect(h.api.requests.where((r) => !r.path.endsWith('/read')).length, 2);
      }
      await t.pumpWidget(const SizedBox.shrink()); await h.dispose();
    });
  }
  for (final type in [
    'OVERTHINKING_REVEAL_REQUEST_RECEIVED',
    'OVERTHINKING_REVEAL_REQUEST_REJECTED',
  ]) {
    for (final native in [false, true]) {
      testWidgets('$type native=$native explicit ACK remains after controller close and does no GET/write', (t) async {
        final h = _Harness(row(type))..native = native..ackFailures = 1;
        await h.mount(t); await t.pumpAndSettle();
        expect(h.acks, [notice]);
        final marker = find.byWidgetPredicate((w) => w is NotificationTargetReady && w.ready).first;
        ScaffoldMessenger.of(t.element(marker)).removeCurrentSnackBar();
        await t.pumpAndSettle(); await t.pump(const Duration(seconds: 20)); await t.pumpAndSettle();
        expect(find.text('Tekrar dene'), findsOneWidget);
        final calls = h.posts.calls, seen = h.posts.seenWrites;
        await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
        expect(h.acks, [notice, notice]);expect(h.posts.calls, calls);expect(h.posts.seenWrites, seen);
        expect(h.api.requests.where((r) => !r.path.endsWith('/read')).single.path, endsWith('/overthinking-target'));
        expect(h.notices.state.unreadCount, 1);
        expect(h.notices.state.items.where((n) => n.id != notice).every((n) => !n.read), isTrue);
        h.navigator.currentState!.pop(); await t.pumpAndSettle();
        expect(find.text('Original product'), findsOneWidget);
      });
    }
    for (final hidden in ['background', 'covered', 'session', 'disposed']) {
      testWidgets('$type late target while $hidden has no navigation or ACK', (t) async {
        final h=_Harness(row(type))..native=true..lookupPending=Completer<void>();
        await h.mount(t);await t.pump();
        if(hidden=='background')t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        if(hidden=='covered')unawaited(h.navigator.currentState!.push(MaterialPageRoute<void>(builder:(_)=>const Scaffold(body:Text('Cover')))));
        if(hidden=='session')h.sessions.replace(audienceSession(user:'70000000-0000-4000-8000-000000000002',role:'ROLE_MUSICIAN'));
        if(hidden=='disposed')await t.pumpWidget(const SizedBox.shrink());
        await t.pump();h.lookupPending!.complete();await t.pumpAndSettle();
        expect(h.acks,isEmpty);expect(h.posts.calls,0);
        if(hidden=='background'||hidden=='covered'){
          if(hidden=='background')t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          if(hidden=='covered')h.navigator.currentState!.pop();
          await t.pumpAndSettle();expect(h.acks,isEmpty);expect(h.api.requests.length,1);
          await t.tap(find.text('Tekrar dene'));await t.pumpAndSettle();expect(h.acks,[notice]);
        }
      });
    }
    testWidgets('$type ACK retry shares one pending request and late covered success cannot update badge', (t) async {
      final h=_Harness(row(type))..native=true..ackFailures=1;
      await h.mount(t);await t.pumpAndSettle();
      h.ackPending=Completer<void>();
      final retry=t.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
      final calls=h.posts.calls;
      retry();retry();await t.pump();expect(h.acks,[notice,notice]);
      unawaited(h.navigator.currentState!.push(MaterialPageRoute<void>(builder:(_)=>const Scaffold(body:Text('Cover')))));
      await t.pumpAndSettle();h.ackPending!.complete();await t.pumpAndSettle();
      expect(h.notices.state.unreadCount,2);expect(h.posts.calls,calls);
      h.navigator.currentState!.pop();await t.pumpAndSettle();expect(h.acks,[notice,notice]);
    });
    testWidgets('$type long exact row can ACK while partly visible', (t) async {
      final h=_Harness(row(type))..native=true;
      h.posts.longTitle=true;
      await h.mount(t);t.view.physicalSize=const Size(600,600);await t.pumpAndSettle();
      final marker=find.byWidgetPredicate((w)=>w is NotificationTargetReady&&w.ready).first;
      expect(t.getSize(marker).height,greaterThan(Scrollable.of(t.element(marker)).position.viewportDimension));
      expect(h.acks,[notice]);
    });
    testWidgets('$type target failure has explicit target retry before exact row/ACK', (t) async {
      final h = _Harness(row(type))..native = true..offline = true;
      await h.mount(t);await t.pumpAndSettle();
      expect(h.acks,isEmpty);expect(h.posts.calls,0);expect(h.observer.pushes,1);
      h.offline=false;await t.tap(find.text('Tekrar dene'));await t.pumpAndSettle();
      expect(h.acks,[notice]);expect(h.api.requests.where((r)=>!r.path.endsWith('/read')).length,2);
    });
    testWidgets('$type cover pop animation cannot expose or invoke ACK retry early', (t) async {
      final h = _Harness(row(type))..native = true..ackFailures = 1;
      await h.mount(t); await t.pumpAndSettle();
      final stale = t.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
      unawaited(h.navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other product')),
      )));
      await t.pumpAndSettle();
      h.navigator.currentState!.pop();
      await t.pump(); await t.pump(const Duration(milliseconds: 50));
      final retry = find.byType(SnackBarAction);
      expect(retry, findsNothing, reason: 'cover still paints during its reverse transition');
      stale(); await t.pump(); expect(h.acks, [notice]);
      await t.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
      expect(h.acks, [notice, notice]);
    });
    testWidgets('$type returning from another product keeps its own ACK retry', (t) async {
      final h = _Harness(row(type))..native = true..ackFailures = 1;
      await h.mount(t); await t.pumpAndSettle();
      final calls = h.posts.calls;
      unawaited(h.navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other product')),
      )));
      await t.pumpAndSettle();
      h.messenger.value.currentState!.showSnackBar(const SnackBar(
        content: Text('Other product feedback'), persist: true,
      ));
      await t.pumpAndSettle();
      h.navigator.currentState!.pop(); await t.pumpAndSettle();
      expect(find.text('Other product feedback'), findsNothing);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(h.acks, [notice]);
      await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
      expect(h.acks, [notice, notice]); expect(h.posts.calls, calls);
    });
    testWidgets('$type physical-size drag restores failed ACK retry', (t) async {
      final h = _Harness(row(type))..native = true..ackFailures = 1;
      h.posts.listCount = 3;
      await h.mount(t);
      t.view.physicalSize = const Size(384, 860);
      await t.pumpAndSettle();
      expect(h.acks, [notice]);
      final target = find.byWidgetPredicate((w) => w is NotificationTargetReady && w.ready).first;
      final scroll = Scrollable.of(t.element(target)).position;
      final origin = scroll.pixels;
      final calls = h.posts.calls;
      await t.timedDragFrom(const Offset(180, 600), const Offset(0, -270), const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      await t.timedDragFrom(const Offset(180, 600), const Offset(0, -270), const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsNothing);
      await t.timedDragFrom(const Offset(180, 350), const Offset(0, 270), const Duration(milliseconds: 700));
      await t.pumpAndSettle();
      await t.timedDragFrom(const Offset(180, 350), const Offset(0, 270), const Duration(milliseconds: 700));
      await t.pumpAndSettle();
      expect(scroll.pixels, closeTo(origin, 10));
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(h.acks, [notice]);
      expect(h.posts.calls, calls);
      await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
      expect(h.acks, [notice, notice]);
    });
    testWidgets('$type fully offscreen cached row hides retry and return does not ACK', (t) async {
      final h=_Harness(row(type))..native=true..ackFailures=1;
      h.posts.listCount=25;
      await h.mount(t);await t.pumpAndSettle();
      final marker=find.byWidgetPredicate((w)=>w is NotificationTargetReady && w.ready,skipOffstage:false).first;
      final element=t.element(marker), scroll=Scrollable.of(t.element(marker)).position;
      final origin=scroll.pixels;
      final oldAction=t.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
      final calls=h.posts.calls;
      scroll.jumpTo(origin+t.getSize(marker).height+150);await t.pumpAndSettle();
      expect(find.text('Tekrar dene'),findsNothing);
      oldAction();await t.pumpAndSettle();expect(h.acks,[notice]);
      scroll.jumpTo(origin);await t.pumpAndSettle();
      expect(find.text('Tekrar dene'),findsOneWidget);expect(h.acks,[notice]);expect(h.posts.calls,calls);
      expect(element.mounted,isTrue,reason:'cached row continuity');
      await t.tap(find.text('Tekrar dene'));await t.pumpAndSettle();expect(h.acks,[notice,notice]);
    });
    for(final mismatch in ['post','decision']) {
      testWidgets('$type same request UUID with wrong $mismatch does not ACK', (t) async {
        final h=_Harness(row(type));
        if(mismatch=='post')h.posts.targetPost='30000000-0000-4000-8000-000000000009';
        if(mismatch=='decision')h.posts.status='APPROVED';
        await h.mount(t);await t.pumpAndSettle();
        expect(find.byType(OverthinkingManageScreen),findsOneWidget);expect(h.acks,isEmpty);
      });
    }
    testWidgets('$type exact later page loads without reading siblings', (t) async {
      final h=_Harness(row(type))..native=true;
      h.posts..targetPage=1..listCount=5;
      await h.mount(t);await t.pumpAndSettle();
      expect(h.posts.calls,greaterThan(2));expect(h.acks,[notice]);
      expect(h.notices.state.items.where((n)=>n.id!=notice).every((n)=>!n.read),isTrue);
    });
    for (final exact in [true, false]) {
      testWidgets('$type exact request=$exact controls visible product read', (
        t,
      ) async {
        final h = _Harness(row(type));
        h.posts.exact = exact;
        await h.mount(t);
        await t.pumpAndSettle();
        expect(find.byType(OverthinkingManageScreen), findsOneWidget);
        expect(h.observer.pushes, 2);
        expect(h.acks, exact ? [notice] : isEmpty);
        if (!exact) {
          expect(find.text('Bu istek artık kullanılamıyor.'), findsOneWidget);
        }
        await t.pumpWidget(const SizedBox.shrink());
        await h.dispose();
      });
    }
  }
}

class _Harness {
  _Harness(this.selected) {
    posts.incoming = selected.type.endsWith('RECEIVED');
    posts.status = posts.incoming ? 'PENDING' : 'REJECTED';
    notices = _Notices(selected);
    api = RecordingApiClient((r) async {
      if (r.path.endsWith('/read')) {
        acks.add(notice);
        if (ackPending != null) await ackPending!.future;
        if (ackFailures-- > 0) throw ApiException(failure);
        return null;
      }
      if (lookupPending != null) await lookupPending!.future;
      if (offline) throw ApiException(failure);
      return wire(selected);
    });
    final repo = NotificationTargetRepository(api, sessions);
    serviceLocator
      ..registerSingleton<AuthSessionManager>(sessions)
      ..registerSingleton<NotificationCubit>(notices)
      ..registerSingleton<TokenStore>(tokens)
      ..registerSingleton<DmBadgeCubit>(badge)
      ..registerSingleton<NotificationTargetRepository>(repo)
      ..registerSingleton<CollabRepository>(domain)
      ..registerSingleton<LocationRepository>(_Locations())
      ..registerSingleton<InstrumentRepository>(_Instruments())
      ..registerSingleton<OverthinkingRepository>(posts)
      ..registerFactory<CollabDiscoveryCubit>(
        () => CollabDiscoveryCubit(domain),
      )
      ..registerFactory<CollabListingDetailCubit>(
        () => CollabListingDetailCubit(domain),
      )
      ..registerFactory<CollabIncomingApplicationsCubit>(
        () => CollabIncomingApplicationsCubit(domain),
      )
      ..registerFactory<CollabMyApplicationsCubit>(
        () => CollabMyApplicationsCubit(domain),
      )
      ..registerFactory<CollabJobsCubit>(() => CollabJobsCubit(domain))
      ..registerFactory<CollabActorReviewsCubit>(
        () => CollabActorReviewsCubit(domain),
      );
  }
  final AppNotification selected;
  final sessions = AudienceTestSessions(
    audienceSession(user: user, role: 'ROLE_MUSICIAN'),
  );
  final tokens = _Tokens();
  late final badge = DmBadgeCubit(_Dm(), tokens);
  final domain = _Domain();
  final posts = _Posts();
  final navigator = GlobalKey<NavigatorState>();
  final messenger = ValueNotifier(GlobalKey<ScaffoldMessengerState>());
  final observer = _Observer();
  final acks = <String>[];
  late final _Notices notices;
  late final RecordingApiClient api;
  bool offline = false;
  bool native = false;
  int ackFailures = 0;
  Completer<void>? lookupPending;
  Future<void>? openFuture;
  Completer<void>? ackPending;
  Future<void> mount(WidgetTester t) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      if (!notices.isClosed) await dispose();
    });
    t.view.physicalSize = const Size(600, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: notices,
        child: ValueListenableBuilder<GlobalKey<ScaffoldMessengerState>>(
          valueListenable: messenger,
          builder: (_, messengerKey, _) => MaterialApp(
          scaffoldMessengerKey: messengerKey,
          navigatorKey: navigator,
          navigatorObservers: [observer, notificationTargetRouteObserver],
          home: const Scaffold(body: Text('Original product')),
        ),
        ),
      ),
    );
    openFuture = open();
    unawaited(openFuture);
  }
  Future<void> open() => NotificationDirectOpen.start(
    navigator.currentContext!, identity: notice,
    builder: (_) => native
      ? InboxProductNotificationOpen.native(target: PushTarget(notificationId: notice, recipientId: user, type: selected.type))
      : InboxProductNotificationOpen(notification: selected),
  );

  Future<void> dispose() async {
    messenger.dispose();
    await notices.close();
    await badge.close();
    sessions.dispose();
  }
}

class _Notices extends Cubit<NotificationState> implements NotificationCubit {
  _Notices(this.selected)
    : super(
        const NotificationState.initial().copyWith(
          unreadCount: 2,
          items: [
            selected,
            AppNotification(
              id: '50000000-0000-4000-8000-000000000002',
              recipientId: user,
              type: selected.type,
              title: 'Sibling',
              message: '',
              read: false,
              createdAt: null,
              payload: selected.payload,
            ),
          ],
        ),
      );
  final AppNotification selected;
  @override
  Future<void> applyConfirmedExternalRead(
    AppNotification n,
    dynamic session,
  ) async {
    emit(
      state.copyWith(
        unreadCount: 1,
        items: state.items
            .map((item) => item.id == n.id ? item.copyWith(read: true) : item)
            .toList(),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> r, Route<dynamic>? p) {
    pushes++;
  }
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _Dm extends Fake implements DmRepository {}

CollabPage<T> page<T>(List<T> items) => CollabPage(
  items: items,
  page: 0,
  size: 30,
  totalElements: items.length,
  totalPages: 1,
  first: true,
  last: true,
);

class _Domain extends Fake implements CollabRepository {
  int calls = 0;
  int listCount = 1, targetIndex = 0;
  bool longApplication = false;
  final listing = collabListingFixture(id: listingId, ownedByMe: true);
  CollabApplication applicationAt(int index) => CollabApplication(
    id: index == targetIndex ? requestId : 'application-$index',
    version: 0,
    listing: listing,
    applicant: musicianActor,
    phone: '05551234567',
    message: longApplication ? List.filled(90, 'Long application line').join('\n') : 'Exact application',
    status: CollabApplicationStatus.pending,
    submittedAt: DateTime.utc(2026),
    statusChangedAt: DateTime.utc(2026),
  );
  CollabJob jobAt(int index) => CollabJob(
    id: index == targetIndex ? jobId : 'job-$index',
    version: 0,
    status: CollabJobStatus.completed,
    listing: listing,
    publisher: venueActor,
    applicant: musicianActor,
    publisherConfirmedCompletion: true,
    applicantConfirmedCompletion: true,
    confirmedByMe: true,
    reviewedByMe: true,
  );
  @override
  Future<Result<CollabListing>> getListing(String id) async =>
      Result.success(listing);
  @override
  Future<Result<List<CollabActor>>> getMyActors() async =>
      const Result.success([musicianActor]);
  @override
  Future<Result<CollabPage<CollabListing>>> discover(
    CollabDiscoveryQuery q,
  ) async => Result.success(page([listing]));
  @override
  Future<Result<CollabPage<CollabApplication>>> getIncomingApplications(
    String id, {
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(_pageApps());
  @override
  Future<Result<CollabPage<CollabApplication>>> getMyApplications({
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(_pageApps());
  CollabPage<CollabApplication> _pageApps() { calls++; return page(List.generate(listCount, applicationAt)); }
  @override
  Future<Result<CollabPage<CollabJob>>> getMyJobs({
    CollabJobStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(_pageJobs());
  CollabPage<CollabJob> _pageJobs() { calls++; return page(List.generate(listCount, jobAt)); }
  @override
  Future<Result<CollabPage<CollabReview>>> getActorReviews(
    String id, {
    int page = 0,
    int size = 20,
  }) async => Result.success(_pageReviews());
  CollabPage<CollabReview> _pageReviews() { calls++; return page(List.generate(listCount, (index) =>
    CollabReview(
      id: index == targetIndex ? reviewId : 'review-$index',
      jobId: jobId,
      reviewer: musicianActor,
      target: venueActor,
      rating: 5,
      comment: 'Exact review',
      createdAt: DateTime.utc(2026),
    ),
  )); }
}

class _Locations extends Fake implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async => const Result.success([]);
}

class _Instruments extends Fake implements InstrumentRepository {
  @override
  Future<Result<List<Instrument>>> getAll() async => const Result.success([]);
}

class _Posts extends Fake implements OverthinkingRepository {
  bool exact = true;
  bool incoming = false;
  String status = 'REJECTED';
  String targetPost = listingId;
  int calls = 0, seenWrites = 0, listCount = 1, targetPage = 0;
  bool longTitle = false;
  OverthinkingRevealRequest get request => OverthinkingRevealRequest(
    id: exact ? requestId : 'other',
    postId: targetPost,
      postTitle: longTitle ? List.filled(7, 'Exact post').join(' ').substring(0,64) : 'Exact post',
    requesterId: incoming ? '70000000-0000-4000-8000-000000000002' : user,
    requesterUsername: 'Demo',
      authorId: status == 'APPROVED' ? (incoming ? user : '70000000-0000-4000-8000-000000000002') : '',
    status: status,
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));
  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) async => _requests(page);
  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) async => _requests(page);
  Result<Page<OverthinkingRevealRequest>> _requests(int page) {
    calls++;
    return Result.success(Page(items: [
      if (page == targetPage) request,
      for (var i = 1; i < listCount; i++) OverthinkingRevealRequest(
        id: 'other-$page-$i', postId: 'other-post-$i', postTitle: 'Sibling post $i',
        requesterId: 'other', requesterUsername: 'Sibling', authorId: user,
        status: 'REJECTED', createdAt: DateTime.utc(2026)),
    ], hasNext: page < targetPage));
  }
  @override
  Future<Result<OverthinkingIncomingUnreadStatus>>
  getIncomingUnreadStatus() async => const Result.success(
    OverthinkingIncomingUnreadStatus(hasUnread: false, revision: 0),
  );
  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) async {
    seenWrites++;
    return const Result.success(OverthinkingIncomingUnreadStatus(hasUnread: false, revision: 0));
  }
}
