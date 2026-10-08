part of 'inbox_product_notification_open_test.dart';

class _Harness {
  _Harness(this.selected) {
    posts.incoming = selected.type.endsWith('RECEIVED');
    posts.status = posts.incoming ? 'PENDING' : 'REJECTED';
    notices = _Notices(selected);
    api = RecordingApiClient((r) async {
      if (r.path.endsWith('/read')) {
        acks.add(notice);
        if (ackPending != null) await ackPending!.future;
        if (ackFailures-- > 0) throw ApiException(failure);
        return null;
      }
      if (lookupPending != null) await lookupPending!.future;
      if (offline) throw ApiException(failure);
      return wire(selected);
    });
    final repo = NotificationTargetRepository(api, sessions);
    serviceLocator
      ..registerSingleton<AuthSessionManager>(sessions)
      ..registerSingleton<NotificationCubit>(notices)
      ..registerSingleton<TokenStore>(tokens)
      ..registerSingleton<DmBadgeCubit>(badge)
      ..registerSingleton<NotificationTargetRepository>(repo)
      ..registerSingleton<CollabRepository>(domain)
      ..registerSingleton<LocationRepository>(_Locations())
      ..registerSingleton<InstrumentRepository>(_Instruments())
      ..registerSingleton<OverthinkingRepository>(posts)
      ..registerFactory<CollabDiscoveryCubit>(
        () => CollabDiscoveryCubit(domain),
      )
      ..registerFactory<CollabListingDetailCubit>(
        () => CollabListingDetailCubit(domain),
      )
      ..registerFactory<CollabIncomingApplicationsCubit>(
        () => CollabIncomingApplicationsCubit(domain),
      )
      ..registerFactory<CollabMyApplicationsCubit>(
        () => CollabMyApplicationsCubit(domain),
      )
      ..registerFactory<CollabJobsCubit>(() => CollabJobsCubit(domain))
      ..registerFactory<CollabActorReviewsCubit>(
        () => CollabActorReviewsCubit(domain),
      );
  }
  final AppNotification selected;
  final sessions = AudienceTestSessions(
    audienceSession(user: user, role: 'ROLE_MUSICIAN'),
  );
  final tokens = _Tokens();
  late final badge = DmBadgeCubit(_Dm(), tokens);
  final domain = _Domain();
  final posts = _Posts();
  final navigator = GlobalKey<NavigatorState>();
  final messenger = ValueNotifier(GlobalKey<ScaffoldMessengerState>());
  final observer = _Observer();
  final acks = <String>[];
  late final _Notices notices;
  late final RecordingApiClient api;
  bool offline = false;
  bool native = false;
  int ackFailures = 0;
  Completer<void>? lookupPending;
  Future<void>? openFuture;
  Completer<void>? ackPending;
  Future<void> mount(WidgetTester t) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      if (!notices.isClosed) await dispose();
    });
    t.view.physicalSize = const Size(600, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: notices,
        child: ValueListenableBuilder<GlobalKey<ScaffoldMessengerState>>(
          valueListenable: messenger,
          builder: (_, messengerKey, _) => MaterialApp(
            scaffoldMessengerKey: messengerKey,
            navigatorKey: navigator,
            navigatorObservers: [observer, notificationTargetRouteObserver],
            home: const Scaffold(body: Text('Original product')),
          ),
        ),
      ),
    );
    openFuture = open();
    unawaited(openFuture);
  }

  Future<void> open() => NotificationDirectOpen.start(
    navigator.currentContext!,
    identity: notice,
    builder: (_) => native
        ? InboxProductNotificationOpen.native(
            target: PushTarget(
              notificationId: notice,
              recipientId: user,
              type: selected.type,
            ),
          )
        : InboxProductNotificationOpen(notification: selected),
  );

  Future<void> dispose() async {
    messenger.dispose();
    await notices.close();
    await badge.close();
    sessions.dispose();
  }
}

class _Notices extends Cubit<NotificationState> implements NotificationCubit {
  _Notices(this.selected)
    : super(
        const NotificationState.initial().copyWith(
          unreadCount: 2,
          items: [
            selected,
            AppNotification(
              id: '50000000-0000-4000-8000-000000000002',
              recipientId: user,
              type: selected.type,
              title: 'Sibling',
              message: '',
              read: false,
              createdAt: null,
              payload: selected.payload,
            ),
          ],
        ),
      );
  final AppNotification selected;
  @override
  Future<void> applyConfirmedExternalRead(
    AppNotification n,
    dynamic session,
  ) async {
    emit(
      state.copyWith(
        unreadCount: 1,
        items: state.items
            .map((item) => item.id == n.id ? item.copyWith(read: true) : item)
            .toList(),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> r, Route<dynamic>? p) {
    pushes++;
  }
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _Dm extends Fake implements DmRepository {}

CollabPage<T> page<T>(List<T> items) => CollabPage(
  items: items,
  page: 0,
  size: 30,
  totalElements: items.length,
  totalPages: 1,
  first: true,
  last: true,
);

class _Domain extends Fake implements CollabRepository {
  int calls = 0;
  int listCount = 1, targetIndex = 0;
  bool longApplication = false;
  final listing = collabListingFixture(id: listingId, ownedByMe: true);
  CollabApplication applicationAt(int index) => CollabApplication(
    id: index == targetIndex ? requestId : 'application-$index',
    version: 0,
    listing: listing,
    applicant: musicianActor,
    phone: '05551234567',
    message: longApplication
        ? List.filled(90, 'Long application line').join('\n')
        : 'Exact application',
    status: CollabApplicationStatus.pending,
    submittedAt: DateTime.utc(2026),
    statusChangedAt: DateTime.utc(2026),
  );
  CollabJob jobAt(int index) => CollabJob(
    id: index == targetIndex ? jobId : 'job-$index',
    version: 0,
    status: CollabJobStatus.completed,
    listing: listing,
    publisher: venueActor,
    applicant: musicianActor,
    publisherConfirmedCompletion: true,
    applicantConfirmedCompletion: true,
    confirmedByMe: true,
    reviewedByMe: true,
  );
  @override
  Future<Result<CollabListing>> getListing(String id) async =>
      Result.success(listing);
  @override
  Future<Result<List<CollabActor>>> getMyActors() async =>
      const Result.success([musicianActor]);
  @override
  Future<Result<CollabPage<CollabListing>>> discover(
    CollabDiscoveryQuery q,
  ) async => Result.success(page([listing]));
  @override
  Future<Result<CollabPage<CollabApplication>>> getIncomingApplications(
    String id, {
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(_pageApps());
  @override
  Future<Result<CollabPage<CollabApplication>>> getMyApplications({
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(_pageApps());
  CollabPage<CollabApplication> _pageApps() {
    calls++;
    return page(List.generate(listCount, applicationAt));
  }

  @override
  Future<Result<CollabPage<CollabJob>>> getMyJobs({
    CollabJobStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result.success(_pageJobs());
  CollabPage<CollabJob> _pageJobs() {
    calls++;
    return page(List.generate(listCount, jobAt));
  }

  @override
  Future<Result<CollabPage<CollabReview>>> getActorReviews(
    String id, {
    int page = 0,
    int size = 20,
  }) async => Result.success(_pageReviews());
  CollabPage<CollabReview> _pageReviews() {
    calls++;
    return page(
      List.generate(
        listCount,
        (index) => CollabReview(
          id: index == targetIndex ? reviewId : 'review-$index',
          jobId: jobId,
          reviewer: musicianActor,
          target: venueActor,
          rating: 5,
          comment: 'Exact review',
          createdAt: DateTime.utc(2026),
        ),
      ),
    );
  }
}

class _Locations extends Fake implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async => const Result.success([]);
}

class _Instruments extends Fake implements InstrumentRepository {
  @override
  Future<Result<List<Instrument>>> getAll() async => const Result.success([]);
}

class _Posts extends Fake implements OverthinkingRepository {
  bool exact = true;
  bool incoming = false;
  String status = 'REJECTED';
  String targetPost = listingId;
  int calls = 0, seenWrites = 0, listCount = 1, targetPage = 0;
  bool longTitle = false;
  OverthinkingRevealRequest get request => OverthinkingRevealRequest(
    id: exact ? requestId : 'other',
    postId: targetPost,
    postTitle: longTitle
        ? List.filled(7, 'Exact post').join(' ').substring(0, 64)
        : 'Exact post',
    requesterId: incoming ? '70000000-0000-4000-8000-000000000002' : user,
    requesterUsername: 'Demo',
    authorId: status == 'APPROVED'
        ? (incoming ? user : '70000000-0000-4000-8000-000000000002')
        : '',
    status: status,
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));
  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) async => _requests(page);
  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) async => _requests(page);
  Result<Page<OverthinkingRevealRequest>> _requests(int page) {
    calls++;
    return Result.success(
      Page(
        items: [
          if (page == targetPage) request,
          for (var i = 1; i < listCount; i++)
            OverthinkingRevealRequest(
              id: 'other-$page-$i',
              postId: 'other-post-$i',
              postTitle: 'Sibling post $i',
              requesterId: 'other',
              requesterUsername: 'Sibling',
              authorId: user,
              status: 'REJECTED',
              createdAt: DateTime.utc(2026),
            ),
        ],
        hasNext: page < targetPage,
      ),
    );
  }

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>>
  getIncomingUnreadStatus() async => const Result.success(
    OverthinkingIncomingUnreadStatus(hasUnread: false, revision: 0),
  );
  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) async {
    seenWrites++;
    return const Result.success(
      OverthinkingIncomingUnreadStatus(hasUnread: false, revision: 0),
    );
  }
}
