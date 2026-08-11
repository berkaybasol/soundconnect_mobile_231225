import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
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
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_actor_reviews_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_async_state.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_discovery_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_jobs_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_editor_cubit.dart';
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
            AppError(code: 'network', message: 'BaÄŸlantÄ± kurulamadÄ±.'),
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
          AppError(code: 'network', message: 'BaÄŸlantÄ± kurulamadÄ±.'),
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
}

class _RepositoryStub implements CollabRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  @override
  Future<Result<List<CollabActor>>> getMyActors() async =>
      Result.success(<CollabActor>[_actor]);

  @override
  Future<Result<CollabListing>> createDraft(
    CollabListingInput input, {
    required String clientRequestId,
  }) async {
    createRequestIds.add(clientRequestId);
    return const Result.failure(
      AppError(code: 'temporary', message: 'Tekrar deneyin.'),
    );
  }
}

class _ControlledPagedCubit extends CollabPagedCubit<CollabListing> {
  final List<Completer<Result<CollabPage<CollabListing>>>> requests =
      <Completer<Result<CollabPage<CollabListing>>>>[];

  @override
  Future<Result<CollabPage<CollabListing>>> fetchPage(int page, int size) {
    final request = Completer<Result<CollabPage<CollabListing>>>();
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
  CollabListingStatus status = CollabListingStatus.open,
  CollabActor publisher = _actor,
}) => CollabListing(
  id: id,
  version: 1,
  status: status,
  cadence: CollabCadence.regular,
  wantedType: CollabProfileKind.musician,
  title: title ?? 'Bas gitarist aranıyor',
  description: 'Düzenli sahneler için bas gitarist arıyoruz.',
  city: const CollabCitySummary(id: 'city-34', name: 'İstanbul'),
  genres: const <String>['Rock'],
  feeStatus: CollabFeeStatus.unspecified,
  publisher: publisher,
  ownedByMe: false,
  appliedByMe: false,
  savedByMe: false,
);

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
