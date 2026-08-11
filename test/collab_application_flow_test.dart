import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_application_compose_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_listing_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_profile_selection_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/collab_test_support.dart';

void main() {
  Widget app(Widget home) => MaterialApp(theme: AppTheme.navy, home: home);

  Widget composeApp(CollabListingDetailCubit cubit) => app(
    BlocProvider<CollabListingDetailCubit>.value(
      value: cubit,
      child: CollabApplicationComposeScreen(
        listing: cubit.state.listing!,
        initialActor: musicianActor,
        eligibleActors: const [musicianActor],
        showBottomNavigation: false,
      ),
    ),
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      400,
      scrollable: find.byType(Scrollable).last,
    );
  }

  testWidgets('profile selection exposes only actors matching wanted type', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const CollabProfileSelectionScreen(
          actors: [musicianActor, bandActor],
          wantedType: CollabProfileKind.musician,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil Seç'), findsOneWidget);
    expect(find.text('Deniz Kaya'), findsOneWidget);
    expect(find.text('Acoustic Route'), findsNothing);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
    expect(find.textContaining('Doğrulan'), findsNothing);
  });

  testWidgets(
    'application form starts empty, validates phone and allows blank message',
    (tester) async {
      final repository =
          FakeCollabDetailRepository(
              listing: collabListingFixture(),
              actors: const [musicianActor],
            )
            ..applyError = const AppError(
              code: 'temporary',
              message: 'Test hata yanıtı',
            );
      final cubit = CollabListingDetailCubit(repository);
      addTearDown(cubit.close);
      await cubit.load('listing-1');

      await tester.pumpWidget(composeApp(cubit));
      await tester.pumpAndSettle();

      final phoneField = tester.widget<TextFormField>(
        find.byKey(const ValueKey<String>('collab-phone-field')),
      );
      final messageField = tester.widget<TextFormField>(
        find.byKey(const ValueKey<String>('collab-message-field')),
      );
      expect(phoneField.controller?.text, isEmpty);
      expect(messageField.controller?.text, isEmpty);

      await scrollTo(tester, find.text('Başvuruyu Gönder'));
      await tester.tap(find.text('Başvuruyu Gönder'));
      await tester.pump();

      expect(find.text('Geçerli bir telefon numarası gir.'), findsOneWidget);
      expect(find.text('Mesaj alanı boş bırakılamaz.'), findsNothing);
      expect(repository.applyCalls, 0);

      await tester.enterText(
        find.byKey(const ValueKey<String>('collab-phone-field')),
        '+90 555 123 45 67',
      );
      await scrollTo(tester, find.text('Başvuruyu Gönder'));
      await tester.tap(find.text('Başvuruyu Gönder'));
      await tester.pumpAndSettle();
      expect(repository.applyCalls, 1);
      expect(repository.lastApplicationInput?.message, isEmpty);
    },
  );

  testWidgets('application error remains on form and can be retried', (
    tester,
  ) async {
    final repository =
        FakeCollabDetailRepository(
            listing: collabListingFixture(),
            actors: const [musicianActor],
          )
          ..applyError = const AppError(
            code: 'temporary',
            message: 'Başvuru şu an gönderilemedi.',
          );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);
    await cubit.load('listing-1');

    await tester.pumpWidget(composeApp(cubit));
    await tester.enterText(
      find.byKey(const ValueKey<String>('collab-phone-field')),
      '+90 555 123 45 67',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('collab-message-field')),
      'İlanınızla ilgileniyorum; repertuvar detaylarını konuşabiliriz.',
    );
    await scrollTo(tester, find.text('Başvuruyu Gönder'));
    await tester.tap(find.text('Başvuruyu Gönder'));
    await tester.pumpAndSettle();

    expect(find.text('Başvuru şu an gönderilemedi.'), findsOneWidget);
    expect(find.byType(CollabApplicationComposeScreen), findsOneWidget);
    expect(repository.applyCalls, 1);
  });

  testWidgets('detail completes actor selection and real application flow', (
    tester,
  ) async {
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(),
      actors: const [musicianActor, bandActor],
    );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      app(
        CollabListingDetailScreen(
          listingId: 'listing-1',
          detailCubit: cubit,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Başvuru Yap'));
    await tester.tap(find.text('Başvuru Yap'));
    await tester.pumpAndSettle();

    expect(find.byType(CollabProfileSelectionScreen), findsOneWidget);
    expect(find.text('Deniz Kaya'), findsOneWidget);
    expect(find.text('Acoustic Route'), findsNothing);
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();

    expect(find.byType(CollabApplicationComposeScreen), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('collab-phone-field')),
      '+90 555 123 45 67',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('collab-message-field')),
      'İlanınıza uygunum ve repertuvarı hızlıca çalışabilirim.',
    );
    await scrollTo(tester, find.text('Başvuruyu Gönder'));
    await tester.tap(find.text('Başvuruyu Gönder'));
    await tester.pumpAndSettle();

    expect(find.byType(CollabListingDetailScreen), findsOneWidget);
    await scrollTo(tester, find.text('Başvuru Gönderildi'));
    expect(find.text('Başvuru Gönderildi'), findsOneWidget);
    expect(repository.applyCalls, 1);
    expect(repository.lastApplicationInput?.applicantActorId, 'actor-musician');
    expect(repository.lastApplicationInput?.phone, '+90 555 123 45 67');
  });

  testWidgets('profile and compose screens fit a phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeCollabDetailRepository(
      listing: collabListingFixture(),
      actors: const [musicianActor],
    );
    final cubit = CollabListingDetailCubit(repository);
    addTearDown(cubit.close);
    await cubit.load('listing-1');

    await tester.pumpWidget(
      app(
        const CollabProfileSelectionScreen(
          actors: [musicianActor],
          wantedType: CollabProfileKind.musician,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(composeApp(cubit));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(Scrollable).last,
      const Offset(0, -900),
      1000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
