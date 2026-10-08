part of 'custom_notification_open_test.dart';

const _profiles = ['MUSICIAN', 'LISTENER', 'VENUE', 'STUDIO'];
const _moduleRoutes = {
  'EVENTS': AppRoutes.eventDiscovery,
  'TABLES': AppRoutes.tableGroupList,
  'COLLAB': AppRoutes.collabDiscovery,
  'MARKETPLACE': AppRoutes.marketplace,
};

Map<String, dynamic> _matrixDestination(String kind) => {
  ..._destination(kind: kind),
  if (kind == 'EVENT')
    'event': {
      'id': _entity,
      'eventOrigin': 'VENUE',
      'title': 'Fresh exact event',
      'performerType': 'UNLINKED',
      'performerName': 'Artist',
      'venueName': 'Venue',
      'eventDate': '2028-01-01',
      'startTime': '21:05:00',
    },
  if (kind == 'CONTENT')
    'media': {
      'uuid': _entity,
      'kind': 'IMAGE',
      'title': 'Fresh exact media',
      'sourceUrl': 'https://example.test/current.png',
    },
};

void _registerProfileTargetMatrix() {
  for (final profile in _profiles) {
    for (final kind in [
      'HOME',
      'EVENTS',
      'PROFILE',
      'EVENT',
      'CONTENT',
      'TABLES',
      'COLLAB',
      'MARKETPLACE',
    ]) {
      test(
        '$profile / $kind fresh target keeps identity and session without ACK',
        () async {
          final h = _Harness(role: profile);
          addTearDown(h.dispose);
          h.destination = () => _matrixDestination(kind);
          final result = await h.repository.resolve(
            _target,
            h.sessions.session,
          );
          expect(result.isSuccess, isTrue);
          expect(result.data?.kind, kind);
          expect(result.data?.notification.id, _notice);
          expect(result.data?.notification.recipientId, counterOwner);
          expect(
            result.data?.targetId,
            {'PROFILE', 'EVENT', 'CONTENT'}.contains(kind) ? _entity : isNull,
          );
          expect(h.gets, 2);
          expect(h.acks, isEmpty);
          for (final request in h.api.requests) {
            expect(request.requestContext?.expectedSessionKey, counterOwner);
            expect(
              request.requestContext?.expectedToken,
              h.sessions.session.token,
            );
          }
        },
      );
    }

    for (final inbox in [false, true]) {
      final entry = inbox ? 'real inbox tap' : 'native metadata opener';
      for (final kind in ['HOME', ..._moduleRoutes.keys]) {
        final denied =
            profile == 'LISTENER' && {'COLLAB', 'MARKETPLACE'}.contains(kind);
        testWidgets('$profile / $kind / $entry route and exact visible read', (
          t,
        ) async {
          final h = _Harness(role: profile);
          h.presenterKind = kind;
          h.destination = () => denied
              ? _destination(available: false)
              : _destination(kind: kind);
          await h.mount(t, inbox: inbox);
          await t.pumpAndSettle();
          expect(h.gets, 2);
          if (denied) {
            expect(h.routeNames, isEmpty);
            expect(find.byType(AlertDialog), findsNothing);
            expect(
              find.text('Bu bildirimin hedefi artık kullanılamıyor.'),
              findsOneWidget,
            );
            expect(
              inbox
                  ? find.byType(NotificationScreen)
                  : find.text('Original product'),
              findsOneWidget,
            );
          } else {
            final expected = kind == 'HOME'
                ? (profile == 'LISTENER'
                      ? AppRoutes.listenerProfile
                      : AppRoutes.home)
                : _moduleRoutes[kind];
            expect(h.routeNames, [expected]);
            expect(h.acks, isEmpty);
            h.presenterKind = 'WRONG_SURFACE';
            h.ready.value = true;
            await t.pumpAndSettle();
            expect(h.acks, isEmpty);
            h.presenterKind = kind;
            h.ready.value = false;
            h.ready.value = true;
            await t.pumpAndSettle();
          }
          expect(h.acks, [_notice]);
          h.expectOnlySelectedRead();
          expect(t.takeException(), isNull);
        });
        if (denied) {
          testWidgets(
            '$profile / $kind / $entry rejects falsely available protected route',
            (t) async {
              final h = _Harness(role: profile);
              h.destination = () => _destination(kind: kind);
              h.ready.value = true;
              await h.mount(t, inbox: inbox);
              await t.pumpAndSettle();
              expect(h.gets, 2);
              expect(h.routeNames, isEmpty);
              expect(h.acks, isEmpty);
              expect(h.cubit.state.unreadCount, 2);
              expect(find.text('Tekrar dene'), findsOneWidget);
            },
          );
        }
      }

      testWidgets(
        '$profile / EVENT / $entry opens real exact event and reads only it',
        (t) async {
          final h = _Harness(role: profile);
          h.destination = () => _matrixDestination('EVENT');
          serviceLocator.registerSingleton<EngagementRepository>(
            _MatrixComments(),
          );
          serviceLocator.registerSingleton<VenueEventRepository>(
            _MatrixEvent(),
          );
          await h.mount(t, inbox: inbox);
          await t.pumpAndSettle();
          final screen = t.widget<WeeklyEventDetailScreen>(
            find.byType(WeeklyEventDetailScreen),
          );
          expect(screen.event.id, _entity);
          expect(screen.event.title, 'Fresh exact event');
          expect(screen.event.startTime, '21:05:00');
          expect(find.text('Fresh exact event'), findsWidgets);
          expect(h.gets, 2);
          expect(h.acks, [_notice]);
          h.expectOnlySelectedRead();
          h.navigator.currentState!.pop();
          await t.pumpAndSettle();
          expect(
            inbox
                ? find.byType(NotificationScreen)
                : find.text('Original product'),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}

class _MatrixComments extends Fake implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}

class _MatrixEvent extends Fake implements VenueEventRepository {
  @override
  Future<Result<VenueEventDetail>> getDetail(String id) async =>
      const Result.success(
        VenueEventDetail(
          id: _entity,
          shareUrl: null,
          posterImage: null,
          performerName: 'Artist',
          musicianProfileId: null,
          title: 'Fresh exact event',
        ),
      );
}
