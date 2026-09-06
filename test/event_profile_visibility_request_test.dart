import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/event_performer_request_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/event_performer_request_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_request_copy.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  test(
    'poster is optional for old responses and independent of venue avatar',
    () {
      expect(EventPerformerRequestModel.fromJson(_json()).posterImage, isNull);
      final request = EventPerformerRequestModel.fromJson({
        ..._json(),
        'posterImage': ' https://cdn.test/poster.jpg ',
        'venueProfilePictureUrl': 'https://cdn.test/avatar.jpg',
      });
      expect(request.posterImage, 'https://cdn.test/poster.jpg');
      expect(request.venueProfilePictureUrl, 'https://cdn.test/avatar.jpg');
      for (final value in <Object?>[
        null,
        '',
        123,
        {'url': 'private'},
      ]) {
        expect(
          EventPerformerRequestModel.fromJson({
            ..._json(),
            'posterImage': value,
          }).posterImage,
          isNull,
        );
      }
    },
  );
  group('request purpose protocol', () {
    test('missing purpose preserves legacy participation approval', () {
      final request = EventPerformerRequestModel.fromJson(_json());
      expect(
        request.requestPurpose,
        EventPerformerRequestPurpose.performerConsent,
      );
    });

    for (final entry in {
      'PERFORMER_CONSENT': EventPerformerRequestPurpose.performerConsent,
      'PROFILE_VISIBILITY': EventPerformerRequestPurpose.profileVisibility,
    }.entries) {
      test('decodes explicit ${entry.key}', () {
        final request = EventPerformerRequestModel.fromJson({
          ..._json(),
          'requestPurpose': entry.key,
        });
        expect(request.requestPurpose, entry.value);
      });
    }

    for (final value in <Object?>[null, '', 'UNKNOWN', 1, true, <String>[]]) {
      test('fails closed for supplied invalid purpose $value', () async {
        final api = _PurposeApiClient({..._json(), 'requestPurpose': value});
        final result = await EventPerformerRequestRepositoryImpl(
          api,
        ).listMine();
        expect(result.isSuccess, isFalse);
        expect(
          result.error?.code,
          'event_performer_requests_malformed_response',
        );
        expect(api.decisionCalls, 0);
      });
    }
  });

  test(
    'band copy names the band and explains both visibility preferences in help',
    () {
      final request = _request(band: true);
      expect(request.purposeExplanation, contains('“Şahbaz” adlı grubunun'));
      expect(
        request.calendarVisibilityExplanation,
        contains('etkinlik grup profilinde görünür'),
      );
      expect(
        request.calendarVisibilityHelpParagraphs.join(' '),
        contains('üyelerin kişisel profillerini değiştirmez'),
      );
      expect(request.rejectionExplanation, isNot(contains('üyelerinin')));
    },
  );

  testWidgets(
    'connected approval describes visibility without opening switches',
    (tester) async {
      final repository = _DecisionRepository(_request());
      await _pump(tester, repository);
      expect(find.text('Profilde gösterim izni'), findsOneWidget);
      expect(find.textContaining('Mevcut profil bağlantın'), findsOneWidget);
      expect(find.text('Detaylar için dokun'), findsOneWidget);
      expect(find.text('Etkinlik katılım onayı'), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);

      final accept = find.byKey(const Key('accept-event-request-request-1'));
      await tester.ensureVisible(accept);
      await tester.pump();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(repository.acceptCalls, 1);
      expect(repository.publicationChoices, [true]);
      expect(repository.rejectCalls, 0);
      expect(find.text('Etkinlik profil takvimine eklendi.'), findsOneWidget);
    },
  );

  testWidgets('connected band rejection preserves venue event and link', (
    tester,
  ) async {
    final repository = _DecisionRepository(_request(band: true));
    await _pump(tester, repository);
    final reject = find.byKey(const Key('reject-event-request-request-1'));
    await tester.ensureVisible(reject);
    await tester.pump();
    await tester.tap(reject);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Etkinlik davetini reddetmek istiyor musunuz?'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Mekan profilindeki etkinlik ve mevcut profil bağlantısı korunur.',
      ),
      findsNothing,
    );
    expect(find.textContaining('profil bağlantısı kurulmaz'), findsNothing);
    expect(repository.rejectCalls, 0);
    await tester.tap(find.byKey(const Key('confirm-reject-request-1')));
    await tester.pumpAndSettle();
    expect(repository.rejectCalls, 1);
    expect(repository.acceptCalls, 0);
    expect(
      find.text(
        'Profilde gösterim reddedildi. Mekandaki etkinlik ve profil bağlantısı korundu.',
      ),
      findsOneWidget,
    );
  });

  for (final band in [false, true]) {
    for (final publish in [false, true]) {
      testWidgets(
        'participation approval sends explicit publication choice: band=$band publish=$publish',
        (tester) async {
          final repository = _DecisionRepository(
            _request(
              band: band,
              purpose: EventPerformerRequestPurpose.performerConsent,
            ),
          );
          await _pump(tester, repository);
          final checkbox = find.byType(CheckboxListTile);
          expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
          expect(
            find.textContaining('SoundConnect’te daha görünür kılar.'),
            findsOneWidget,
          );
          if (publish) {
            await tester.ensureVisible(checkbox);
            await tester.pump();
            await tester.tap(checkbox);
            await tester.pump();
            expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
          }
          final accept = find.byKey(
            const Key('accept-event-request-request-1'),
          );
          await tester.ensureVisible(accept);
          await tester.pump();
          await tester.tap(accept);
          await tester.pumpAndSettle();
          expect(repository.publicationChoices, [publish]);
          expect(repository.rejectCalls, 0);
          expect(
            find.text(
              publish
                  ? 'Profil bağlantısı açıldı. Etkinlik profil takvimine eklendi.'
                  : 'Profil bağlantısı açıldı. Etkinlik profil takvimine eklenmedi.',
            ),
            findsOneWidget,
          );
        },
      );
    }
  }

  testWidgets(
    'unconnected rejection uses concise confirmation and cancel does not write',
    (tester) async {
      final repository = _DecisionRepository(
        _request(purpose: EventPerformerRequestPurpose.performerConsent),
      );
      await _pump(tester, repository);
      expect(find.text('Etkinlik katılım onayı'), findsOneWidget);
      final reject = find.byKey(const Key('reject-event-request-request-1'));
      await tester.ensureVisible(reject);
      await tester.pump();
      await tester.tap(reject);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Etkinlik davetini reddetmek istiyor musunuz?'),
        findsOneWidget,
      );
      expect(find.textContaining('profil bağlantısı kurulmaz'), findsNothing);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(repository.rejectCalls, 0);
    },
  );

  testWidgets('visibility request remains accessible at 320dp and 200% text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final completion = Completer<Result<void>>();
    final repository = _DecisionRepository(
      _request(band: true),
      completion: completion,
    );
    await _pump(tester, repository, scale: 2);
    expect(tester.takeException(), isNull);
    final accept = find.byKey(const Key('accept-event-request-request-1'));
    await tester.scrollUntilVisible(
      accept,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<GradientOutlineButton>(accept).strokeWidth, 0.8);
    expect(tester.getSize(accept).height, greaterThanOrEqualTo(48));
    await tester.tap(accept);
    await tester.pump();
    expect(tester.widget<GradientOutlineButton>(accept).onPressed, isNull);
    expect(tester.widget<GradientOutlineButton>(accept).loading, isTrue);
    await tester.tap(accept, warnIfMissed: false);
    expect(repository.acceptCalls, 1);
    expect(repository.publicationChoices, [true]);
    completion.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _DecisionRepository repository, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: EventPerformerRequestsScreen(
          repository: repository,
          targetType: repository.request.targetType,
          targetId: repository.request.targetId,
          sessionKeyProvider: () => 'musician-owner',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _json({bool band = false}) => {
  'id': 'request-1',
  'eventId': 'event-1',
  'eventTitle': 'Akustik Gece',
  'eventDate': '2026-09-08',
  'startTime': '21:00:00',
  'endTime': '23:00:00',
  'venueId': 'venue-1',
  'venueName': 'SoundConnect Ankara',
  'performerType': band ? 'BAND' : 'MUSICIAN',
  if (band) 'bandId': 'band-1' else 'musicianProfileId': 'musician-1',
  'performerName': band ? 'Şahbaz' : 'Buğra Şahin',
  'status': 'PENDING',
  'profileCalendarApproved': false,
  'decisionAllowed': true,
  'canReconsider': false,
  'expired': false,
  'serverNow': '2026-09-06T12:00:00Z',
  'eventStartsAt': '2026-09-08T18:00:00Z',
};

EventPerformerRequest _request({
  bool band = false,
  EventPerformerRequestPurpose purpose =
      EventPerformerRequestPurpose.profileVisibility,
}) => EventPerformerRequestModel.fromJson({
  ..._json(band: band),
  'requestPurpose': purpose == EventPerformerRequestPurpose.profileVisibility
      ? 'PROFILE_VISIBILITY'
      : 'PERFORMER_CONSENT',
});

class _DecisionRepository implements EventPerformerRequestRepository {
  @override
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  }) => throw UnimplementedError(
    'Unexpected reconsideration in pending visibility test.',
  );

  _DecisionRepository(this.request, {this.completion});

  final EventPerformerRequest request;
  final Completer<Result<void>>? completion;
  int acceptCalls = 0;
  final List<bool> publicationChoices = [];
  int rejectCalls = 0;

  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async {
    final pending = acceptCalls == 0 && rejectCalls == 0;
    return Result.success(
      EventPerformerRequestPage(
        items: pending ? [request] : [],
        page: 0,
        size: 20,
        totalElements: pending ? 1 : 0,
        totalPages: pending ? 1 : 0,
        hasNext: false,
      ),
    );
  }

  @override
  Future<Result<void>> accept(
    String requestId, {
    bool showOnProfile = false,
  }) async {
    expect(requestId, request.requestId);
    acceptCalls++;
    publicationChoices.add(showOnProfile);
    return completion?.future ?? const Result.success(null);
  }

  @override
  Future<Result<void>> reject(String requestId) async {
    expect(requestId, request.requestId);
    rejectCalls++;
    return const Result.success(null);
  }
}

class _PurposeApiClient extends ApiClient {
  _PurposeApiClient(this.item);

  final Map<String, dynamic> item;
  int decisionCalls = 0;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async => decoder!([item]);

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    decisionCalls++;
    return decoder!(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
