import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/realtime_client_error.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_chat_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_message.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_game_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_detail_screen.dart';

import 'support/event_audience_fakes.dart';

// Observe the real public ChangeNotifier protocol without replacing dispatch
// or cleanup, wrapping callbacks, or reading ChangeNotifier's private storage.
mixin _ListenerCalls on ChangeNotifier {
  final added = <VoidCallback>[];
  final removed = <VoidCallback>[];
  bool get observed => hasListeners;

  @override
  void addListener(VoidCallback listener) {
    added.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removed.add(listener);
    super.removeListener(listener);
  }
}

class _RefreshSignal extends ValueNotifier<int> with _ListenerCalls {
  _RefreshSignal() : super(0);
}

class _Sessions extends AudienceTestSessions with _ListenerCalls {
  _Sessions(super.current);
}

class _Posts extends AudienceTestRepository {
  final profiles = <String>[];

  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    profiles.add(listenerProfileId);
    return const Result.success(
      EventAudiencePage(
        items: [],
        page: 0,
        size: 20,
        totalElements: 0,
        totalPages: 0,
        hasNext: false,
      ),
    );
  }
}

class _Tables extends Fake implements TableGroupRepository {}

class _Games extends Fake implements TableGroupGameRepository {}

class _Tokens extends Fake implements TokenStore {
  final pending = Completer<String?>();
  @override
  Future<String?> readToken() => pending.future;
}

class _Realtime extends Fake implements TableGroupChatRealtimeClient {
  @override
  Stream<TableGroupMessage> get messageStream => const Stream.empty();
  @override
  Stream<void> get connectionStream => const Stream.empty();
  @override
  Stream<RealtimeClientError> get errorStream => const Stream.empty();
  @override
  Future<void> disconnect() async {}
}

Widget _profile(
  _RefreshSignal? signal,
  _Posts repository,
  _Sessions sessions, {
  String profile = 'profile',
}) => MaterialApp(
  home: Scaffold(
    body: ListenerEventPostsSection(
      listenerProfileId: profile,
      username: 'listener',
      refreshSignal: signal,
      repository: repository,
      sessions: sessions,
    ),
  ),
);

void main() {
  testWidgets(
    'actual TableGroupDetailScreen removes long-lived session listener on dispose',
    (tester) async {
      final sessions = _Sessions(const AuthSession.guest());
      addTearDown(sessions.dispose);
      for (var cycle = 0; cycle < 3; cycle++) {
        await tester.pumpWidget(
          MaterialApp(
            home: TableGroupDetailScreen(
              args: const TableGroupDetailArgs(
                tableGroupId: 'table',
                openChat: false,
              ),
              repository: _Tables(),
              gameRepository: _Games(),
              tokenStore: _Tokens(),
              sessions: sessions,
              realtimeClient: _Realtime(),
            ),
          ),
        );
        expect(sessions.observed, isTrue);
        expect(sessions.added, hasLength(cycle + 1));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(
          sessions.observed,
          isFalse,
          reason: 'caller-owned session must release disposed table State',
        );
        expect(sessions.removed, orderedEquals(sessions.added));
        // The owner can still use the notifier after the screen closes.
        sessions.replace(audienceSession(user: 'next-$cycle'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'actual ListenerEventPostsSection removes externally owned refresh listener on dispose',
    (tester) async {
      final signal = _RefreshSignal();
      final sessions = _Sessions(audienceSession());
      final posts = _Posts();
      addTearDown(signal.dispose);
      addTearDown(sessions.dispose);
      addTearDown(posts.signal.dispose);
      for (var cycle = 0; cycle < 3; cycle++) {
        await tester.pumpWidget(_profile(signal, posts, sessions));
        await tester.pumpAndSettle();
        expect(signal.observed, isTrue);
        expect(signal.added, hasLength(cycle + 1));
        var calls = posts.profiles.length;
        signal.value++;
        await tester.pumpAndSettle();
        expect(posts.profiles, hasLength(calls + 1));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(
          signal.observed,
          isFalse,
          reason: 'disposed product State must detach from caller signal',
        );
        expect(signal.removed, orderedEquals(signal.added));
        expect(sessions.observed, isFalse);
        calls = posts.profiles.length;
        signal.value++;
        await tester.pump();
        expect(posts.profiles, hasLength(calls));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'actual ListenerEventPostsSection removes old refresh source on didUpdateWidget',
    (tester) async {
      final oldSignal = _RefreshSignal();
      final nextSignal = _RefreshSignal();
      final sessions = _Sessions(audienceSession());
      final posts = _Posts();
      addTearDown(oldSignal.dispose);
      addTearDown(nextSignal.dispose);
      addTearDown(sessions.dispose);
      addTearDown(posts.signal.dispose);
      await tester.pumpWidget(_profile(oldSignal, posts, sessions));
      await tester.pumpAndSettle();
      expect(oldSignal.observed, isTrue);
      for (final signal in [nextSignal, null, oldSignal, nextSignal]) {
        await tester.pumpWidget(_profile(signal, posts, sessions));
        await tester.pumpAndSettle();
        expect(
          oldSignal.observed,
          identical(signal, oldSignal),
          reason: 'replaced source must detach while State stays mounted',
        );
        expect(nextSignal.observed, identical(signal, nextSignal));
        final calls = posts.profiles.length;
        oldSignal.value++;
        nextSignal.value++;
        await tester.pumpAndSettle();
        expect(posts.profiles, hasLength(calls + (signal == null ? 0 : 1)));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(oldSignal.observed, isFalse);
      expect(nextSignal.observed, isFalse);
      expect(oldSignal.removed, orderedEquals(oldSignal.added));
      expect(nextSignal.removed, orderedEquals(nextSignal.added));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('old refresh source cannot reload the current profile feed', (
    tester,
  ) async {
    final oldSignal = _RefreshSignal();
    final nextSignal = _RefreshSignal();
    final sessions = _Sessions(audienceSession());
    final posts = _Posts();
    addTearDown(oldSignal.dispose);
    addTearDown(nextSignal.dispose);
    addTearDown(sessions.dispose);
    addTearDown(posts.signal.dispose);
    await tester.pumpWidget(_profile(oldSignal, posts, sessions));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _profile(nextSignal, posts, sessions, profile: 'next-profile'),
    );
    await tester.pumpAndSettle();
    final calls = posts.profiles.length;
    expect(posts.profiles.last, 'next-profile');
    oldSignal.value++;
    await tester.pumpAndSettle();
    expect(
      posts.profiles,
      hasLength(calls),
      reason: 'old external source must not trigger work on the new feed',
    );
    nextSignal.value++;
    await tester.pumpAndSettle();
    expect(posts.profiles, hasLength(calls + 1));
    expect(posts.profiles.last, 'next-profile');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'rebind keeps one refresh callback and detaches old feed sources',
    (tester) async {
      final signal = _RefreshSignal();
      addTearDown(signal.dispose);
      _Sessions? previousSessions;
      _Posts? previousPosts;
      for (var cycle = 0; cycle < 3; cycle++) {
        final sessions = _Sessions(audienceSession(user: 'viewer-$cycle'));
        final posts = _Posts();
        addTearDown(sessions.dispose);
        addTearDown(posts.signal.dispose);
        await tester.pumpWidget(
          _profile(signal, posts, sessions, profile: 'profile-$cycle'),
        );
        await tester.pumpAndSettle();
        expect(signal.added, hasLength(1));
        expect(signal.observed, isTrue);
        expect(previousSessions?.observed ?? false, isFalse);
        final calls = posts.profiles.length;
        final oldCalls = previousPosts?.profiles.length;
        previousSessions?.replace(audienceSession(user: 'obsolete'));
        previousPosts?.signal.value++;
        await tester.pumpAndSettle();
        expect(posts.profiles, hasLength(calls));
        expect(previousPosts?.profiles.length, oldCalls);
        signal.value++;
        await tester.pumpAndSettle();
        expect(posts.profiles, hasLength(calls + 1));
        expect(posts.profiles.last, 'profile-$cycle');
        previousSessions = sessions;
        previousPosts = posts;
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(signal.observed, isFalse);
      expect(signal.removed, orderedEquals(signal.added));
      expect(previousSessions!.observed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
