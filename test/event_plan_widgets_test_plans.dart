part of 'event_plan_widgets_test.dart';

class _Plans extends Fake implements EventPlanRepository {
  EventPlan plan = EventPlanRepositoryImpl.decodePlan(planJson());
  List<EventPlan>? ownerItems;
  final List<String> ownerReads = [];
  int ownerListCalls = 0;
  final List<int> ownerRequestedPages = [];
  Result<EventPlanPage<EventPlan>> Function(int page)? ownerPageResult;
  final List<EventPlanDefinition> previews = [];
  final List<(String?, int?)> previewContexts = [];
  List<DateTime> previewDates = [DateTime(2026, 9, 21), DateTime(2026, 9, 25)];
  List<EventPlanPreservedDate> preservedDates = [];
  int? previewFailureAfter;
  EventPlan? updatedPlan;
  EventPlanDefinition? updatedDefinition;
  int writes = 0;
  String? decision;
  bool? publication;
  Future<Result<EventPlan>>? performerRead, stopWrite;
  bool? stopCancelFuture;
  List<EventPlanOccurrence> rows = [];
  EventPlanOccurrence? editedOccurrence;
  DateTime? editedDate;
  EventPlanTemplate? editedTemplate;
  @override
  Future<Result<EventPlanPreview>> preview(
    EventPlanDefinition definition, {
    String? planId,
    int? expectedVersion,
  }) async {
    previews.add(definition);
    previewContexts.add((planId, expectedVersion));
    if (previewFailureAfter != null && previews.length > previewFailureAfter!) {
      return const Result.failure(
        AppError(code: '409', message: 'Program değişti. Yeniden aç.'),
      );
    }
    return Result.success(
      EventPlanPreview(
        dates: previewDates
            .where(
              (d) => !definition.excludedDates.any(
                (x) => eventPlanDate(x) == eventPlanDate(d),
              ),
            )
            .toList(),
        throughDate: DateTime(2026, 10, 18),
        hasMore: true,
        serverNow: DateTime.utc(2026, 9, 21, 10),
        preservedDates: preservedDates,
      ),
    );
  }

  @override
  Future<Result<EventPlan>> update(
    EventPlan plan,
    EventPlanDefinition definition,
  ) async {
    updatedPlan = plan;
    updatedDefinition = definition;
    writes++;
    return Result.success(plan);
  }

  @override
  Future<Result<EventPlanPage<EventPlan>>> listOwner(
    String venueId, {
    int page = 0,
  }) async {
    ownerListCalls++;
    ownerRequestedPages.add(page);
    if (ownerPageResult != null) return ownerPageResult!(page);
    return Result.success(
      EventPlanPage(items: ownerItems ?? [plan], page: page, hasNext: false),
    );
  }

  @override
  Future<Result<EventPlan>> getOwner(String id) async {
    ownerReads.add(id);
    return Result.success(
      (ownerItems ?? [plan]).firstWhere((item) => item.id == id),
    );
  }

  @override
  Future<Result<EventPlan>> getPerformer(String id) async =>
      performerRead ?? Result.success(plan);
  @override
  Future<Result<EventPlanPage<EventPlanOccurrence>>> occurrences(
    String id, {
    int page = 0,
  }) async =>
      Result.success(EventPlanPage(items: rows, page: page, hasNext: false));
  @override
  Future<Result<EventPlanPage<EventPlan>>> listPerformer(
    EventPerformerTargetType type,
    String id, {
    int page = 0,
  }) async =>
      Result.success(EventPlanPage(items: [plan], page: page, hasNext: false));
  @override
  Future<Result<EventPlan>> decide(
    EventPlan plan,
    String decision, {
    bool? showOnProfile,
  }) async {
    writes++;
    this.decision = decision;
    publication = showOnProfile;
    return Result.success(plan);
  }

  @override
  Future<Result<EventPlan>> stop(
    EventPlan plan, {
    required bool cancelFuture,
  }) async {
    stopCancelFuture = cancelFuture;
    return stopWrite ?? Result.success(plan);
  }

  @override
  Future<Result<EventPlan>> editOccurrence(
    EventPlan plan,
    EventPlanOccurrence occurrence, {
    required DateTime eventDate,
    required EventPlanTemplate template,
  }) async {
    editedOccurrence = occurrence;
    editedDate = eventDate;
    editedTemplate = template;
    return Result.success(plan);
  }
}

class _Sessions extends ChangeNotifier implements AuthSessionManager {
  AuthSession value = AuthSession.authenticated(
    token: 'token',
    userId: 'owner',
    username: 'Owner',
    accountStatus: 'ACTIVE',
    roles: ['ROLE_MUSICIAN'],
    permissions: [],
    expiresAt: DateTime(2100),
    isAdmin: false,
  );
  @override
  AuthSession get session => value;
  void signOut() {
    value = const AuthSession.guest();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Events extends Fake implements VenueEventRepository {
  @override
  Future<Result<VenueEventManagementSnapshot>> loadManagement(
    String id,
  ) async => Result.success(
    VenueEventManagementSnapshot(
      upcomingEvents: const [],
      pastCount: 0,
      historyAsOf: DateTime.now(),
    ),
  );

  @override
  Future<Result<VenueEventHistoryPage>> loadHistory(
    String id, {
    required DateTime asOf,
    String? cursor,
  }) async => const Result.success(
    VenueEventHistoryPage(items: [], nextCursor: null, hasNext: false),
  );

  @override
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String id) async =>
      const Result.success([]);
}

class _Search extends Fake implements ProfileSearchRepository {
  @override
  Future<Result<List<ProfileSearchResult>>> searchProfiles(
    String query, {
    Set<ProfileSearchResultType>? types,
  }) async => const Result.success([]);
}

const _owner = VenueOwnerProfile(
  venueProfileId: 'venue-profile',
  venueId: 'venue-1',
  ownerUserId: 'owner',
  venueName: 'Ankara Sahne',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: null,
  musicStartTime: null,
  cityId: null,
  cityName: 'Ankara',
  districtId: null,
  districtName: 'Çankaya',
  neighborhoodId: null,
  neighborhoodName: null,
  status: 'APPROVED',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);
