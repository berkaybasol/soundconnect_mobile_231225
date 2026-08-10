import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_management_mock_data.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_mock_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_application_models.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_discovery_models.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_listing_draft.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_management_models.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_create_listing_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_incoming_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_my_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_my_listings_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  Widget app(Widget home) => MaterialApp(theme: AppTheme.navy, home: home);

  test('application status contains only the five approved states', () {
    expect(CollabApplicationStatus.values, hasLength(5));
    expect(
      CollabApplicationStatus.values.map((status) => status.label),
      containsAll(<String>[
        'Bekliyor',
        'Kabul edildi',
        'Reddedildi',
        'Başvuran geri çekti',
        'İlan kapanınca geçersizleşti',
      ]),
    );
    expect(
      CollabApplicationStatus.values.map((status) => status.label),
      isNot(contains('Tamamlandı')),
    );
  });

  test('controller keeps completed work separate from applications', () {
    final controller = CollabMockController();
    expect(controller.jobs.single.status, CollabJobStatus.completed);
    expect(
      controller.jobs.single.application.status,
      CollabApplicationStatus.accepted,
    );
  });

  test('accepting an applicant closes the single-need listing', () {
    final controller = CollabMockController();
    final accepted = controller.accept('incoming-melis');

    expect(accepted, isTrue);
    expect(
      controller.incomingApplications
          .firstWhere((item) => item.id == 'incoming-melis')
          .status,
      CollabApplicationStatus.accepted,
    );
    final owned = controller.ownedListings.firstWhere(
      (item) => item.listing.id == 'owned-studio-guitar',
    );
    expect(owned.status, CollabOwnedListingStatus.closed);
  });

  test('closing a listing invalidates only pending applications', () {
    final controller = CollabMockController();
    controller.closeListing('owned-studio-guitar');

    final melis = controller.incomingApplications.firstWhere(
      (item) => item.id == 'incoming-melis',
    );
    final bugra = controller.incomingApplications.firstWhere(
      (item) => item.id == 'incoming-bugra',
    );
    expect(melis.status, CollabApplicationStatus.invalidatedByListingClosure);
    expect(bugra.status, CollabApplicationStatus.accepted);
  });

  test('accepting an available listing offer creates an active job', () {
    final listing = _testListing(
      id: 'available-offer-listing',
      direction: CollabDirection.available,
    );
    final application = _pendingApplication(
      id: 'available-offer',
      listing: listing,
    );
    final owned = _ownedListing(listing: listing);
    final controller = _controller(
      incomingApplications: [application],
      ownedListings: [owned],
      createdListings: [listing],
    );

    expect(controller.accept(application.id), isTrue);

    final updatedOwned = controller.ownedListings.single;
    expect(updatedOwned.status, CollabOwnedListingStatus.closed);
    expect(controller.createdListings, isEmpty);
    expect(
      controller.incomingApplications.single.status,
      CollabApplicationStatus.accepted,
    );
    expect(controller.jobs, hasLength(1));
    expect(controller.jobs.single.status, CollabJobStatus.active);
    expect(controller.jobs.single.application.id, application.id);
  });

  test('an active job can be completed exactly once', () {
    final listing = _testListing(
      id: 'job-lifecycle-listing',
      direction: CollabDirection.available,
    );
    final application = _pendingApplication(
      id: 'job-lifecycle-offer',
      listing: listing,
    );
    final controller = _controller(
      incomingApplications: [application],
      ownedListings: [_ownedListing(listing: listing)],
    );
    expect(controller.accept(application.id), isTrue);
    final jobId = controller.jobs.single.id;

    expect(controller.completeJob(jobId), isTrue);
    expect(controller.jobs.single.status, CollabJobStatus.completed);
    expect(controller.completeJob(jobId), isFalse);
  });

  test('the same profile cannot submit twice to the same listing', () {
    final listing = _testListing(id: 'duplicate-submit-listing');
    final draft = CollabApplicationDraft(
      listing: listing,
      profile: _testApplicant,
      phoneNumber: '+90 555 111 22 33',
      message: 'Bu ilana başvurmak istiyorum.',
    );
    final controller = _controller();

    expect(controller.submit(draft), isTrue);
    expect(controller.submit(draft), isFalse);
    expect(controller.outgoingApplications, hasLength(1));
  });

  test('closing a created listing removes it from the feed source', () {
    final listing = _testListing(id: 'created-listing-to-close');
    final controller = _controller(
      ownedListings: [_ownedListing(listing: listing)],
      createdListings: [listing],
    );
    expect(controller.createdListings.single.id, listing.id);

    controller.closeListing(listing.id);

    expect(controller.createdListings, isEmpty);
    expect(
      controller.ownedListings.single.status,
      CollabOwnedListingStatus.closed,
    );
  });

  test('accepting a created listing removes the fulfilled need from feed', () {
    final listing = _testListing(id: 'created-seeking-listing');
    final application = _pendingApplication(
      id: 'created-seeking-application',
      listing: listing,
    );
    final controller = _controller(
      incomingApplications: [application],
      ownedListings: [_ownedListing(listing: listing)],
      createdListings: [listing],
    );

    expect(controller.accept(application.id), isTrue);

    expect(controller.createdListings, isEmpty);
    expect(
      controller.ownedListings.single.status,
      CollabOwnedListingStatus.closed,
    );
  });

  testWidgets('my applications separates active states and completed jobs', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(
      app(
        CollabMyApplicationsScreen(
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başvurularım'), findsOneWidget);
    expect(find.text('Başvurular (5)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tamamlanan İşler (1)'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tamamlanan İşler (1)'), findsOneWidget);
    expect(find.textContaining('Collab Puanı'), findsNothing);
    expect(find.textContaining('Doğrulan'), findsNothing);
  });

  testWidgets('incoming application card exposes phone and approved metrics', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(
      app(
        CollabIncomingApplicationsScreen(
          ownedListing: collabOwnedMockListings.first,
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+90 532 123 45 67'), findsOneWidget);
    expect(find.text('4.8 / 5'), findsOneWidget);
    expect(find.text('14 yorum'), findsOneWidget);
    expect(find.textContaining('Collab Puanı'), findsNothing);
    expect(find.textContaining('Doğrulan'), findsNothing);
  });

  testWidgets('incoming accept action closes the fulfilled listing', (
    tester,
  ) async {
    final controller = CollabMockController();
    await tester.pumpWidget(
      app(
        CollabIncomingApplicationsScreen(
          ownedListing: collabOwnedMockListings.first,
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final accept = find.text('Kabul Et').first;
    await tester.scrollUntilVisible(
      accept,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(accept);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Kabul Et'));
    await tester.pumpAndSettle();

    expect(
      controller.ownedListings.first.status,
      CollabOwnedListingStatus.closed,
    );
    expect(
      controller.incomingApplications
          .firstWhere((item) => item.id == 'incoming-melis')
          .status,
      CollabApplicationStatus.accepted,
    );
  });

  testWidgets('closed listings hide the incoming accept action', (
    tester,
  ) async {
    for (final status in <CollabOwnedListingStatus>[
      CollabOwnedListingStatus.closed,
    ]) {
      final listing = _testListing(id: 'blocked-${status.name}');
      final application = _pendingApplication(
        id: 'blocked-application-${status.name}',
        listing: listing,
      );
      final owned = _ownedListing(listing: listing, status: status);
      final controller = _controller(
        incomingApplications: [application],
        ownedListings: [owned],
      );

      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('blocked-${status.name}'),
          theme: AppTheme.navy,
          home: CollabIncomingApplicationsScreen(
            ownedListing: owned,
            controller: controller,
            showBottomNavigation: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(application.phoneNumber), findsOneWidget);
      expect(find.text('Kabul Et'), findsNothing);
    }
  });

  testWidgets('incoming UI omits capacity metrics', (tester) async {
    final listing = _testListing(
      id: 'available-incoming-ui',
      direction: CollabDirection.available,
    );
    final application = _pendingApplication(
      id: 'available-incoming-ui-offer',
      listing: listing,
    );
    final owned = _ownedListing(listing: listing);
    final controller = _controller(
      incomingApplications: [application],
      ownedListings: [owned],
    );

    await tester.pumpWidget(
      app(
        CollabIncomingApplicationsScreen(
          ownedListing: owned,
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başvuru'), findsOneWidget);
    expect(find.text('İlan Durumu'), findsOneWidget);
    expect(find.textContaining('0/0'), findsNothing);
    expect(find.text('Kontenjan Dolu'), findsNothing);
    expect(find.text('Kalan Kontenjan'), findsNothing);
    expect(find.text('Kabul Et'), findsOneWidget);
  });

  testWidgets('saved drafts are reachable and resume from My Listings', (
    tester,
  ) async {
    final draft = _testDraft('Devam edilecek Collab taslağı');
    final controller = _controller(drafts: [draft]);
    await tester.pumpWidget(
      app(
        CollabMyListingsScreen(
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Taslaklar (1)'));
    await tester.pumpAndSettle();
    expect(find.text(draft.title), findsOneWidget);
    await tester.tap(find.text(draft.title));
    await tester.pumpAndSettle();

    expect(find.byType(CollabCreateListingScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('collab-create-continue')));
    await tester.pumpAndSettle();
    final titleField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('collab-create-title')),
    );
    expect(titleField.controller?.text, draft.title);
  });

  testWidgets('management screens fit a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = CollabMockController();

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('my-applications-phone'),
        theme: AppTheme.navy,
        home: CollabMyApplicationsScreen(
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('my-listings-phone'),
        theme: AppTheme.navy,
        home: CollabMyListingsScreen(
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('incoming-phone'),
        theme: AppTheme.navy,
        home: CollabIncomingApplicationsScreen(
          ownedListing: collabOwnedMockListings.first,
          controller: controller,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

const _testApplicant = CollabApplicantProfile(
  id: 'test-applicant',
  name: 'testmusician',
  initials: 'TM',
  profileKind: CollabProfileKind.musician,
  specialty: 'Bas Gitarist',
  rating: 4.7,
  reviewCount: 12,
  completedJobs: 21,
);

CollabDiscoveryListing _testListing({
  required String id,
  CollabDirection direction = CollabDirection.seeking,
}) {
  return CollabDiscoveryListing(
    id: id,
    ownerName: 'Test Mekan',
    ownerInitials: 'TM',
    profileKind: CollabProfileKind.venue,
    wantedKind: CollabProfileKind.musician,
    title: 'Test Collab ilanı',
    cadence: CollabCadence.regular,
    direction: direction,
    location: 'Kadıköy, İstanbul',
    city: 'İstanbul',
    scheduleLabel: 'Düzenli',
    timeWindow: CollabTimeWindow.flexible,
    feeAmount: 2500,
    role: 'Bas Gitar',
    description: 'Controller ve arayüz regresyonlarını doğrulayan test ilanı.',
    rating: 4.8,
    reviewCount: 24,
    completedJobs: 45,
    publishedAt: DateTime(2026, 8, 6),
    genres: const {'Rock'},
  );
}

CollabApplicationRecord _pendingApplication({
  required String id,
  required CollabDiscoveryListing listing,
}) {
  return CollabApplicationRecord(
    id: id,
    listing: listing,
    applicantProfile: _testApplicant,
    phoneNumber: '+90 555 444 33 22',
    message: 'İlanınızla ilgileniyorum, detayları konuşabiliriz.',
    status: CollabApplicationStatus.pending,
    submittedAt: DateTime(2026, 8, 6, 12),
  );
}

CollabOwnedListingRecord _ownedListing({
  required CollabDiscoveryListing listing,
  CollabOwnedListingStatus status = CollabOwnedListingStatus.open,
}) {
  return CollabOwnedListingRecord(
    listing: listing,
    status: status,
    applicationCount: 1,
    createdAt: DateTime(2026, 8, 6, 10),
  );
}

CollabListingDraft _testDraft(String title) {
  return CollabListingDraft(
    cadence: CollabCadence.regular,
    direction: CollabDirection.available,
    title: title,
    description:
        'Kaydedilmiş ilan taslağının yeniden açılmasını doğrulayan açıklama.',
    location: 'Çankaya, Ankara',
    city: 'Ankara',
    role: 'Stüdyo',
    genres: const {'Rock'},
    occurrenceDate: null,
    occurrenceTime: null,
    feeMode: CollabFeeMode.paid,
    feeAmount: 3000,
    publisher: const CollabPublisherProfile(
      id: 'draft-studio',
      name: 'Taslak Stüdyo',
      initials: 'TS',
      profileKind: CollabProfileKind.studio,
      subtitle: 'Stüdyo',
      rating: 4.8,
      reviewCount: 10,
      completedJobs: 20,
    ),
  );
}

CollabMockController _controller({
  List<CollabApplicationRecord> outgoingApplications =
      const <CollabApplicationRecord>[],
  List<CollabApplicationRecord> incomingApplications =
      const <CollabApplicationRecord>[],
  List<CollabOwnedListingRecord> ownedListings =
      const <CollabOwnedListingRecord>[],
  List<CollabJobRecord> jobs = const <CollabJobRecord>[],
  List<CollabDiscoveryListing> createdListings =
      const <CollabDiscoveryListing>[],
  List<CollabListingDraft> drafts = const <CollabListingDraft>[],
}) {
  return CollabMockController(
    outgoingApplications: outgoingApplications,
    incomingApplications: incomingApplications,
    ownedListings: ownedListings,
    jobs: jobs,
    createdListings: createdListings,
    drafts: drafts,
  );
}
