part of 'artist_venue_application_flow_test.dart';

class _Applications extends Fake implements ArtistVenueConnectionRepository {
  final connectionFilters = <bool>[];
  Result<List<ArtistVenueApplication>> readResult = Result.success([
    _application(),
  ]);
  Result<void> actionResult = const Result.success(null);
  Completer<Result<void>>? pendingAction;
  int reads = 0;
  final actions = <(String, String?)>[];
  final pageRequests =
      <(int, ArtistVenueApplicationTarget, String, bool, String?)>[];
  Future<Result<ArtistVenueApplicationPage>> Function(int)? onPageRead;
  @override
  Future<Result<ArtistVenueApplicationPage>> listApplicationPage({
    required ArtistVenueApplicationTarget target,
    required String targetId,
    required bool incoming,
    bool connectionsOnly = false,
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  }) async {
    reads++;
    connectionFilters.add(connectionsOnly);
    pageRequests.add((page, target, targetId, incoming, expectedSessionKey));
    if (onPageRead != null) return onPageRead!(page);
    if (!readResult.isSuccess) return Result.failure(readResult.error);
    final items = readResult.data!;
    return Result.success(
      ArtistVenueApplicationPage(
        items: items,
        page: page,
        size: size,
        totalElements: items.length,
        totalPages: items.isEmpty ? 0 : 1,
        last: true,
      ),
    );
  }

  @override
  Future<Result<void>> acceptRequest(
    String requestId, {
    String? expectedSessionKey,
  }) async {
    actions.add((requestId, expectedSessionKey));
    return pendingAction?.future ?? actionResult;
  }

  @override
  Future<Result<void>> rejectRequest(
    String requestId, {
    String? expectedSessionKey,
  }) => acceptRequest(requestId, expectedSessionKey: expectedSessionKey);

  @override
  Future<Result<void>> disconnect(
    String requestId, {
    String? expectedSessionKey,
  }) => acceptRequest(requestId, expectedSessionKey: expectedSessionKey);
}

class _Profiles extends Fake implements MusicianProfileRepository {}

// Same recording boundary as profile_notification_target_read_test.dart:
// production ticket and destination run; only the outgoing read call is recorded.
class _ApplicationReadCubit extends Fake implements NotificationCubit {
  final ids = <String>[];

  @override
  bool get isClosed => false;

  @override
  Future<void> markAsRead(AppNotification notification) async {
    ids.add(notification.id);
  }
}

class _ApplicationTicketObserver extends NavigatorObserver {
  NotificationTargetRead? nextTicket;
  int attached = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final ticket = nextTicket;
    if (ticket != null && route is PopupRoute) {
      nextTicket = null;
      ticket.attach(route);
      attached++;
    }
    super.didPush(route, previousRoute);
  }
}

class _Directory extends Fake implements VenueDirectoryRepository {
  int reads = 0;
  @override
  Future<Result<List<VenueOption>>> getAllVenues() async {
    reads++;
    return const Result.success([]);
  }
}

class _Api extends Fake implements ApiClient {
  final contexts = <String?>[];
  final methods = <ApiHttpMethod>[];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    contexts.add(requestContext?.expectedSessionKey);
    methods.add(method);
    return decoder!(null);
  }
}

const _musician = MusicianProfile(
  id: 'musician',
  userId: 'account',
  username: 'Artist',
  stageName: 'Artist',
  bio: null,
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: [],
  activeVenues: [],
  bands: [],
);
