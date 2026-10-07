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
  bool failNextPage = false;
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
    if (page > 0 && failNextPage) {
      failNextPage = false;
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
    rows.removeWhere((n) => n.id == notificationId);
    return const Result.success(null);
  }
}

void main() {
  for (final failPage in [false, true]) {
    testWidgets(
      'refresh at the real scrolled boundary resumes paging with failPage=$failPage',
      (tester) async {
        final repo = _Repository();
        final realtime = _Realtime();
        final sessions = AudienceTestSessions(
          audienceSession(user: _owner, role: 'ROLE_MUSICIAN'),
        );
        final cubit = NotificationCubit(
          repo,
          _Tokens(),
          realtimeClient: realtime,
          sessions: sessions,
        );
        addTearDown(() async {
          await cubit.close();
          await realtime.dispose();
          sessions.dispose();
        });
        await cubit.ensureStarted();
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.android),
              home: const NotificationScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(Dismissible).first,
          const Offset(-700, 0),
        );
        await tester.pumpAndSettle();
        expect(repo.deleted, ['notice-1']);
        // Only real gestures advance pagination: no test calls to loadMore.
        for (var i = 0; i < 30; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pumpAndSettle();
          final scroll = tester
              .widget<ListView>(find.byType(ListView))
              .controller!;
          if (!cubit.state.hasNext && scroll.position.extentAfter < 1) break;
        }
        expect(cubit.state.items.map((n) => n.id), repo.rows.map((n) => n.id));
        final scroll = tester
            .widget<ListView>(find.byType(ListView))
            .controller!;
        expect(scroll.position.extentAfter, lessThan(1));
        expect(find.text('Notice 41'), findsOneWidget);
        final requestsBeforeRefresh = repo.pages.length;
        repo.failNextPage = failPage;
        repo.holdNextPage = true;
        await cubit.reconcileAfterResume();
        // Let the clamped layout trigger paging, then actually render its
        // spinner while the response is pending (including metrics frames).
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // A first-page background refresh clamps the offset during layout. It
        // must issue the next page without requiring a new scroll offset event.
        expect(repo.pages.sublist(requestsBeforeRefresh), [0, 1]);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(repo.pages.sublist(requestsBeforeRefresh), [0, 1]);
        repo.pendingPage!.complete();
        await tester.pumpAndSettle();
        if (failPage) {
          expect(cubit.state.errorMessage, isNotNull);
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(seconds: 1));
          }
          expect(
            repo.pages.sublist(requestsBeforeRefresh),
            [0, 1],
            reason:
                'Layout and spinner removal must not retry failed page requests.',
          );
          await tester.drag(find.byType(ListView), const Offset(0, 160));
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(cubit.state.items.map((n) => n.id), repo.rows.map((n) => n.id));
        expect(cubit.state.hasNext, isFalse);
        expect(repo.deleted, ['notice-1']);
        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pumpAndSettle();
        expect(find.text('Notice 41'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
