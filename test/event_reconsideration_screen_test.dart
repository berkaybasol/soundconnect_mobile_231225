import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  for (final code in [
    '9252',
    '9253',
    '9255',
    'event_performer_decision_unconfirmed',
    'event_performer_decision_unknown',
    'event_performer_decision_unexpected_failure',
    'timeout',
    '503',
  ]) {
    testWidgets(
      'reconsideration $code reconciles without repeating the mutation',
      (tester) async {
        final repository = _Repository([_request()]);
        repository.completion = Completer<Result<void>>();
        await _mount(tester, repository);
        final action = find.byKey(const Key('accept-event-request-r1'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        repository.items.clear();
        repository.completion!.complete(
          Result.failure(
            AppError(code: code, message: 'Güncel durum kontrol ediliyor.'),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.reconsidered.length, 1);
        expect(repository.queries.length, 2);
        expect(find.text('Reddedilen etkinlik yok'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'reconsideration serializes decisions and defers refresh until confirmation',
    (tester) async {
      final repository = _Repository([_request(), _request(id: 'r2')]);
      repository.completion = Completer<Result<void>>();
      await _mount(tester, repository);
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh;
      final first = find.byKey(const Key('accept-event-request-r1'));
      await tester.ensureVisible(first);
      await tester.pump();
      final acceptFirst = tester
          .widget<GradientOutlineButton>(first)
          .onPressed!;
      final second = find.byKey(const Key('accept-event-request-r2'));
      await tester.scrollUntilVisible(second, 300);
      final acceptSecond = tester
          .widget<GradientOutlineButton>(second)
          .onPressed!;
      acceptFirst();
      await tester.pump();
      await refresh();
      acceptSecond();
      await tester.pump();
      expect(repository.reconsidered, [('r1', false)]);
      expect(repository.queries.length, 1);
      expect(tester.widget<GradientOutlineButton>(second).onPressed, isNull);
      repository.items.removeAt(0);
      repository.completion!.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(repository.queries.length, 2);
      expect(find.byKey(const Key('event-approval-card-r1')), findsNothing);
      expect(find.byKey(const Key('event-approval-card-r2')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final type in EventPerformerTargetType.values) {
    for (final publish in [false, true]) {
      testWidgets('$type reconsideration captures publication=$publish once', (
        tester,
      ) async {
        final repository = _Repository([_request(type: type)]);
        repository.completion = Completer<Result<void>>();
        await _mount(tester, repository, type: type);
        expect(repository.queries, [
          (EventPerformerRequestStatus.rejected, 0, type, 'target'),
        ]);
        expect(find.text('Reddedilen Etkinlikler'), findsOneWidget);
        expect(find.byKey(const Key('reject-event-request-r1')), findsNothing);
        final checkbox = find.byKey(
          const Key('show-on-profile-event-request-r1'),
        );
        await tester.ensureVisible(checkbox);
        await tester.pump();
        if (publish) {
          await tester.tap(checkbox);
          await tester.pump();
        }
        final staleChoice = tester
            .widget<CheckboxListTile>(checkbox)
            .onChanged!;
        final action = find.byKey(const Key('accept-event-request-r1'));
        await tester.ensureVisible(action);
        await tester.pump();
        final staleAccept = tester
            .widget<GradientOutlineButton>(action)
            .onPressed!;
        staleAccept();
        await tester.pump();
        staleChoice(!publish);
        staleAccept();
        await tester.pump();
        expect(repository.reconsidered, [('r1', publish)]);
        expect(repository.accepts, 0);
        expect(repository.rejects, 0);
        repository.items.clear();
        repository.completion!.complete(const Result.success(null));
        await tester.pumpAndSettle();
        expect(find.text('Reddedilen etkinlik yok'), findsOneWidget);
        expect(repository.queries.length, 2);
        expect(repository.queries.last.$2, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final status in [
    EventPerformerRequestStatus.pending,
    EventPerformerRequestStatus.rejected,
  ]) {
    testWidgets(
      '$status expired invitations remain readable without mutation controls',
      (tester) async {
        final repository = _Repository([
          _request(status: status, expired: true),
        ]);
        await _mount(tester, repository, status: status);
        expect(find.text('Test Gecesi r1'), findsOneWidget);
        expect(find.byKey(const Key('accept-event-request-r1')), findsNothing);
        expect(find.byKey(const Key('reject-event-request-r1')), findsNothing);
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(
          find.text('Etkinlik başladığı için bu davet artık yanıtlanamaz.'),
          findsOneWidget,
        );
        expect(repository.reconsidered, isEmpty);
        expect(repository.accepts + repository.rejects, 0);
      },
    );

    testWidgets(
      '$status eligibility disappears at server deadline and stale callbacks fail closed',
      (tester) async {
        var elapsed = Duration.zero;
        final repository = _Repository([
          _request(status: status, remaining: const Duration(seconds: 10)),
        ]);
        await _mount(
          tester,
          repository,
          status: status,
          elapsed: () => elapsed,
        );
        final accept = find.byKey(const Key('accept-event-request-r1'));
        await tester.ensureVisible(accept);
        final callback = tester
            .widget<GradientOutlineButton>(accept)
            .onPressed!;
        elapsed = const Duration(seconds: 10);
        await tester.pump(const Duration(seconds: 10));
        callback();
        await tester.pump();
        expect(find.byKey(const Key('accept-event-request-r1')), findsNothing);
        expect(repository.reconsidered, isEmpty);
        expect(repository.accepts + repository.rejects, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('deadline reached while rejection dialog is open never writes', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    final repository = _Repository([
      _request(
        status: EventPerformerRequestStatus.pending,
        remaining: const Duration(seconds: 10),
      ),
    ]);
    await _mount(
      tester,
      repository,
      status: EventPerformerRequestStatus.pending,
      elapsed: () => elapsed,
    );
    final reject = find.byKey(const Key('reject-event-request-r1'));
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await tester.pump(const Duration(milliseconds: 300));
    elapsed = const Duration(seconds: 10);
    await tester.pump(const Duration(seconds: 10));
    repository.items[0] = _request(
      status: EventPerformerRequestStatus.pending,
      expired: true,
    );
    await tester.tap(find.byKey(const Key('confirm-reject-r1')));
    await tester.pumpAndSettle();
    expect(repository.rejects, 0);
    expect(repository.queries.length, 2);
    expect(find.text('Süresi doldu'), findsOneWidget);
  });

  testWidgets(
    'missing authoritative metadata does not enable reconsideration',
    (tester) async {
      final repository = _Repository([_request(metadata: false)]);
      await _mount(tester, repository);
      expect(
        find.text('Davetin güncel durumu doğrulanamadı. Listeyi yenile.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('accept-event-request-r1')), findsNothing);
      expect(repository.reconsidered, isEmpty);
    },
  );

  testWidgets('rejected pagination retains scope and deduplicates overlap', (
    tester,
  ) async {
    final repository = _Repository([_request()])..hasNext = true;
    repository.nextItems = [_request(), _request(id: 'r2')];
    await _mount(tester, repository);
    await tester.ensureVisible(
      find.byKey(const Key('load-more-event-performer-requests')),
    );
    await tester.pumpAndSettle();
    if (repository.queries.length == 1) {
      await tester.tap(
        find.byKey(const Key('load-more-event-performer-requests')),
      );
      await tester.pumpAndSettle();
    }
    expect(repository.queries.map((q) => q.$2), [0, 1]);
    expect(
      repository.queries.every(
        (q) => q.$1 == EventPerformerRequestStatus.rejected && q.$4 == 'target',
      ),
      isTrue,
    );
    expect(find.byKey(const Key('event-approval-card-r1')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('event-approval-card-r2')),
      300,
    );
    expect(find.byKey(const Key('event-approval-card-r2')), findsOneWidget);
  });

  testWidgets(
    'session changes cannot use a previously enabled reconsider callback',
    (tester) async {
      var session = 'owner';
      final repository = _Repository([_request()]);
      await _mount(tester, repository, session: () => session);
      final action = find.byKey(const Key('accept-event-request-r1'));
      await tester.ensureVisible(action);
      final callback = tester.widget<GradientOutlineButton>(action).onPressed!;
      session = 'other-owner';
      callback();
      await tester.pumpAndSettle();
      expect(repository.reconsidered, isEmpty);
      expect(find.text('Test Gecesi r1'), findsNothing);
      expect(
        find.text('Oturum değişti. Etkinlik davetlerini yeniden aç.'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  EventPerformerTargetType type = EventPerformerTargetType.musician,
  EventPerformerRequestStatus status = EventPerformerRequestStatus.rejected,
  Duration Function()? elapsed,
  String? Function()? session,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: EventPerformerRequestsScreen(
        repository: repository,
        targetType: type,
        targetId: 'target',
        status: status,
        sessionKeyProvider: session ?? () => 'owner',
        elapsedProvider: elapsed,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

EventPerformerRequest _request({
  String id = 'r1',
  EventPerformerTargetType type = EventPerformerTargetType.musician,
  EventPerformerRequestStatus status = EventPerformerRequestStatus.rejected,
  bool expired = false,
  bool metadata = true,
  Duration remaining = const Duration(days: 2),
}) => EventPerformerRequest(
  requestId: id,
  eventId: 'event-$id',
  eventTitle: 'Test Gecesi $id',
  eventDate: DateTime(2026, 9, 8),
  startTime: '20:00:00',
  endTime: '22:00:00',
  venueId: 'venue',
  venueName: 'SoundConnect Ankara',
  venueProfilePictureUrl: null,
  targetType: type,
  targetId: 'target',
  musicianProfileId: type == EventPerformerTargetType.musician
      ? 'target'
      : null,
  bandId: type == EventPerformerTargetType.band ? 'target' : null,
  performerName: type == EventPerformerTargetType.band
      ? 'Şahbaz'
      : 'bugrasahin',
  status: status,
  profileCalendarApproved: false,
  decisionAllowed: metadata
      ? status == EventPerformerRequestStatus.pending && !expired
      : null,
  canReconsider: metadata
      ? status == EventPerformerRequestStatus.rejected && !expired
      : null,
  expired: metadata ? expired : null,
  serverNow: metadata ? DateTime.utc(2026, 9, 6, 17) : null,
  eventStartsAt: metadata
      ? DateTime.utc(2026, 9, 6, 17).add(expired ? Duration.zero : remaining)
      : null,
  createdAt: DateTime.utc(2026, 9, 5),
  decidedAt: null,
);

class _Repository implements EventPerformerRequestRepository {
  _Repository(this.items);
  final List<EventPerformerRequest> items;
  List<EventPerformerRequest> nextItems = [];
  bool hasNext = false;
  Completer<Result<void>>? completion;
  final queries =
      <
        (EventPerformerRequestStatus, int, EventPerformerTargetType?, String?)
      >[];
  final reconsidered = <(String, bool)>[];
  int accepts = 0;
  int rejects = 0;
  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async {
    queries.add((status, page, targetType, targetId));
    final selected = page == 0 ? items : nextItems;
    return Result.success(
      EventPerformerRequestPage(
        items: List.of(selected),
        page: page,
        size: size,
        totalElements: items.length + nextItems.length,
        totalPages: hasNext ? 2 : (items.isEmpty ? 0 : 1),
        hasNext: page == 0 && hasNext,
      ),
    );
  }

  @override
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  }) async {
    reconsidered.add((requestId, showOnProfile));
    return completion?.future ?? const Result.success(null);
  }

  @override
  Future<Result<void>> accept(
    String requestId, {
    bool showOnProfile = false,
  }) async {
    accepts++;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> reject(String requestId) async {
    rejects++;
    return const Result.success(null);
  }
}
