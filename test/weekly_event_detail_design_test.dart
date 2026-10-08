import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_tracker.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/venue_analytics_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/venue_analytics_reporting_config.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/venue_analytics_reporting_scope.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/analytics_exposure.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/presentation/widgets/event_audience_controls.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_state.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_data.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_service.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/event_poster_fallback.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'support/event_audience_fakes.dart';

part 'weekly_event_detail_self_navigation_cases.dart';
part 'weekly_event_detail_band_navigation_cases.dart';
part 'weekly_event_detail_profile_chip_cases.dart';
part 'weekly_event_detail_profile_auth_cases.dart';
part 'weekly_event_detail_comment_auth_cases.dart';
part 'weekly_event_detail_comment_quality_cases.dart';
part 'weekly_event_detail_reference_cases.dart';
part 'weekly_event_detail_reply_design_cases.dart';
part 'weekly_event_detail_reply_pagination_cases.dart';
part 'weekly_event_detail_analytics_cases.dart';
part 'weekly_event_detail_audience_cases.dart';
part 'weekly_event_detail_loading_cases.dart';

part 'weekly_event_detail_design_test_register_weekly_event_detail_design1.dart';
part 'weekly_event_detail_design_test_register_weekly_event_detail_design2.dart';
part 'weekly_event_detail_design_test_cases.dart';

void main() {
  _WeeklyEventDetailDesignCases().register();
}

Finder _performerInfoButton() =>
    find.byKey(const Key('event-performer-verification-info'));

Finder _performerInfoDialog() =>
    find.byKey(const Key('event-performer-verification-dialog'));

InkWell _performerNameInkWell(WidgetTester tester, String name) {
  final chip = find.byKey(const Key('event-performer-profile-chip'));
  return tester.widget<InkWell>(
    find
        .ancestor(
          of: find.descendant(of: chip, matching: find.text(name)),
          matching: find.byType(InkWell),
        )
        .first,
  );
}

Finder _posterTapTarget() => find
    .ancestor(
      of: find.byType(EventPosterFallback),
      matching: find.byType(InkWell),
    )
    .first;

Future<void> _openDetail(
  WidgetTester tester,
  WeeklyCalendarEvent event, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool boldText = false,
  bool settle = true,
  ValueChanged<RouteSettings>? onRoute,
  EventShareService? shareService,
  VoidCallback? onEngagementChanged,
  GlobalKey? capture,
  VenueAnalyticsReportingConfig? reportingConfig,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final application = MaterialApp(
    navigatorObservers: [analyticsRouteObserver],
    debugShowCheckedModeBanner: capture == null,
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
      ).copyWith(textScaler: TextScaler.linear(textScale), boldText: boldText),
      child: child!,
    ),
    home: WeeklyEventDetailScreen(
      event: event,
      shareService: shareService,
      onEngagementChanged: onEngagementChanged,
    ),
    onGenerateRoute: (settings) {
      onRoute?.call(settings);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) =>
            const Scaffold(body: Text('Public profile destination')),
      );
    },
  );
  final capturedApplication = capture == null
      ? application
      : RepaintBoundary(key: capture, child: application);
  await tester.pumpWidget(
    reportingConfig == null
        ? capturedApplication
        : VenueAnalyticsReportingScope(
            config: reportingConfig,
            child: capturedApplication,
          ),
  );
  if (settle) {
    await tester.pumpAndSettle();
    // Post-paint zero-duration exposure callbacks use the next event-loop turn.
    await tester.pump(const Duration(milliseconds: 1));
  } else {
    // Resolve the fake repositories and render their avatar/identity result
    // without waiting for the network image's indeterminate placeholder.
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
    }
  }
}

WeeklyCalendarEvent _event({
  String id = 'event-design-1',
  String title = 'M-T1 — Katıl, gösterme',
  String artistName = 'bugrasahin',
  String? artistProfileId,
  String? bandProfileId,
  String performerType = 'MANUAL',
  String venueName = 'soundconnectankara',
  String? venueId,
  String city = 'Ankara',
  String district = 'Çankaya',
  String neighborhood = 'Çayyolu',
  String description = '',
}) => WeeklyCalendarEvent(
  id: id,
  title: title,
  artistName: artistName,
  artistProfileId: artistProfileId,
  bandProfileId: bandProfileId,
  performerType: performerType,
  venueName: venueName,
  venueId: venueId,
  city: city,
  district: district,
  neighborhood: neighborhood,
  eventDate: '06.09.2026',
  startTime: '20:00:00',
  endTime: '22:00:00',
  description: description,
);

VenueEventDetail _detail({required String? description}) => VenueEventDetail(
  id: 'event-design-1',
  shareUrl: null,
  posterImage: null,
  performerName: 'bugrasahin',
  musicianProfileId: null,
  description: description,
);

VenueEventDetail _shareDetail({
  String id = 'event-design-1',
  bool linked = false,
  String? description = 'Mekânın etkinlik için yazdığı güncel açıklama.',
}) => VenueEventDetail(
  id: id,
  shareUrl: 'https://soundconnect.app/event/event-design-1',
  posterImage: 'https://example.invalid/new-poster.png',
  performerName: 'Yeni sanatçı',
  musicianProfileId: linked ? 'current-profile-id' : null,
  performerType: linked ? 'MUSICIAN' : 'MANUAL',
  title: 'Güncel etkinlik',
  description: description,
  eventDate: DateTime(2026, 9, 12),
  startTime: '21:30:00',
  endTime: '23:00:00',
  venueId: 'current-venue-id',
  venueName: 'yenimekan',
  venueCity: 'İstanbul',
  venueDistrict: 'Kadıköy',
);

final Uint8List _sharePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

PreparedEventShare _prepared(EventShareData data) =>
    PreparedEventShare(bytes: _sharePng, data: data);

Future<void> _pumpShareSheet(WidgetTester tester) async {
  // The underlying share button intentionally animates while the preview is
  // open, so pumpAndSettle would wait forever for that progress indicator.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

class _EventShareService implements EventShareService {
  final preparedData = <EventShareData>[];
  final shared = <(PreparedEventShare, EventShareTarget)>[];
  Completer<PreparedEventShare>? preparation;
  Completer<void>? sending;
  bool failPreparation = false;
  bool failSending = false;

  @override
  Future<PreparedEventShare> prepare(
    BuildContext context,
    EventShareData data,
  ) async {
    preparedData.add(data);
    if (failPreparation) throw StateError('Preparation failed.');
    return preparation?.future ?? _prepared(data);
  }

  @override
  Future<void> share(
    BuildContext context,
    PreparedEventShare prepared,
    EventShareTarget target, {
    bool Function()? isValid,
  }) async {
    shared.add((prepared, target));
    if (failSending) throw StateError('Share failed.');
    await sending?.future;
  }
}

class _DetailRepository extends Fake implements VenueEventRepository {
  Result<VenueEventDetail> result = const Result.failure(
    AppError(code: 'unavailable', message: 'Details unavailable.'),
  );
  Completer<Result<VenueEventDetail>>? completion;
  final requestedIds = <String>[];

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async {
    requestedIds.add(eventId);
    return completion?.future ?? result;
  }
}

class _MusicianRepository extends Fake implements MusicianProfileRepository {
  final requestedIds = <String>[];
  Result<MusicianProfile> result = const Result.failure(
    AppError(code: 'unavailable', message: 'Profile image unavailable.'),
  );
  Completer<Result<MusicianProfile>>? completion;
  Result<MusicianProfile> myResult = const Result.failure(
    AppError(code: 'unavailable', message: 'Profile unavailable.'),
  );
  Completer<Result<MusicianProfile>>? myCompletion;
  int myReads = 0;
  bool throwMyRead = false;

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async {
    requestedIds.add(profileId);
    return completion?.future ?? result;
  }

  @override
  Future<Result<MusicianProfile>> getMyProfile() async {
    myReads++;
    if (throwMyRead) throw StateError('Profile request unavailable.');
    return myCompletion?.future ?? myResult;
  }
}

class _BandRepository extends Fake implements BandRepository {
  final requestedIds = <String>[];
  Result<BandProfile> result = const Result.failure(
    AppError(code: 'unavailable', message: 'Profile image unavailable.'),
  );
  Completer<Result<BandProfile>>? completion;
  bool throwRead = false;

  @override
  Future<Result<BandProfile>> getPublicBandById(String bandId) async {
    requestedIds.add(bandId);
    if (throwRead) throw StateError('Band profile request unavailable.');
    return completion?.future ?? result;
  }
}

class _VenueRepository extends Fake implements VenueProfileRepository {
  final requestedIds = <String?>[];
  bool includePhoto = true;
  Completer<void>? profileGate;

  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async {
    requestedIds.add(venueId);
    if (profileGate != null) await profileGate!.future;
    return Result.success(
      VenuePublicProfile(
        venueProfileId: 'venue-profile-id',
        venueId: venueId!,
        ownerUserId: 'venue-owner-id',
        venueName: 'soundconnectankarauzunmekankullaniciadi',
        bio: null,
        profilePictureUrl: includePhoto
            ? 'https://example.invalid/venue.jpg'
            : null,
        instagramUrl: null,
        youtubeUrl: null,
        websiteUrl: null,
        address: null,
        phone: null,
        website: null,
        description: null,
        musicStartTime: null,
        cityName: 'Ankara',
        districtName: 'Çankaya',
        neighborhoodName: 'Çayyolu',
        activeMusicians: const [],
        activeBands: const [],
        weeklyEvents: const [],
      ),
    );
  }
}

class _CommentsRepository extends Fake implements EngagementRepository {
  final comments = <CommentItem>[];
  final creations = <(String, String, String)>[];
  final creationParents = <String?>[];
  final replies = <String, List<CommentItem>>{};
  final replyReads = <(String, String?)>[];
  final listPages = <int>[];
  final replyPages = <int>[];
  final listSizes = <int>[];
  final replySizes = <int>[];
  final deletions = <String>[];
  Future<Result<CommentPage>> Function(int page)? replyPageResponse;
  Completer<Result<CommentItem>>? creationCompletion;
  Future<Result<CommentPage>> Function()? listResponse;
  int listCalls = 0;

  @override
  Future<Result<void>> deleteComment({required String commentId}) async {
    deletions.add(commentId);
    final index = comments.indexWhere((item) => item.id == commentId);
    if (index >= 0) {
      final old = comments[index];
      comments[index] = CommentItem(
        id: old.id,
        user: old.user,
        text: '',
        deleted: true,
        parentCommentId: old.parentCommentId,
        replyCount: old.replyCount,
        createdAt: old.createdAt,
      );
    }
    return const Result.success(null);
  }

  @override
  Future<Result<CommentPage>> listReplyPage(
    String commentId, {
    String? eventId,
    int page = 0,
    int size = 20,
  }) async {
    replyPages.add(page);
    replySizes.add(size);
    replyReads.add((commentId, eventId));
    if (replyPageResponse != null) return replyPageResponse!(page);
    final rows = replies[commentId] ?? const <CommentItem>[];
    return Result.success(
      CommentPage(
        items: rows.skip(page * size).take(size).toList(),
        totalElements: rows.length,
        page: page,
        size: size,
      ),
    );
  }

  @override
  Future<Result<List<CommentItem>>> listReplies(
    String commentId, {
    String? eventId,
  }) async {
    replyReads.add((commentId, eventId));
    return Result.success(List.of(replies[commentId] ?? const []));
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    listCalls++;
    listPages.add(page);
    listSizes.add(size);
    if (listResponse != null) return listResponse!();
    return Result.success(
      CommentPage(
        items: comments.skip(page * size).take(size).toList(),
        totalElements: comments.length,
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
    creations.add((targetType, targetId, text));
    creationParents.add(parentCommentId);
    if (creationCompletion != null) return creationCompletion!.future;
    final comment = CommentItem(
      id: 'comment-${creations.length}',
      user: const CommentUserSummary(
        id: 'commenter',
        username: 'dinleyici',
        avatarUrl: null,
      ),
      text: text,
      deleted: false,
      parentCommentId: parentCommentId,
      replyCount: 0,
      createdAt: DateTime(2026, 9, 5, 22),
    );
    if (parentCommentId == null) {
      comments.add(comment);
    } else {
      replies.putIfAbsent(parentCommentId, () => []).add(comment);
      final index = comments.indexWhere((item) => item.id == parentCommentId);
      if (index >= 0) {
        final parent = comments[index];
        comments[index] = CommentItem(
          id: parent.id,
          user: parent.user,
          text: parent.text,
          deleted: parent.deleted,
          parentCommentId: parent.parentCommentId,
          replyCount: parent.replyCount + 1,
          createdAt: parent.createdAt,
        );
      }
    }
    return Result.success(comment);
  }
}
