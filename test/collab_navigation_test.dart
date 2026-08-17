import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_actor.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/collab_navigation.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_chat_screen.dart';

void main() {
  testWidgets(
    'band DM warning explains the personal account and cancel stops',
    (tester) async {
      final resolver = _FakeProfileResolver(const <DmProfileTarget>[]);
      RouteSettings? openedRoute;

      await tester.pumpWidget(
        _navigationApp(
          actor: _bandActor,
          resolver: resolver,
          onRoute: (settings) => openedRoute = settings,
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-collab-dm')));
      await tester.pumpAndSettle();

      expect(find.text('Grup yetkilisiyle mesajlaş'), findsOneWidget);
      expect(
        find.text(
          'Acoustic Route grubunun mesajlarını @deniz yanıtlıyor. '
          'Sohbete geçmek ister misin?',
        ),
        findsOneWidget,
      );
      expect(resolver.calls, 0);

      await tester.tap(
        find.byKey(const ValueKey<String>('band-representative-dm-cancel')),
      );
      await tester.pumpAndSettle();

      expect(openedRoute, isNull);
      expect(resolver.calls, 0);
    },
  );

  testWidgets(
    'band DM confirmation opens the representative musician account',
    (tester) async {
      final resolver = _FakeProfileResolver(const <DmProfileTarget>[
        DmProfileTarget(
          type: DmProfileTargetType.venue,
          id: 'venue-1',
          displayName: 'Başka Profil',
          imageUrl: 'https://cdn.example.com/venue.jpg',
        ),
        DmProfileTarget(
          type: DmProfileTargetType.musician,
          id: 'musician-1',
          displayName: 'Deniz Kaya',
          imageUrl: 'https://cdn.example.com/musician.jpg',
        ),
      ]);
      RouteSettings? openedRoute;

      await tester.pumpWidget(
        _navigationApp(
          actor: _bandActor,
          resolver: resolver,
          onRoute: (settings) => openedRoute = settings,
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-collab-dm')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('band-representative-dm-confirm')),
      );
      await tester.pumpAndSettle();

      expect(resolver.calls, 1);
      expect(resolver.lastUserId, 'user-band');
      expect(resolver.lastUsernameHint, 'deniz');
      expect(openedRoute?.name, AppRoutes.dmChat);
      final args = openedRoute?.arguments as DmChatScreenArgs;
      expect(args.otherUserId, 'user-band');
      expect(args.otherUsername, 'deniz');
      expect(
        args.otherUserProfilePicture,
        'https://cdn.example.com/musician.jpg',
      );
      expect(args.otherMusicianProfileId, 'musician-1');
      expect(args.otherUsername, isNot(_bandActor.displayName));
      expect(args.otherUserProfilePicture, isNot(_bandActor.avatarUrl));
    },
  );

  testWidgets('band DM resolver failure never falls back to band identity', (
    tester,
  ) async {
    final resolver = _FakeProfileResolver(
      const <DmProfileTarget>[],
      error: StateError('resolver unavailable'),
    );
    RouteSettings? openedRoute;
    const actorWithoutUsername = CollabActor(
      actorId: 'actor-band',
      profileType: CollabProfileKind.band,
      sourceProfileId: 'band-profile-1',
      contactUserId: 'user-band',
      displayName: 'Acoustic Route',
      avatarUrl: 'https://cdn.example.com/band.jpg',
      rating: 4.7,
      reviewCount: 9,
      completedJobCount: 21,
    );

    await tester.pumpWidget(
      _navigationApp(
        actor: actorWithoutUsername,
        resolver: resolver,
        onRoute: (settings) => openedRoute = settings,
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('open-collab-dm')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Acoustic Route grubunun mesajlarını grup yetkilisi yanıtlıyor. '
        'Sohbete geçmek ister misin?',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('band-representative-dm-confirm')),
    );
    await tester.pumpAndSettle();

    final args = openedRoute?.arguments as DmChatScreenArgs;
    expect(args.otherUsername, 'SoundConnect kullanıcısı');
    expect(args.otherUserProfilePicture, isNull);
    expect(args.otherMusicianProfileId, isNull);
    expect(args.otherUsername, isNot(actorWithoutUsername.displayName));
    expect(args.otherUserProfilePicture, isNot(actorWithoutUsername.avatarUrl));
  });

  testWidgets('non-band Collab DM behavior stays unchanged', (tester) async {
    final resolver = _FakeProfileResolver(const <DmProfileTarget>[]);
    RouteSettings? openedRoute;
    const musician = CollabActor(
      actorId: 'actor-musician',
      profileType: CollabProfileKind.musician,
      sourceProfileId: 'musician-profile-1',
      contactUserId: 'user-musician',
      displayName: 'Deniz Kaya',
      avatarUrl: 'https://cdn.example.com/deniz.jpg',
      rating: 4.9,
      reviewCount: 18,
      completedJobCount: 32,
    );

    await tester.pumpWidget(
      _navigationApp(
        actor: musician,
        resolver: resolver,
        onRoute: (settings) => openedRoute = settings,
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('open-collab-dm')));
    await tester.pumpAndSettle();

    expect(find.text('Grup yetkilisiyle mesajlaş'), findsNothing);
    expect(resolver.calls, 0);
    final args = openedRoute?.arguments as DmChatScreenArgs;
    expect(args.otherUserId, musician.contactUserId);
    expect(args.otherUsername, musician.displayName);
    expect(args.otherUserProfilePicture, musician.avatarUrl);
    expect(args.otherMusicianProfileId, musician.sourceProfileId);
  });
}

const _bandActor = CollabActor(
  actorId: 'actor-band',
  profileType: CollabProfileKind.band,
  sourceProfileId: 'band-profile-1',
  contactUserId: 'user-band',
  contactUsername: '@deniz',
  displayName: 'Acoustic Route',
  avatarUrl: 'https://cdn.example.com/band.jpg',
  rating: 4.7,
  reviewCount: 9,
  completedJobCount: 21,
);

Widget _navigationApp({
  required CollabActor actor,
  required DmUserProfileResolver resolver,
  required ValueChanged<RouteSettings> onRoute,
}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          key: const ValueKey<String>('open-collab-dm'),
          onPressed: () => openCollabActorConversation(
            context,
            actor,
            profileResolver: resolver,
          ),
          child: const Text('Mesaj Gönder'),
        ),
      ),
    ),
  ),
  onGenerateRoute: (settings) {
    onRoute(settings);
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(body: Text('DM hedefi')),
    );
  },
);

class _FakeProfileResolver implements DmUserProfileResolver {
  _FakeProfileResolver(this.targets, {this.error});

  final List<DmProfileTarget> targets;
  final Object? error;
  int calls = 0;
  String? lastUserId;
  String? lastUsernameHint;

  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async {
    calls += 1;
    lastUserId = userId;
    lastUsernameHint = usernameHint;
    final failure = error;
    if (failure != null) throw failure;
    return targets;
  }
}
