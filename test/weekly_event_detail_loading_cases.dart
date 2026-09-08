part of 'weekly_event_detail_design_test.dart';

void _detailLoadingTests() {
  group('detail mount request budget', () {
    for (final band in [false, true]) {
      testWidgets(
        '${band ? 'band' : 'musician'} shell renders before all network responses and comments resolve independently',
        (tester) async {
          _registerCommentMember();
          final details =
              serviceLocator<VenueEventRepository>() as _DetailRepository;
          final musicians =
              serviceLocator<MusicianProfileRepository>()
                  as _MusicianRepository;
          final bands = serviceLocator<BandRepository>() as _BandRepository;
          final venues =
              serviceLocator<VenueProfileRepository>() as _VenueRepository;
          details.completion = Completer<Result<VenueEventDetail>>();
          musicians.completion = Completer<Result<MusicianProfile>>();
          bands.completion = Completer<Result<BandProfile>>();
          venues
            ..includePhoto = false
            ..profileGate = Completer<void>();
          final pendingComments = Completer<Result<CommentPage>>();
          final comments = _MountBudgetComments()
            ..listResponse = () => pendingComments.future;
          await serviceLocator.unregister<EngagementRepository>();
          serviceLocator.registerSingleton<EngagementRepository>(comments);
          final pendingAudience = Completer<Result<EventAudienceState>>();
          final audience = AudienceTestRepository()
            ..onRead = () => pendingAudience.future;
          serviceLocator.registerSingleton<EventAudienceRepository>(audience);
          final event = _event(
            title: 'Hemen görünen etkinlik',
            artistProfileId: band ? null : 'artist',
            bandProfileId: band ? 'band' : null,
            performerType: band ? 'BAND' : 'MUSICIAN',
            venueId: 'venue',
          );

          // Zero-time frames only. No response completes and no artificial
          // delay masks the loading state or blocks rendering the event shell.
          await _openDetail(
            tester,
            event,
            settle: false,
            size: const Size(390, 1100),
          );
          expect(find.text(event.title), findsWidgets);
          expect(find.text('@bugrasahin'), findsOneWidget);
          expect(find.text('@soundconnectankara'), findsOneWidget);
          expect(find.textContaining('06.09.2026'), findsNWidgets(2));
          expect(find.textContaining('20:00'), findsNWidgets(2));
          expect(find.textContaining('22:00'), findsNWidgets(2));
          final share = find.widgetWithText(TextButton, 'Paylaş');
          expect(share, findsOneWidget);
          expect(tester.widget<TextButton>(share).onPressed, isNotNull);
          expect(
            find.byKey(const Key('event-audience-loading')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('event-audience-going')), findsNothing);
          expect(
            find.text('Henüz yorum yok. İlk yorumu sen yaz.'),
            findsNothing,
          );
          expect(details.completion!.isCompleted, isFalse);
          expect(venues.profileGate!.isCompleted, isFalse);
          expect(pendingComments.isCompleted, isFalse);
          expect(pendingAudience.isCompleted, isFalse);
          expect(details.requestedIds, ['event-design-1']);
          expect(musicians.requestedIds, band ? isEmpty : ['artist']);
          expect(bands.requestedIds, band ? ['band'] : isEmpty);
          expect(venues.requestedIds, ['venue']);
          expect(audience.reads, ['commenter']);
          _expectMountCommentBudget(comments);

          pendingComments.complete(
            Result.success(
              CommentPage(
                items: [
                  _authComment(
                    'ready',
                    'Bağımsız yüklenen yorum',
                    replyCount: 400,
                  ),
                ],
                totalElements: 1,
                page: 0,
                size: 50,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(find.text('Bağımsız yüklenen yorum'), findsOneWidget);
          expect(
            find.byKey(const Key('event-audience-loading')),
            findsOneWidget,
          );
          expect(details.completion!.isCompleted, isFalse);
          expect(venues.profileGate!.isCompleted, isFalse);
          _expectMountCommentBudget(comments);

          details.completion!.complete(details.result);
          musicians.completion!.complete(musicians.result);
          bands.completion!.complete(bands.result);
          venues.profileGate!.complete();
          pendingAudience.complete(
            Result.success(audienceState(eventId: event.id)),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('event-audience-loading')), findsNothing);
          expect(find.byKey(const Key('event-audience-going')), findsOneWidget);
          expect(details.requestedIds, hasLength(1));
          expect(venues.requestedIds, hasLength(1));
          expect(audience.reads, hasLength(1));
          _expectMountCommentBudget(comments);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    for (final count in [1, 400]) {
      testWidgets(
        '$count roots have the same initial request budget and no eager reply or like reads',
        (tester) async {
          _registerCommentMember();
          final comments = _MountBudgetComments()
            ..comments.addAll([
              for (var index = 0; index < count; index++)
                _authComment('root-$index', 'Yorum $index', replyCount: 400),
            ]);
          await serviceLocator.unregister<EngagementRepository>();
          serviceLocator.registerSingleton<EngagementRepository>(comments);
          final details =
              serviceLocator<VenueEventRepository>() as _DetailRepository;
          final musicians =
              serviceLocator<MusicianProfileRepository>()
                  as _MusicianRepository;
          final bands = serviceLocator<BandRepository>() as _BandRepository;
          final venues =
              serviceLocator<VenueProfileRepository>() as _VenueRepository;
          venues.includePhoto = false;
          final audience = AudienceTestRepository()
            ..current = audienceState(eventId: 'event-design-1');
          serviceLocator.registerSingleton<EventAudienceRepository>(audience);
          await _openDetail(
            tester,
            _event(
              artistProfileId: 'artist',
              performerType: 'MUSICIAN',
              venueId: 'venue',
            ),
          );

          expect(details.requestedIds, ['event-design-1']);
          expect(musicians.requestedIds, ['artist']);
          expect(bands.requestedIds, isEmpty);
          expect(venues.requestedIds, ['venue']);
          expect(audience.reads, ['commenter']);
          _expectMountCommentBudget(comments);
          final consumer = tester
              .widget<BlocConsumer<CommentThreadCubit, CommentThreadState>>(
                find.byType(
                  BlocConsumer<CommentThreadCubit, CommentThreadState>,
                ),
              );
          final state = consumer.bloc!.state;
          expect(state.comments, hasLength(count > 50 ? 50 : count));
          expect(state.totalElements, count);
          expect(state.hasMore, count > 50);
          expect(find.text('Yorum 399'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  });
}

void _expectMountCommentBudget(_MountBudgetComments comments) {
  expect(comments.listCalls, 1);
  expect(comments.listPages, [0]);
  expect(comments.listSizes, [50]);
  expect(comments.replyReads, isEmpty);
  expect(comments.likeReads, isEmpty);
  expect(comments.likeWrites, isEmpty);
  expect(comments.creations, isEmpty);
  expect(comments.deletions, isEmpty);
}

/// The normal fixtures intentionally don't implement row-like API methods.
/// Record any accidental N+1 call explicitly instead of letting Fake swallow
/// an unexpected request behind a recoverable row error.
class _MountBudgetComments extends _CommentsRepository {
  final likeReads = <String>[];
  final likeWrites = <String>[];

  @override
  Future<Never> readCommentLike({required String commentId}) {
    likeReads.add(commentId);
    return Future<Never>.error(
      StateError('Unexpected eager comment-like read'),
    );
  }

  @override
  Future<Never> setCommentLike({
    required String commentId,
    required bool liked,
  }) {
    likeWrites.add(commentId);
    return Future<Never>.error(StateError('Unexpected comment-like mutation'));
  }

  @override
  Future<Never> getLikeCount({
    required String targetType,
    required String targetId,
  }) {
    likeReads.add('$targetType/$targetId/count');
    return Future<Never>.error(StateError('Unexpected per-row count request'));
  }

  @override
  Future<Never> isLiked({
    required String targetType,
    required String targetId,
  }) {
    likeReads.add('$targetType/$targetId/is-liked');
    return Future<Never>.error(
      StateError('Unexpected per-row personal state request'),
    );
  }
}
