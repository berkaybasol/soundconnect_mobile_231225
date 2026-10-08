import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/policy/access_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_listing.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/collab_access_gate.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_actor_reviews_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_application_compose_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_create_listing_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_incoming_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_listing_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_my_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_my_listings_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_profile_selection_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_saved_listings_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/share/collab_share_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/theme/collab_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/collab_test_support.dart';
import 'support/event_audience_fakes.dart';

void main() {
  late AudienceTestSessions sessions;
  setUp(() {
    sessions = AudienceTestSessions(audienceSession(role: 'MUSICIAN'));
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  });
  tearDown(() async {
    await serviceLocator.reset();
    sessions.dispose();
  });

  test('listener authority takes precedence over a business role', () {
    for (final role in ['MUSICIAN', 'VENUE', 'STUDIO']) {
      expect(AccessPolicy.canAccessCollab(['ROLE_LISTENER', role]), isFalse);
      expect(AccessPolicy.canAccessCollab([role]), isTrue);
    }
  });

  testWidgets('loaded listing disappears when the account becomes a listener', (
    tester,
  ) async {
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(),
    );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: CollabListingDetailScreen(
          listingId: 'listing-1',
          detailCubit: cubit,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(repository.listing.title), findsOneWidget);
    sessions.replace(audienceSession());
    await tester.pumpAndSettle();
    expect(find.text(repository.listing.title), findsNothing);
    expect(find.text('₺1.500,75'), findsNothing);
    expect(repository.detailCalls, 1);
    expect(tester.takeException(), isNull);
  });

  for (final entry in <String, Widget>{
    'discovery': const CollabDiscoveryScreen(),
    'detail': const CollabListingDetailScreen(listingId: 'listing-1'),
    'create': const CollabCreateListingScreen(),
    'incoming': const CollabIncomingApplicationsScreen(listingId: 'listing-1'),
    'own listings': const CollabMyListingsScreen(),
    'saved': const CollabSavedListingsScreen(),
    'applications and jobs': const CollabMyApplicationsScreen(),
    'actor reviews': const CollabActorReviewsScreen(actor: venueActor),
    'actor picker': const CollabProfileSelectionScreen(
      actors: [musicianActor],
      wantedType: CollabProfileKind.musician,
    ),
    'compose': CollabApplicationComposeScreen(
      listing: collabListingFixture(),
      initialActor: musicianActor,
      eligibleActors: const [musicianActor],
    ),
  }.entries) {
    testWidgets(
      'listener direct ${entry.key} entry does not construct data providers',
      (tester) async {
        sessions.replace(audienceSession());
        // No data Cubit/repository is registered. A denied widget must not fetch.
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.navy, home: entry.value),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('collab-access-unavailable')),
          findsOneWidget,
        );
        expect(find.text(collabListingFixture().title), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('delayed detail cannot revive a retired account route', (
    tester,
  ) async {
    final pending = Completer<Result<CollabListing>>();
    final repository = _DelayedDetailRepository(pending);
    late CollabListingDetailCubit ownedCubit;
    serviceLocator.registerFactory<CollabListingDetailCubit>(() {
      ownedCubit = CollabListingDetailCubit(repository);
      return ownedCubit;
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: const CollabListingDetailScreen(
          listingId: 'listing-1',
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pump();
    sessions.replace(audienceSession());
    await tester.pumpAndSettle();
    expect(ownedCubit.isClosed, isTrue);
    pending.complete(Result.success(collabListingFixture()));
    await tester.pumpAndSettle();
    expect(find.text(collabListingFixture().title), findsNothing);
    expect(find.byKey(const Key('collab-access-unavailable')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final newRole in ['LISTENER', 'MUSICIAN']) {
    testWidgets('share snapshot is hidden on replacement $newRole account', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showCollabShareSheet(context, collabListingFixture()),
                child: const Text('Open share'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open share'));
      await tester.pumpAndSettle();
      expect(find.text(collabListingFixture().title), findsOneWidget);
      sessions.replace(audienceSession(user: 'next-user', role: newRole));
      await tester.pumpAndSettle();
      expect(find.text(collabListingFixture().title), findsNothing);
      expect(
        find.byKey(const Key('collab-access-unavailable')),
        findsOneWidget,
      );
      await tester.tap(find.text('Geri dön'));
      await tester.pumpAndSettle();
      expect(find.text('Open share'), findsOneWidget);
    });
  }

  testWidgets(
    'refreshing the same account token preserves current form state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CollabAccessGate(
            builder: (_) => const Scaffold(body: TextField()),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Local draft');
      sessions.replace(
        audienceSession(role: 'MUSICIAN', token: 'refreshed-token'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local draft'), findsOneWidget);
      expect(find.byKey(const Key('collab-access-unavailable')), findsNothing);
    },
  );

  for (final surface in ['share', 'dialog', 'page']) {
    testWidgets('$surface captures the account before its first frame', (
      tester,
    ) async {
      final privateTitle = collabListingFixture().title;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  if (surface == 'share') {
                    showCollabShareSheet(context, collabListingFixture());
                  } else if (surface == 'dialog') {
                    showCollabDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(title: Text(privateTitle)),
                    );
                  } else {
                    Navigator.of(context).push(
                      collabPageRoute<void>(
                        context: context,
                        builder: (_) => Scaffold(body: Text(privateTitle)),
                      ),
                    );
                  }
                },
                child: const Text('Open old snapshot'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open old snapshot'));
      // Deliberately switch before pumping: route widgets do not exist yet.
      sessions.replace(
        audienceSession(user: 'different-musician', role: 'MUSICIAN'),
      );
      await tester.pumpAndSettle();
      expect(find.text(privateTitle), findsNothing);
      expect(
        find.byKey(const Key('collab-access-unavailable')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _DelayedDetailRepository extends FakeCollabDetailRepository {
  _DelayedDetailRepository(this.pending)
    : super(listing: collabListingFixture());
  final Completer<Result<CollabListing>> pending;

  @override
  Future<Result<CollabListing>> getListing(String listingId) => pending.future;
}
