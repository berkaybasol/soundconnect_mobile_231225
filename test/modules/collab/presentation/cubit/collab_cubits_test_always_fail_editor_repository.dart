part of 'collab_cubits_test.dart';

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
