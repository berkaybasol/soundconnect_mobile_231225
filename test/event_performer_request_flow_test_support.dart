part of 'event_performer_request_flow_test.dart';

class _DisabledApprovalBandCalendarFactory
    implements BandCalendarRepositoryFactory {
  _DisabledApprovalBandCalendarFactory(this.repository);
  final MusicianCalendarRepository repository;
  int acquires = 0;
  final List<String> acquiredIds = [];
  final List<String> releasedIds = [];

  @override
  MusicianCalendarRepository acquire(String bandId) {
    acquires++;
    acquiredIds.add(bandId);
    return repository;
  }

  @override
  Future<void> release(String bandId) async {
    releasedIds.add(bandId);
  }

  @override
  Future<void> dispose() async {}
}

class _DisabledApprovalCalendarRepository
    implements MusicianCalendarRepository {
  int reads = 0;
  int updates = 0;
  bool visible = false;
  @override
  Stream<void> get changes => const Stream<void>.empty();
  @override
  void invalidate() {}
  @override
  Future<void> dispose() async {}
  @override
  Future<Result<MusicianCalendarSettings>> getSettings() async {
    reads++;
    return Result.success(
      MusicianCalendarSettings(visible: visible, version: 0),
    );
  }

  @override
  Future<Result<MusicianCalendarSettings>> updateSettings({
    required bool visible,
    required int version,
  }) async {
    updates++;
    return const Result.success(
      MusicianCalendarSettings(visible: false, version: 0),
    );
  }

  @override
  Future<Result<MusicianCalendarPage>> getCalendar({
    required String profileId,
    required DateTime startDate,
    required DateTime endDate,
    int page = 0,
    int size = 20,
  }) => throw UnimplementedError();
}

class _FakePerformerRequestRepository
    implements EventPerformerRequestRepository {
  @override
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  }) => throw UnimplementedError(
    'Unexpected reconsideration in pending request test.',
  );

  final Map<int, EventPerformerRequestPage> pages;
  final List<Result<EventPerformerRequestPage>>? listResults;
  final List<Future<Result<EventPerformerRequestPage>>>? listFutures;
  final Completer<Result<void>>? acceptCompletion;
  final bool throwOnAccept;
  int listCalls = 0;
  int acceptCalls = 0;
  final List<(String, bool)> acceptChoices = [];
  int rejectCalls = 0;
  final List<int> requestedPages = <int>[];
  final List<EventPerformerTargetType?> targetTypes =
      <EventPerformerTargetType?>[];
  final List<String?> targetIds = <String?>[];

  _FakePerformerRequestRepository({
    this.pages = const <int, EventPerformerRequestPage>{},
    this.listResults,
    this.listFutures,
    this.acceptCompletion,
    this.throwOnAccept = false,
  });

  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async {
    requestedPages.add(page);
    targetTypes.add(targetType);
    targetIds.add(targetId);
    final call = listCalls++;
    final futures = listFutures;
    if (futures != null && futures.isNotEmpty) {
      return futures[call.clamp(0, futures.length - 1)];
    }
    final results = listResults;
    if (results != null && results.isNotEmpty) {
      return results[call.clamp(0, results.length - 1)];
    }
    return Result.success(
      pages[page] ?? _page(const <EventPerformerRequest>[], page: page),
    );
  }

  @override
  Future<Result<void>> accept(
    String requestId, {
    bool showOnProfile = false,
  }) async {
    acceptCalls += 1;
    acceptChoices.add((requestId, showOnProfile));
    if (throwOnAccept) throw StateError('unexpected decision failure');
    return acceptCompletion == null
        ? const Result.success(null)
        : acceptCompletion!.future;
  }

  @override
  Future<Result<void>> reject(String requestId) async {
    rejectCalls += 1;
    return const Result.success(null);
  }
}

class _DetailVenueEventRepository implements VenueEventRepository {
  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async {
    return const Result.failure(
      AppError(code: 'not_needed', message: 'Not needed by this widget test.'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredVenueEventRepository implements VenueEventRepository {
  final Map<String, Completer<Result<VenueEventDetail>>> _completers =
      <String, Completer<Result<VenueEventDetail>>>{};
  final List<String> requestedIds = <String>[];

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) {
    requestedIds.add(eventId);
    return (_completers[eventId] ??= Completer<Result<VenueEventDetail>>())
        .future;
  }

  void complete(String eventId, {required String performerName}) {
    _completers[eventId]!.complete(
      Result.success(
        VenueEventDetail(
          id: eventId,
          shareUrl: null,
          posterImage: null,
          performerName: performerName,
          musicianProfileId: null,
          bandId: null,
          performerType: 'MANUAL',
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopEngagementRepository implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnavailableMusicianProfileRepository
    implements MusicianProfileRepository {
  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async => const Result.failure(
    AppError(code: 'not_needed', message: 'Profile loading is not under test.'),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingMusicianProfileRepository implements MusicianProfileRepository {
  final Map<String, int> calls = <String, int>{};

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async {
    calls.update(profileId, (count) => count + 1, ifAbsent: () => 1);
    return Result.success(
      MusicianProfile(
        id: profileId,
        userId: 'user-$profileId',
        username: profileId,
        stageName: profileId,
        bio: null,
        profilePicture: null,
        instagramUrl: null,
        youtubeUrl: null,
        soundcloudUrl: null,
        spotifyEmbedUrl: null,
        spotifyArtistId: null,
        spotifyTrackIds: const <String>[],
        spotifyTracks: const [],
        instruments: const <String>[],
        activeVenues: const <String>[],
        bands: const <String>[],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnavailableBandRepository implements BandRepository {
  @override
  Future<Result<BandProfile>> getPublicBandById(String bandId) async {
    return const Result.failure(
      AppError(
        code: 'not_needed',
        message: 'Profile loading is not under test.',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PerformerRequestApiClient extends ApiClient {
  final List<Object?> getResponses;
  final List<String> getPaths = <String>[];
  final List<Map<String, dynamic>> getQueries = <Map<String, dynamic>>[];
  final List<String> postPaths = <String>[];
  ApiRequestContext? requestContext;
  Completer<void>? pendingDecision;

  _PerformerRequestApiClient(this.getResponses);

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    this.requestContext = requestContext;
    postPaths.add(path);
    if (pendingDecision != null) await pendingDecision!.future;
    return decoder!(null);
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    getPaths.add(path);
    getQueries.add(Map<String, dynamic>.from(query ?? const {}));
    final index = getPaths.length - 1;
    return decoder!(getResponses[index]);
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    postPaths.add(path);
    return decoder!(null);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();
}
