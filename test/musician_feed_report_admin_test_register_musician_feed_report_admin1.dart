part of 'musician_feed_report_admin_test.dart';

void _registerMusicianFeedReportAdmin1() {
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
}
