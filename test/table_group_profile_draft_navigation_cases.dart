part of 'overthinking_profile_draft_navigation_test.dart';

const _tableDraftId = 'd0509152-94ea-4f28-9df4-4eb419b5d35f';
final _tableNote = find.byKey(const Key('listener-table-group-draft-note'));
final _tableLeaveDialog = find.byKey(
  const Key('listener-table-group-draft-leave-dialog'),
);

void _registerTableGroupDraftNavigationCases() {
  testWidgets(
    'typed table draft route loads own profile and publishes only explicitly',
    (tester) async {
      final h = await _mountTableProfile(tester);
      expect(find.byType(ListenerProfileScreen), findsOneWidget);
      expect(find.byType(ListenerTableGroupDraftComposer), findsOneWidget);
      expect(_tableNote, findsOneWidget);
      expect(tester.getRect(_tableNote).top, lessThan(760));
      expect(find.byType(BottomSheet), findsNothing);
      final route = h.routes.single;
      expect(route.name, AppRoutes.listenerProfile);
      final args = route.arguments! as TableGroupProfileDraftArgs;
      expect(args.tableGroupId, _tableDraftId);
      expect(args.expectedSession, same(h.expected));
      expect(h.tables.reads, [h.expected]);
      expect(h.tables.writes, isEmpty);
      await tester.enterText(_tableNote, '  Masamızda yer var 🎵  ');
      expect(h.tables.writes, isEmpty);
      await _tap(
        tester,
        find.byKey(const Key('listener-table-group-draft-publish')),
      );
      expect(h.tables.writes.single, (
        tableGroupId: _tableDraftId,
        note: 'Masamızda yer var 🎵',
        session: h.expected,
      ));
      expect(find.byType(ListenerTableGroupDraftComposer), findsNothing);
      expect(h.events.writes, isEmpty);
      expect(h.overthinking.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final exit in ['back', 'bottom navigation', 'settings menu']) {
    testWidgets('table profile draft guards $exit and retains authored note', (
      tester,
    ) async {
      final h = await _mountTableProfile(tester);
      await tester.enterText(_tableNote, 'Masa taslağım kaybolmasın');
      FocusManager.instance.primaryFocus?.unfocus();
      if (exit == 'back') {
        await tester.binding.handlePopRoute();
      } else if (exit == 'bottom navigation') {
        unawaited(Future.sync(_beforeNavigate(tester)));
      } else {
        await tester.tap(find.byKey(const Key('listener-owner-menu')));
      }
      await tester.pumpAndSettle();
      expect(_tableLeaveDialog, findsOneWidget);
      await _tap(tester, find.text('Düzenlemeye devam et'));
      expect(
        tester.widget<TextField>(_tableNote).controller!.text,
        'Masa taslağım kaybolmasın',
      );
      expect(h.tables.writes, isEmpty);
      expect(h.tables.deleted, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'discarding table draft returns to its source without publishing',
    (tester) async {
      final h = await _mountTableProfile(tester);
      await tester.enterText(_tableNote, 'Geçici not');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Taslağı bırak'));
      expect(find.byType(ListenerProfileScreen), findsNothing);
      expect(find.text('OPEN TABLE DRAFT'), findsOneWidget);
      expect(h.tables.writes, isEmpty);
      expect(h.tables.deleted, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final stage in ['before profile load', 'while editing']) {
    testWidgets('table draft does not cross relogin $stage', (tester) async {
      final pending = Completer<Result<ListenerProfile>>();
      final h = await _mountTableProfile(
        tester,
        profileRead: stage == 'before profile load'
            ? () => pending.future
            : null,
        settle: stage != 'before profile load',
      );
      if (stage == 'while editing') {
        await tester.enterText(_tableNote, 'Önceki oturumun taslağı');
      }
      h.sessions.replace(audienceSession(token: 'new-login'));
      await tester.pump();
      if (stage == 'before profile load') {
        pending.complete(Result.success(_profile()));
      }
      // The cubit clears the previous account's profile, whose loading
      // indicator keeps animating until the stale route is left.
      await tester.pump();
      expect(_tableNote, findsNothing);
      expect(h.tables.writes, isEmpty);
      if (stage == 'before profile load') expect(h.tables.reads, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('OPEN TABLE DRAFT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('table draft duplicate source taps share one profile route', (
    tester,
  ) async {
    final h = await _mountTableProfile(tester, open: false);
    unawaited(h.open());
    unawaited(h.open());
    await tester.pumpAndSettle();
    expect(h.routes, hasLength(1));
    expect(h.tables.reads, hasLength(1));
    expect(h.tables.writes, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    unawaited(h.open());
    await tester.pumpAndSettle();
    expect(h.routes, hasLength(2));
    expect(h.tables.reads, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}

Future<_TableProfileHarness> _mountTableProfile(
  WidgetTester tester, {
  Future<Result<ListenerProfile>> Function()? profileRead,
  bool settle = true,
  bool open = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h = _TableProfileHarness();
  h.profiles.onRead = profileRead;
  addTearDown(h.sessions.dispose);
  addTearDown(h.tables.signal.dispose);
  addTearDown(h.events.signal.dispose);
  addTearDown(h.overthinking.signal.dispose);
  serviceLocator
    ..registerSingleton<AuthSessionManager>(h.sessions)
    ..registerSingleton<TableGroupProfileShareRepository>(h.tables)
    ..registerSingleton<OverthinkingProfileShareRepository>(h.overthinking)
    ..registerSingleton<EventAudienceRepository>(h.events)
    ..registerFactory<ListenerProfileCubit>(
      () => ListenerProfileCubit(h.profiles, sessions: h.sessions),
    )
    ..registerSingleton<DmBadgeCubit>(_Badges());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      onGenerateRoute: (settings) {
        h.routes.add(settings);
        return AppRouter.onGenerateRoute(settings);
      },
      home: Builder(
        builder: (context) {
          h.context = context;
          return Scaffold(
            body: TextButton(
              onPressed: h.open,
              child: const Text('OPEN TABLE DRAFT'),
            ),
          );
        },
      ),
    ),
  );
  if (open) await tester.tap(find.text('OPEN TABLE DRAFT'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
  return h;
}

class _TableProfileHarness {
  final expected = audienceSession();
  late final sessions = AudienceTestSessions(expected);
  final tables = _TableDraftShares();
  final overthinking = _Shares();
  final events = _Events();
  final profiles = _Profiles();
  final routes = <RouteSettings>[];
  late BuildContext context;

  Future<void> open() => openTableGroupProfileDraft(
    context,
    tableGroupId: _tableDraftId,
    expectedSession: expected,
    sessions: sessions,
  );
}

class _TableDraftShares extends Fake
    implements TableGroupProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  final reads = <AuthSession>[];
  final writes = <({String tableGroupId, String? note, AuthSession session})>[];
  final deleted = <String>[];

  @override
  Future<Result<TableGroupProfileShareState>> getState({
    required String tableGroupId,
    required AuthSession expectedSession,
  }) async {
    reads.add(expectedSession);
    return Result.success(_tableState());
  }

  @override
  Future<Result<TableGroupProfileShareState>> publish({
    required String tableGroupId,
    String? note,
    required AuthSession expectedSession,
  }) async {
    writes.add((
      tableGroupId: tableGroupId,
      note: note,
      session: expectedSession,
    ));
    signal.value++;
    return Result.success(_tableState(published: true, note: note));
  }

  @override
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  }) async {
    deleted.add(shareId);
    return const Result.success(null);
  }

  @override
  Future<Result<Page<TableGroupProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));
}

TableGroupProfileShareState _tableState({
  bool published = false,
  String? note,
}) => TableGroupProfileShareState(
  tableGroupId: _tableDraftId,
  shareId: published ? 'table-publication' : null,
  publishedOnProfile: published,
  note: note,
  publishedAt: published ? DateTime.utc(2026, 9, 10) : null,
  canPublish: true,
  tableGroup: TableGroupProfileShareSource(
    id: _tableDraftId,
    description: 'Birlikte müzik dinleyelim.',
    venueName: null,
    cityName: 'Ankara',
    districtName: 'Çankaya',
    meetingAt: DateTime.utc(2100, 9, 10),
    expiresAt: DateTime.utc(2100, 9, 11),
    status: 'ACTIVE',
    maxPersonCount: 4,
    acceptedCount: 2,
  ),
);
