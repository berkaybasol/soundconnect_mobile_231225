import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_event_feed_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_note_editor.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_ghost_profile_content.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

part 'listener_event_posts_test_register_listener_event_posts1.dart';
part 'listener_event_posts_test_register_listener_event_posts2.dart';
part 'listener_event_posts_test_register_listener_event_posts3.dart';
part 'listener_event_posts_test_cases.dart';

void main() {
  _ListenerEventPostsCases().register();
}

ListenerEventFeedController _feed(
  _Repository repository,
  _Sessions sessions, {
  bool privatePlans = true,
  int size = 20,
}) => ListenerEventFeedController(
  repository: repository,
  sessions: sessions,
  listenerProfileId: 'profile',
  ownerUserId: privatePlans ? 'user' : null,
  privatePlans: privatePlans,
  pageSize: size,
);

AuthSession _session({
  String userId = 'user',
  String token = 'token',
  String username = 'listener',
  String role = 'ROLE_LISTENER',
  String status = 'ACTIVE',
  List<String> extraRoles = const [],
}) => AuthSession.authenticated(
  token: token,
  userId: userId,
  username: username,
  accountStatus: status,
  roles: [role, ...extraRoles],
  permissions: const [],
  expiresAt: DateTime.utc(2040),
  isAdmin: false,
);

class _Sessions extends Fake with ChangeNotifier implements AuthSessionManager {
  _Sessions(this._session);
  AuthSession _session;
  @override
  AuthSession get session => _session;
  void change(AuthSession value) {
    _session = value;
    notifyListeners();
  }
}

typedef _Call = (String, String, EventAudiencePeriod, int, int);

class _Repository extends Fake implements EventAudienceRepository {
  @override
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  final calls = <_Call>[];
  int getCalls = 0;
  EventAudienceState viewerIntent = _state(intent: EventAudienceStatus.none);
  final intentWrites = <(EventAudienceStatus, bool, String?, int, String)>[];
  Completer<Result<EventAudienceState>>? pendingIntent;
  Completer<Result<EventAudienceState>>? pendingRead;
  bool failIntent = false;
  final deletedPosts = <(String, String)>[];
  bool deleteFailure = false;
  int minePage = 0;
  bool mineHasNext = false;
  bool publicFailure = false;
  bool publicHasNext = false;
  List<EventAudiencePost>? posts;
  Future<Result<EventAudiencePage<EventAudienceState>>> Function(
    EventAudiencePeriod,
  )?
  mine;
  @override
  Future<Result<EventAudiencePage<EventAudienceState>>> listMine({
    required String expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.upcoming,
    int page = 0,
    int size = 20,
  }) {
    calls.add(('mine', expectedSessionKey, period, page, size));
    return mine?.call(period) ??
        Future.value(
          Result.success(
            _page([_state()], page: minePage, hasNext: mineHasNext),
          ),
        );
  }

  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    calls.add((
      listenerProfileId,
      expectedSessionKey ?? '',
      period,
      page,
      size,
    ));
    if (publicFailure) {
      return const Result.failure(
        AppError(code: '404', message: 'Profil kullanılamıyor.'),
      );
    }
    return Result.success(_page(posts ?? [_post()], hasNext: publicHasNext));
  }

  @override
  Future<Result<EventAudienceState>> getIntent({
    required String eventId,
    required String expectedSessionKey,
  }) async {
    getCalls++;
    if (pendingRead != null) return pendingRead!.future;
    return Result.success(viewerIntent);
  }

  @override
  Future<Result<EventAudienceState>> setIntent({
    required String eventId,
    required EventAudienceStatus intent,
    required bool publishedOnProfile,
    required String? note,
    required int expectedVersion,
    required String expectedSessionKey,
  }) async {
    intentWrites.add((
      intent,
      publishedOnProfile,
      note,
      expectedVersion,
      expectedSessionKey,
    ));
    if (pendingIntent != null) return pendingIntent!.future;
    if (failIntent) {
      return const Result.failure(
        AppError(code: 'network', message: 'Offline'),
      );
    }
    viewerIntent = _state(
      id: eventId,
      intent: intent,
      published: publishedOnProfile,
      note: note,
      version: expectedVersion + 1,
    );
    changes.value++;
    return Result.success(viewerIntent);
  }

  @override
  Future<Result<EventAudienceState>> deletePost({
    required String postId,
    required String expectedSessionKey,
  }) async {
    deletedPosts.add((postId, expectedSessionKey));
    if (deleteFailure) {
      return const Result.failure(
        AppError(code: 'network', message: 'Paylaşım silinemedi.'),
      );
    }
    posts = [];
    changes.value++;
    return Result.success(_state());
  }
}

class _CommentsRepository extends Fake implements EngagementRepository {
  final reads = <(String, String)>[];
  final writes = <(String, String, String)>[];
  final likes = <(String, String, bool)>[];
  final likedPosts = <String>{};
  bool failLike = false;
  Completer<Result<void>>? pendingLike;
  Completer<Result<bool>>? pendingIsLiked;

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async => Result.success(likedPosts.contains(targetId) ? 1 : 0);

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async {
    final pending = pendingIsLiked;
    pendingIsLiked = null;
    return pending != null
        ? pending.future
        : Result.success(likedPosts.contains(targetId));
  }

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) async {
    likes.add((targetType, targetId, true));
    if (pendingLike != null) return pendingLike!.future;
    if (failLike) {
      return const Result.failure(
        AppError(code: 'network', message: 'Beğeni kaydedilemedi.'),
      );
    }
    likedPosts.add(targetId);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async {
    likes.add((targetType, targetId, false));
    likedPosts.remove(targetId);
    return const Result.success(null);
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    reads.add((targetType, targetId));
    return Result.success(
      CommentPage(
        items: const [],
        totalElements: writes.length,
        page: page,
        size: size,
      ),
    );
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    writes.add((targetType, targetId, text));
    return Result.success(
      CommentItem(
        id: 'new-comment',
        user: const CommentUserSummary(
          id: 'user',
          username: 'listener',
          avatarUrl: null,
        ),
        text: text,
        deleted: false,
        parentCommentId: parentCommentId,
        replyCount: 0,
        createdAt: DateTime.now(),
      ),
    );
  }
}

EventAudiencePage<T> _page<T>(
  List<T> items, {
  int page = 0,
  bool hasNext = false,
}) => EventAudiencePage(
  items: items,
  page: page,
  size: 20,
  totalElements: hasNext ? 21 : items.length,
  totalPages: hasNext
      ? 2
      : items.isEmpty
      ? 0
      : 1,
  hasNext: hasNext,
);

EventAudienceState _state({
  String id = 'event',
  bool ended = false,
  bool available = true,
  bool published = false,
  bool visible = false,
  String? note,
  int version = 1,
  EventAudienceStatus intent = EventAudienceStatus.going,
}) => EventAudienceState(
  eventId: id,
  postId: published ? 'post-$id' : null,
  intent: intent,
  publishedOnProfile: published,
  note: note,
  version: version,
  updatedAt: DateTime.utc(2026, 9, 8),
  eventAvailable: available,
  eventEnded: ended,
  canSetIntent: !ended,
  canPublish: !ended,
  publicationVisible: visible,
  event: available ? _event(id: id) : null,
);

EventAudiencePost _post({bool ended = false, String postId = 'post-event'}) =>
    EventAudiencePost(
      eventId: 'event',
      postId: postId,
      intent: EventAudienceStatus.going,
      note: 'Birlikte müzik dinleyelim.',
      publishedAt: DateTime.utc(2026, 9, 8),
      event: _event(),
      eventEnded: ended,
    );

VenueEventDetail _event({String id = 'event', bool long = false}) =>
    VenueEventDetail(
      id: id,
      shareUrl: null,
      posterImage: null,
      musicianProfileId: null,
      performerName: long
          ? 'Dolu Kadehi Ters Tut ve uzun bir sanatçı adı'
          : 'Sahbaz',
      title: long
          ? 'Çok uzun bir etkinlik başlığı ve devam eden açıklayıcı ad'
          : 'Gerçek etkinlik',
      eventDate: DateTime(2026, 9, 9),
      startTime: '20:00:00',
      endTime: '22:00:00',
      venueId: 'venue',
      venueName: 'SoundConnect Ankara',
      venueCity: 'Ankara',
      venueDistrict: 'Çankaya',
    );

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  bool screen = false,
  GlobalKey? capture,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: capture == null
            ? AppTheme.navy
            : AppTheme.navy.copyWith(
                textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
                primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                  fontFamily: 'Roboto',
                ),
              ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen
            ? child
            : Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
