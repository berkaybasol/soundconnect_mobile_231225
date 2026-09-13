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

const reportAdminTestId = '11111111-1111-4111-8111-111111111111';
const _secondId = '22222222-2222-4222-8222-222222222222';
const _targetId = '33333333-3333-4333-8333-333333333333';
const _userId = '44444444-4444-4444-8444-444444444444';
const _offline = AppError(code: 'offline', message: 'Bağlantı kurulamadı.');

void main() {
  group('admin report contract', () {
    test('requires exact authority, active account and authenticated user', () {
      expect(canManageMusicianFeedReports(reportAdminTestSession()), isTrue);
      for (final permission in [
        'ADMIN_PANEL_ACCESS',
        'MANAGE_USERS',
        'ROLE_ADMIN',
        'manage_musician_feed_reports',
        ' MANAGE_MUSICIAN_FEED_REPORTS ',
      ]) {
        expect(
          canManageMusicianFeedReports(
            reportAdminTestSession(permissions: [permission]),
          ),
          isFalse,
        );
      }
      expect(
        canManageMusicianFeedReports(
          reportAdminTestSession(status: 'INACTIVE'),
        ),
        isFalse,
      );
      expect(
        canManageMusicianFeedReports(reportAdminTestSession(user: '')),
        isFalse,
      );
      expect(
        canManageMusicianFeedReports(reportAdminTestSession(token: ' ')),
        isFalse,
      );
      expect(canManageMusicianFeedReports(const AuthSession.guest()), isFalse);
    });

    test('parses detail evidence, action scope and immutable audit', () {
      final detail = MusicianFeedReportDetail.fromJson(
        _wireDetail(
          status: 'RESTORED',
          version: 3,
          restricted: true,
          decisions: [],
          history: true,
        ),
      );
      expect(detail.report.status, MusicianFeedReportStatus.restored);
      expect(detail.activeRestriction, isTrue);
      expect(
        detail.history.single.decision,
        MusicianFeedReportDecision.restoreToFeed,
      );
      expect(
        detail.history.single.resolutionNote,
        'Karar yeniden değerlendirildi.',
      );
      expect(() => detail.evidence['payload'] = {}, throwsUnsupportedError);
      expect(
        () => (detail.evidence['payload'] as Map)['title'] = 'Changed',
        throwsUnsupportedError,
      );
      expect(
        () => MusicianFeedReportDetail.fromJson({
          ..._wireDetail(),
          'allowedDecisions': ['DELETE_ACCOUNT'],
        }),
        throwsFormatException,
      );
      expect(
        () => MusicianFeedReportSummary.fromJson({
          ..._wireSummary(),
          'id': '../report',
        }),
        throwsFormatException,
      );
      expect(
        () => MusicianFeedReportSummary.fromJson({
          ..._wireSummary(),
          'reportedAt': '2026-09-13',
        }),
        throwsFormatException,
      );
      expect(
        () => MusicianFeedReportAdminPage.fromJson({
          'items': [],
          'hasMore': true,
        }),
        throwsFormatException,
      );
      expect(
        () => MusicianFeedReportAdminPage.fromJson({
          'items': [],
          'hasMore': true,
          'nextCursor': 'a' * 1025,
        }),
        throwsFormatException,
      );
    });

    test(
      'resolution validation matches UTF-16 length and control-character rules',
      () {
        expect(isValidMusicianFeedResolutionNote('  Geçerli karar  '), isTrue);
        expect(isValidMusicianFeedResolutionNote('1234'), isFalse);
        expect(isValidMusicianFeedResolutionNote('a' * 500), isTrue);
        expect(isValidMusicianFeedResolutionNote('a' * 501), isFalse);
        expect(isValidMusicianFeedResolutionNote('😀' * 250), isTrue);
        expect(isValidMusicianFeedResolutionNote('😀' * 251), isFalse);
        expect(
          isValidMusicianFeedResolutionNote('Geçerli\nkarar\tnotu'),
          isTrue,
        );
        for (final control in [0, 13, 127, 128, 159, 0xd800]) {
          expect(
            isValidMusicianFeedResolutionNote(
              'Karar${String.fromCharCode(control)}notu',
            ),
            isFalse,
          );
        }
      },
    );
  });

  group('admin report repository', () {
    test(
      'list detail and review use exact paths and session-bound requests',
      () async {
        final sessions = _sessions();
        final api = RecordingApiClient(
          (request) =>
              request.path.endsWith('/reports') ? _wirePage() : _wireDetail(),
        );
        final repository = MusicianFeedReportAdminRepositoryImpl(api, sessions);
        expect(
          (await repository.load(
            status: MusicianFeedReportStatus.reviewing,
            itemType: 'TRACK',
            cursor: 'opaque+/=',
          )).isSuccess,
          isTrue,
        );
        expect(api.lastRequest.path, '/api/v1/admin/musician-feed/reports');
        expect(api.lastRequest.query, {
          'status': 'REVIEWING',
          'itemType': 'TRACK',
          'limit': 20,
          'cursor': 'opaque+/=',
        });
        expect((await repository.detail(reportAdminTestId)).isSuccess, isTrue);
        expect(
          api.lastRequest.path,
          '/api/v1/admin/musician-feed/reports/$reportAdminTestId',
        );
        expect(
          (await repository.review(
            reportAdminTestId,
            clientRequestId: _secondId,
            expectedVersion: 0,
            decision: MusicianFeedReportDecision.removeFromFeed,
            resolutionNote: '  İncelendi ve uygun bulundu.  ',
          )).isSuccess,
          isTrue,
        );
        expect(api.lastRequest.method, RecordedHttpMethod.post);
        expect(
          api.lastRequest.path,
          '/api/v1/admin/musician-feed/reports/$reportAdminTestId/review',
        );
        expect(api.lastRequest.body, {
          'clientRequestId': _secondId,
          'expectedVersion': 0,
          'decision': 'REMOVE_FROM_FEED',
          'resolutionNote': 'İncelendi ve uygun bulundu.',
        });
        for (final request in api.requests) {
          expect(request.requestContext?.expectedSessionKey, _userId);
          expect(request.requestContext?.expectedToken, 'admin-token');
        }
      },
    );

    test(
      'invalid requests and insufficient permissions perform no I/O',
      () async {
        final sessions = _sessions();
        final api = RecordingApiClient((_) => _wirePage());
        final repository = MusicianFeedReportAdminRepositoryImpl(api, sessions);
        for (final limit in [0, 51]) {
          expect((await repository.load(limit: limit)).isSuccess, isFalse);
        }
        expect((await repository.load(cursor: 'a' * 1025)).isSuccess, isFalse);
        expect((await repository.load(itemType: 'UNKNOWN')).isSuccess, isFalse);
        expect((await repository.detail('../private')).isSuccess, isFalse);
        expect(
          (await repository.review(
            reportAdminTestId,
            clientRequestId: _secondId,
            expectedVersion: -1,
            decision: MusicianFeedReportDecision.dismiss,
            resolutionNote: 'Valid reason',
          )).isSuccess,
          isFalse,
        );
        sessions.replace(
          reportAdminTestSession(permissions: const ['MANAGE_USERS']),
        );
        expect((await repository.load()).isSuccess, isFalse);
        expect(api.requests, isEmpty);
      },
    );

    test('rejects a response for a different report identity', () async {
      final repository = MusicianFeedReportAdminRepositoryImpl(
        RecordingApiClient((_) => _wireDetail(id: _secondId)),
        _sessions(),
      );
      expect((await repository.detail(reportAdminTestId)).isSuccess, isFalse);
    });

    for (final transition in ['account', 'token', 'authority', 'transient']) {
      test(
        'rejects pending read and review after $transition changes',
        () async {
          final sessions = _sessions();
          final read = Completer<Object?>();
          final write = Completer<Object?>();
          final api = RecordingApiClient(
            (request) => request.method == RecordedHttpMethod.get
                ? read.future
                : write.future,
          );
          final repository = MusicianFeedReportAdminRepositoryImpl(
            api,
            sessions,
          );
          final loading = repository.detail(reportAdminTestId);
          final reviewing = repository.review(
            reportAdminTestId,
            clientRequestId: _secondId,
            expectedVersion: 0,
            decision: MusicianFeedReportDecision.dismiss,
            resolutionNote: 'Valid reason',
          );
          _transition(sessions, transition);
          read.complete(_wireDetail());
          write.complete(_wireDetail());
          expect((await loading).isSuccess, isFalse);
          expect((await reviewing).isSuccess, isFalse);
        },
      );
    }

    test('retains numeric conflict and cursor error codes', () async {
      var error = const AppError(code: '1322', message: 'Stale version');
      final repository = MusicianFeedReportAdminRepositoryImpl(
        RecordingApiClient((_) => throw ApiException(error)),
        _sessions(),
      );
      expect((await repository.detail(reportAdminTestId)).error?.code, '1322');
      error = const AppError(code: '1323', message: 'Expired cursor');
      expect((await repository.load(cursor: 'expired')).error?.code, '1323');
    });
  });

  group('report queue state', () {
    test('loads on each new opening with default filters', () async {
      final repository = ReportAdminTestRepository();
      final first = _queue(repository);
      await first.initialize();
      expect(first.state.items.single.id, reportAdminTestId);
      await first.close();
      final second = _queue(repository);
      await second.initialize();
      expect(repository.loads, hasLength(2));
      expect(
        repository.loads.every(
          (request) =>
              request.status == MusicianFeedReportStatus.fresh &&
              request.cursor == null,
        ),
        isTrue,
      );
    });

    test(
      'filter reset rejects stale paging and duplicate load-more taps',
      () async {
        final pending = Completer<Result<MusicianFeedReportAdminPage>>();
        final repository = ReportAdminTestRepository()
          ..page = reportAdminTestPage(cursor: 'next')
          ..onLoad = (request) => request.cursor != null
              ? pending.future
              : Future.value(
                  Result.success(
                    request.status == MusicianFeedReportStatus.dismissed
                        ? reportAdminTestPage(
                            items: [
                              reportAdminTestSummary(
                                id: _secondId,
                                status: 'DISMISSED',
                              ),
                            ],
                          )
                        : reportAdminTestPage(cursor: 'next'),
                  ),
                );
        final cubit = _queue(repository);
        await cubit.initialize();
        final loading = cubit.loadMore();
        await cubit.loadMore();
        expect(repository.loads, hasLength(2));
        await cubit.filter(
          status: MusicianFeedReportStatus.dismissed,
          itemType: 'TRACK',
        );
        pending.complete(Result.success(reportAdminTestPage()));
        await loading;
        expect(cubit.state.items.single.id, _secondId);
        expect(cubit.state.itemType, 'TRACK');
        expect(cubit.state.loadingMore, isFalse);
      },
    );

    test(
      'deduplicates pages and restarts expired cursors from the first page',
      () async {
        final repository = ReportAdminTestRepository()
          ..page = reportAdminTestPage(cursor: 'next');
        final cubit = _queue(repository);
        await cubit.initialize();
        repository.onLoad = (_) async => Result.success(
          reportAdminTestPage(
            items: [
              reportAdminTestSummary(),
              reportAdminTestSummary(id: _secondId),
            ],
            cursor: 'next-2',
          ),
        );
        await cubit.loadMore();
        expect(cubit.state.items, hasLength(2));
        repository.onLoad = (request) async => request.cursor != null
            ? const Result.failure(
                AppError(code: '1323', message: 'Expired cursor'),
              )
            : Result.success(
                reportAdminTestPage(
                  items: [reportAdminTestSummary(id: _secondId)],
                ),
              );
        await cubit.loadMore();
        expect(cubit.state.items.single.id, _secondId);
        expect(repository.loads.last.cursor, isNull);
        expect(cubit.state.hasMore, isFalse);
      },
    );

    test(
      'retains rows on refresh and paging failures and supports retry',
      () async {
        final repository = ReportAdminTestRepository()
          ..page = reportAdminTestPage(cursor: 'next');
        final cubit = _queue(repository);
        await cubit.initialize();
        repository.onLoad = (_) async => const Result.failure(_offline);
        await cubit.refresh();
        expect(cubit.state.items, hasLength(1));
        expect(cubit.state.error, _offline);
        await cubit.loadMore();
        expect(cubit.state.pagingError, _offline);
        repository.onLoad = (_) async =>
            Result.success(reportAdminTestPage(items: []));
        await cubit.refresh();
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.error, isNull);
      },
    );

    test(
      'permission loss clears queue and prevents old-row navigation even after restore',
      () async {
        final sessions = _sessions();
        final repository = ReportAdminTestRepository();
        final cubit = _queue(repository, sessions: sessions);
        await cubit.initialize();
        sessions.replace(reportAdminTestSession(permissions: const []));
        expect(cubit.state.items, isEmpty);
        expect(
          cubit.state.loadStatus,
          MusicianFeedReportLoadStatus.accessDenied,
        );
        sessions.replace(reportAdminTestSession());
        expect(cubit.canOpen(reportAdminTestId), isFalse);
        await cubit.refresh();
        expect(repository.loads, hasLength(1));
      },
    );

    test('pending first page cannot leak into a replacement session', () async {
      final pending = Completer<Result<MusicianFeedReportAdminPage>>();
      final sessions = _sessions();
      final cubit = _queue(
        ReportAdminTestRepository()..onLoad = (_) => pending.future,
        sessions: sessions,
      );
      final loading = cubit.initialize();
      sessions.replace(reportAdminTestSession(user: _secondId));
      pending.complete(Result.success(reportAdminTestPage()));
      await loading;
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.loadStatus, MusicianFeedReportLoadStatus.accessDenied);
    });
  });

  group('report decisions', () {
    test(
      'double taps are single flight and successful response replaces decision and audit',
      () async {
        final pending = Completer<Result<MusicianFeedReportDetail>>();
        final repository = ReportAdminTestRepository()
          ..onReview = (_) => pending.future;
        final cubit = _detail(repository);
        await cubit.load();
        final writing = _remove(cubit);
        expect(cubit.state.submitting, isTrue);
        expect(await _remove(cubit), isFalse);
        expect(repository.reviews, hasLength(1));
        pending.complete(
          Result.success(
            reportAdminTestDetail(
              status: 'ACTIONED',
              version: 1,
              decisions: ['RESTORE_TO_FEED'],
              restricted: true,
            ),
          ),
        );
        expect(await writing, isTrue);
        expect(
          cubit.state.detail!.report.status,
          MusicianFeedReportStatus.actioned,
        );
        expect(cubit.state.detail!.allowedDecisions, [
          MusicianFeedReportDecision.restoreToFeed,
        ]);
        expect(cubit.state.submitting, isFalse);
      },
    );

    test(
      'network retry keeps request ID and payload while an edited reason receives a new ID',
      () async {
        final repository = ReportAdminTestRepository()
          ..onReview = (_) async => const Result.failure(_offline);
        final cubit = _detail(repository);
        await cubit.load();
        await _remove(cubit);
        await _remove(cubit);
        expect(
          repository.reviews[0].requestId,
          repository.reviews[1].requestId,
        );
        expect(cubit.state.detail, isNotNull);
        expect(cubit.state.error, _offline);
        await cubit.review(
          MusicianFeedReportDecision.removeFromFeed,
          'Başka bir gerekçe',
          expectedVersion: 0,
          expectedEpoch: cubit.sessionEpoch,
        );
        expect(
          repository.reviews.last.requestId,
          isNot(repository.reviews.first.requestId),
        );
      },
    );

    test(
      '409 reloads authoritative detail with a warning and never resubmits automatically',
      () async {
        final repository = ReportAdminTestRepository();
        final cubit = _detail(repository);
        await cubit.load();
        repository.detailValue = reportAdminTestDetail(
          status: 'ACTIONED',
          version: 1,
          decisions: ['RESTORE_TO_FEED'],
          restricted: true,
        );
        repository.onReview = (_) async =>
            const Result.failure(AppError(code: '1322', message: 'Conflict'));
        expect(await _remove(cubit), isFalse);
        expect(repository.detailIds, hasLength(2));
        expect(repository.reviews, hasLength(1));
        expect(cubit.state.detail!.report.version, 1);
        expect(cubit.state.notice, contains('kararını yeniden ver'));
        expect(await _remove(cubit), isFalse);
        expect(repository.reviews, hasLength(1));
      },
    );

    test(
      'stale confirmation versions and disallowed decisions never send a mutation',
      () async {
        final repository = ReportAdminTestRepository();
        final cubit = _detail(repository);
        await cubit.load();
        expect(
          await cubit.review(
            MusicianFeedReportDecision.restoreToFeed,
            'Valid note',
            expectedVersion: 0,
            expectedEpoch: 0,
          ),
          isFalse,
        );
        expect(
          await cubit.review(
            MusicianFeedReportDecision.removeFromFeed,
            'Valid note',
            expectedVersion: 9,
            expectedEpoch: 0,
          ),
          isFalse,
        );
        expect(repository.reviews, isEmpty);
      },
    );

    for (final transition in ['account', 'token', 'authority', 'transient']) {
      test('pending decision is erased after $transition changes', () async {
        final pending = Completer<Result<MusicianFeedReportDetail>>();
        final sessions = _sessions();
        final repository = ReportAdminTestRepository()
          ..onReview = (_) => pending.future;
        final cubit = _detail(repository, sessions: sessions);
        await cubit.load();
        final epoch = cubit.sessionEpoch;
        final writing = _remove(cubit);
        _transition(sessions, transition);
        pending.complete(
          Result.success(reportAdminTestDetail(status: 'ACTIONED', version: 1)),
        );
        expect(await writing, isFalse);
        expect(cubit.state.detail, isNull);
        expect(cubit.state.notice, isNull);
        expect(
          cubit.state.loadStatus,
          MusicianFeedReportLoadStatus.accessDenied,
        );
        expect(
          await cubit.review(
            MusicianFeedReportDecision.removeFromFeed,
            'Valid note',
            expectedVersion: 0,
            expectedEpoch: epoch,
          ),
          isFalse,
        );
        expect(repository.reviews, hasLength(1));
      });
    }

    test(
      'a silently replaced account cannot submit a previously loaded report',
      () async {
        final sessions = _sessions();
        final repository = ReportAdminTestRepository();
        final cubit = _detail(repository, sessions: sessions);
        await cubit.load();
        sessions.current = reportAdminTestSession(user: _secondId);
        expect(await _remove(cubit), isFalse);
        expect(repository.reviews, isEmpty);
        expect(cubit.state.detail, isNull);
      },
    );

    test(
      'a server authorization failure clears detail and prevents further I/O',
      () async {
        final repository = ReportAdminTestRepository();
        final cubit = _detail(repository);
        await cubit.load();
        repository.onReview = (_) async =>
            const Result.failure(AppError(code: '403', message: 'Forbidden'));
        await _remove(cubit);
        expect(cubit.state.detail, isNull);
        await cubit.load();
        expect(repository.detailIds, hasLength(1));
        expect(
          cubit.state.loadStatus,
          MusicianFeedReportLoadStatus.accessDenied,
        );
      },
    );

    test(
      'missing report is a recoverable detail error without stale actions',
      () async {
        final repository = ReportAdminTestRepository()
          ..onDetail = (_) async => const Result.failure(
            AppError(code: '1321', message: 'Not found'),
          );
        final cubit = _detail(repository);
        await cubit.load();
        expect(cubit.state.detail, isNull);
        expect(cubit.state.error!.message, contains('artık bulunamıyor'));
      },
    );
  });

  test(
    'a report disappearing during review clears its snapshot and actions',
    () async {
      final repository = ReportAdminTestRepository();
      final cubit = _detail(repository);
      await cubit.load();
      repository.onReview = (_) async =>
          const Result.failure(AppError(code: '1321', message: 'Deleted'));
      expect(await _remove(cubit), isFalse);
      expect(cubit.state.detail, isNull);
      expect(cubit.state.loadStatus, MusicianFeedReportLoadStatus.failure);
      expect(cubit.state.error!.message, contains('artık bulunamıyor'));
      expect(await _remove(cubit), isFalse);
      expect(repository.reviews, hasLength(1));
    },
  );

  group('restrictions with deleted source reports', () {
    test(
      'repository retains target identity and fences restore with expected timestamp',
      () async {
        final api = RecordingApiClient(
          (request) => request.method == RecordedHttpMethod.get
              ? {
                  'items': [_wireRestriction()],
                  'nextCursor': null,
                  'hasMore': false,
                }
              : {
                  'reportId': reportAdminTestId,
                  'active': false,
                  'updatedAt': '2026-09-13T18:00:00Z',
                  'activeRestriction': true,
                },
        );
        final repository = MusicianFeedReportAdminRepositoryImpl(
          api,
          _sessions(),
        );
        final list = await repository.restrictions();
        expect(
          api.lastRequest.path,
          '/api/v1/admin/musician-feed/restrictions',
        );
        expect(api.lastRequest.query, {'limit': 20});
        expect(list.data!.items.single.scopeKey, 'MEDIA:$_targetId');
        expect(list.data!.items.single.appliedByUserId, _userId);
        final result = await repository.restoreRestriction(
          reportAdminTestId,
          clientRequestId: _secondId,
          expectedUpdatedAt: list.data!.items.single.updatedAt,
          resolutionNote: '  Yeniden incelendi.  ',
        );
        expect(result.data!.activeRestriction, isTrue);
        expect(
          api.lastRequest.path,
          '/api/v1/admin/musician-feed/restrictions/$reportAdminTestId/restore',
        );
        expect(api.lastRequest.body, {
          'clientRequestId': _secondId,
          'expectedUpdatedAt': '2026-09-13T17:00:00.123456Z',
          'resolutionNote': 'Yeniden incelendi.',
        });
        expect(api.lastRequest.requestContext?.expectedSessionKey, _userId);
        expect(api.lastRequest.requestContext?.expectedToken, 'admin-token');
      },
    );

    test(
      'successful restore removes only its row and keeps another active restriction visible in the notice',
      () async {
        final repository = ReportAdminTestRepository();
        final cubit = _restrictions(repository);
        await cubit.refresh();
        expect(
          await cubit.restore(
            cubit.state.items.single,
            'Yeniden incelendi.',
            expectedEpoch: cubit.sessionEpoch,
          ),
          isTrue,
        );
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.notice, contains('Başka etkin kaldırma kararları'));
      },
    );

    test(
      'network retry reuses request ID, double click is blocked and failure retains the row',
      () async {
        final pending = Completer<Result<MusicianFeedRestrictionRestored>>();
        final repository = ReportAdminTestRepository()
          ..onRestore = (_) => pending.future;
        final cubit = _restrictions(repository);
        await cubit.refresh();
        final row = cubit.state.items.single;
        final restoring = cubit.restore(
          row,
          'Yeniden incelendi.',
          expectedEpoch: 0,
        );
        expect(
          await cubit.restore(row, 'Yeniden incelendi.', expectedEpoch: 0),
          isFalse,
        );
        pending.complete(const Result.failure(_offline));
        expect(await restoring, isFalse);
        expect(cubit.state.items, hasLength(1));
        repository.onRestore = (_) async => const Result.failure(_offline);
        await cubit.restore(row, 'Yeniden incelendi.', expectedEpoch: 0);
        expect(repository.restores, hasLength(2));
        expect(
          repository.restores[0].requestId,
          repository.restores[1].requestId,
        );
      },
    );

    test(
      'conflict reloads changed timestamps without retrying the old decision',
      () async {
        final repository = ReportAdminTestRepository();
        final cubit = _restrictions(repository);
        await cubit.refresh();
        final old = cubit.state.items.single;
        repository.restrictionsPage = MusicianFeedOrphanRestrictionsPage(
          items: [
            reportAdminTestRestriction(updatedAt: '2026-09-13T18:00:00Z'),
          ],
          hasMore: false,
        );
        repository.onRestore = (_) async =>
            const Result.failure(AppError(code: '1322', message: 'Conflict'));
        expect(
          await cubit.restore(old, 'Yeniden incelendi.', expectedEpoch: 0),
          isFalse,
        );
        expect(cubit.state.items.single.updatedAt, isNot(old.updatedAt));
        expect(cubit.state.notice, contains('kararını yeniden ver'));
        expect(
          await cubit.restore(old, 'Yeniden incelendi.', expectedEpoch: 0),
          isFalse,
        );
        expect(repository.restores, hasLength(1));
      },
    );

    test(
      'session switch clears pending restore and never adopts an old success',
      () async {
        final pending = Completer<Result<MusicianFeedRestrictionRestored>>();
        final sessions = _sessions();
        final repository = ReportAdminTestRepository()
          ..onRestore = (_) => pending.future;
        final cubit = _restrictions(repository, sessions: sessions);
        await cubit.refresh();
        final restoring = cubit.restore(
          cubit.state.items.single,
          'Yeniden incelendi.',
          expectedEpoch: 0,
        );
        sessions.replace(reportAdminTestSession(user: _secondId));
        pending.complete(Result.success(_restored()));
        expect(await restoring, isFalse);
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.notice, isNull);
        expect(cubit.state.status, MusicianFeedReportLoadStatus.accessDenied);
      },
    );

    test(
      'expired paging cursor refreshes the orphan list with no duplicate rows',
      () async {
        final repository = ReportAdminTestRepository()
          ..restrictionsPage = MusicianFeedOrphanRestrictionsPage(
            items: [reportAdminTestRestriction()],
            nextCursor: 'expired',
            hasMore: true,
          );
        final cubit = _restrictions(repository);
        await cubit.refresh();
        repository.onRestrictions = (cursor) async => cursor != null
            ? const Result.failure(AppError(code: '1323', message: 'Expired'))
            : Result.success(
                MusicianFeedOrphanRestrictionsPage(
                  items: [reportAdminTestRestriction()],
                  hasMore: false,
                ),
              );
        await cubit.loadMore();
        expect(repository.restrictionCursors, [null, 'expired', null]);
        expect(cubit.state.items, hasLength(1));
        expect(cubit.state.hasMore, isFalse);
      },
    );

    testWidgets(
      'orphan list shows target references, supports narrow text and fences its dialog',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 850);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final sessions = _sessions();
        final repository = ReportAdminTestRepository();
        await tester.pumpWidget(
          _app(
            MusicianFeedRestrictionsAdminScreen(
              repository: repository,
              sessions: sessions,
              expectedIdentity: musicianFeedReportAdminIdentity(
                sessions.session,
              )!,
            ),
            2,
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(
          const ValueKey('restore-restriction-$reportAdminTestId'),
        );
        await tester.scrollUntilVisible(
          action,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(tester.element(action), alignment: 0.5);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        expect(find.text('Hedef kimliği'), findsOneWidget);
        expect(find.text('MEDIA:$_targetId'), findsOneWidget);
        expect(find.text('Karar kimliği'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('restriction-resolution-note')),
          'Yeniden incelendi.',
        );
        final confirm = tester
            .widget<FilledButton>(
              find.byKey(const Key('restriction-restore-confirm')),
            )
            .onPressed!;
        sessions.replace(const AuthSession.guest());
        confirm();
        await tester.pumpAndSettle();
        expect(repository.restores, isEmpty);
        expect(find.text('Kısıtlama bilgileri değişti'), findsOneWidget);
        expect(
          find.byKey(const Key('restriction-resolution-note')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('report management widgets', () {
    for (final orphan in [false, true]) {
      testWidgets(
        '${orphan ? 'orphan' : 'report'} dialog labels input and submit remain accessible at 320dp 200% with keyboard',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 850);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final sessions = _sessions();
          final repository = ReportAdminTestRepository();
          await tester.pumpWidget(
            _app(
              orphan
                  ? MusicianFeedRestrictionsAdminScreen(
                      repository: repository,
                      sessions: sessions,
                      expectedIdentity: musicianFeedReportAdminIdentity(
                        sessions.session,
                      )!,
                    )
                  : MusicianFeedReportAdminDetailScreen(
                      repository: repository,
                      sessions: sessions,
                      reportId: reportAdminTestId,
                    ),
              2,
            ),
          );
          await tester.pumpAndSettle();
          if (orphan) {
            final action = find.byKey(
              const ValueKey('restore-restriction-$reportAdminTestId'),
            );
            await _reveal(tester, action);
            await tester.tap(action);
            await tester.pumpAndSettle();
          } else {
            await _openRemoval(tester);
          }
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          final input = find.byKey(
            Key(
              orphan
                  ? 'restriction-resolution-note'
                  : 'feed-report-resolution-note',
            ),
          );
          for (final label in ['Karar gerekçesi', '5–500 karakter']) {
            final text = find.text(label);
            expect(
              tester.widget<Text>(text).overflow,
              isNot(TextOverflow.ellipsis),
            );
            await Scrollable.ensureVisible(
              tester.element(text),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            expect(text.hitTestable(), findsOneWidget);
          }
          await Scrollable.ensureVisible(tester.element(input), alignment: 0.5);
          await tester.pumpAndSettle();
          expect(input.hitTestable(), findsOneWidget);
          await tester.enterText(input, 'İnceleme tamamlandı.');
          await tester.pumpAndSettle();
          final confirm = find.byKey(
            Key(
              orphan
                  ? 'restriction-restore-confirm'
                  : 'feed-report-review-confirm',
            ),
          );
          expect(confirm.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(
            orphan ? repository.restores.length : repository.reviews.length,
            1,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'orphan restore reveals its result above remaining long restriction rows',
      (tester) async {
        final sessions = _sessions();
        final repository = ReportAdminTestRepository()
          ..restrictionsPage = MusicianFeedOrphanRestrictionsPage(
            items: [
              reportAdminTestRestriction(),
              MusicianFeedOrphanRestriction.fromJson({
                ..._wireRestriction(),
                'reportId': _secondId,
              }),
            ],
            hasMore: false,
          );
        await tester.pumpWidget(
          _app(
            MusicianFeedRestrictionsAdminScreen(
              repository: repository,
              sessions: sessions,
              expectedIdentity: musicianFeedReportAdminIdentity(
                sessions.session,
              )!,
            ),
            1,
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(
          const ValueKey('restore-restriction-$reportAdminTestId'),
        );
        await _reveal(tester, action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('restriction-resolution-note')),
          'Yeniden incelendi.',
        );
        await tester.tap(find.byKey(const Key('restriction-restore-confirm')));
        await tester.pumpAndSettle();
        expect(repository.restores, hasLength(1));
        expect(
          find
              .textContaining('Başka etkin kaldırma kararları nedeniyle')
              .hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('restore-restriction-$reportAdminTestId')),
          findsNothing,
        );
      },
    );
    testWidgets('Overthinking evidence shows the captured source content', (
      tester,
    ) async {
      final wire = _wireDetail(itemType: 'OVERTHINKING_PROFILE_SHARE');
      wire['evidence'] = {
        'payload': {
          'note': 'Paylaşım notu',
          'source': {
            'title': 'Bir düşünce',
            'content': 'Kayda alınmış düşüncenin tam metni.',
          },
        },
      };
      final repository = ReportAdminTestRepository()
        ..detailValue = MusicianFeedReportDetail.fromJson(wire);
      await _pumpDetail(tester, repository);
      expect(find.text('Kayda alınmış düşüncenin tam metni.'), findsOneWidget);
    });
    testWidgets(
      'list opens detail and presents readable evidence without raw JSON or unsafe media',
      (tester) async {
        final repository = ReportAdminTestRepository();
        await _pumpQueue(tester, repository);
        await tester.tap(
          find.byKey(const ValueKey('feed-report-$reportAdminTestId')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Şikâyet incelemesi'), findsOneWidget);
        expect(find.text('Kayda alınan parça başlığı'), findsOneWidget);
        expect(find.text('Sanatçının içerik açıklaması.'), findsOneWidget);
        expect(find.byType(AppCachedNetworkImage), findsNothing);
        expect(find.textContaining('javascript:'), findsNothing);
        expect(find.textContaining('targetPayload'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('queue error retry and empty filters remain usable', (
      tester,
    ) async {
      final repository = ReportAdminTestRepository()
        ..onLoad = (_) async => const Result.failure(_offline);
      await _pumpQueue(tester, repository);
      expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
      repository.onLoad = (_) async =>
          Result.success(reportAdminTestPage(items: []));
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(find.text('Bu filtrelerde şikâyet bulunmuyor.'), findsOneWidget);
      expect(
        find.byType(DropdownButtonFormField<MusicianFeedReportStatus>),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'omitted evidence and absent historical comment text are explicit',
      (tester) async {
        final repository = ReportAdminTestRepository()
          ..detailValue = reportAdminTestDetail(
            itemType: 'ACTIVITY_COMMENT',
            omitted: true,
          );
        await _pumpDetail(tester, repository);
        expect(find.text('İçerik önizlemesi kayda alınmamış.'), findsOneWidget);
        expect(
          find.textContaining('Yorum metni bu kayda alınmamış.'),
          findsOneWidget,
        );
        expect(find.text('Kayda alınan parça başlığı'), findsNothing);
      },
    );

    testWidgets('restore can retain another restriction and shows real audit', (
      tester,
    ) async {
      final repository = ReportAdminTestRepository()
        ..detailValue = reportAdminTestDetail(
          status: 'RESTORED',
          version: 3,
          decisions: [],
          restricted: true,
          history: true,
        );
      await _pumpDetail(tester, repository);
      await tester.scrollUntilVisible(
        find.textContaining('başka bir etkin kaldırma kararı'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('başka bir etkin kaldırma kararı'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Karar yeniden değerlendirildi.'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Karar yeniden değerlendirildi.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('review-RESTORE_TO_FEED')),
        findsNothing,
      );
    });

    testWidgets(
      'decision dialog validates a reason and submits the explicit confirmed action',
      (tester) async {
        final repository = ReportAdminTestRepository();
        await _pumpDetail(tester, repository);
        await _openRemoval(tester);
        await tester.tap(find.byKey(const Key('feed-report-review-confirm')));
        await tester.pump();
        expect(find.text('5–500 karakterlik bir gerekçe yaz.'), findsOneWidget);
        expect(repository.reviews, isEmpty);
        await tester.enterText(
          find.byKey(const Key('feed-report-resolution-note')),
          '  İnceleme tamamlandı.  ',
        );
        await tester.tap(find.byKey(const Key('feed-report-review-confirm')));
        await tester.pumpAndSettle();
        expect(repository.reviews, hasLength(1));
        expect(
          repository.reviews.single.decision,
          MusicianFeedReportDecision.removeFromFeed,
        );
        expect(repository.reviews.single.note, 'İnceleme tamamlandı.');
        expect(find.text('Karar kaydedildi.').hitTestable(), findsOneWidget);
      },
    );

    testWidgets(
      'permission loss during confirmation removes evidence and fences captured confirm callback',
      (tester) async {
        final sessions = _sessions();
        final repository = ReportAdminTestRepository();
        await _pumpDetail(tester, repository, sessions: sessions);
        await _openRemoval(tester);
        await tester.enterText(
          find.byKey(const Key('feed-report-resolution-note')),
          'Önceki hesabın kararı.',
        );
        final capturedConfirm = tester
            .widget<FilledButton>(
              find.byKey(const Key('feed-report-review-confirm')),
            )
            .onPressed!;
        sessions.replace(reportAdminTestSession(permissions: const []));
        capturedConfirm();
        await tester.pumpAndSettle();
        expect(repository.reviews, isEmpty);
        expect(find.text('İnceleme bilgileri değişti'), findsOneWidget);
        expect(
          find.byKey(const Key('feed-report-resolution-note')),
          findsNothing,
        );
        expect(find.text('Kayda alınan parça başlığı'), findsNothing);
        sessions.replace(reportAdminTestSession());
        capturedConfirm();
        await tester.pumpAndSettle();
        expect(repository.reviews, isEmpty);
      },
    );

    testWidgets(
      'account switch before modal result processing sends no old decision',
      (tester) async {
        final sessions = _sessions();
        final repository = ReportAdminTestRepository();
        await _pumpDetail(tester, repository, sessions: sessions);
        await _openRemoval(tester);
        await tester.enterText(
          find.byKey(const Key('feed-report-resolution-note')),
          'İnceleme tamamlandı.',
        );
        final dialogContext = tester.element(find.byType(AlertDialog));
        Navigator.of(dialogContext).pop('İnceleme tamamlandı.');
        sessions.replace(reportAdminTestSession(user: _secondId));
        await tester.pumpAndSettle();
        expect(repository.reviews, isEmpty);
        expect(find.text('Kayda alınan parça başlığı'), findsNothing);
      },
    );

    for (final size in [(390.0, 1.0), (320.0, 2.0)]) {
      testWidgets(
        'queue detail and decision fit ${size.$1}dp at ${size.$2}x text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(size.$1, 850);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final repository = ReportAdminTestRepository();
          await _pumpQueue(tester, repository, scale: size.$2);
          expect(tester.takeException(), isNull);
          final open = find.byKey(
            const ValueKey('feed-report-open-$reportAdminTestId'),
          );
          await _reveal(tester, open);
          await tester.tap(open);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _openRemoval(tester);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.enterText(
            find.byKey(const Key('feed-report-resolution-note')),
            'İnceleme tamamlandı.',
          );
          await tester.ensureVisible(
            find.byKey(const Key('feed-report-review-confirm')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('feed-report-review-confirm')));
          await tester.pumpAndSettle();
          expect(repository.reviews, hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
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
