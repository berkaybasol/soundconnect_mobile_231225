import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_profile_publication.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_profile_publication_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_invitation_navigation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_profile_publications_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_invitation_navigation_fakes.dart';

void main() {
  late InvitationSession session;
  late InvitationBands bands;
  late InvitationProfileRepository profiles;
  late _Requests requests;
  late _Publications publications;

  setUp(() async {
    await serviceLocator.reset();
    session = InvitationSession();
    bands = InvitationBands();
    profiles = InvitationProfileRepository();
    requests = _Requests();
    publications = _Publications();
  });
  tearDown(() async {
    session.dispose();
    await serviceLocator.reset();
  });

  Future<void> launch(
    WidgetTester tester, {
    EventPerformerTargetType type = EventPerformerTargetType.musician,
    String? id,
    bool doubleTap = false,
    double scale = 1,
  }) async {
    final dependencies = EventInvitationNavigationDependencies(
      sessionKeyProvider: () => session.userId,
      sessionChanges: session,
      loadMyProfile: profiles.getMyProfile,
      loadBand: bands.getBandById,
      requests: requests,
      publications: publications,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-management'),
              onPressed: () => unawaited(
                openEventManagement(
                  context,
                  targetType: type,
                  targetId:
                      id ??
                      (type == EventPerformerTargetType.band
                          ? 'band-1'
                          : 'musician-1'),
                  dependencies: dependencies,
                ),
              ),
              child: const Text('Yönetim paneli'),
            ),
          ),
        ),
      ),
    );
    final action = tester
        .widget<TextButton>(find.byKey(const Key('open-management')))
        .onPressed!;
    action();
    if (doubleTap) action();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'hub presents exactly three destinations without fetching any list',
    (tester) async {
      await launch(tester);
      expect(find.text('Etkinlik Yönetimi'), findsOneWidget);
      expect(find.text('Etkinlik Davetleri'), findsOneWidget);
      expect(find.text('Etkinliklerim'), findsOneWidget);
      expect(find.text('Reddedilen Etkinlikler'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(requests.reads, 0);
      expect(publications.reads, isEmpty);
      expect(profiles.reads, 0);
      expect(bands.reads, 0);
    },
  );

  for (final type in EventPerformerTargetType.values) {
    for (final destination in ['invitations', 'events', 'rejected']) {
      testWidgets(
        '$type $destination validates profile and passes the exact scope',
        (tester) async {
          await launch(tester, type: type);
          await tester.tap(find.byKey(Key('event-management-$destination')));
          await tester.pumpAndSettle();
          final id = type == EventPerformerTargetType.band
              ? 'band-1'
              : 'musician-1';
          expect(find.byType(BottomSheet), findsNothing);
          if (destination == 'events') {
            expect(find.byType(EventProfilePublicationsScreen), findsOneWidget);
            expect(find.byType(EventPerformerRequestsScreen), findsNothing);
            expect(publications.reads.single, (
              type,
              id,
              EventProfilePublicationPeriod.current,
              0,
              20,
            ));
            expect(requests.reads, 0);
            expect(
              find.byKey(const Key('event-period-current')),
              findsOneWidget,
            );
          } else {
            expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
            expect(find.byType(EventProfilePublicationsScreen), findsNothing);
            expect(requests.targetType, type);
            expect(requests.targetId, id);
            expect(requests.statuses, [
              destination == 'rejected'
                  ? EventPerformerRequestStatus.rejected
                  : EventPerformerRequestStatus.pending,
            ]);
            expect(publications.reads, isEmpty);
          }
          expect(
            profiles.reads,
            type == EventPerformerTargetType.musician ? 1 : 0,
          );
          expect(bands.reads, type == EventPerformerTargetType.band ? 1 : 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('dismissing the hub performs no ownership or list fetch', (
    tester,
  ) async {
    await launch(tester);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Yönetim paneli'), findsOneWidget);
    expect(profiles.reads + bands.reads + requests.reads, 0);
    expect(publications.reads, isEmpty);
  });

  for (final changedSession in <String?>['owner-2', null]) {
    testWidgets(
      'session change to $changedSession while menu is open blocks navigation',
      (tester) async {
        await launch(tester);
        session.switchTo(changedSession);
        await tester.tap(find.byKey(const Key('event-management-events')));
        await tester.pumpAndSettle();
        expect(find.byType(EventProfilePublicationsScreen), findsNothing);
        expect(find.byType(EventPerformerRequestsScreen), findsNothing);
        expect(find.text('Yönetim paneli'), findsOneWidget);
        expect(profiles.reads + bands.reads + requests.reads, 0);
        expect(publications.reads, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'double entry and duplicate selection create only one destination',
    (tester) async {
      await launch(tester, doubleTap: true);
      expect(find.byType(BottomSheet), findsOneWidget);
      final select = tester
          .widget<InkWell>(
            find.byKey(const Key('event-management-invitations')),
          )
          .onTap!;
      select();
      select();
      await tester.pumpAndSettle();
      expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
      expect(requests.reads, 1);
      expect(profiles.reads, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Yönetim paneli'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wrong musician identity blocks all event history reads', (
    tester,
  ) async {
    await launch(tester, id: 'different-profile');
    await tester.tap(find.byKey(const Key('event-management-events')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('event-invitations-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(EventProfilePublicationsScreen), findsNothing);
    expect(publications.reads, isEmpty);
    expect(requests.reads, 0);
  });

  for (final membership in [('MEMBER', 'ACTIVE'), ('FOUNDER', 'INACTIVE')]) {
    testWidgets(
      'band ${membership.$1}/${membership.$2} cannot open rejected management',
      (tester) async {
        bands.read = (_) async => Result.success(
          invitationBand(role: membership.$1, status: membership.$2),
        );
        await launch(tester, type: EventPerformerTargetType.band);
        await tester.tap(find.byKey(const Key('event-management-rejected')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('event-invitations-unavailable')),
          findsOneWidget,
        );
        expect(find.byType(EventPerformerRequestsScreen), findsNothing);
        expect(requests.reads, 0);
        expect(publications.reads, isEmpty);
      },
    );
  }

  for (final viewport in [const Size(320, 800), const Size(740, 320)]) {
    testWidgets(
      'hub scrolls and remains actionable at $viewport with 200 percent text',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await launch(tester, scale: 2);
        final rejected = find.byKey(const Key('event-management-rejected'));
        await tester.ensureVisible(rejected);
        await tester.pumpAndSettle();
        expect(rejected.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(rejected);
        await tester.pumpAndSettle();
        expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
        expect(requests.statuses, [EventPerformerRequestStatus.rejected]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Requests extends InvitationRequests {
  final statuses = <EventPerformerRequestStatus>[];
  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) {
    statuses.add(status);
    return super.listMine(
      status: status,
      page: page,
      size: size,
      targetType: targetType,
      targetId: targetId,
    );
  }
}

class _Publications extends Fake implements EventProfilePublicationRepository {
  final reads =
      <
        (
          EventPerformerTargetType,
          String,
          EventProfilePublicationPeriod,
          int,
          int,
        )
      >[];
  @override
  Future<Result<EventProfilePublicationPage>> listMine({
    required EventPerformerTargetType targetType,
    required String targetId,
    EventProfilePublicationPeriod period = EventProfilePublicationPeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    reads.add((targetType, targetId, period, page, size));
    return Result.success(
      EventProfilePublicationPage(
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
