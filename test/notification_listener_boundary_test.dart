import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late AudienceTestSessions sessions;
  late _Repository repository;
  late _Realtime realtime;
  late NotificationCubit cubit;

  setUp(() {
    sessions = AudienceTestSessions(audienceSession(user: 'account'));
    repository = _Repository();
    realtime = _Realtime();
    cubit = NotificationCubit(
      repository,
      _Tokens(),
      sessions: sessions,
      realtimeClient: realtime,
    );
  });

  tearDown(() async {
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  });

  test(
    'listener inbox and later pages reject business rows before render',
    () async {
      repository.pages = {
        0: [
          _item('reservation', 'STUDIO_RESERVATION_APPROVED'),
          _item('collab', 'COLLAB_APPLICATION_RECEIVED'),
          _item('band', 'BAND_INVITE_RECEIVED'),
          _item('social', 'SOCIAL_NEW_BAND_FOLLOWER'),
        ],
        1: [
          _item('event', 'EVENT_PERFORMER_APPROVAL_REQUESTED'),
          _item('link', 'ARTIST_VENUE_LINK_APPLICATION_ACCEPT'),
          _item('venue', 'VENUE_APPLICATION_REJECTED'),
          _item('table', 'TABLE_JOIN_REQUEST_APPROVED'),
        ],
      };
      await cubit.ensureStarted();
      await cubit.loadMore();
      expect(cubit.state.items.map((item) => item.id), ['social', 'table']);
      expect(cubit.state.hasNext, isFalse);
    },
  );

  test(
    'listener keeps account, media, social, table and personal messages',
    () async {
      const types = [
        'AUTH_EMAIL_VERIFIED',
        'MEDIA_TRANSCODE_READY',
        'SOCIAL_LIKE',
        'SOCIAL_COMMENT',
        'SOCIAL_NEW_BAND_FOLLOWER',
        'DM_NEW_MESSAGE',
        'TABLE_CANCELLED',
        'OVERTHINKING_REVEAL_REQUEST_APPROVED',
      ];
      repository.pages = {
        0: [for (final type in types) _item(type, type)],
      };
      await cubit.ensureStarted();
      expect(cubit.state.items.map((item) => item.type), types);
    },
  );

  test(
    'business realtime frames never create a row or increase the badge',
    () async {
      await cubit.ensureStarted();
      final emitted = <List<AppNotification>>[];
      final subscription = cubit.stream.listen(
        (state) => emitted.add(state.items),
      );
      realtime.notifications.add(
        _item('reservation', 'STUDIO_RESERVATION_APPROVED'),
      );
      realtime.notifications.add(_item('job', 'COLLAB_JOB_COMPLETED'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
      expect(emitted.expand((items) => items), isEmpty);
      realtime.notifications.add(_item('message', 'DM_NEW_MESSAGE'));
      expect(cubit.state.items.single.id, 'message');
      expect(cubit.state.unreadCount, 1);
      await subscription.cancel();
    },
  );

  test(
    'canonical type cannot be bypassed by a social payload module',
    () async {
      repository.pages = {
        0: [
          _item('hidden', 'STUDIO_RESERVATION_APPROVED', module: 'SOCIAL'),
          _item('visible', 'SOCIAL_COMMENT', module: 'COLLAB'),
        ],
      };
      await cubit.ensureStarted();
      expect(cubit.state.items.single.id, 'visible');
    },
  );

  testWidgets('count-only frames reconcile without flashing a business badge', (
    tester,
  ) async {
    await cubit.ensureStarted();
    realtime.badges.add(12);
    expect(cubit.state.unreadCount, 0);
    repository.unread = 2;
    await tester.pump(const Duration(milliseconds: 251));
    expect(cubit.state.unreadCount, 2);
    expect(repository.reads, 2);
  });

  test(
    'same-account musician to listener switch clears old rows immediately',
    () async {
      sessions.replace(audienceSession(user: 'account', role: 'ROLE_MUSICIAN'));
      repository.pages = {
        0: [_item('old-business', 'COLLAB_JOB_COMPLETED')],
      };
      await cubit.ensureStarted();
      expect(cubit.state.items.single.id, 'old-business');
      final pending = Completer<Result<Page<AppNotification>>>();
      repository.pendingPage = pending.future;
      final oldRefresh = cubit.refresh();
      repository.pendingPage = null;
      repository.pages = {
        0: [_item('new-social', 'SOCIAL_COMMENT')],
      };
      sessions.replace(
        audienceSession(user: 'account', token: 'listener-token'),
      );
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
      await cubit.ensureStarted();
      pending.complete(
        Result.success(
          Page(
            items: [_item('late-business', 'BAND_INVITE_RECEIVED')],
            hasNext: false,
          ),
        ),
      );
      await oldRefresh;
      expect(cubit.state.items.map((item) => item.id), ['new-social']);
    },
  );

  test(
    'listener startup does not wait for an old audience network request',
    () async {
      sessions.replace(audienceSession(user: 'account', role: 'ROLE_MUSICIAN'));
      final oldPage = Completer<Result<Page<AppNotification>>>();
      repository.pendingPage = oldPage.future;
      final oldStartup = cubit.ensureStarted();
      await Future<void>.delayed(Duration.zero);
      repository.pendingPage = null;
      repository.pages = {
        0: [_item('current', 'SOCIAL_COMMENT')],
      };
      sessions.replace(audienceSession(user: 'account', token: 'new-listener'));
      final newStartup = cubit.ensureStarted();
      await Future<void>.delayed(Duration.zero);
      final currentIds = cubit.state.items.map((item) => item.id).toList();
      oldPage.complete(
        Result.success(
          Page(
            items: [_item('old-business', 'COLLAB_JOB_COMPLETED')],
            hasNext: false,
          ),
        ),
      );
      await Future.wait([oldStartup, newStartup]);
      expect(currentIds, ['current']);
      expect(cubit.state.items.map((item) => item.id), ['current']);
    },
  );

  test(
    'delayed old startup token read cannot disconnect the new listener socket',
    () async {
      final localSessions = AudienceTestSessions(
        audienceSession(user: 'musician-a', role: 'ROLE_MUSICIAN'),
      );
      final tokens = _DelayedFirstTokens();
      final socket = _ConnectableRealtime();
      final localCubit = NotificationCubit(
        _Repository(),
        tokens,
        sessions: localSessions,
        realtimeClient: socket,
      );
      addTearDown(() async {
        if (!tokens.firstRead.isCompleted) tokens.firstRead.complete(null);
        await localCubit.close();
        await socket.dispose();
        localSessions.dispose();
      });

      final oldStartup = localCubit.ensureStarted();
      await tokens.firstReadStarted.future;
      localSessions.replace(
        audienceSession(user: 'listener-b', token: 'listener-b-token'),
      );
      await localCubit.ensureStarted();
      expect(socket.isConnected, isTrue);
      expect(socket.connectedUserId, 'listener-b');
      expect(socket.connects, ['listener-b']);
      final disconnectsAfterNewConnection = socket.disconnects;

      tokens.firstRead.complete('musician-a-token');
      await oldStartup;
      expect(socket.isConnected, isTrue);
      expect(socket.connectedUserId, 'listener-b');
      expect(socket.connects, ['listener-b']);
      expect(socket.disconnects, disconnectsAfterNewConnection);
    },
  );

  test('guest transition clears rows and fences a delayed page', () async {
    repository.pages = {
      0: [_item('social', 'SOCIAL_COMMENT')],
    };
    await cubit.ensureStarted();
    final pending = Completer<Result<Page<AppNotification>>>();
    repository.pendingPage = pending.future;
    final refresh = cubit.refresh();
    sessions.replace(const AuthSession.guest());
    expect(cubit.state.items, isEmpty);
    pending.complete(
      Result.success(
        Page(items: [_item('old', 'SOCIAL_COMMENT')], hasNext: false),
      ),
    );
    await refresh;
    await cubit.stop();
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.unreadCount, 0);
  });

  test(
    'a listener authority still hides business in a mixed-role projection',
    () async {
      sessions.replace(
        audienceSession(
          user: 'account',
          roles: ['ROLE_LISTENER', 'ROLE_MUSICIAN'],
        ),
      );
      repository.pages = {
        0: [_item('business', 'COLLAB_JOB_COMPLETED')],
      };
      await cubit.ensureStarted();
      expect(cubit.state.items, isEmpty);
    },
  );

  test(
    'musician business inbox and realtime notifications remain available',
    () async {
      sessions.replace(audienceSession(user: 'account', role: 'ROLE_MUSICIAN'));
      repository.pages = {
        0: [_item('collab', 'COLLAB_JOB_COMPLETED')],
      };
      await cubit.ensureStarted();
      realtime.notifications.add(
        _item('studio', 'STUDIO_RESERVATION_APPROVED'),
      );
      expect(cubit.state.items.map((item) => item.id), ['studio', 'collab']);
      realtime.badges.add(5);
      expect(cubit.state.unreadCount, 5);
    },
  );

  test(
    'listener does not project a stale response for another recipient',
    () async {
      repository.pages = {
        0: [_item('wrong-account', 'SOCIAL_COMMENT', recipient: 'other')],
      };
      await cubit.ensureStarted();
      expect(cubit.state.items, isEmpty);
    },
  );
}

AppNotification _item(
  String id,
  String type, {
  String recipient = 'account',
  String? module,
}) => AppNotification(
  id: id,
  recipientId: recipient,
  type: type,
  title: id,
  message: id,
  read: false,
  createdAt: DateTime.utc(2026, 9, 14),
  payload: {if (module != null) 'module': module},
);

class _Repository extends Fake implements NotificationRepository {
  Map<int, List<AppNotification>> pages = {0: []};
  Future<Result<Page<AppNotification>>>? pendingPage;
  int unread = 0;
  int reads = 0;
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async {
    reads++;
    return pendingPage ??
        Result.success(
          Page(items: pages[page] ?? [], hasNext: pages.containsKey(page + 1)),
        );
  }

  @override
  Future<Result<int>> getUnreadCount() async => Result.success(unread);
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => 'token';
}

// These fixtures model a delayed secure-storage read and actual connection
// state, leaving the existing inbox/realtime fixtures unchanged.
class _DelayedFirstTokens extends Fake implements TokenStore {
  final firstReadStarted = Completer<void>();
  final firstRead = Completer<String?>();
  int reads = 0;

  @override
  Future<String?> readToken() {
    if (++reads == 1) {
      firstReadStarted.complete();
      return firstRead.future;
    }
    return Future.value('listener-b-token');
  }
}

class _ConnectableRealtime extends NotificationRealtimeClient {
  String? connectedUserId;
  final connects = <String>[];
  int disconnects = 0;

  @override
  bool get isConnected => connectedUserId != null;

  @override
  Future<void> connect({required String userId, required String token}) async {
    connectedUserId = userId;
    connects.add(userId);
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    connectedUserId = null;
  }
}

class _Realtime extends NotificationRealtimeClient {
  final notifications = StreamController<AppNotification>.broadcast(sync: true);
  final badges = StreamController<int>.broadcast(sync: true);
  @override
  Stream<AppNotification> get notificationStream => notifications.stream;
  @override
  Stream<int> get badgeStream => badges.stream;
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await notifications.close();
    await badges.close();
    await super.dispose();
  }
}
