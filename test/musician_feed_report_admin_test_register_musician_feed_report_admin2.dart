part of 'musician_feed_report_admin_test.dart';

void _registerMusicianFeedReportAdmin2() {
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
