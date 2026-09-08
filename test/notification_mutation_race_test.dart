import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart'
    as pagination;
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';

void main() {
  late _Repository repository;
  late NotificationCubit cubit;
  late NotificationRealtimeClient realtime;

  setUp(() {
    repository = _Repository();
    realtime = NotificationRealtimeClient();
    cubit = NotificationCubit(repository, _Tokens(), realtimeClient: realtime);
  });
  tearDown(() async {
    await cubit.close();
    await realtime.dispose();
  });

  test(
    'old refresh cannot restore unread after an acknowledged read',
    () async {
      await cubit.refresh();
      repository.pendingPage =
          Completer<Result<pagination.Page<AppNotification>>>();
      final refresh = cubit.refresh();
      await cubit.markAsRead(cubit.state.items.single);
      repository.pendingPage!.complete(_page([_notification()]));
      await refresh;
      expect(cubit.state.items.single.read, isTrue);
      expect(cubit.state.unreadCount, 0);
    },
  );

  test('old refresh cannot restore a locally read DM notification', () async {
    repository.items = [
      _notification(
        payload: {'module': 'DM', 'conversationId': 'conversation'},
      ),
    ];
    await cubit.refresh();
    repository.pendingPage =
        Completer<Result<pagination.Page<AppNotification>>>();
    final refresh = cubit.refresh();
    cubit.markDmConversationAsReadLocally('conversation');
    repository.pendingPage!.complete(_page(repository.items));
    await refresh;
    expect(cubit.state.items.single.read, isTrue);
    expect(cubit.state.unreadCount, 0);
  });

  test(
    'read acknowledgement during refresh preserves server notification order',
    () async {
      repository.items = [
        _notification(id: 'newest'),
        _notification(id: 'older'),
      ];
      await cubit.refresh();
      repository.pendingPage =
          Completer<Result<pagination.Page<AppNotification>>>();
      final refresh = cubit.refresh();
      await cubit.markAsRead(cubit.state.items.last);
      repository.pendingPage!.complete(_page(repository.items));
      await refresh;
      expect(cubit.state.items.map((item) => item.id), ['newest', 'older']);
      expect(cubit.state.items.first.read, isFalse);
      expect(cubit.state.items.last.read, isTrue);
      expect(cubit.state.unreadCount, 1);
    },
  );

  test(
    'old refresh cannot resurrect a successfully deleted notification',
    () async {
      await cubit.refresh();
      repository.pendingPage =
          Completer<Result<pagination.Page<AppNotification>>>();
      final refresh = cubit.refresh();
      await cubit.deleteNotification(cubit.state.items.single);
      repository.pendingPage!.complete(_page([_notification()]));
      await refresh;
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
    },
  );

  test('shifted pagination cannot reinsert a pending deletion', () async {
    await cubit.refresh();
    repository.pendingPage =
        Completer<Result<pagination.Page<AppNotification>>>();
    repository.pendingDeletion = Completer<Result<void>>();
    final more = cubit.loadMore();
    final deletion = cubit.deleteNotification(cubit.state.items.single);
    repository.pendingPage!.complete(
      _page([_notification(), _notification(id: 'other')]),
    );
    await more;
    expect(cubit.state.items.map((item) => item.id), ['other']);
    repository.pendingDeletion!.complete(const Result.success(null));
    await deletion;
  });

  test('pagination waits while a full refresh is in progress', () async {
    await cubit.refresh();
    repository.pendingPage =
        Completer<Result<pagination.Page<AppNotification>>>();
    final refresh = cubit.refresh();
    await cubit.loadMore();
    expect(repository.pages, [0, 0]);
    repository.pendingPage!.complete(_page([_notification()]));
    await refresh;
  });

  for (final payload in [
    {
      'module': 'ARTIST_VENUE',
      'requestByType': 'VENUE',
      'action': 'REQUEST_CREATED',
      'bandId': 'band',
    },
    {
      'module': 'ARTIST_VENUE',
      'requestByType': 'BAND',
      'action': 'REQUEST_ACCEPTED',
      'bandId': 'band',
    },
  ]) {
    testWidgets(
      'band connection notification ${payload['action']} resolves current band membership',
      (tester) async {
        repository.items = [_notification(payload: payload)];
        RouteSettings? opened;
        await tester.pumpWidget(
          BlocProvider<NotificationCubit>.value(
            value: cubit,
            child: MaterialApp(
              home: const NotificationScreen(),
              onGenerateRoute: (settings) {
                opened = settings;
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('destination')),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Notification'));
        await tester.pumpAndSettle();
        expect(opened?.name, AppRoutes.bandPublicProfile);
        final args = opened?.arguments as BandProfileScreenArgs;
        expect(args.bandId, 'band');
        expect(args.viewMode, BandProfileViewMode.public);
      },
    );
  }
}

AppNotification _notification({
  String id = 'notification',
  Map<String, dynamic> payload = const {},
}) => AppNotification(
  id: id,
  recipientId: 'account',
  type: 'ARTIST_VENUE',
  title: 'Notification',
  message: 'Message',
  read: false,
  createdAt: DateTime.utc(2026, 9),
  payload: payload,
);

Result<pagination.Page<AppNotification>> _page(List<AppNotification> items) =>
    Result.success(pagination.Page(items: items, hasNext: true));

class _Repository extends Fake implements NotificationRepository {
  List<AppNotification> items = [_notification()];
  final pages = <int>[];
  Completer<Result<pagination.Page<AppNotification>>>? pendingPage;
  Completer<Result<void>>? pendingDeletion;
  @override
  Future<Result<pagination.Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    return pendingPage?.future ?? _page(items);
  }

  @override
  Future<Result<int>> getUnreadCount() async => const Result.success(1);
  @override
  Future<Result<void>> markAsRead({required String notificationId}) async =>
      const Result.success(null);
  @override
  Future<Result<void>> deleteNotification({
    required String notificationId,
  }) async => pendingDeletion?.future ?? const Result.success(null);
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}
