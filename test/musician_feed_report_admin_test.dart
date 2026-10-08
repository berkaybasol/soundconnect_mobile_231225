import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/musician_feed_report_admin_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/musician_feed_report_admin.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/musician_feed_report_admin_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/cubit/musician_feed_report_admin_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/cubit/musician_feed_restrictions_admin_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/musician_feed_restrictions_admin_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/musician_feed_report_admin_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

part 'musician_feed_report_admin_test_register_musician_feed_report_admin1.dart';
part 'musician_feed_report_admin_test_register_musician_feed_report_admin2.dart';

const reportAdminTestId = '11111111-1111-4111-8111-111111111111';

const _secondId = '22222222-2222-4222-8222-222222222222';

const _targetId = '33333333-3333-4333-8333-333333333333';

const _userId = '44444444-4444-4444-8444-444444444444';

const _offline = AppError(code: 'offline', message: 'Bağlantı kurulamadı.');

void main() {
  _registerMusicianFeedReportAdmin1();
  _registerMusicianFeedReportAdmin2();
}

AuthSession reportAdminTestSession({
  String user = _userId,
  String token = 'admin-token',
  String status = 'ACTIVE',
  List<String> permissions = const [musicianFeedReportAdminPermission],
}) => AuthSession.authenticated(
  token: token,
  userId: user,
  username: 'Moderator',
  accountStatus: status,
  roles: const ['ROLE_ADMIN'],
  permissions: permissions,
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
);

MusicianFeedRestrictionsAdminCubit _restrictions(
  ReportAdminTestRepository repository, {
  AudienceTestSessions? sessions,
}) {
  final cubit = MusicianFeedRestrictionsAdminCubit(
    repository,
    sessions ?? _sessions(),
  );
  addTearDown(cubit.close);
  return cubit;
}

MusicianFeedOrphanRestriction reportAdminTestRestriction({
  String updatedAt = '2026-09-13T17:00:00.123456Z',
}) => MusicianFeedOrphanRestriction.fromJson(
  _wireRestriction(updatedAt: updatedAt),
);

Map<String, Object?> _wireRestriction({
  String updatedAt = '2026-09-13T17:00:00.123456Z',
}) => {
  'reportId': reportAdminTestId,
  'scopeKey': 'MEDIA:$_targetId',
  'scopeDescription':
      'Bu medya ve aynı medyayı gösteren müzisyen akışı kartları.',
  'appliedByUserId': _userId,
  'appliedAt': '2026-09-13T17:00:00.123456Z',
  'updatedAt': updatedAt,
};

MusicianFeedRestrictionRestored _restored() => MusicianFeedRestrictionRestored(
  reportId: reportAdminTestId,
  updatedAt: DateTime.utc(2026, 9, 13, 18),
  activeRestriction: true,
);

AudienceTestSessions _sessions() {
  final sessions = AudienceTestSessions(reportAdminTestSession());
  addTearDown(sessions.dispose);
  return sessions;
}

void _transition(AudienceTestSessions sessions, String kind) {
  switch (kind) {
    case 'account':
      sessions.replace(reportAdminTestSession(user: _secondId));
    case 'token':
      sessions.replace(reportAdminTestSession(token: 'rotated-token'));
    case 'authority':
      sessions.replace(reportAdminTestSession(permissions: const []));
    case 'transient':
      sessions.replace(reportAdminTestSession(permissions: const []));
      sessions.replace(reportAdminTestSession());
  }
}

MusicianFeedReportAdminCubit _queue(
  ReportAdminTestRepository repository, {
  AudienceTestSessions? sessions,
}) {
  final cubit = MusicianFeedReportAdminCubit(
    repository,
    sessions ?? _sessions(),
  );
  addTearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });
  return cubit;
}

MusicianFeedReportDetailCubit _detail(
  ReportAdminTestRepository repository, {
  AudienceTestSessions? sessions,
}) {
  final cubit = MusicianFeedReportDetailCubit(
    repository,
    sessions ?? _sessions(),
    reportAdminTestId,
  );
  addTearDown(cubit.close);
  return cubit;
}

Future<bool> _remove(MusicianFeedReportDetailCubit cubit) => cubit.review(
  MusicianFeedReportDecision.removeFromFeed,
  'İnceleme tamamlandı.',
  expectedVersion: 0,
  expectedEpoch: cubit.sessionEpoch,
);

Future<void> _pumpQueue(
  WidgetTester tester,
  ReportAdminTestRepository repository, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    _app(
      MusicianFeedReportAdminScreen(
        repository: repository,
        sessions: _sessions(),
      ),
      scale,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester,
  ReportAdminTestRepository repository, {
  AudienceTestSessions? sessions,
}) async {
  await tester.pumpWidget(
    _app(
      MusicianFeedReportAdminDetailScreen(
        repository: repository,
        sessions: sessions ?? _sessions(),
        reportId: reportAdminTestId,
      ),
      1,
    ),
  );
  await tester.pumpAndSettle();
}

Widget _app(Widget home, double scale) => MaterialApp(
  theme: AppTheme.navy,
  home: home,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
);

Future<void> _openRemoval(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('review-REMOVE_FROM_FEED'));
  await _reveal(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder button) async {
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget);
}

typedef ReportAdminLoad = ({
  MusicianFeedReportStatus status,
  String? itemType,
  int limit,
  String? cursor,
});

typedef ReportAdminReview = ({
  String reportId,
  String requestId,
  int version,
  MusicianFeedReportDecision decision,
  String note,
});

typedef ReportAdminRestore = ({
  String reportId,
  String requestId,
  DateTime updatedAt,
  String note,
});

class ReportAdminTestRepository implements MusicianFeedReportAdminRepository {
  MusicianFeedReportAdminPage page = reportAdminTestPage();
  MusicianFeedReportDetail detailValue = reportAdminTestDetail();
  final loads = <ReportAdminLoad>[];
  final detailIds = <String>[];
  final reviews = <ReportAdminReview>[];
  MusicianFeedOrphanRestrictionsPage restrictionsPage =
      MusicianFeedOrphanRestrictionsPage(
        items: [reportAdminTestRestriction()],
        hasMore: false,
      );
  final restrictionCursors = <String?>[];
  final restores = <ReportAdminRestore>[];
  Future<Result<MusicianFeedOrphanRestrictionsPage>> Function(String?)?
  onRestrictions;
  Future<Result<MusicianFeedRestrictionRestored>> Function(ReportAdminRestore)?
  onRestore;

  @override
  Future<Result<MusicianFeedOrphanRestrictionsPage>> restrictions({
    int limit = 20,
    String? cursor,
  }) {
    restrictionCursors.add(cursor);
    return onRestrictions?.call(cursor) ??
        Future.value(Result.success(restrictionsPage));
  }

  @override
  Future<Result<MusicianFeedRestrictionRestored>> restoreRestriction(
    String reportId, {
    required String clientRequestId,
    required DateTime expectedUpdatedAt,
    required String resolutionNote,
  }) {
    final request = (
      reportId: reportId,
      requestId: clientRequestId,
      updatedAt: expectedUpdatedAt,
      note: resolutionNote,
    );
    restores.add(request);
    return onRestore?.call(request) ??
        Future.value(Result.success(_restored()));
  }

  Future<Result<MusicianFeedReportAdminPage>> Function(ReportAdminLoad)? onLoad;
  Future<Result<MusicianFeedReportDetail>> Function(String)? onDetail;
  Future<Result<MusicianFeedReportDetail>> Function(ReportAdminReview)?
  onReview;
  @override
  Future<Result<MusicianFeedReportAdminPage>> load({
    MusicianFeedReportStatus status = MusicianFeedReportStatus.fresh,
    String? itemType,
    int limit = 20,
    String? cursor,
  }) {
    final request = (
      status: status,
      itemType: itemType,
      limit: limit,
      cursor: cursor,
    );
    loads.add(request);
    return onLoad?.call(request) ?? Future.value(Result.success(page));
  }

  @override
  Future<Result<MusicianFeedReportDetail>> detail(String reportId) {
    detailIds.add(reportId);
    return onDetail?.call(reportId) ??
        Future.value(Result.success(detailValue));
  }

  @override
  Future<Result<MusicianFeedReportDetail>> review(
    String reportId, {
    required String clientRequestId,
    required int expectedVersion,
    required MusicianFeedReportDecision decision,
    required String resolutionNote,
  }) {
    final request = (
      reportId: reportId,
      requestId: clientRequestId,
      version: expectedVersion,
      decision: decision,
      note: resolutionNote,
    );
    reviews.add(request);
    return onReview?.call(request) ??
        Future.value(
          Result.success(
            reportAdminTestDetail(
              status: 'ACTIONED',
              version: expectedVersion + 1,
              decisions: ['RESTORE_TO_FEED'],
              restricted: true,
            ),
          ),
        );
  }
}

MusicianFeedReportSummary reportAdminTestSummary({
  String id = reportAdminTestId,
  String status = 'NEW',
}) => MusicianFeedReportSummary.fromJson(_wireSummary(id: id, status: status));

MusicianFeedReportAdminPage reportAdminTestPage({
  List<MusicianFeedReportSummary>? items,
  String? cursor,
}) => MusicianFeedReportAdminPage(
  items: items ?? [reportAdminTestSummary()],
  nextCursor: cursor,
  hasMore: cursor != null,
);

MusicianFeedReportDetail reportAdminTestDetail({
  String status = 'NEW',
  int version = 0,
  List<String> decisions = const [
    'START_REVIEW',
    'DISMISS',
    'REMOVE_FROM_FEED',
  ],
  bool restricted = false,
  bool history = false,
  String itemType = 'TRACK',
  bool omitted = false,
}) => MusicianFeedReportDetail.fromJson(
  _wireDetail(
    status: status,
    version: version,
    decisions: decisions,
    restricted: restricted,
    history: history,
    itemType: itemType,
    omitted: omitted,
  ),
);

Map<String, Object?> _wireSummary({
  String id = reportAdminTestId,
  String status = 'NEW',
  int version = 0,
  String itemType = 'TRACK',
}) => {
  'id': id,
  'version': version,
  'status': status,
  'itemId': 'TRACK:$_targetId',
  'itemType': itemType,
  'targetType': 'MEDIA',
  'targetId': _targetId,
  'reason': 'Bu içerik yanıltıcı bilgi içeriyor.',
  'reportedAt': '2026-09-13T15:20:00.123456Z',
  'title': 'Geceye Kalan Sesler',
  'authorDisplayName': 'Deniz Akarsu',
};

Map<String, Object?> _wirePage() => {
  'items': [_wireSummary()],
  'hasMore': false,
  'nextCursor': null,
};

Map<String, Object?> _wireDetail({
  String id = reportAdminTestId,
  String status = 'NEW',
  int version = 0,
  List<String> decisions = const [
    'START_REVIEW',
    'DISMISS',
    'REMOVE_FROM_FEED',
  ],
  bool restricted = false,
  bool history = false,
  String itemType = 'TRACK',
  bool omitted = false,
}) => {
  'report': _wireSummary(
    id: id,
    status: status,
    version: version,
    itemType: itemType,
  ),
  'reporterUserId': _userId,
  'evidence': {
    'itemType': itemType,
    'author': {'displayName': 'Deniz Akarsu'},
    'payload': omitted
        ? {'omitted': true, 'reason': 'MAX_EVIDENCE_BYTES'}
        : {
            'title': 'Kayda alınan parça başlığı',
            'description': 'Sanatçının içerik açıklaması.',
            'thumbnailUrl': 'javascript:alert(1)',
            'ctaUrl': 'https://untrusted.example/action',
          },
  },
  'scopeDescription':
      'Bu medya ve aynı medyayı gösteren müzisyen akışı kartları etkilenir.',
  'allowedDecisions': decisions,
  'activeRestriction': restricted,
  'history': history
      ? [
          {
            'id': _secondId,
            'decision': 'RESTORE_TO_FEED',
            'previousStatus': 'ACTIONED',
            'status': 'RESTORED',
            'actorUserId': _userId,
            'occurredAt': '2026-09-13T16:20:00Z',
            'resolutionNote': 'Karar yeniden değerlendirildi.',
          },
        ]
      : [],
};
