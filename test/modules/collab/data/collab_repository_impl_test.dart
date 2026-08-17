import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/data/collab_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_commands.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';

import '../../../support/recording_api_client.dart';

void main() {
  group('CollabRepositoryImpl', () {
    test(
      'serializes server-side discovery filters and decodes PageResponse',
      () async {
        final api = RecordingApiClient(
          (_) => <String, dynamic>{
            'content': <Object?>[_listingJson()],
            'page': 2,
            'size': 25,
            'totalElements': 76,
            'totalPages': 4,
            'first': false,
            'last': false,
          },
        );
        final repository = CollabRepositoryImpl(api);

        final result = await repository.discover(
          const CollabDiscoveryQuery(
            search: 'bas gitar',
            cityId: 'city-34',
            wantedType: CollabProfileKind.musician,
            instrumentIds: <String>{'instrument-2', 'instrument-1'},
            branches: <CollabBranch>{CollabBranch.vocal},
            publisherTypes: <CollabProfileKind>{
              CollabProfileKind.venue,
              CollabProfileKind.musician,
            },
            publishedWithin: CollabPublishedWithin.last7Days,
            cadence: CollabCadence.regular,
            page: 2,
            size: 25,
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.data!.items.single.id, 'listing-1');
        expect(result.data!.page, 2);
        expect(result.data!.hasNext, isTrue);
        expect(result.data!.items.single.publisher.actorId, 'actor-1');
        expect(result.data!.items.single.publisher.rating, 4.75);
        expect(api.lastRequest.method, RecordedHttpMethod.get);
        expect(api.lastRequest.path, CollabEndpoints.root);
        expect(api.lastRequest.query, <String, dynamic>{
          'q': 'bas gitar',
          'cityId': 'city-34',
          'wantedType': 'MUSICIAN',
          'instrumentIds': 'instrument-1,instrument-2',
          'branches': 'VOCAL',
          'publisherTypes': 'MUSICIAN,VENUE',
          'publishedWindow': 'LAST_7_DAYS',
          'cadence': 'REGULAR',
          'page': 2,
          'size': 25,
        });
      },
    );

    test(
      'create draft uses minor money, UTC date and idempotency key',
      () async {
        final api = RecordingApiClient(
          (_) => _listingJson(status: 'DRAFT', cadence: 'EXTRA'),
        );
        final repository = CollabRepositoryImpl(api);
        final scheduledAt = DateTime.parse('2026-08-12T22:30:00+03:00');

        final result = await repository.createDraft(
          CollabListingInput(
            publisherActorId: ' actor-1 ',
            cadence: CollabCadence.extra,
            wantedType: CollabProfileKind.musician,
            instrumentId: 'instrument-1',
            title: ' Basçı aranıyor ',
            description: ' Çarşamba akşamı sahne için basçı aranıyor. ',
            cityId: 'city-34',
            genres: const <String>['Rock', ' Rock ', 'Blues'],
            scheduledAt: scheduledAt,
            feeAmountMinor: 150075,
            currency: 'try',
          ),
          clientRequestId: 'request-1',
        );

        expect(result.isSuccess, isTrue);
        expect(api.lastRequest.method, RecordedHttpMethod.post);
        expect(api.lastRequest.path, CollabEndpoints.drafts);
        final body = api.lastRequest.body! as Map<String, dynamic>;
        expect(body['clientRequestId'], 'request-1');
        expect(body['feeAmountMinor'], 150075);
        expect(body['currency'], 'TRY');
        expect(body['scheduledAt'], '2026-08-12T19:30:00.000Z');
        expect(body.containsKey('timeZone'), isFalse);
        expect(body['genres'], <String>['Blues', 'Rock']);
      },
    );

    test(
      'application decoder accepts phoneNumber and exact withdrawn state',
      () async {
        final api = RecordingApiClient(
          (_) => _applicationJson(status: 'WITHDRAWN_BY_APPLICANT'),
        );
        final repository = CollabRepositoryImpl(api);

        final result = await repository.withdrawApplication(
          'application-1',
          expectedVersion: 3,
        );

        expect(result.isSuccess, isTrue);
        expect(
          result.data!.status,
          CollabApplicationStatus.withdrawnByApplicant,
        );
        expect(result.data!.phone, '+905551112233');
        expect(api.lastRequest.body, <String, dynamic>{'expectedVersion': 3});
      },
    );

    test('apply sends private phoneNumber contract key', () async {
      final api = RecordingApiClient((_) => _applicationJson());
      final repository = CollabRepositoryImpl(api);

      await repository.apply(
        'listing-1',
        const CollabApplicationInput(
          applicantActorId: 'actor-2',
          phone: ' +905551112233 ',
          message: ' Uygunum. ',
        ),
        clientRequestId: 'apply-request-1',
      );

      expect(api.lastRequest.body, <String, dynamic>{
        'clientRequestId': 'apply-request-1',
        'applicantActorId': 'actor-2',
        'phoneNumber': '+905551112233',
        'message': 'Uygunum.',
      });
    });

    test('canonical request bodies omit blank optional text', () async {
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/applications')) {
          return _applicationJson();
        }
        if (request.path.endsWith('/reviews')) return _reviewJson();
        return null;
      });
      final repository = CollabRepositoryImpl(api);

      await repository.apply(
        'listing-1',
        const CollabApplicationInput(
          applicantActorId: ' actor-2 ',
          phone: ' +90 (555) 111-22-33 ',
          message: '   ',
        ),
        clientRequestId: 'apply-request-1',
      );
      expect(api.lastRequest.body, <String, dynamic>{
        'clientRequestId': 'apply-request-1',
        'applicantActorId': 'actor-2',
        'phoneNumber': '+905551112233',
      });

      await repository.reportListing(
        'listing-1',
        const CollabReportInput(
          reason: CollabReportReason.spam,
          details: '   ',
        ),
        clientRequestId: 'report-request-1',
      );
      expect(api.lastRequest.body, <String, dynamic>{
        'clientRequestId': 'report-request-1',
        'reason': 'SPAM',
      });

      await repository.createReview(
        'job-1',
        const CollabReviewInput(rating: 5, comment: '   '),
        clientRequestId: 'review-request-1',
      );
      expect(api.lastRequest.body, <String, dynamic>{
        'clientRequestId': 'review-request-1',
        'rating': 5,
      });
    });

    test(
      'rejects a phone outside the backend normalization contract',
      () async {
        final api = RecordingApiClient((_) => _applicationJson());
        final repository = CollabRepositoryImpl(api);

        final result = await repository.apply(
          'listing-1',
          const CollabApplicationInput(
            applicantActorId: 'actor-2',
            phone: 'abc1234567',
            message: '',
          ),
          clientRequestId: 'apply-request-1',
        );

        expect(result.isSuccess, isFalse);
        expect(result.error!.code, 'collab_application_input_invalid');
        expect(api.requests, isEmpty);
      },
    );

    test('accept decodes the atomically created job response', () async {
      final api = RecordingApiClient((_) => _jobJson());
      final repository = CollabRepositoryImpl(api);

      final result = await repository.acceptApplication(
        'application-1',
        expectedVersion: 3,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.id, 'job-1');
      expect(result.data!.publisherConfirmedCompletion, isFalse);
      expect(result.data!.applicantConfirmedCompletion, isFalse);
      expect(result.data!.confirmedByMe, isFalse);
      expect(
        api.lastRequest.path,
        '/api/v1/collabs/applications/application-1/accept',
      );
    });

    test('unknown status fails safely as a contract error', () async {
      final api = RecordingApiClient(
        (_) => _listingJson(status: 'FUTURE_SERVER_STATUS'),
      );
      final repository = CollabRepositoryImpl(api);

      final result = await repository.getListing('listing-1');

      expect(result.isSuccess, isFalse);
      expect(result.error!.code, 'collab_contract_invalid');
      expect(result.error!.details.single, contains('FUTURE_SERVER_STATUS'));
    });

    test('missing ownership flags fail closed as a contract error', () async {
      final response = _listingJson()..remove('ownedByMe');
      final api = RecordingApiClient((_) => response);
      final repository = CollabRepositoryImpl(api);

      final result = await repository.getListing('listing-1');

      expect(result.isSuccess, isFalse);
      expect(result.error!.code, 'collab_contract_invalid');
      expect(result.error!.details.single, contains('ownedByMe'));
    });

    test(
      'rejects invalid review rating without dispatching a request',
      () async {
        final api = RecordingApiClient((_) => null);
        final repository = CollabRepositoryImpl(api);

        final result = await repository.createReview(
          'job-1',
          const CollabReviewInput(rating: 6),
          clientRequestId: 'review-request-1',
        );

        expect(result.isSuccess, isFalse);
        expect(result.error!.code, 'collab_review_rating_invalid');
        expect(api.requests, isEmpty);
      },
    );

    test('reports a listing with stable reason and idempotency key', () async {
      final api = RecordingApiClient((_) => null);
      final repository = CollabRepositoryImpl(api);

      final result = await repository.reportListing(
        'listing-1',
        const CollabReportInput(
          reason: CollabReportReason.misleading,
          details: ' Yanıltıcı tarih ',
        ),
        clientRequestId: 'report-request-1',
      );

      expect(result.isSuccess, isTrue);
      expect(api.lastRequest.path, '/api/v1/collabs/listing-1/reports');
      expect(api.lastRequest.body, <String, dynamic>{
        'clientRequestId': 'report-request-1',
        'reason': 'MISLEADING',
        'details': 'Yanıltıcı tarih',
      });
    });
  });
}

Map<String, dynamic> _actorJson({
  String actorId = 'actor-1',
  String profileType = 'VENUE',
}) => <String, dynamic>{
  'actorId': actorId,
  'profileType': profileType,
  'sourceProfileId': 'profile-$actorId',
  'contactUserId': 'user-$actorId',
  'displayName': actorId == 'actor-1' ? 'Kadıköy Sahne' : 'Deniz Kaya',
  'avatarUrl': 'https://cdn.example.com/$actorId.jpg',
  'rating': 4.75,
  'reviewCount': 12,
  'completedJobCount': 31,
};

Map<String, dynamic> _listingJson({
  String status = 'OPEN',
  String cadence = 'REGULAR',
}) => <String, dynamic>{
  'id': 'listing-1',
  'version': 4,
  'status': status,
  'closureReason': null,
  'cadence': cadence,
  'wantedType': 'MUSICIAN',
  'instrument': <String, dynamic>{'id': 'instrument-1', 'name': 'Bas Gitar'},
  'branch': null,
  'customSpecialty': null,
  'title': 'Bas gitarist aranıyor',
  'description': 'Çarşamba gecesi sahne için bas gitarist arıyoruz.',
  'city': <String, dynamic>{'id': 'city-34', 'name': 'İstanbul'},
  'genres': <String>['Rock', 'Blues'],
  'scheduledAt': cadence == 'EXTRA' ? '2026-08-12T19:30:00Z' : null,
  'expiresAt': '2026-09-01T12:00:00Z',
  'feeAmountMinor': cadence == 'EXTRA' ? 150075 : null,
  'currency': cadence == 'EXTRA' ? 'TRY' : null,
  'feeStatus': cadence == 'EXTRA' ? 'SPECIFIED' : 'UNSPECIFIED',
  'publishedAt': status == 'DRAFT' ? null : '2026-08-11T10:00:00Z',
  'createdAt': '2026-08-11T09:55:00Z',
  'closedAt': null,
  'publisher': _actorJson(),
  'ownedByMe': false,
  'appliedByMe': false,
  'savedByMe': false,
  'applicationCount': 2,
};

Map<String, dynamic> _applicationJson({String status = 'PENDING'}) =>
    <String, dynamic>{
      'id': 'application-1',
      'version': 3,
      'listing': _listingJson(),
      'applicant': _actorJson(actorId: 'actor-2', profileType: 'MUSICIAN'),
      'phoneNumber': '+905551112233',
      'message': 'Uygunum.',
      'status': status,
      'submittedAt': '2026-08-11T11:00:00Z',
      'statusChangedAt': '2026-08-11T11:10:00Z',
      'decidedAt': null,
    };

Map<String, dynamic> _jobJson() => <String, dynamic>{
  'id': 'job-1',
  'version': 0,
  'status': 'ACTIVE',
  'listing': _listingJson(status: 'CLOSED'),
  'publisher': _actorJson(),
  'applicant': _actorJson(actorId: 'actor-2', profileType: 'MUSICIAN'),
  'publisherConfirmed': false,
  'applicantConfirmed': false,
  'publisherConfirmedAt': null,
  'applicantConfirmedAt': null,
  'confirmedByMe': false,
  'reviewedByMe': false,
  'completedAt': null,
};

Map<String, dynamic> _reviewJson() => <String, dynamic>{
  'id': 'review-1',
  'jobId': 'job-1',
  'reviewer': _actorJson(actorId: 'actor-1'),
  'target': _actorJson(actorId: 'actor-2'),
  'rating': 5,
  'comment': null,
  'submittedAt': '2026-08-11T12:00:00Z',
};
