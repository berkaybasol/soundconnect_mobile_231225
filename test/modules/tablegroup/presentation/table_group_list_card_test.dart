import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_participant.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_expiry_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_list_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_list_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/widgets/table_group_overview_style.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/brand_gradient_icon.dart';

void main() {
  testWidgets('reference card renders the compact detail-first composition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final meetingAt = DateTime(2030, 5, 14, 23).toUtc();
    final expiresAt = DateTime(2030, 5, 15, 4).toUtc();

    await _pumpList(tester, <TableGroup>[
      _group(
        id: 'reference',
        ownerProfileImageUrl: 'https://cdn.example.com/owner.jpg',
        meetingAt: meetingAt,
        expiresAt: expiresAt,
      ),
    ]);

    final card = find.byKey(const Key('table_group_card-reference'));
    expect(card, findsOneWidget);
    expect(tester.getTopLeft(card).dx, closeTo(12, 0.1));
    expect(tester.getTopLeft(card).dy, inInclusiveRange(210, 224));
    expect(tester.getSize(card).height, inInclusiveRange(116, 124));
    expect(
      tester.getTopLeft(find.byKey(const Key('table_group_hero_title'))).dx,
      closeTo(28, 0.1),
    );
    final decoration =
        tester.widget<Container>(card).decoration! as BoxDecoration;
    expect(decoration.color, isNull);
    expect(decoration.gradient, TableGroupOverviewStyle.cardGradient);
    expect(decoration.boxShadow, TableGroupOverviewStyle.cardShadows);
    expect(decoration.border, isNotNull);

    final image = tester.widget<AppCachedNetworkImage>(
      find.byKey(const Key('table_group_owner_image-reference')),
    );
    expect(image.imageUrl, 'https://cdn.example.com/owner.jpg');
    expect(
      tester.getSize(
        find.byKey(const Key('table_group_owner_avatar-reference')),
      ),
      const Size.square(58),
    );

    final titleFinder = find.byKey(
      const Key('table_group_description_title-reference'),
    );
    final title = tester.widget<Text>(titleFinder);
    expect(title.data, 'Akustik müzik ve güzel sohbet için bekliyoruz.');
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(find.text('@Owner Name’in masası'), findsNothing);
    expect(find.text('@Owner Name'), findsNothing);

    final detail = find.byKey(
      const Key('table_group_detail_affordance-reference'),
    );
    expect(find.descendant(of: detail, matching: find.text('Detay')), findsOne);
    expect(
      find.descendant(
        of: detail,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOne,
    );

    final location = find.byKey(const Key('table_group_location-reference'));
    expect(
      find.descendant(of: location, matching: find.text('Çankaya · Ankara')),
      findsOne,
    );
    expect(
      find.descendant(
        of: location,
        matching: find.byIcon(Icons.location_on_outlined),
      ),
      findsOne,
    );

    final stats = find.byKey(const Key('table_group_stats_strip-reference'));
    expect(stats, findsOneWidget);
    expect(
      find.byKey(const Key('table_group_stats_inline-reference')),
      findsOneWidget,
    );
    final venue = find.byKey(const Key('table_group_venue_line-reference'));
    expect(
      find.descendant(of: venue, matching: find.text('Studio Nocturne')),
      findsOne,
    );
    expect(
      tester
          .widget<BrandGradientIcon>(
            find.descendant(
              of: venue,
              matching: find.byType(BrandGradientIcon),
            ),
          )
          .icon,
      Icons.storefront_outlined,
    );

    final meeting = find.byKey(const Key('table_group_meeting_time-reference'));
    final expectedMeeting = formatTableGroupMeetingAt(meetingAt);
    expect(
      find.descendant(of: meeting, matching: find.text(expectedMeeting)),
      findsOne,
    );
    expect(
      find.descendant(
        of: meeting,
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOne,
    );
    expect(find.text(_clockText(expiresAt)), findsNothing);

    expect(find.text('1/4 kişi'), findsOneWidget);
    final slots = find.byKey(
      const Key('table_group_participant_slots-reference'),
    );
    expect(
      find.descendant(
        of: slots,
        matching: find.byKey(const Key('table_group_filled_slot-reference-0')),
      ),
      findsOne,
    );
    for (var index = 1; index < 4; index++) {
      expect(
        find.descendant(
          of: slots,
          matching: find.byKey(Key('table_group_empty_slot-reference-$index')),
        ),
        findsOne,
      );
    }

    expect(find.textContaining('yer kaldı'), findsNothing);
    expect(find.text('Katıl'), findsNothing);
    expect(find.text('Masaya git'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.byIcon(Icons.remove_rounded), findsNothing);
    expect(
      find.descendant(of: card, matching: find.byType(Divider)),
      findsNothing,
    );

    final semantics = tester
        .widget<Semantics>(
          find.byKey(const Key('table_group_open_detail-reference')),
        )
        .properties;
    expect(semantics.button, isTrue);
    expect(semantics.label, contains('Buluşma saati $expectedMeeting'));
    expect(semantics.label, contains('1/4 kişi'));
    expect(semantics.label, isNot(contains('kapanış')));
    expect(tester.getSize(card).height, lessThan(210));
    expect(tester.takeException(), isNull);
  });

  testWidgets('420dp moderate text scaling preserves the one-row stats strip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpList(tester, <TableGroup>[
      _group(
        id: 'moderate-scale',
        maxPersonCount: 6,
        venueName: 'Studio Nocturne',
      ),
    ], textScale: 1.4);

    expect(
      find.byKey(const Key('table_group_stats_inline-moderate-scale')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('table_group_stats_stacked-moderate-scale')),
      findsNothing,
    );
    expect(
      tester.getSize(
        find.byKey(const Key('table_group_owner_avatar-moderate-scale')),
      ),
      const Size.square(58),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact density keeps four complete cards above the fold', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpList(
      tester,
      List<TableGroup>.generate(5, (index) => _group(id: 'density-$index')),
    );

    final listRect = tester.getRect(find.byType(ListView));
    final firstCard = find.byKey(const Key('table_group_card-density-0'));
    final secondCard = find.byKey(const Key('table_group_card-density-1'));
    final fourthCard = find.byKey(const Key('table_group_card-density-3'));

    expect(firstCard, findsOneWidget);
    expect(secondCard, findsOneWidget);
    expect(fourthCard, findsOneWidget);
    expect(tester.getSize(firstCard).height, inInclusiveRange(116, 124));
    expect(
      tester.getTopLeft(secondCard).dy - tester.getTopLeft(firstCard).dy,
      lessThanOrEqualTo(132),
    );
    expect(
      tester.getRect(fourthCard).bottom,
      lessThanOrEqualTo(listRect.bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling near the end requests and renders the next page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firstPage = List<TableGroup>.generate(
      6,
      (index) => _group(id: 'page-0-$index'),
    );
    final repository = await _pumpList(
      tester,
      firstPage,
      pages: <int, Page<TableGroup>>{
        0: Page<TableGroup>(items: firstPage, hasNext: true, totalElements: 8),
        1: Page<TableGroup>(
          items: <TableGroup>[
            _group(id: 'page-0-5'),
            _group(id: 'page-1-0'),
            _group(id: 'page-1-1'),
          ],
          hasNext: false,
          totalElements: 8,
        ),
      },
    );

    expect(repository.requestedPages, <int>[0]);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.requestedPages, <int>[0, 1]);
    expect(find.byKey(const Key('table_group_card-page-1-0')), findsOneWidget);
    expect(find.text('8 masa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('whole card opens detail without jumping straight into chat', (
    tester,
  ) async {
    TableGroupDetailArgs? openedArgs;
    await _pumpList(tester, <TableGroup>[
      _group(id: 'open-detail'),
    ], onOpenDetail: (args) => openedArgs = args);

    final cardInkWell = find
        .descendant(
          of: find.byKey(const Key('table_group_card-open-detail')),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(cardInkWell);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('table_group_detail_route-open-detail')),
      findsOneWidget,
    );
    expect(openedArgs?.tableGroupId, 'open-detail');
    expect(openedArgs?.openChat, isFalse);
  });

  testWidgets('missing canonical meeting time never falls back to expiry', (
    tester,
  ) async {
    final legacyTime = DateTime(2030, 5, 14, 21, 15).toUtc();
    await _pumpList(tester, <TableGroup>[
      _group(
        id: 'legacy',
        venueName: '   ',
        description: '   ',
        meetingAt: null,
        expiresAt: legacyTime,
        ownerProfileImageUrl: 'not-a-valid-url',
      ),
    ]);

    expect(find.text('Masa buluşması'), findsOneWidget);
    expect(
      find.byKey(const Key('table_group_owner_fallback-legacy')),
      findsOneWidget,
    );
    expect(find.text('ON'), findsOneWidget);
    expect(
      find.byKey(const Key('table_group_venue_line-legacy')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('table_group_venue_line-legacy')),
        matching: find.text('Belirtilmemiş'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('table_group_venue_line-legacy')),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
    expect(find.text('--:--'), findsOneWidget);
    expect(find.text(formatTableGroupMeetingAt(legacyTime)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meeting day label refreshes while the list remains open', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 2, 23, 59, 59);
    await _pumpList(tester, <TableGroup>[
      _group(
        id: 'midnight',
        meetingAt: DateTime(2026, 9, 3, 9),
        expiresAt: DateTime(2026, 9, 3, 23),
      ),
    ], now: () => now);

    expect(find.text('Yarın 09:00'), findsOneWidget);
    now = DateTime(2026, 9, 3, 0, 0, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Bugün 09:00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 9, 4, 12);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('03.09.2026 09:00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('accepted participants fill silhouettes including the owner', (
    tester,
  ) async {
    await _pumpList(tester, <TableGroup>[
      _group(
        id: 'capacity',
        maxPersonCount: 6,
        participants: <TableGroupParticipant>[
          _participant('guest-a', TableGroupParticipantStatus.accepted),
          _participant('guest-b', TableGroupParticipantStatus.accepted),
          _participant('pending', TableGroupParticipantStatus.pending),
        ],
      ),
    ]);

    expect(find.text('3/6 kişi'), findsOneWidget);
    for (var index = 0; index < 3; index++) {
      expect(
        find.byKey(Key('table_group_filled_slot-capacity-$index')),
        findsOneWidget,
      );
    }
    for (var index = 3; index < 6; index++) {
      expect(
        find.byKey(Key('table_group_empty_slot-capacity-$index')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('card remains overflow-free at 320dp and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longDescription =
        'Çok uzun masa açıklaması dar ekranda güvenli biçimde kısalmalı ve '
        'kartın alt bilgi alanını asla taşırmamalı.';

    await _pumpList(tester, <TableGroup>[
      _group(
        id: 'narrow',
        description: longDescription,
        venueName: 'Çok Uzun Bir Mekân İsmi Denemesi',
        districtName: 'Oldukça Uzun Bir İlçe İsmi',
        maxPersonCount: 6,
      ),
    ], textScale: 2);

    final card = find.byKey(const Key('table_group_card-narrow'));
    final titleFinder = find.byKey(
      const Key('table_group_description_title-narrow'),
    );
    final title = tester.widget<Text>(titleFinder);
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(
      tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
      isTrue,
    );
    expect(
      find.byKey(const Key('table_group_stats_stacked-narrow')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('table_group_owner_avatar-narrow'))),
      const Size.square(68),
    );

    for (final child in <Finder>[
      find.byKey(const Key('table_group_owner_avatar-narrow')),
      titleFinder,
      find.byKey(const Key('table_group_detail_affordance-narrow')),
      find.byKey(const Key('table_group_location-narrow')),
      find.byKey(const Key('table_group_stats_strip-narrow')),
      find.byKey(const Key('table_group_venue_line-narrow')),
      find.byKey(const Key('table_group_meeting_time-narrow')),
      find.byKey(const Key('table_group_participant_slots-narrow')),
      find.byKey(const Key('table_group_capacity-narrow')),
    ]) {
      _expectHorizontallyContained(tester, child: child, container: card);
    }
    expect(find.text('Katıl'), findsNothing);
    final layoutException = tester.takeException();
    expect(
      layoutException,
      isNull,
      reason: layoutException is FlutterError
          ? layoutException.toStringDeep()
          : null,
    );
  });

  testWidgets('first feed failure stays inline and retry can recover', (
    tester,
  ) async {
    const feedError = AppError(
      code: 'table_group_feed_unavailable',
      message: 'Masalar şu anda yüklenemiyor',
    );
    final repository = _SequencedTableRepository(<Result<Page<TableGroup>>>[
      const Result<Page<TableGroup>>.failure(feedError),
      Result<Page<TableGroup>>.success(
        Page<TableGroup>(
          items: <TableGroup>[_group(id: 'recovered')],
          hasNext: false,
          totalElements: 1,
        ),
      ),
    ]);

    await _pumpList(tester, const <TableGroup>[], tableRepository: repository);

    expect(find.byKey(const Key('table_group_feed_error')), findsOneWidget);
    expect(find.text(feedError.message), findsOneWidget);
    expect(find.text('Bu filtrede aktif masa bulunamadi'), findsNothing);
    expect(find.byKey(const Key('table_group_retry_feed')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const Key('table_group_retry_feed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('table_group_feed_error')), findsNothing);
    expect(
      find.byKey(const Key('table_group_description_title-recovered')),
      findsOneWidget,
    );
    expect(repository.requestedPages, <int>[0, 0]);
  });

  testWidgets('successful empty feed renders the empty state', (tester) async {
    await _pumpList(tester, const <TableGroup>[]);

    expect(find.byKey(const Key('table_group_feed_error')), findsNothing);
    expect(find.text('Bu filtrede aktif masa bulunamadi'), findsOneWidget);
  });

  testWidgets('metadata failure cannot replace a successful empty feed', (
    tester,
  ) async {
    const metadataError = AppError(
      code: 'cities_unavailable',
      message: 'Şehirler yüklenemedi',
    );

    await _pumpList(
      tester,
      const <TableGroup>[],
      locationRepository: _FailingLocationRepository(metadataError),
    );

    expect(find.byKey(const Key('table_group_feed_error')), findsNothing);
    expect(find.text('Bu filtrede aktif masa bulunamadi'), findsOneWidget);
    expect(find.text(metadataError.message), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

String _clockText(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

void _expectHorizontallyContained(
  WidgetTester tester, {
  required Finder child,
  required Finder container,
}) {
  final childRect = tester.getRect(child);
  final containerRect = tester.getRect(container);
  expect(childRect.left, greaterThanOrEqualTo(containerRect.left - 0.1));
  expect(childRect.right, lessThanOrEqualTo(containerRect.right + 0.1));
}

Future<_TableRepository> _pumpList(
  WidgetTester tester,
  List<TableGroup> groups, {
  String? userId = 'viewer',
  List<String> roles = const <String>['ROLE_MUSICIAN'],
  double textScale = 1,
  ValueChanged<TableGroupDetailArgs>? onOpenDetail,
  Map<int, Page<TableGroup>>? pages,
  _TableRepository? tableRepository,
  LocationRepository? locationRepository,
  DateTime Function()? now,
}) async {
  await serviceLocator.reset();
  final resolvedTableRepository =
      tableRepository ?? _TableRepository(groups, pages: pages);
  final resolvedLocationRepository =
      locationRepository ?? _LocationRepository();
  final tokenStore = _UserTokenStore(userId);
  serviceLocator.registerFactory<TableGroupListCubit>(
    () => TableGroupListCubit(
      tableGroupRepository: resolvedTableRepository,
      locationRepository: resolvedLocationRepository,
    ),
  );
  serviceLocator.registerSingleton<AuthSessionManager>(
    _FixedAuthSessionManager(
      userId == null
          ? const AuthSession.guest()
          : AuthSession.authenticated(
              token: 'test-token',
              userId: userId,
              username: userId,
              accountStatus: 'ACTIVE',
              roles: roles,
              permissions: const <String>[],
              expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
              isAdmin: false,
            ),
      tokenStore,
    ),
    dispose: (manager) => manager.dispose(),
  );
  serviceLocator.registerSingleton<TokenStore>(tokenStore);
  serviceLocator.registerSingleton<DmBadgeCubit>(
    DmBadgeCubit(
      _DmRepository(),
      tokenStore,
      realtimeClient: _NoopDmRealtimeClient(),
    ),
    dispose: (cubit) => cubit.close(),
  );
  addTearDown(serviceLocator.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: TableGroupListScreen(now: now),
      onGenerateRoute: (settings) {
        if (settings.name != AppRoutes.tableGroupDetail) return null;
        final args = settings.arguments! as TableGroupDetailArgs;
        onOpenDetail?.call(args);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => Scaffold(
            body: Text(
              'Masa detayı ${args.tableGroupId}',
              key: Key('table_group_detail_route-${args.tableGroupId}'),
            ),
          ),
        );
      },
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return resolvedTableRepository;
}

TableGroup _group({
  required String id,
  String ownerId = 'owner',
  String ownerUsername = 'Owner Name',
  String? ownerProfileImageUrl,
  String? venueName = 'Studio Nocturne',
  String? description = 'Akustik müzik ve güzel sohbet için bekliyoruz.',
  String districtName = 'Çankaya',
  int maxPersonCount = 4,
  DateTime? meetingAt,
  DateTime? expiresAt,
  List<TableGroupParticipant> participants = const <TableGroupParticipant>[],
}) {
  return TableGroup(
    id: id,
    ownerId: ownerId,
    ownerUsername: ownerUsername,
    ownerProfileImageUrl: ownerProfileImageUrl,
    venueId: null,
    venueName: venueName,
    description: description,
    maxPersonCount: maxPersonCount,
    genderPrefs: const <String>[],
    ageMin: 18,
    ageMax: 99,
    meetingAt: meetingAt,
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 24)),
    status: 'ACTIVE',
    participants: <TableGroupParticipant>[
      _participant(ownerId, TableGroupParticipantStatus.accepted),
      ...participants,
    ],
    city: const TableGroupLocation(id: 'city-1', name: 'Ankara'),
    district: TableGroupLocation(id: 'district-1', name: districtName),
    neighborhood: null,
  );
}

TableGroupParticipant _participant(
  String userId,
  TableGroupParticipantStatus status,
) {
  return TableGroupParticipant(
    userId: userId,
    joinedAt: DateTime.now().toUtc(),
    status: status,
    joinNote: null,
    username: userId,
    profilePictureUrl: null,
  );
}

class _TableRepository extends Fake implements TableGroupRepository {
  _TableRepository(this.groups, {this.pages});

  final List<TableGroup> groups;
  final Map<int, Page<TableGroup>>? pages;
  final List<int> requestedPages = <int>[];

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    final configuredPage = pages?[page];
    if (configuredPage != null) return Result.success(configuredPage);
    return Result.success(
      Page<TableGroup>(
        items: page == 0 ? groups : const <TableGroup>[],
        hasNext: false,
      ),
    );
  }
}

class _LocationRepository extends Fake implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async =>
      const Result.success(<City>[City(id: 'city-1', name: 'Ankara')]);

  @override
  Future<Result<List<District>>> getDistricts(String cityId) async =>
      const Result.success(<District>[]);

  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(
    String districtId,
  ) async => const Result.success(<Neighborhood>[]);
}

class _FailingLocationRepository extends _LocationRepository {
  _FailingLocationRepository(this.error);

  final AppError error;

  @override
  Future<Result<List<City>>> getCities() async => Result.failure(error);
}

class _SequencedTableRepository extends _TableRepository {
  _SequencedTableRepository(this.responses) : super(const <TableGroup>[]);

  final List<Result<Page<TableGroup>>> responses;

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    return responses.removeAt(0);
  }
}

class _DmRepository extends Fake implements DmRepository {
  @override
  Future<Result<int>> getUnreadCount() async => const Result.success(0);
}

class _NoopDmRealtimeClient extends DmRealtimeClient {
  @override
  Stream<int> get badgeStream => const Stream<int>.empty();

  @override
  Future<void> connect({required String userId, required String token}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void retain() {}

  @override
  Future<void> release() async {}
}

class _FixedAuthSessionManager extends AuthSessionManager {
  _FixedAuthSessionManager(this._session, TokenStore tokenStore)
    : super(tokenStore: tokenStore, sessionStore: _SessionStore());

  final AuthSession _session;

  @override
  AuthSession get session => _session;
}

class _SessionStore extends Fake implements AuthSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSessionMetadata?> read() async => null;

  @override
  Future<void> write(AuthSessionMetadata metadata) async {}
}

class _UserTokenStore implements TokenStore {
  const _UserTokenStore(this.userId);

  final String? userId;

  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async {
    final currentUserId = userId;
    if (currentUserId == null) return null;
    final payload = base64Url
        .encode(utf8.encode(jsonEncode(<String, String>{'sub': currentUserId})))
        .replaceAll('=', '');
    return 'e30.$payload.signature';
  }

  @override
  Future<void> writeToken(String token) async {}
}
