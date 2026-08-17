import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_idempotency_store.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_commands.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_page.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_actor.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_application.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_job.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_listing.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_review.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_actor_reviews_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_async_state.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_discovery_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_jobs_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_editor_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_my_applications_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_paged_cubit.dart';

void main() {
  group('CollabDiscoveryCubit', () {
    test('discards stale filter responses', () async {
      final repository = _ControlledDiscoveryRepository();
      final cubit = CollabDiscoveryCubit(repository);

      final oldRequest = cubit.setFilters(
        const CollabDiscoveryQuery(cityId: 'old-city'),
      );
      final newRequest = cubit.setFilters(
        const CollabDiscoveryQuery(cityId: 'new-city'),
      );
      expect(repository.requests, hasLength(2));

      repository.requests[1].complete(
        Result.success(_page(<CollabListing>[_listing('new-listing')])),
      );
      await newRequest;
      repository.requests[0].complete(
        Result.success(_page(<CollabListing>[_listing('old-listing')])),
      );
      await oldRequest;

      expect(cubit.state.query.cityId, 'new-city');
      expect(cubit.state.items.map((item) => item.id), <String>['new-listing']);
      await cubit.close();
    });

    test('stale save failure cannot roll back a refreshed listing', () async {
      final repository = _SaveRaceDiscoveryRepository();
      final cubit = CollabDiscoveryCubit(repository);
      final initialLoad = cubit.loadInitial();
      repository.requests.single.complete(
        Result.success(
          _page(<CollabListing>[_listing('listing-1', title: 'Eski başlık')]),
        ),
      );
      await initialLoad;

      final save = cubit.toggleSaved('listing-1');
      final refresh = cubit.refresh();
      repository.requests[1].complete(
        Result.success(
          _page(<CollabListing>[_listing('listing-1', title: 'Yeni başlık')]),
        ),
      );
      await refresh;
      repository.saveRequest.complete(
        const Result.failure(
          AppError(code: 'offline', message: 'Bağlantı kurulamadı.'),
        ),
      );
      await save;

      expect(cubit.state.items.single.title, 'Yeni başlık');
      expect(cubit.state.savingListingIds, isEmpty);
      expect(cubit.state.actionError, isNull);
      await cubit.close();
    });

    test(
      'clears the previous result set when semantic filters change',
      () async {
        final repository = _ControlledDiscoveryRepository();
        final cubit = CollabDiscoveryCubit(repository);

        final initialLoad = cubit.loadInitial();
        repository.requests[0].complete(
          Result.success(
            _page(<CollabListing>[_listing('old-a')], last: false, total: 2),
          ),
        );
        await initialLoad;
        final loadMore = cubit.loadMore();
        repository.requests[1].complete(
          Result.success(
            _page(<CollabListing>[_listing('old-b')], page: 1, total: 2),
          ),
        );
        await loadMore;
        expect(cubit.state.page, 1);
        expect(cubit.state.totalElements, 2);

        final filteredLoad = cubit.setFilters(
          const CollabDiscoveryQuery(cityId: 'new-city'),
        );

        expect(cubit.state.query.cityId, 'new-city');
        expect(cubit.state.status, CollabLoadStatus.loading);
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.page, 0);
        expect(cubit.state.hasNext, isFalse);
        expect(cubit.state.totalElements, 0);
        expect(cubit.state.isRefreshing, isFalse);

        repository.requests[2].complete(
          const Result.failure(
            AppError(code: 'network', message: 'Bağlantı kurulamadı.'),
          ),
        );
        await filteredLoad;

        expect(cubit.state.query.cityId, 'new-city');
        expect(cubit.state.status, CollabLoadStatus.failure);
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.page, 0);
        expect(cubit.state.totalElements, 0);
        expect(cubit.state.error?.code, 'network');
        await cubit.close();
      },
    );

    test('clears visible results as soon as the search changes', () async {
      final repository = _ControlledDiscoveryRepository();
      final cubit = CollabDiscoveryCubit(
        repository,
        searchDebounce: const Duration(milliseconds: 1),
      );

      final initialLoad = cubit.loadInitial();
      repository.requests[0].complete(
        Result.success(_page(<CollabListing>[_listing('old-listing')])),
      );
      await initialLoad;

      cubit.setSearchQuery('bas gitar');

      expect(cubit.state.query.search, 'bas gitar');
      expect(cubit.state.status, CollabLoadStatus.loading);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.page, 0);
      expect(cubit.state.hasNext, isFalse);
      expect(cubit.state.totalElements, 0);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repository.requests, hasLength(2));
      expect(repository.queries.last.search, 'bas gitar');
      repository.requests[1].complete(
        Result.success(_page(const <CollabListing>[])),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.query.search, 'bas gitar');
      expect(cubit.state.status, CollabLoadStatus.success);
      expect(cubit.state.items, isEmpty);
      await cubit.close();
    });

    test('refresh keeps the current result set visible', () async {
      final repository = _ControlledDiscoveryRepository();
      final cubit = CollabDiscoveryCubit(repository);

      final initialLoad = cubit.loadInitial();
      repository.requests[0].complete(
        Result.success(_page(<CollabListing>[_listing('visible-listing')])),
      );
      await initialLoad;

      final refresh = cubit.refresh();

      expect(cubit.state.items.map((item) => item.id), <String>[
        'visible-listing',
      ]);
      expect(cubit.state.status, CollabLoadStatus.success);
      expect(cubit.state.totalElements, 1);
      expect(cubit.state.isRefreshing, isTrue);

      repository.requests[1].complete(
        const Result.failure(
          AppError(code: 'network', message: 'Bağlantı kurulamadı.'),
        ),
      );
      await refresh;

      expect(cubit.state.items.map((item) => item.id), <String>[
        'visible-listing',
      ]);
      expect(cubit.state.status, CollabLoadStatus.success);
      expect(cubit.state.isRefreshing, isFalse);
      expect(cubit.state.error?.code, 'network');
      await cubit.close();
    });

    test('deduplicates stable paged results by listing id', () async {
      final repository = _QueueDiscoveryRepository(<CollabPage<CollabListing>>[
        _page(
          <CollabListing>[_listing('a'), _listing('b', title: 'old b')],
          page: 0,
          last: false,
          total: 3,
        ),
        _page(
          <CollabListing>[_listing('b', title: 'new b'), _listing('c')],
          page: 1,
          last: true,
          total: 3,
        ),
      ]);
      final cubit = CollabDiscoveryCubit(repository);

      await cubit.loadInitial();
      await cubit.loadMore();

      expect(cubit.state.items.map((item) => item.id), <String>['a', 'b', 'c']);
      expect(
        cubit.state.items.singleWhere((item) => item.id == 'b').title,
        'new b',
      );
      expect(cubit.state.hasNext, isFalse);
      await cubit.close();
    });

    test('debounces search and dispatches only the latest query', () async {
      final repository = _QueueDiscoveryRepository(<CollabPage<CollabListing>>[
        _page(const <CollabListing>[]),
      ]);
      final cubit = CollabDiscoveryCubit(
        repository,
        searchDebounce: const Duration(milliseconds: 10),
      );

      cubit.setSearchQuery('bas');
      cubit.setSearchQuery('bas gitar');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(repository.queries, hasLength(1));
      expect(repository.queries.single.search, 'bas gitar');
      await cubit.close();
    });

    test('removes a listing as soon as detail reports it closed', () async {
      final listing = _listing('listing-1');
      final repository = _QueueDiscoveryRepository(<CollabPage<CollabListing>>[
        _page(<CollabListing>[listing]),
      ]);
      final cubit = CollabDiscoveryCubit(repository);
      await cubit.loadInitial();

      cubit.upsertListing(listing.copyWith(status: CollabListingStatus.closed));

      expect(cubit.state.items, isEmpty);
      expect(cubit.state.totalElements, 0);
      await cubit.close();
    });
  });

  test(
    'editor reuses clientRequestId when draft creation is retried',
    () async {
      final repository = _EditorRepository();
      final cubit = CollabListingEditorCubit(
        repository,
        requestIdFactory: () => 'stable-request-id',
      );

      await cubit.initialize();
      cubit.updateInput(
        cubit.state.input!.copyWith(
          instrumentId: 'instrument-1',
          title: 'Basçı aranıyor',
          description: 'Düzenli sahnelerimiz için bas gitarist arıyoruz.',
          cityId: 'city-34',
        ),
      );
      await cubit.saveDraft();
      expect(cubit.state.error?.code, 'temporary');
      await cubit.saveDraft();

      expect(repository.createRequestIds, <String>[
        'stable-request-id',
        'stable-request-id',
      ]);
      expect(cubit.state.listing?.isDraft, isTrue);
      await cubit.close();
    },
  );

  test(
    'editor rotates clientRequestId when failed draft payload changes',
    () async {
      final repository = _AlwaysFailEditorRepository();
      var sequence = 0;
      final cubit = CollabListingEditorCubit(
        repository,
        requestIdFactory: () => 'request-${++sequence}',
      );

      await cubit.initialize();
      final valid = cubit.state.input!.copyWith(
        instrumentId: 'instrument-1',
        title: 'Basçı aranıyor',
        description: 'Düzenli sahnelerimiz için bas gitarist arıyoruz.',
        cityId: 'city-34',
      );
      cubit.updateInput(valid);
      await cubit.saveDraft();
      cubit.updateInput(
        valid.copyWith(
          description: 'Düzenli sahnelerimiz için deneyimli basçı arıyoruz.',
        ),
      );
      await cubit.saveDraft();

      expect(repository.createRequestIds, <String>['request-1', 'request-2']);
      await cubit.close();
    },
  );

  test(
    'changed paged filter clears stale rows before its request completes',
    () async {
      final cubit = _ControlledPagedCubit();
      final initial = cubit.loadInitial();
      cubit.requests.single.complete(
        Result.success(_page(<CollabListing>[_listing('old')], total: 1)),
      );
      await initial;

      final changed = cubit.reloadForChangedFilter();

      expect(cubit.state.status, CollabLoadStatus.loading);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.totalElements, 0);
      cubit.requests.last.complete(
        const Result.failure(
          AppError(code: 'network', message: 'Yüklenemedi.'),
        ),
      );
      await changed;
      expect(cubit.state.status, CollabLoadStatus.failure);
      expect(cubit.state.items, isEmpty);
      await cubit.close();
    },
  );

  test(
    'server removal rebases offset pagination before loading more',
    () async {
      final cubit = _ControlledPagedCubit();
      final initial = cubit.loadInitial();
      cubit.requests.single.complete(
        Result.success(
          _page(
            <CollabListing>[_listing('a'), _listing('b')],
            last: false,
            total: 5,
          ),
        ),
      );
      await initial;
      final more = cubit.loadMore();
      cubit.requests.last.complete(
        Result.success(
          _page(
            <CollabListing>[_listing('c'), _listing('d')],
            page: 1,
            last: false,
            total: 5,
          ),
        ),
      );
      await more;

      final rebased = cubit.removeItemAndRefresh('a');
      expect(cubit.state.page, 0);
      expect(cubit.state.hasNext, isFalse);
      expect(cubit.state.items.map((item) => item.id), isNot(contains('a')));
      cubit.requests.last.complete(
        Result.success(
          _page(
            <CollabListing>[_listing('b'), _listing('c')],
            last: false,
            total: 4,
          ),
        ),
      );
      await rebased;
      final afterRebase = cubit.loadMore();
      cubit.requests.last.complete(
        Result.success(
          _page(
            <CollabListing>[_listing('d'), _listing('e')],
            page: 1,
            total: 4,
          ),
        ),
      );
      await afterRebase;

      expect(cubit.requestedPages, <int>[0, 1, 0, 1]);
      expect(cubit.state.items.map((item) => item.id), <String>[
        'b',
        'c',
        'd',
        'e',
      ]);
      await cubit.close();
    },
  );

  test(
    'application idempotency key changes only when payload changes',
    () async {
      final repository = _FailingApplicationRepository();
      var sequence = 0;
      final cubit = CollabListingDetailCubit(
        repository,
        requestIdFactory: () => 'apply-${++sequence}',
      );
      await cubit.load('listing-1');
      const first = CollabApplicationInput(
        applicantActorId: 'actor-applicant',
        phone: '+90 555 111 22 33',
        message: 'Uygunum.',
      );

      await cubit.apply(first);
      await cubit.apply(first);
      await cubit.apply(
        const CollabApplicationInput(
          applicantActorId: 'actor-applicant',
          phone: '+90 555 111 22 33',
          message: 'Bu tarih için uygunum.',
        ),
      );

      expect(repository.requestIds, <String>['apply-1', 'apply-1', 'apply-2']);
      await cubit.close();
    },
  );

  test('review idempotency key rotates after review payload changes', () async {
    final repository = _FailingReviewRepository();
    var sequence = 0;
    final cubit = CollabJobsCubit(
      repository,
      requestIdFactory: () => 'review-${++sequence}',
    );
    final job = _completedJob();

    await cubit.review(job, const CollabReviewInput(rating: 5));
    await cubit.review(job, const CollabReviewInput(rating: 5));
    await cubit.review(
      job,
      const CollabReviewInput(rating: 4, comment: 'Gayet iyiydi.'),
    );

    expect(repository.requestIds, <String>['review-1', 'review-1', 'review-2']);
    await cubit.close();
  });

  test('create idempotency lease survives editor recreation', () async {
    final repository = _AlwaysFailEditorRepository();
    final store = MemoryCollabIdempotencyStore(scope: 'user-a');
    var sequence = 0;
    CollabListingEditorCubit createCubit() => CollabListingEditorCubit(
      repository,
      idempotencyStore: store,
      requestIdFactory: () => 'create-${++sequence}',
    );
    Future<void> prepare(CollabListingEditorCubit cubit) async {
      await cubit.initialize();
      cubit.updateInput(
        cubit.state.input!.copyWith(
          instrumentId: 'instrument-1',
          title: 'Basçı aranıyor',
          description: 'Düzenli sahnelerimiz için bas gitarist arıyoruz.',
          cityId: 'city-34',
        ),
      );
    }

    final first = createCubit();
    await prepare(first);
    await first.saveDraft();
    await first.close();
    final restarted = createCubit();
    await prepare(restarted);
    await restarted.saveDraft();

    expect(repository.createRequestIds, <String>['create-1', 'create-1']);
    await restarted.close();
  });

  test(
    'create lease canonicalizes reordered genres and blank optionals across restart',
    () async {
      final repository = _AlwaysFailEditorRepository();
      final store = MemoryCollabIdempotencyStore(scope: 'user-a');
      var sequence = 0;

      Future<void> submit({
        required List<String> genres,
        required String? customSpecialty,
      }) async {
        final cubit = CollabListingEditorCubit(
          repository,
          idempotencyStore: store,
          requestIdFactory: () => 'create-${++sequence}',
        );
        await cubit.initialize();
        cubit.updateInput(
          cubit.state.input!.copyWith(
            instrumentId: ' instrument-1 ',
            customSpecialty: customSpecialty,
            clearCustomSpecialty: customSpecialty == null,
            title: ' Basçı aranıyor ',
            description: ' Düzenli sahnelerimiz için bas gitarist arıyoruz. ',
            cityId: ' city-34 ',
            genres: genres,
          ),
        );
        await cubit.saveDraft();
        await cubit.close();
      }

      await submit(
        genres: const <String>[' Rock ', 'Funk', 'rock'],
        customSpecialty: '   ',
      );
      await submit(
        genres: const <String>['Funk', 'Rock'],
        customSpecialty: null,
      );

      expect(repository.createRequestIds, <String>['create-1', 'create-1']);
      expect(repository.inputs, hasLength(2));
      expect(repository.inputs.first.genres, <String>['Funk', 'Rock']);
      expect(repository.inputs.last.genres, <String>['Funk', 'Rock']);
      expect(
        repository.inputs.every((input) => input.customSpecialty == null),
        isTrue,
      );
    },
  );

  test('abandoning a new draft rotates its operation instance', () async {
    final repository = _AlwaysFailEditorRepository();
    final store = MemoryCollabIdempotencyStore(scope: 'user-a');
    var sequence = 0;
    final cubit = CollabListingEditorCubit(
      repository,
      idempotencyStore: store,
      requestIdFactory: () => 'create-${++sequence}',
    );
    await cubit.initialize();
    cubit.updateInput(
      cubit.state.input!.copyWith(
        instrumentId: 'instrument-1',
        title: 'Basçı aranıyor',
        description: 'Düzenli sahnelerimiz için bas gitarist arıyoruz.',
        cityId: 'city-34',
      ),
    );

    await cubit.saveDraft();
    expect(await cubit.abandonPendingCreate(), isTrue);
    await cubit.saveDraft();

    expect(repository.createRequestIds, <String>['create-1', 'create-2']);
    await cubit.close();
  });

  test(
    'successful editor response survives local lease cleanup failure',
    () async {
      final repository = _EditorRepository();
      final cubit = CollabListingEditorCubit(
        repository,
        idempotencyStore: _ThrowingCleanupStore(),
        requestIdFactory: () => 'create-1',
      );
      await cubit.initialize();
      cubit.updateInput(
        cubit.state.input!.copyWith(
          instrumentId: 'instrument-1',
          title: 'Basçı aranıyor',
          description: 'Düzenli sahnelerimiz için bas gitarist arıyoruz.',
          cityId: 'city-34',
        ),
      );

      await cubit.saveDraft();
      await cubit.saveDraft();

      expect(cubit.state.listing?.id, 'draft-1');
      expect(cubit.state.error, isNull);
      await cubit.close();
    },
  );

  test('apply, report and review leases survive cubit recreation', () async {
    final store = MemoryCollabIdempotencyStore(scope: 'user-a');
    final applicationRepository = _FailingApplicationRepository();
    var applySequence = 0;
    for (var index = 0; index < 2; index++) {
      final cubit = CollabListingDetailCubit(
        applicationRepository,
        idempotencyStore: store,
        requestIdFactory: () => 'apply-${++applySequence}',
      );
      await cubit.load('listing-1');
      await cubit.apply(
        CollabApplicationInput(
          applicantActorId: index == 0
              ? ' actor-applicant '
              : 'actor-applicant',
          phone: index == 0 ? '+90 (555) 111-22-33' : '+905551112233',
          message: index == 0 ? '   ' : '',
        ),
      );
      await cubit.close();
    }
    expect(applicationRepository.requestIds, <String>['apply-1', 'apply-1']);

    final reportRepository = _FailingReportRepository();
    var reportSequence = 0;
    for (var index = 0; index < 2; index++) {
      final cubit = CollabListingDetailCubit(
        reportRepository,
        idempotencyStore: store,
        requestIdFactory: () => 'report-${++reportSequence}',
      );
      await cubit.load('listing-1');
      await cubit.report(
        CollabReportInput(
          reason: CollabReportReason.spam,
          details: index == 0 ? null : '   ',
        ),
      );
      await cubit.close();
    }
    expect(reportRepository.requestIds, <String>['report-1', 'report-1']);

    final reviewRepository = _FailingReviewRepository();
    var reviewSequence = 0;
    for (var index = 0; index < 2; index++) {
      final cubit = CollabJobsCubit(
        reviewRepository,
        idempotencyStore: store,
        requestIdFactory: () => 'review-${++reviewSequence}',
      );
      await cubit.review(
        _completedJob(),
        CollabReviewInput(rating: 5, comment: index == 0 ? null : '   '),
      );
      await cubit.close();
    }
    expect(reviewRepository.requestIds, <String>['review-1', 'review-1']);
  });

  test('closing detail cubit during apply cleanup does not emit', () async {
    final repository = _SuccessfulMutationRepository();
    final store = _BlockingCleanupStore();
    final cubit = CollabListingDetailCubit(
      repository,
      idempotencyStore: store,
      requestIdFactory: () => 'apply-1',
    );
    await cubit.load('listing-1');

    final operation = cubit.apply(
      const CollabApplicationInput(
        applicantActorId: 'actor-applicant',
        phone: '+905551112233',
        message: '',
      ),
    );
    await store.cleanupStarted.future;
    await cubit.close();
    store.allowCleanup.complete();

    await expectLater(operation, completes);
  });

  test('closing detail cubit during report cleanup does not emit', () async {
    final repository = _SuccessfulMutationRepository();
    final store = _BlockingCleanupStore();
    final cubit = CollabListingDetailCubit(
      repository,
      idempotencyStore: store,
      requestIdFactory: () => 'report-1',
    );
    await cubit.load('listing-1');

    final operation = cubit.report(
      const CollabReportInput(reason: CollabReportReason.spam),
    );
    await store.cleanupStarted.future;
    await cubit.close();
    store.allowCleanup.complete();

    await expectLater(operation, completes);
  });

  test(
    'closing jobs cubit during review cleanup skips refresh and emit',
    () async {
      final repository = _SuccessfulMutationRepository();
      final store = _BlockingCleanupStore();
      final cubit = CollabJobsCubit(
        repository,
        idempotencyStore: store,
        requestIdFactory: () => 'review-1',
      );

      final operation = cubit.review(
        _completedJob(),
        const CollabReviewInput(rating: 5),
      );
      await store.cleanupStarted.future;
      await cubit.close();
      store.allowCleanup.complete();

      await expectLater(operation, completes);
      expect(repository.getMyJobsCalls, 0);
    },
  );

  test('closed listings reject save mutations in both cubits', () async {
    final listing = _listing('closed', status: CollabListingStatus.closed);
    final repository = _SaveGuardRepository(listing);
    final detail = CollabListingDetailCubit(repository);
    await detail.load(listing.id);
    await detail.toggleSaved();

    final applications = CollabMyApplicationsCubit(repository);
    final now = DateTime.utc(2026, 8, 11);
    await applications.toggleSaved(
      CollabApplication(
        id: 'application-closed',
        version: 1,
        listing: listing,
        applicant: _actor,
        message: 'Uygunum.',
        status: CollabApplicationStatus.rejected,
        submittedAt: now,
        statusChangedAt: now,
      ),
    );

    expect(repository.saveCalls, 0);
    expect(repository.unsaveCalls, 0);
    await detail.close();
    await applications.close();
  });

  test(
    'actor review pagination clears prior actor reviews on actor switch',
    () async {
      final repository = _ControlledReviewsRepository();
      final cubit = CollabActorReviewsCubit(repository);
      final firstLoad = cubit.loadForActor('actor-a');
      repository.requests.single.complete(
        Result.success(_reviewPage(<CollabReview>[_review('review-a')])),
      );
      await firstLoad;

      final secondLoad = cubit.loadForActor('actor-b');

      expect(cubit.state.items, isEmpty);
      expect(cubit.state.status, CollabLoadStatus.loading);
      repository.requests.last.complete(
        Result.success(_reviewPage(<CollabReview>[_review('review-b')])),
      );
      await secondLoad;
      expect(cubit.actorId, 'actor-b');
      expect(cubit.state.items.single.id, 'review-b');
      await cubit.close();
    },
  );

  test(
    'a stale detail action cannot overwrite a newly loaded listing',
    () async {
      final repository = _ControlledDetailRepository();
      final cubit = CollabListingDetailCubit(repository);

      final firstLoad = cubit.load('listing-a');
      repository.listingRequests['listing-a']!.complete(
        Result.success(_listing('listing-a')),
      );
      await firstLoad;
      final staleSave = cubit.toggleSaved();
      expect(cubit.state.isSaving, isTrue);

      final secondLoad = cubit.load('listing-b');
      expect(cubit.state.isSaving, isFalse);
      repository.listingRequests['listing-b']!.complete(
        Result.success(_listing('listing-b')),
      );
      await secondLoad;
      repository.saveRequest.complete(
        const Result.failure(
          AppError(code: 'offline', message: 'Bağlantı kurulamadı.'),
        ),
      );
      await staleSave;

      expect(cubit.state.listing?.id, 'listing-b');
      expect(cubit.state.actionError, isNull);
      expect(cubit.state.isSaving, isFalse);
      await cubit.close();
    },
  );

  test(
    'detail close conflict reloads the authoritative listing once',
    () async {
      final repository = _StaleDetailCloseRepository();
      final cubit = CollabListingDetailCubit(repository);

      await cubit.load('listing-1');
      await cubit.closeListing();

      expect(repository.getListingCalls, 2);
      expect(repository.closeCalls, 1);
      expect(cubit.state.listing?.status, CollabListingStatus.closed);
      expect(cubit.state.listing?.version, 2);
      expect(cubit.state.actionError?.code, '9317');
      await cubit.close();
    },
  );

  test(
    'withdraw conflict refreshes latest application without retrying',
    () async {
      final repository = _StaleWithdrawRepository();
      final cubit = CollabMyApplicationsCubit(repository);
      await cubit.loadInitial();
      final staleApplication = cubit.state.items.single;

      await cubit.withdraw(staleApplication);

      expect(repository.withdrawCalls, 1);
      expect(repository.pageCalls, 2);
      expect(cubit.state.items.single.status, CollabApplicationStatus.rejected);
      expect(cubit.state.actionError?.code, '9317');
      await cubit.close();
    },
  );

  test(
    'editor conflict preserves local form until explicit server reload',
    () async {
      final localDraft = _listing(
        'draft-1',
        status: CollabListingStatus.draft,
        title: 'Yerel taslak başlığı',
        version: 1,
      );
      final remoteDraft = _listing(
        'draft-1',
        status: CollabListingStatus.draft,
        title: 'Diğer cihazdaki başlık',
        version: 2,
      );
      final repository = _StaleEditorRepository(remoteDraft);
      final cubit = CollabListingEditorCubit(repository);
      await cubit.initialize(listing: localDraft);
      cubit.updateInput(
        cubit.state.input!.copyWith(
          instrumentId: 'instrument-1',
          title: 'Bu cihazdaki kaydedilmemiş başlık',
        ),
      );

      await cubit.saveDraft();

      expect(repository.updateCalls, 1);
      expect(repository.getListingCalls, 1);
      expect(cubit.state.listing?.version, 1);
      expect(cubit.state.conflictListing?.version, 2);
      expect(cubit.state.input?.title, 'Bu cihazdaki kaydedilmemiş başlık');
      expect(cubit.state.isDirty, isTrue);
      expect(cubit.state.hasUnresolvedConflict, isTrue);
      expect(cubit.state.error?.code, '9317');
      expect(cubit.state.error?.message, contains('korundu'));

      await cubit.saveDraft();
      expect(repository.updateCalls, 1, reason: 'conflict must not auto-retry');

      cubit.loadLatestConflictVersion();
      expect(cubit.state.listing?.version, 2);
      expect(cubit.state.input?.title, 'Diğer cihazdaki başlık');
      expect(cubit.state.conflictListing, isNull);
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.hasUnresolvedConflict, isFalse);
      await cubit.close();
    },
  );
}

class _RepositoryStub implements CollabRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledDetailRepository extends _RepositoryStub {
  final Map<String, Completer<Result<CollabListing>>> listingRequests =
      <String, Completer<Result<CollabListing>>>{};
  final Completer<Result<void>> saveRequest = Completer<Result<void>>();

  @override
  Future<Result<CollabListing>> getListing(String listingId) {
    final request = Completer<Result<CollabListing>>();
    listingRequests[listingId] = request;
    return request.future;
  }

  @override
  Future<Result<void>> saveListing(String listingId) => saveRequest.future;
}

const AppError _staleUpdateError = AppError(
  code: '9317',
  message: 'Kayıt değişti; yenileyip tekrar deneyin.',
);

class _StaleDetailCloseRepository extends _RepositoryStub {
  int getListingCalls = 0;
  int closeCalls = 0;

  @override
  Future<Result<CollabListing>> getListing(String listingId) async {
    getListingCalls += 1;
    return Result.success(
      _listing(
        listingId,
        version: getListingCalls == 1 ? 1 : 2,
        status: getListingCalls == 1
            ? CollabListingStatus.open
            : CollabListingStatus.closed,
        ownedByMe: true,
      ),
    );
  }

  @override
  Future<Result<CollabListing>> closeListing(
    String listingId, {
    required int expectedVersion,
  }) async {
    closeCalls += 1;
    return const Result.failure(_staleUpdateError);
  }
}

class _StaleWithdrawRepository extends _RepositoryStub {
  int pageCalls = 0;
  int withdrawCalls = 0;

  @override
  Future<Result<CollabPage<CollabApplication>>> getMyApplications({
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) async {
    pageCalls += 1;
    final application = _application(
      status: pageCalls == 1
          ? CollabApplicationStatus.pending
          : CollabApplicationStatus.rejected,
      version: pageCalls,
    );
    return Result.success(
      CollabPage<CollabApplication>(
        items: <CollabApplication>[application],
        page: 0,
        size: size,
        totalElements: 1,
        totalPages: 1,
        first: true,
        last: true,
      ),
    );
  }

  @override
  Future<Result<CollabApplication>> withdrawApplication(
    String applicationId, {
    required int expectedVersion,
  }) async {
    withdrawCalls += 1;
    return const Result.failure(_staleUpdateError);
  }
}

class _StaleEditorRepository extends _RepositoryStub {
  _StaleEditorRepository(this.latest);

  final CollabListing latest;
  int updateCalls = 0;
  int getListingCalls = 0;

  @override
  Future<Result<List<CollabActor>>> getMyActors() async =>
      const Result.success(<CollabActor>[_actor]);

  @override
  Future<Result<CollabListing>> updateDraft(
    String listingId,
    CollabListingInput input, {
    required int expectedVersion,
  }) async {
    updateCalls += 1;
    return const Result.failure(_staleUpdateError);
  }

  @override
  Future<Result<CollabListing>> getListing(String listingId) async {
    getListingCalls += 1;
    return Result.success(latest);
  }
}

class _ControlledDiscoveryRepository extends _RepositoryStub {
  final List<Completer<Result<CollabPage<CollabListing>>>> requests =
      <Completer<Result<CollabPage<CollabListing>>>>[];
  final List<CollabDiscoveryQuery> queries = <CollabDiscoveryQuery>[];

  @override
  Future<Result<CollabPage<CollabListing>>> discover(
    CollabDiscoveryQuery query,
  ) {
    final completer = Completer<Result<CollabPage<CollabListing>>>();
    queries.add(query);
    requests.add(completer);
    return completer.future;
  }
}

class _SaveRaceDiscoveryRepository extends _ControlledDiscoveryRepository {
  final Completer<Result<void>> saveRequest = Completer<Result<void>>();

  @override
  Future<Result<void>> saveListing(String listingId) => saveRequest.future;
}

class _QueueDiscoveryRepository extends _RepositoryStub {
  _QueueDiscoveryRepository(this.pages);

  final List<CollabPage<CollabListing>> pages;
  final List<CollabDiscoveryQuery> queries = <CollabDiscoveryQuery>[];
  int _index = 0;

  @override
  Future<Result<CollabPage<CollabListing>>> discover(
    CollabDiscoveryQuery query,
  ) async {
    queries.add(query);
    return Result.success(pages[_index++]);
  }
}

class _EditorRepository extends _RepositoryStub {
  final List<String> createRequestIds = <String>[];
  int _createCount = 0;

  @override
  Future<Result<List<CollabActor>>> getMyActors() async =>
      Result.success(<CollabActor>[_actor]);

  @override
  Future<Result<CollabListing>> createDraft(
    CollabListingInput input, {
    required String clientRequestId,
  }) async {
    createRequestIds.add(clientRequestId);
    _createCount++;
    if (_createCount == 1) {
      return const Result.failure(
        AppError(code: 'temporary', message: 'Tekrar deneyin.'),
      );
    }
    return Result.success(
      _listing('draft-1', status: CollabListingStatus.draft),
    );
  }
}

class _AlwaysFailEditorRepository extends _RepositoryStub {
  final List<String> createRequestIds = <String>[];
  final List<CollabListingInput> inputs = <CollabListingInput>[];

  @override
  Future<Result<List<CollabActor>>> getMyActors() async =>
      Result.success(<CollabActor>[_actor]);

  @override
  Future<Result<CollabListing>> createDraft(
    CollabListingInput input, {
    required String clientRequestId,
  }) async {
    createRequestIds.add(clientRequestId);
    inputs.add(input);
    return const Result.failure(
      AppError(code: 'temporary', message: 'Tekrar deneyin.'),
    );
  }
}

class _ControlledPagedCubit extends CollabPagedCubit<CollabListing> {
  final List<Completer<Result<CollabPage<CollabListing>>>> requests =
      <Completer<Result<CollabPage<CollabListing>>>>[];
  final List<int> requestedPages = <int>[];

  @override
  Future<Result<CollabPage<CollabListing>>> fetchPage(int page, int size) {
    final request = Completer<Result<CollabPage<CollabListing>>>();
    requestedPages.add(page);
    requests.add(request);
    return request.future;
  }

  @override
  String itemId(CollabListing item) => item.id;
}

class _FailingApplicationRepository extends _RepositoryStub {
  final List<String> requestIds = <String>[];

  @override
  Future<Result<CollabListing>> getListing(String listingId) async =>
      Result.success(_listing(listingId, publisher: _venueActor));

  @override
  Future<Result<CollabApplication>> apply(
    String listingId,
    CollabApplicationInput input, {
    required String clientRequestId,
  }) async {
    requestIds.add(clientRequestId);
    return const Result.failure(
      AppError(code: 'temporary', message: 'Tekrar deneyin.'),
    );
  }
}

class _FailingReviewRepository extends _RepositoryStub {
  final List<String> requestIds = <String>[];

  @override
  Future<Result<CollabReview>> createReview(
    String jobId,
    CollabReviewInput input, {
    required String clientRequestId,
  }) async {
    requestIds.add(clientRequestId);
    return const Result.failure(
      AppError(code: 'temporary', message: 'Tekrar deneyin.'),
    );
  }
}

class _FailingReportRepository extends _RepositoryStub {
  final List<String> requestIds = <String>[];

  @override
  Future<Result<CollabListing>> getListing(String listingId) async =>
      Result.success(_listing(listingId, publisher: _venueActor));

  @override
  Future<Result<void>> reportListing(
    String listingId,
    CollabReportInput input, {
    required String clientRequestId,
  }) async {
    requestIds.add(clientRequestId);
    return const Result.failure(
      AppError(code: 'temporary', message: 'Tekrar deneyin.'),
    );
  }
}

class _SuccessfulMutationRepository extends _RepositoryStub {
  int getMyJobsCalls = 0;

  @override
  Future<Result<CollabListing>> getListing(String listingId) async =>
      Result.success(_listing(listingId, publisher: _venueActor));

  @override
  Future<Result<CollabApplication>> apply(
    String listingId,
    CollabApplicationInput input, {
    required String clientRequestId,
  }) async => Result.success(
    CollabApplication(
      id: 'application-1',
      version: 0,
      listing: _listing(listingId, publisher: _venueActor),
      applicant: _applicantActor,
      phone: input.phone,
      message: input.message,
      status: CollabApplicationStatus.pending,
      submittedAt: DateTime.utc(2026, 8, 11),
      statusChangedAt: DateTime.utc(2026, 8, 11),
    ),
  );

  @override
  Future<Result<void>> reportListing(
    String listingId,
    CollabReportInput input, {
    required String clientRequestId,
  }) async => const Result.success(null);

  @override
  Future<Result<CollabReview>> createReview(
    String jobId,
    CollabReviewInput input, {
    required String clientRequestId,
  }) async => Result.success(_review('created'));

  @override
  Future<Result<CollabPage<CollabJob>>> getMyJobs({
    CollabJobStatus? status,
    int page = 0,
    int size = 20,
  }) async {
    getMyJobsCalls += 1;
    return Result.success(
      CollabPage<CollabJob>(
        items: const <CollabJob>[],
        page: page,
        size: size,
        totalElements: 0,
        totalPages: 0,
        first: true,
        last: true,
      ),
    );
  }
}

class _ThrowingCleanupStore extends MemoryCollabIdempotencyStore {
  @override
  Future<void> complete(CollabIdempotencyLease lease) async {
    throw const CollabIdempotencyStoreException('cleanup failed');
  }
}

class _BlockingCleanupStore extends MemoryCollabIdempotencyStore {
  final Completer<void> cleanupStarted = Completer<void>();
  final Completer<void> allowCleanup = Completer<void>();

  @override
  Future<void> complete(CollabIdempotencyLease lease) async {
    cleanupStarted.complete();
    await allowCleanup.future;
    await super.complete(lease);
  }
}

class _SaveGuardRepository extends _RepositoryStub {
  _SaveGuardRepository(this.listing);

  final CollabListing listing;
  int saveCalls = 0;
  int unsaveCalls = 0;

  @override
  Future<Result<CollabListing>> getListing(String listingId) async =>
      Result.success(listing);

  @override
  Future<Result<void>> saveListing(String listingId) async {
    saveCalls += 1;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> unsaveListing(String listingId) async {
    unsaveCalls += 1;
    return const Result.success(null);
  }
}

class _ControlledReviewsRepository extends _RepositoryStub {
  final List<Completer<Result<CollabPage<CollabReview>>>> requests =
      <Completer<Result<CollabPage<CollabReview>>>>[];

  @override
  Future<Result<CollabPage<CollabReview>>> getActorReviews(
    String actorId, {
    int page = 0,
    int size = 20,
  }) {
    final request = Completer<Result<CollabPage<CollabReview>>>();
    requests.add(request);
    return request.future;
  }
}

CollabPage<CollabListing> _page(
  List<CollabListing> items, {
  int page = 0,
  bool last = true,
  int? total,
}) => CollabPage<CollabListing>(
  items: items,
  page: page,
  size: 20,
  totalElements: total ?? items.length,
  totalPages: last ? page + 1 : page + 2,
  first: page == 0,
  last: last,
);

const CollabActor _actor = CollabActor(
  actorId: 'actor-1',
  profileType: CollabProfileKind.venue,
  sourceProfileId: 'venue-1',
  contactUserId: 'user-1',
  displayName: 'Kadıköy Sahne',
  rating: 4.8,
  reviewCount: 12,
  completedJobCount: 22,
);

CollabListing _listing(
  String id, {
  String? title,
  int version = 1,
  CollabListingStatus status = CollabListingStatus.open,
  CollabActor publisher = _actor,
  bool ownedByMe = false,
}) => CollabListing(
  id: id,
  version: version,
  status: status,
  cadence: CollabCadence.regular,
  wantedType: CollabProfileKind.musician,
  title: title ?? 'Bas gitarist aranıyor',
  description: 'Düzenli sahneler için bas gitarist arıyoruz.',
  city: const CollabCitySummary(id: 'city-34', name: 'İstanbul'),
  genres: const <String>['Rock'],
  feeStatus: CollabFeeStatus.unspecified,
  publisher: publisher,
  ownedByMe: ownedByMe,
  appliedByMe: false,
  savedByMe: false,
);

CollabApplication _application({
  required CollabApplicationStatus status,
  required int version,
}) {
  final now = DateTime.utc(2026, 8, 15);
  return CollabApplication(
    id: 'application-1',
    version: version,
    listing: _listing('listing-1', publisher: _venueActor),
    applicant: _applicantActor,
    phone: '+905551112233',
    message: 'Uygunum.',
    status: status,
    submittedAt: now,
    statusChangedAt: now,
  );
}

const CollabActor _venueActor = CollabActor(
  actorId: 'actor-publisher',
  profileType: CollabProfileKind.venue,
  sourceProfileId: 'venue-2',
  contactUserId: 'user-publisher',
  displayName: 'Moda Sahne',
  rating: 4.5,
  reviewCount: 4,
  completedJobCount: 9,
);

const CollabActor _applicantActor = CollabActor(
  actorId: 'actor-applicant',
  profileType: CollabProfileKind.musician,
  sourceProfileId: 'musician-1',
  contactUserId: 'user-applicant',
  displayName: 'Deniz Kaya',
  rating: 4.7,
  reviewCount: 6,
  completedJobCount: 11,
);

CollabJob _completedJob() => CollabJob(
  id: 'job-1',
  version: 2,
  status: CollabJobStatus.completed,
  listing: _listing(
    'listing-job',
    status: CollabListingStatus.closed,
    publisher: _venueActor,
  ),
  publisher: _venueActor,
  applicant: _applicantActor,
  publisherConfirmedCompletion: true,
  applicantConfirmedCompletion: true,
  confirmedByMe: true,
  reviewedByMe: false,
  completedAt: DateTime.utc(2026, 8, 11),
);

CollabReview _review(String id) => CollabReview(
  id: id,
  jobId: 'job-$id',
  reviewer: _applicantActor,
  target: _venueActor,
  rating: 5,
  comment: 'Harika bir ekip.',
  createdAt: DateTime.utc(2026, 8, 11),
);

CollabPage<CollabReview> _reviewPage(List<CollabReview> items) =>
    CollabPage<CollabReview>(
      items: items,
      page: 0,
      size: 20,
      totalElements: items.length,
      totalPages: items.isEmpty ? 0 : 1,
      first: true,
      last: true,
    );
