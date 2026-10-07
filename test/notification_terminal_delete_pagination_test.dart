import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';

import 'support/event_audience_fakes.dart';

const _owner = '22222222-2222-4222-8222-222222222222';

class _Tokens extends Fake implements TokenStore {}

class _Realtime extends NotificationRealtimeClient {
  @override
  bool get isConnected => true;
  @override
  Future<void> disconnect() async {}
}

class _Repository extends Fake implements NotificationRepository {
  final rows = List.generate(
    41,
    (index) => AppNotification(
      id: 'notice-${index + 1}',
      recipientId: _owner,
      type: 'SOCIAL_NEW_FOLLOWER',
      title: 'Notice ${index + 1}',
      message: '',
      read: false,
      createdAt: DateTime.utc(2026, 10, 7),
      payload: const {},
    ),
  );
  final pages = <int>[];
  final deleted = <String>[];
  Completer<void>? pendingDelete;
  bool failNextPage = false;
  bool failNextRequest = false;
  bool holdNextPage = false;
  Completer<void>? pendingPage;
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    if (page > 0 && holdNextPage) {
      holdNextPage = false;
      pendingPage = Completer<void>();
      await pendingPage!.future;
    }
    if (failNextRequest || (page > 0 && failNextPage)) {
      failNextPage = false;
      failNextRequest = false;
      return const Result.failure(
        AppError(code: 'offline', message: 'Offline'),
      );
    }
    return Result.success(
      Page(
        items: rows.skip(page * size).take(size).toList(),
        hasNext: (page + 1) * size < rows.length,
      ),
    );
  }

  @override
  Future<Result<int>> getUnreadCount() async => Result.success(rows.length);
  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async {
    deleted.add(notificationId);
    pendingDelete = Completer<void>();
    await pendingDelete!.future;
    rows.removeWhere((n) => n.id == notificationId);
    return const Result.success(null);
  }
}

void main() {
  for (final mode in [
    'late-response',
    'response-before-paging',
    'explicit-refresh-recovery',
    'repair-page-failure',
  ]) {
    testWidgets(
      'real inbox gestures after fully loaded pending DELETE mode=$mode',
      (tester) async {
        final repo = _Repository(), rt = _Realtime();
        final ss = AudienceTestSessions(
          audienceSession(user: _owner, role: 'ROLE_MUSICIAN'),
        );
        final c = NotificationCubit(
          repo,
          _Tokens(),
          realtimeClient: rt,
          sessions: ss,
        );
        addTearDown(() async {
          await c.close();
          await rt.dispose();
          ss.dispose();
        });
        await c.ensureStarted();
        await tester.pumpWidget(
          BlocProvider.value(
            value: c,
            child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.android),
              home: const NotificationScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> toBottom() async {
          for (var i = 0; i < 30; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -500));
            await tester.pumpAndSettle();
            final sc = tester
                .widget<ListView>(find.byType(ListView))
                .controller!;
            if (!c.state.hasNext && sc.position.extentAfter < 1) break;
          }
        }

        Future<void> toTop() async {
          for (var i = 0; i < 30; i++) {
            final sc = tester
                .widget<ListView>(find.byType(ListView))
                .controller!;
            if (sc.position.pixels < 1) break;
            final distance = (sc.position.pixels + 30).clamp(0.0, 500.0);
            await tester.drag(find.byType(ListView), Offset(0, distance));
            await tester.pumpAndSettle();
          }
          expect(
            tester
                .widget<ListView>(find.byType(ListView))
                .controller!
                .position
                .pixels,
            lessThan(1),
          );
        }

        await toBottom();
        expect(c.state.items.length, 41);
        expect(c.state.hasNext, isFalse);
        await toTop();
        expect(c.state.items.length, 41);
        expect(c.state.hasNext, isFalse);
        expect(find.text('Notice 1'), findsOneWidget);
        await tester.drag(
          find.byType(Dismissible).first,
          const Offset(-700, 0),
        );
        await tester.pumpAndSettle();
        expect(repo.deleted, ['notice-1']);
        expect(repo.pendingDelete, isNotNull);
        final beforeRefresh = repo.pages.length;
        // Actual RefreshIndicator drag, not a direct Cubit refresh call.
        await tester.drag(find.byType(ListView), const Offset(0, 500));
        await tester.pumpAndSettle();
        expect(repo.pages.sublist(beforeRefresh), [0]);
        expect(c.state.items.length, 19);
        expect(c.state.hasNext, isTrue);
        // Server commits while the HTTP DELETE response is still pending.
        repo.rows.removeWhere((n) => n.id == 'notice-1');
        if (mode == 'response-before-paging') {
          repo.pendingDelete!.complete();
          await tester.pumpAndSettle();
        }
        await toBottom();
        if (mode != 'response-before-paging') {
          if (mode == 'repair-page-failure') repo.failNextRequest = true;
          repo.pendingDelete!.complete();
          await tester.pumpAndSettle();
        }
        if (mode == 'repair-page-failure') {
          expect(c.state.errorMessage, 'Offline');
          final requestsAfterFailure = repo.pages.length;
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(seconds: 1));
          }
          expect(repo.pages.length, requestsAfterFailure);
          expect(repo.deleted, ['notice-1']);
          await tester.drag(find.byType(ListView), const Offset(0, 180));
          await tester.pumpAndSettle();
        } else {
          // At the clamped bottom, DELETE completion alone must recover the
          // gap without another scroll gesture or a fresh first-page refresh.
          expect(c.state.items.map((n) => n.id), repo.rows.map((n) => n.id));
          expect(c.state.hasNext, isFalse);
        }
        await toBottom(); // Further real scrolling must not silently stall.
        debugPrint(
          'WIDGET mode=$mode actual=${c.state.items.map((n) => n.id).toList()} unread=${c.state.unreadCount} hasNext=${c.state.hasNext} pages=${repo.pages}',
        );
        if (mode == 'explicit-refresh-recovery') {
          await toTop();
          await tester.drag(find.byType(ListView), const Offset(0, 500));
          await tester.pumpAndSettle();
          await toBottom();
        }
        expect(c.state.unreadCount, 40);
        expect(repo.deleted, ['notice-1']);
        expect(c.state.items.map((n) => n.id), repo.rows.map((n) => n.id));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
