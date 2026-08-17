import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_page.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_listing.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_review.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_actor_reviews_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_actor_reviews_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_listing_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/share/collab_share_service.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/collab_test_support.dart';

void main() {
  Widget detailApp(
    CollabListingDetailCubit cubit, {
    String listingId = 'listing-1',
    CollabShareService? shareService,
    RouteFactory? onGenerateRoute,
  }) => MaterialApp(
    theme: AppTheme.navy,
    onGenerateRoute: onGenerateRoute,
    home: CollabListingDetailScreen(
      listingId: listingId,
      detailCubit: cubit,
      shareService: shareService,
      showBottomNavigation: false,
    ),
  );

  test('share message uses the permanent SoundConnect listing URL', () {
    final message = const CollabShareMessageBuilder().build(
      collabListingFixture(),
    );

    expect(message, contains('İlan detayını SoundConnect’te görüntüle.'));
    expect(
      message,
      contains('https://soundconnect.com.tr/is-birligi/ilan/listing-1'),
    );
    expect(message, isNot(contains('Henüz üye değil misin?')));
    expect(message, isNot(contains('İlan kodu')));
  });

  test('share message appends the configured production listing URL', () {
    const builder = CollabShareMessageBuilder(
      listingBaseUrl: 'https://soundconnect.example/is-birligi/ilanlar/',
    );

    final message = builder.build(collabListingFixture());

    expect(
      message,
      contains('https://soundconnect.example/is-birligi/ilanlar/listing-1'),
    );
  });

  testWidgets('extra detail shows date, exact fee and approved job fields', (
    tester,
  ) async {
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(),
    );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(detailApp(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Çarşamba gecesi bas gitarist arıyoruz'), findsOneWidget);
    expect(find.textContaining('12.08.2026'), findsOneWidget);
    expect(find.text('₺1.500,75'), findsOneWidget);
    expect(find.text('Funk, Rock, Alternatif'), findsOneWidget);
    expect(find.text('Performans Süresi'), findsNothing);
    expect(find.text('Ekipman'), findsNothing);
    expect(find.text('Prova'), findsNothing);
    expect(find.text('Ulaşım'), findsNothing);
  });

  testWidgets('regular musician detail omits date and fee', (tester) async {
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(
        cadence: CollabCadence.regular,
        publisher: musicianActor,
        feeAmountMinor: 1000000,
      ),
    );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(detailApp(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Ücret'), findsNothing);
    expect(find.text('₺10.000'), findsNothing);
    expect(find.textContaining('12.08.2026'), findsNothing);
  });

  testWidgets('regular venue states when fee was not provided', (tester) async {
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(
        cadence: CollabCadence.regular,
        feeAmountMinor: null,
      ),
    );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(detailApp(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Ücret'), findsOneWidget);
    expect(find.text('Ücret belirtilmemiş'), findsOneWidget);
  });

  testWidgets('bookmark action calls repository and updates real state', (
    tester,
  ) async {
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(),
    );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(detailApp(cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('İlanı kaydet'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(cubit.state.listing?.savedByMe, isTrue);
    expect(find.byTooltip('Kaydedilenlerden çıkar'), findsOneWidget);
  });

  testWidgets('owner card exposes profile and Collab review destinations', (
    tester,
  ) async {
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(),
    );
    final cubit = CollabListingDetailCubit(repository);
    RouteSettings? openedRoute;
    addTearDown(cubit.close);

    await tester.pumpWidget(
      detailApp(
        cubit,
        onGenerateRoute: (settings) {
          openedRoute = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Profil hedefi')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final ownerCard = find.byKey(const ValueKey<String>('collab-owner-card'));
    await tester.scrollUntilVisible(
      ownerCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(ownerCard);
    await tester.pumpAndSettle();

    expect(find.text('Profili görüntüle'), findsOneWidget);
    expect(find.text('Collab değerlendirmelerini gör'), findsOneWidget);
    expect(find.text('42 değerlendirme · 4.8 / 5'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('collab-owner-profile-action')),
    );
    await tester.pumpAndSettle();

    expect(openedRoute?.name, AppRoutes.venuePublicProfile);
    final arguments = openedRoute?.arguments as VenuePublicProfileArgs;
    expect(arguments.venueId, 'venue-profile-1');
  });

  testWidgets('owner review action opens the matching Collab reviews screen', (
    tester,
  ) async {
    final repository = _DetailWithReviewsRepository(
      listing: collabListingFixture(),
    );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);
    if (serviceLocator.isRegistered<CollabActorReviewsCubit>()) {
      await serviceLocator.unregister<CollabActorReviewsCubit>();
    }
    serviceLocator.registerFactory<CollabActorReviewsCubit>(
      () => CollabActorReviewsCubit(repository),
    );
    addTearDown(() async {
      if (serviceLocator.isRegistered<CollabActorReviewsCubit>()) {
        await serviceLocator.unregister<CollabActorReviewsCubit>();
      }
    });

    await tester.pumpWidget(detailApp(cubit));
    await tester.pumpAndSettle();

    final ownerCard = find.byKey(const ValueKey<String>('collab-owner-card'));
    await tester.scrollUntilVisible(
      ownerCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(ownerCard);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('collab-owner-reviews-action')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CollabActorReviewsScreen), findsOneWidget);
    expect(find.text('Collab Değerlendirmeleri'), findsOneWidget);
    expect(find.text('Collab değerlendirmelerini gör'), findsNothing);
  });

  testWidgets('owner can close the listing after destructive confirmation', (
    tester,
  ) async {
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(ownedByMe: true),
    );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(detailApp(cubit));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('İlanı Kapat'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('İlanı Kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'İlanı Kapat'));
    await tester.pumpAndSettle();

    expect(repository.closeCalls, 1);
    expect(cubit.state.listing?.status, CollabListingStatus.closed);
    expect(find.text('İlan Kapandı'), findsWidgets);
  });

  testWidgets('detail error can retry the same real listing id', (
    tester,
  ) async {
    final repository =
        FakeCollabDetailRepository(
            listing: collabListingFixture(id: 'retry-listing'),
          )
          ..detailError = const AppError(
            code: 'temporary',
            message: 'İlan şu an getirilemedi.',
          );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(detailApp(cubit, listingId: 'retry-listing'));
    await tester.pumpAndSettle();
    expect(find.text('İlan şu an getirilemedi.'), findsOneWidget);

    repository.detailError = null;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();

    expect(repository.detailCalls, 2);
    expect(find.text('Çarşamba gecesi bas gitarist arıyoruz'), findsOneWidget);
  });

  testWidgets('share opens branded preview and routes WhatsApp explicitly', (
    tester,
  ) async {
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(cadence: CollabCadence.regular),
    );
    final cubit = CollabListingDetailCubit(repository);
    final shareService = _RecordingShareService();
    addTearDown(cubit.close);

    await tester.pumpWidget(detailApp(cubit, shareService: shareService));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    expect(find.text('İlanı paylaş'), findsOneWidget);
    expect(find.text('COLLAB'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('collab-share-card')),
        matching: find.text('Düzenli'),
      ),
      findsNothing,
    );
    expect(find.text('#İŞBİRLİĞİ'), findsNothing);
    expect(find.text('Instagram\nHikâyesi'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.byKey(const Key('collab-share-whatsapp')), findsOneWidget);

    await tester.tap(find.byKey(const Key('collab-share-whatsapp')));
    await tester.pumpAndSettle();

    expect(shareService.targets, <CollabShareTarget>[
      CollabShareTarget.whatsapp,
    ]);
    expect(shareService.listingIds, <String>['listing-1']);
  });

  testWidgets('non-Android share sheet only promises generic system sharing', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(cadence: CollabCadence.regular),
    );
    final cubit = CollabListingDetailCubit(repository);
    final shareService = _RecordingShareService();
    addTearDown(cubit.close);

    await tester.pumpWidget(detailApp(cubit, shareService: shareService));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Instagram\nHikâyesi'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.byKey(const Key('collab-share-generic')), findsOneWidget);
    expect(find.text('Paylaş'), findsOneWidget);

    await tester.tap(find.byKey(const Key('collab-share-generic')));
    await tester.pumpAndSettle();

    expect(shareService.targets, <CollabShareTarget>[CollabShareTarget.other]);
    debugDefaultTargetPlatformOverride = null;
  });
}

class _RecordingShareService implements CollabShareService {
  final List<CollabShareTarget> targets = <CollabShareTarget>[];
  final List<String> listingIds = <String>[];

  @override
  Future<void> share(
    BuildContext context,
    CollabListing listing,
    CollabShareTarget target,
  ) async {
    targets.add(target);
    listingIds.add(listing.id);
  }
}

class _DetailWithReviewsRepository extends FakeCollabDetailRepository {
  _DetailWithReviewsRepository({required super.listing});

  @override
  Future<Result<CollabPage<CollabReview>>> getActorReviews(
    String actorId, {
    int page = 0,
    int size = 20,
  }) async => Result<CollabPage<CollabReview>>.success(
    CollabPage<CollabReview>(
      items: const <CollabReview>[],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      first: true,
      last: true,
    ),
  );
}
