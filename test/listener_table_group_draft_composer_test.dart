import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_table_group_draft_composer.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/table_group_profile_draft.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';

final _publish = find.byKey(const Key('listener-table-group-draft-publish'));
final _remove = find.byKey(const Key('listener-table-group-draft-remove'));
final _note = find.byKey(const Key('listener-table-group-draft-note'));
final _reload = find.byKey(const Key('listener-table-group-draft-reload'));
const _offline = AppError(code: 'network', message: 'Bağlantı kesildi.');

void main() {
  testWidgets(
    'table draft loads one authoritative state and publishes only on explicit tap',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      expect(h.repository.reads, 1);
      expect(h.repository.notes, isEmpty);
      expect(find.text('Taslak · Henüz paylaşılmadı'), findsOneWidget);
      await tester.enterText(_note, ' Bu akşam burada buluşalım. ');
      expect(h.repository.notes, isEmpty);
      await _tap(tester, _publish);
      expect(h.repository.notes, ['Bu akşam burada buluşalım.']);
      expect(h.completed, [true]);
    },
  );

  testWidgets('membership revoked before draft loads cannot publish', (
    tester,
  ) async {
    final h = _Harness();
    h.repository.current = _state(eligible: false);
    await h.mount(tester);
    expect(tester.widget<GradientOutlineButton>(_publish).onPressed, isNull);
    expect(find.textContaining('Yalnızca sahibi'), findsOneWidget);
    expect(h.repository.notes, isEmpty);
  });

  testWidgets('hidden existing share can be removed without a source preview', (
    tester,
  ) async {
    final h = _Harness();
    h.repository.current = _state(
      published: true,
      eligible: false,
      note: 'Eski notum',
    );
    await h.mount(tester);
    expect(find.text('Eski notum'), findsOneWidget);
    expect(tester.widget<GradientOutlineButton>(_remove).onPressed, isNotNull);
    await _tap(tester, _remove);
    expect(h.repository.deleted, ['share']);
    expect(h.completed, [false]);
  });

  testWidgets(
    'uncertain removal reconciles even after source access is revoked',
    (tester) async {
      final h = _Harness();
      h.repository.current = _state(published: true);
      h.repository.deleteResult = const Result.failure(_offline);
      await h.mount(tester);
      await _tap(tester, _remove);
      expect(h.completed, isEmpty);
      h.repository.current = _state(eligible: false);
      await _tap(tester, _reload);
      expect(h.completed, [false]);
      expect(h.repository.deleted, ['share']);
    },
  );

  testWidgets(
    'lost publication response preserves note and reconciles without a duplicate write',
    (tester) async {
      final h = _Harness();
      h.repository.publishResult = const Result.failure(_offline);
      await h.mount(tester);
      await tester.enterText(_note, 'Kaybolmasın');
      await _tap(tester, _publish);
      expect(h.completed, isEmpty);
      expect(tester.widget<TextField>(_note).controller!.text, 'Kaybolmasın');
      h.repository.current = _state(published: true, note: 'Kaybolmasın');
      await _tap(tester, _reload);
      expect(h.completed, [true]);
      expect(h.repository.notes, ['Kaybolmasın']);
    },
  );

  testWidgets(
    'same-user relogin rejects late publication and clears authored draft',
    (tester) async {
      final h = _Harness();
      final pending = Completer<Result<TableGroupProfileShareState>>();
      h.repository.pending = pending.future;
      await h.mount(tester);
      await tester.enterText(_note, 'Özel taslak');
      await tester.ensureVisible(_publish);
      await tester.tap(_publish);
      await tester.pump();
      expect(h.key.currentState!.saving, isTrue);
      h.sessions.replace(audienceSession(token: 'replacement'));
      await tester.pumpAndSettle();
      pending.complete(
        Result.success(_state(published: true, note: 'Özel taslak')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Özel taslak'), findsNothing);
      expect(h.completed, isEmpty);
    },
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

TableGroupProfileShareState _state({
  bool published = false,
  bool eligible = true,
  String? note,
}) => TableGroupProfileShareState(
  tableGroupId: 'table',
  shareId: published ? 'share' : null,
  publishedOnProfile: published,
  note: published ? note : null,
  publishedAt: published ? DateTime.utc(2026, 9, 10) : null,
  canPublish: eligible,
  tableGroup: eligible
      ? TableGroupProfileShareSource(
          id: 'table',
          description: 'Birlikte müzik dinleyelim',
          venueName: null,
          cityName: 'Ankara',
          districtName: 'Çankaya',
          meetingAt: DateTime.utc(2100),
          expiresAt: DateTime.utc(2100, 1, 2),
          status: 'ACTIVE',
          maxPersonCount: 4,
          acceptedCount: 1,
        )
      : null,
);

class _Shares extends Fake implements TableGroupProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  var current = _state();
  int reads = 0;
  final notes = <String?>[];
  final deleted = <String>[];
  Result<TableGroupProfileShareState>? publishResult;
  Future<Result<TableGroupProfileShareState>>? pending;
  Result<void>? deleteResult;
  @override
  Future<Result<TableGroupProfileShareState>> getState({
    required String tableGroupId,
    required AuthSession expectedSession,
  }) async {
    reads++;
    return Result.success(current);
  }

  @override
  Future<Result<TableGroupProfileShareState>> publish({
    required String tableGroupId,
    String? note,
    required AuthSession expectedSession,
  }) async {
    notes.add(note);
    return pending ??
        publishResult ??
        Result.success(current = _state(published: true, note: note));
  }

  @override
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  }) async {
    deleted.add(shareId);
    return deleteResult ?? const Result.success(null);
  }
}

class _Harness {
  final repository = _Shares();
  final sessions = AudienceTestSessions(audienceSession());
  final completed = <bool>[];
  final key = GlobalKey<ListenerTableGroupDraftComposerState>();
  Future<void> mount(WidgetTester tester) async {
    addTearDown(() {
      repository.signal.dispose();
      sessions.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenerTableGroupDraftComposer(
              key: key,
              draft: TableGroupProfileDraftArgs(
                tableGroupId: 'table',
                expectedSession: sessions.session,
              ),
              profile: const ListenerProfile(
                id: 'profile',
                userId: 'listener',
                username: 'listener',
                bio: null,
                profilePictureUrl: null,
                followerCount: 0,
                followingCount: 0,
                visibilityChoiceCompleted: true,
                profileContentVisible: true,
                profileContentEditable: true,
              ),
              repository: repository,
              sessions: sessions,
              onFinished: completed.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
