import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_listing_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/collab_test_support.dart';

void main() {
  Widget detailApp(
    CollabListingDetailCubit cubit, {
    String listingId = 'listing-1',
  }) => MaterialApp(
    theme: AppTheme.navy,
    home: CollabListingDetailScreen(
      listingId: listingId,
      detailCubit: cubit,
      showBottomNavigation: false,
    ),
  );

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
}
