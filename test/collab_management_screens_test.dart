import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_commands.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_page.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_actor.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_application.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_job.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_listing.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_review.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_incoming_applications_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_jobs_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_my_applications_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_my_listings_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_saved_listings_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_incoming_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_my_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_my_listings_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_saved_listings_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/theme/collab_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  Widget app(Widget home) => MaterialApp(
    theme: AppTheme.navy,
    home: CollabThemeScope(child: home),
  );

  test('application status contract contains the five approved states', () {
    expect(CollabApplicationStatus.values, hasLength(5));
    expect(
      CollabApplicationStatus.values.map((status) => status.label),
      <String>[
        'Bekliyor',
        'Kabul edildi',
        'Reddedildi',
        'Başvuran geri çekti',
        'İlan kapanınca geçersizleşti',
      ],
    );
  });

  test('my listings uses real server pagination', () async {
    final repository = _ManagementRepository(
      myListings: List<CollabListing>.generate(
        21,
        (index) => _listing('listing-$index', title: 'İlan $index'),
      ),
    );
    final cubit = CollabMyListingsCubit(repository);

    await cubit.setStatusFilter(CollabListingStatus.open);
    expect(cubit.state.items, hasLength(20));
    expect(cubit.state.hasNext, isTrue);

    await cubit.loadMore();
    expect(cubit.state.items, hasLength(21));
    expect(cubit.state.hasNext, isFalse);
    await cubit.close();
  });

  testWidgets('my listings closes through the real cubit and filtered page', (
    tester,
  ) async {
    final repository = _ManagementRepository(
      myListings: <CollabListing>[_listing('owned', ownedByMe: true)],
    );
    final cubit = CollabMyListingsCubit(repository);

    await tester.pumpWidget(
      app(CollabMyListingsScreen(cubit: cubit, showBottomNavigation: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('İlanlarım'), findsOneWidget);
    expect(find.text('Bas gitarist aranıyor'), findsOneWidget);
    await tester.tap(find.text('İlanı kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'İlanı kapat'));
    await tester.pumpAndSettle();

    expect(repository.closeCalls, 1);
    expect(find.text('Bas gitarist aranıyor'), findsNothing);
    await cubit.close();
  });

  testWidgets('incoming shows phone and accept refreshes atomic statuses', (
    tester,
  ) async {
    final listing = _listing('incoming-listing', ownedByMe: true);
    final repository = _ManagementRepository(
      incoming: <CollabApplication>[
        _application('first', listing: listing, applicant: _applicant),
        _application('second', listing: listing, applicant: _secondApplicant),
      ],
    );
    final cubit = CollabIncomingApplicationsCubit(repository);

    await tester.pumpWidget(
      app(
        CollabIncomingApplicationsScreen(
          listingId: listing.id,
          listingTitle: listing.title,
          cubit: cubit,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+90 555 111 22 33'), findsNWidgets(2));
    await tester.tap(find.text('Kabul et').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Kabul et'));
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    expect(find.text('Kabul edildi'), findsAtLeastNWidgets(1));
    expect(find.text('İlan kapanınca geçersizleşti'), findsOneWidget);
    await cubit.close();
  });

  testWidgets(
    'outgoing withdraw and bilateral completion use separate cubits',
    (tester) async {
      final listing = _listing('applied-listing');
      final repository = _ManagementRepository(
        outgoing: <CollabApplication>[
          _application('mine', listing: listing, applicant: _me),
        ],
        jobs: <CollabJob>[_job('active-job', listing: listing)],
      );
      final applicationsCubit = CollabMyApplicationsCubit(repository);
      final jobsCubit = CollabJobsCubit(repository);

      await tester.pumpWidget(
        app(
          CollabMyApplicationsScreen(
            applicationsCubit: applicationsCubit,
            jobsCubit: jobsCubit,
            showBottomNavigation: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Geri çek'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Geri çek'));
      await tester.pumpAndSettle();
      expect(repository.withdrawCalls, 1);
      expect(find.text('Başvuran geri çekti'), findsOneWidget);

      await tester.tap(find.text('İşlerim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İşi tamamladım'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Tamamlandı'));
      await tester.pumpAndSettle();

      expect(repository.completionCalls, 1);
      expect(
        find.text('Sen onayladın · Karşı taraf bekleniyor.'),
        findsOneWidget,
      );
      await applicationsCubit.close();
      await jobsCubit.close();
    },
  );

  testWidgets('completed job accepts a one-to-five star review', (
    tester,
  ) async {
    final listing = _listing('completed-listing');
    final repository = _ManagementRepository(
      jobs: <CollabJob>[
        _job('completed-job', listing: listing, completed: true),
      ],
    );
    final applicationsCubit = CollabMyApplicationsCubit(repository);
    final jobsCubit = CollabJobsCubit(repository);

    await tester.pumpWidget(
      app(
        CollabMyApplicationsScreen(
          applicationsCubit: applicationsCubit,
          jobsCubit: jobsCubit,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşlerim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamamlandı').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Puanla ve yorumla'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('3 yıldız'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField),
      'İletişimi güçlü ve hazırlıklıydı.',
    );
    await tester.tap(find.text('Değerlendirmeyi gönder'));
    await tester.pumpAndSettle();

    expect(repository.reviewCalls, 1);
    expect(repository.lastRating, 3);
    expect(find.text('Değerlendirildi'), findsOneWidget);
    await applicationsCubit.close();
    await jobsCubit.close();
  });

  testWidgets('saved listing can be removed from the server page', (
    tester,
  ) async {
    final repository = _ManagementRepository(
      saved: <CollabListing>[_listing('saved', savedByMe: true)],
    );
    final cubit = CollabSavedListingsCubit(repository);

    await tester.pumpWidget(
      app(CollabSavedListingsScreen(cubit: cubit, showBottomNavigation: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bas gitarist aranıyor'), findsOneWidget);
    await tester.tap(find.text('Kaydı kaldır'));
    await tester.pumpAndSettle();

    expect(repository.unsaveCalls, 1);
    expect(find.text('Bas gitarist aranıyor'), findsNothing);
    await cubit.close();
  });
}

class _RepositoryStub implements CollabRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ManagementRepository extends _RepositoryStub {
  _ManagementRepository({
    List<CollabListing>? myListings,
    List<CollabListing>? saved,
    List<CollabApplication>? incoming,
    List<CollabApplication>? outgoing,
    List<CollabJob>? jobs,
  }) : myListings = myListings ?? <CollabListing>[],
       saved = saved ?? <CollabListing>[],
       incoming = incoming ?? <CollabApplication>[],
       outgoing = outgoing ?? <CollabApplication>[],
       jobs = jobs ?? <CollabJob>[];

  final List<CollabListing> myListings;
  final List<CollabListing> saved;
  final List<CollabApplication> incoming;
  final List<CollabApplication> outgoing;
  final List<CollabJob> jobs;

  int closeCalls = 0;
  int acceptCalls = 0;
  int withdrawCalls = 0;
  int completionCalls = 0;
  int reviewCalls = 0;
  int unsaveCalls = 0;
  int? lastRating;

  @override
  Future<Result<CollabPage<CollabListing>>> getMyListings({
    CollabListingStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    _page(
      myListings
          .where((item) => status == null || item.status == status)
          .toList(),
      page: page,
      size: size,
    ),
  );

  @override
  Future<Result<CollabListing>> closeListing(
    String listingId, {
    required int expectedVersion,
  }) async {
    closeCalls++;
    final index = myListings.indexWhere((item) => item.id == listingId);
    final updated = myListings[index].copyWith(
      version: expectedVersion + 1,
      status: CollabListingStatus.closed,
      closureReason: CollabClosureReason.ownerClosed,
    );
    myListings[index] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<void>> deleteDraft(
    String listingId, {
    required int expectedVersion,
  }) async {
    myListings.removeWhere((item) => item.id == listingId);
    return const Result<void>.success(null);
  }

  @override
  Future<Result<CollabPage<CollabApplication>>> getIncomingApplications(
    String listingId, {
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    _page(
      incoming
          .where((item) => item.listing.id == listingId)
          .where((item) => status == null || item.status == status)
          .toList(),
      page: page,
      size: size,
    ),
  );

  @override
  Future<Result<CollabJob>> acceptApplication(
    String applicationId, {
    required int expectedVersion,
  }) async {
    acceptCalls++;
    final accepted = incoming.firstWhere((item) => item.id == applicationId);
    for (var index = 0; index < incoming.length; index++) {
      final application = incoming[index];
      if (!application.isPending) continue;
      incoming[index] = application.copyWith(
        version: application.version + 1,
        status: application.id == applicationId
            ? CollabApplicationStatus.accepted
            : CollabApplicationStatus.invalidatedByListingClosure,
      );
    }
    final job = _job('accepted-job', listing: accepted.listing);
    jobs.add(job);
    return Result.success(job);
  }

  @override
  Future<Result<CollabApplication>> rejectApplication(
    String applicationId, {
    required int expectedVersion,
  }) async {
    final index = incoming.indexWhere((item) => item.id == applicationId);
    final updated = incoming[index].copyWith(
      version: expectedVersion + 1,
      status: CollabApplicationStatus.rejected,
    );
    incoming[index] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<CollabPage<CollabApplication>>> getMyApplications({
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    _page(
      outgoing
          .where((item) => status == null || item.status == status)
          .toList(),
      page: page,
      size: size,
    ),
  );

  @override
  Future<Result<CollabApplication>> withdrawApplication(
    String applicationId, {
    required int expectedVersion,
  }) async {
    withdrawCalls++;
    final index = outgoing.indexWhere((item) => item.id == applicationId);
    final updated = outgoing[index].copyWith(
      version: expectedVersion + 1,
      status: CollabApplicationStatus.withdrawnByApplicant,
    );
    outgoing[index] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<void>> saveListing(String listingId) async =>
      const Result<void>.success(null);

  @override
  Future<Result<void>> unsaveListing(String listingId) async {
    unsaveCalls++;
    saved.removeWhere((item) => item.id == listingId);
    return const Result<void>.success(null);
  }

  @override
  Future<Result<CollabPage<CollabListing>>> getSavedListings({
    int page = 0,
    int size = 20,
  }) async => Result.success(_page(saved, page: page, size: size));

  @override
  Future<Result<CollabPage<CollabJob>>> getMyJobs({
    CollabJobStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    _page(
      jobs.where((item) => status == null || item.status == status).toList(),
      page: page,
      size: size,
    ),
  );

  @override
  Future<Result<CollabJob>> confirmJobCompletion(
    String jobId, {
    required int expectedVersion,
  }) async {
    completionCalls++;
    final index = jobs.indexWhere((item) => item.id == jobId);
    final current = jobs[index];
    final updated = _copyJob(
      current,
      version: expectedVersion + 1,
      confirmedByMe: true,
      applicantConfirmed: true,
    );
    jobs[index] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<CollabReview>> createReview(
    String jobId,
    CollabReviewInput input, {
    required String clientRequestId,
  }) async {
    reviewCalls++;
    lastRating = input.rating;
    final index = jobs.indexWhere((item) => item.id == jobId);
    jobs[index] = _copyJob(jobs[index], reviewedByMe: true);
    return Result.success(
      CollabReview(
        id: 'review-1',
        jobId: jobId,
        reviewer: _me,
        target: _publisher,
        rating: input.rating,
        comment: input.comment,
        createdAt: DateTime(2026, 8, 11),
      ),
    );
  }
}

CollabPage<T> _page<T>(List<T> all, {required int page, required int size}) {
  final start = page * size;
  final end = (start + size).clamp(0, all.length);
  final items = start >= all.length ? <T>[] : all.sublist(start, end);
  final totalPages = all.isEmpty ? 0 : (all.length / size).ceil();
  return CollabPage<T>(
    items: items,
    page: page,
    size: size,
    totalElements: all.length,
    totalPages: totalPages,
    first: page == 0,
    last: totalPages == 0 || page >= totalPages - 1,
  );
}

const CollabActor _publisher = CollabActor(
  actorId: 'publisher-actor',
  profileType: CollabProfileKind.venue,
  sourceProfileId: 'venue-1',
  contactUserId: 'publisher-user',
  displayName: 'Kadıköy Sahne',
  rating: 4.8,
  reviewCount: 12,
  completedJobCount: 22,
);

const CollabActor _me = CollabActor(
  actorId: 'me-actor',
  profileType: CollabProfileKind.musician,
  sourceProfileId: 'musician-me',
  contactUserId: 'me-user',
  displayName: 'Deniz Yılmaz',
  rating: 4.9,
  reviewCount: 7,
  completedJobCount: 14,
);

const CollabActor _applicant = CollabActor(
  actorId: 'applicant-1',
  profileType: CollabProfileKind.musician,
  sourceProfileId: 'musician-1',
  contactUserId: 'applicant-user-1',
  displayName: 'Melis Kaya',
  rating: 4.7,
  reviewCount: 9,
  completedJobCount: 11,
);

const CollabActor _secondApplicant = CollabActor(
  actorId: 'applicant-2',
  profileType: CollabProfileKind.musician,
  sourceProfileId: 'musician-2',
  contactUserId: 'applicant-user-2',
  displayName: 'Buğra Can',
  rating: 4.5,
  reviewCount: 5,
  completedJobCount: 8,
);

CollabListing _listing(
  String id, {
  String title = 'Bas gitarist aranıyor',
  bool ownedByMe = false,
  bool savedByMe = false,
}) => CollabListing(
  id: id,
  version: 1,
  status: CollabListingStatus.open,
  cadence: CollabCadence.regular,
  wantedType: CollabProfileKind.musician,
  title: title,
  description: 'Düzenli sahnelerimiz için bas gitarist arıyoruz.',
  city: const CollabCitySummary(id: 'city-34', name: 'İstanbul'),
  genres: const <String>['Rock'],
  feeStatus: CollabFeeStatus.unspecified,
  publisher: _publisher,
  ownedByMe: ownedByMe,
  appliedByMe: !ownedByMe,
  savedByMe: savedByMe,
  applicationCount: 2,
);

CollabApplication _application(
  String id, {
  required CollabListing listing,
  required CollabActor applicant,
}) => CollabApplication(
  id: id,
  version: 1,
  listing: listing,
  applicant: applicant,
  phone: '+90 555 111 22 33',
  message: 'Bu iş için uygunum ve detayları konuşmak isterim.',
  status: CollabApplicationStatus.pending,
  submittedAt: DateTime(2026, 8, 11, 12),
  statusChangedAt: DateTime(2026, 8, 11, 12),
);

CollabJob _job(
  String id, {
  required CollabListing listing,
  bool completed = false,
}) => CollabJob(
  id: id,
  version: 1,
  status: completed ? CollabJobStatus.completed : CollabJobStatus.active,
  listing: listing,
  publisher: _publisher,
  applicant: _me,
  publisherConfirmedCompletion: completed,
  applicantConfirmedCompletion: completed,
  confirmedByMe: completed,
  reviewedByMe: false,
  completedAt: completed ? DateTime(2026, 8, 10) : null,
);

CollabJob _copyJob(
  CollabJob job, {
  int? version,
  bool? confirmedByMe,
  bool? publisherConfirmed,
  bool? applicantConfirmed,
  bool? reviewedByMe,
}) => CollabJob(
  id: job.id,
  version: version ?? job.version,
  status: job.status,
  listing: job.listing,
  publisher: job.publisher,
  applicant: job.applicant,
  publisherConfirmedCompletion:
      publisherConfirmed ?? job.publisherConfirmedCompletion,
  applicantConfirmedCompletion:
      applicantConfirmed ?? job.applicantConfirmedCompletion,
  confirmedByMe: confirmedByMe ?? job.confirmedByMe,
  publisherConfirmedAt: job.publisherConfirmedAt,
  applicantConfirmedAt: job.applicantConfirmedAt,
  completedAt: job.completedAt,
  reviewedByMe: reviewedByMe ?? job.reviewedByMe,
);
