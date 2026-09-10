import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late _Harness h;
  late Duration originalInterval;
  setUp(() async {
    await serviceLocator.reset();
    originalInterval = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    h = _Harness();
  });
  tearDown(() async {
    h.dispose();
    VisibilityDetectorController.instance.updateInterval = originalInterval;
    await serviceLocator.reset();
  });

  testWidgets('visible cards share one automatic request and update in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    h.tables.items = [_share('one'), _share('two')];
    await h.mount(tester);
    expect(find.text('1/4 kişi'), findsNWidgets(2));
    h.tables.items = [_share('one', count: 2), _share('two', count: 3)];
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(h.tables.lookups, [
      {'one', 'two'},
    ]);
    expect(find.text('2/4 kişi'), findsOneWidget);
    expect(find.text('3/4 kişi'), findsOneWidget);
    expect(h.tables.pageReads, 1);
    expect(h.events.reads, 1);
    expect(h.writings.reads, 1);
    expect(h.scroll.offset, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('offscreen sliver cards do not poll until visible', (
    tester,
  ) async {
    h.tables.items = [_share('one')];
    await h.mount(tester, precedingHeight: 1200);
    await tester.pump(const Duration(seconds: 30));
    expect(h.tables.lookups, isEmpty);
    h.scroll.jumpTo(1100);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(h.tables.lookups, hasLength(1));
    h.scroll.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    expect(h.tables.lookups, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'covered route, hidden tab, and background suspend automatic reads',
    (tester) async {
      h.tables.items = [_share('one')];
      await h.mount(tester);
      unawaited(
        h.navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Another page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      expect(h.tables.lookups, isEmpty);
      h.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(h.tables.lookups, hasLength(1));
      h.visible.value = false;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      expect(h.tables.lookups, hasLength(1));
      h.visible.value = true;
      await tester.pumpAndSettle();
      final beforePause = h.tables.lookups.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 1));
      expect(h.tables.lookups, hasLength(beforePause));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(h.tables.lookups.length, greaterThan(beforePause));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('slow requests never overlap and network failure backs off', (
    tester,
  ) async {
    h.tables.items = [_share('one')];
    await h.mount(tester);
    final pending = Completer<Result<List<TableGroupProfileShare>>>();
    h.tables.lookup = (_) => pending.future;
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(minutes: 1));
    expect(h.tables.lookups, hasLength(1));
    pending.complete(
      const Result.failure(AppError(code: 'NETWORK', message: 'Offline')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1/4 kişi'), findsOneWidget);
    h.tables.lookup = null;
    h.tables.items = [_share('one', count: 2)];
    await tester.pump(const Duration(seconds: 29));
    expect(h.tables.lookups, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(h.tables.lookups, hasLength(2));
    expect(find.text('2/4 kişi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('canonical ended snapshots remain without periodic requests', (
    tester,
  ) async {
    h.tables.items = [_share('one', status: 'INACTIVE', count: 3)];
    await h.mount(tester);
    await tester.pump(const Duration(minutes: 2));
    expect(h.tables.lookups, isEmpty);
    expect(find.text('3/4 kişi'), findsOneWidget);
    expect(find.text('Bu masanın süresi doldu'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Harness {
  final tables = _Tables();
  final events = _Events();
  final writings = _Writings();
  final sessions = AudienceTestSessions(audienceSession());
  final scroll = ScrollController();
  final navigator = GlobalKey<NavigatorState>();
  final visible = ValueNotifier(true);

  Future<void> mount(WidgetTester tester, {double precedingHeight = 0}) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.navy,
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, visible, child) => TickerMode(
              enabled: visible,
              child: Offstage(offstage: !visible, child: child),
            ),
            child: CustomScrollView(
              controller: scroll,
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: precedingHeight)),
                ListenerProfilePostsSection(
                  listenerProfileId: 'profile',
                  username: 'listener',
                  ownerUserId: 'listener',
                  sessions: sessions,
                  eventsRepository: events,
                  overthinkingRepository: writings,
                  tableGroupRepository: tables,
                  asSliver: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() {
    sessions.dispose();
    tables.signal.dispose();
    events.signal.dispose();
    writings.signal.dispose();
    scroll.dispose();
    visible.dispose();
  }
}

TableGroupProfileShare _share(
  String id, {
  int count = 1,
  String status = 'ACTIVE',
}) => TableGroupProfileShare(
  shareId: id,
  note: null,
  publishedAt: DateTime.utc(2026),
  likeCount: 0,
  commentCount: 0,
  likedByMe: false,
  tableGroup: TableGroupProfileShareSource(
    id: 'table-$id',
    description: 'Birlikte müzik',
    venueName: null,
    cityName: 'Ankara',
    districtName: null,
    meetingAt: DateTime.utc(2100),
    expiresAt: DateTime.utc(2100, 1, 2),
    status: status,
    maxPersonCount: 4,
    acceptedCount: count,
  ),
);

class _Tables extends Fake implements TableGroupProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  List<TableGroupProfileShare> items = [];
  int pageReads = 0;
  final lookups = <Set<String>>[];
  Future<Result<List<TableGroupProfileShare>>> Function(Set<String>)? lookup;

  @override
  Future<Result<Page<TableGroupProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async {
    pageReads++;
    return Result.success(
      Page(
        items: items.skip(page * size).take(size).toList(),
        hasNext: (page + 1) * size < items.length,
      ),
    );
  }

  @override
  Future<Result<List<TableGroupProfileShare>>> lookupProfile({
    required String profileId,
    required AuthSession expectedSession,
    required Set<String> shareIds,
  }) async {
    lookups.add(Set.of(shareIds));
    return lookup?.call(shareIds) ??
        Result.success(
          items.where((share) => shareIds.contains(share.shareId)).toList(),
        );
  }
}

class _Writings extends Fake implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  int reads = 0;
  @override
  ValueListenable<int> get changes => signal;
  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async {
    reads++;
    return const Result.success(Page(items: [], hasNext: false));
  }
}

class _Events extends Fake implements EventAudienceRepository {
  final signal = ValueNotifier(0);
  int reads = 0;
  @override
  ValueListenable<int> get changes => signal;
  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    reads++;
    return Result.success(
      EventAudiencePage(
        items: const [],
        page: page,
        size: size,
        totalElements: 0,
        totalPages: 0,
        hasNext: false,
      ),
    );
  }
}
