import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/collab_report_admin_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/collab_report_admin.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _id = '4f56cb09-63b8-480c-a840-d92f9cdd464f';
const _base = '/api/v1/admin/collab/reports';
const _note = 'Yanıltıcı ilan bilgisi';

AuthSession _admin({List<String> roles = const ['ROLE_ADMIN']}) =>
    AuthSession.authenticated(
      userId: 'reviewer',
      username: 'reviewer',
      token: 'admin-token',
      accountStatus: 'ACTIVE',
      roles: roles,
      permissions: const ['MANAGE_COLLAB_REPORTS'],
      expiresAt: DateTime.utc(2100),
      isAdmin: true,
    );

Map<String, dynamic> _report({CollabReportDecision? decision}) => {
  'id': _id,
  'version': decision == null ? 1 : 2,
  'status': decision?.resultingStatus.apiValue ?? 'OPEN',
  'reason': 'MISLEADING',
  'details': 'Mekân farklı.',
  'reportedAt': '2026-11-22T02:15:00Z',
  'listingId': 'listing',
  'listingTitle': 'Konser',
  'listingDescription': 'Tek gecelik sahne',
  'hasListingEvidence': true,
  'listingStatusAtReport': 'OPEN',
  'listingStatus': 'CLOSED',
  'publisherActorId': 'publisher',
  'publisherDisplayName': 'Ada',
  'cadence': 'EXTRA',
  'wantedType': 'MUSICIAN',
  'instrument': {'id': 'instrument', 'name': 'Gitar'},
  'city': {'id': 'city', 'name': 'Ankara'},
  'listingGenres': ['Rock'],
  'scheduledAt': '2026-11-24T19:30:00Z',
  'feeAmountMinor': 540000,
  'currency': 'TRY',
  'reporterUserId': 'reporter',
  'reporterUsername': 'deniz',
  if (decision != null) ...{
    'reviewedAt': '2026-11-23T12:05:00Z',
    'resolutionNote': _note,
    'reviewDecision': decision.apiValue,
    'reviewedByUserId': 'reviewer',
    'reviewedByUsername': 'moderatör',
  },
};

void main() {
  late AudienceTestSessions sessions;
  setUp(() => sessions = AudienceTestSessions(_admin()));
  tearDown(() => sessions.dispose());

  test(
    'loads filtered page, keeping listing evidence and current status separate',
    () async {
      final api = RecordingApiClient(
        (_) => {
          'content': [_report(decision: CollabReportDecision.removeListing)],
          'page': 1,
          'size': 20,
          'totalElements': 21,
          'totalPages': 2,
          'first': false,
          'last': true,
        },
      );
      final result = await CollabReportAdminRepository(api, sessions).load(
        page: 1,
        reason: CollabReportReason.misleading,
        status: CollabReportStatus.actioned,
      );
      final request = api.lastRequest;
      expect(request.path, _base);
      expect(request.query, {
        'page': 1,
        'size': 20,
        'reason': 'MISLEADING',
        'status': 'ACTIONED',
      });
      expect(
        request.requestContext?.expectedCredentialRevision,
        sessions.credentialRevision,
      );
      expect(request.requestContext?.expectedToken, sessions.session.token);
      final item = result.data!.items.single;
      expect(item.hasListingEvidence, isTrue);
      expect(item.listingStatus, CollabListingStatus.closed);
      expect(item.listingStatusAtReport, CollabListingStatus.open);
      expect(item.instrument?.name, 'Gitar');
      expect(item.city.name, 'Ankara');
      expect(item.listingGenres, ['Rock']);
      expect(item.feeAmountMinor, 540000);
      expect(item.reporterUserId, 'reporter');
      expect(item.reporterUsername, 'deniz');
      expect(item.reviewedByUserId, 'reviewer');
      expect(item.reviewedByUsername, 'moderatör');
      expect(item.reviewedAt, DateTime.utc(2026, 11, 23, 12, 5));
      expect(item.resolutionNote, _note);
    },
  );

  test(
    'detail never treats unverifiable older evidence as report-time evidence',
    () async {
      final data = _report()..remove('hasListingEvidence');
      final api = RecordingApiClient((_) => data);
      final repository = CollabReportAdminRepository(api, sessions);
      final result = await repository.detail(_id);
      expect(api.lastRequest.path, '$_base/$_id');
      expect(result.data!.hasListingEvidence, isFalse);
      data['hasListingEvidence'] = false;
      expect((await repository.detail(_id)).data!.hasListingEvidence, isFalse);
      data['id'] = 'unrelated';
      expect((await repository.detail(_id)).isSuccess, isFalse);
    },
  );

  test('resolution note length matches database Unicode character limits', () {
    expect(isValidCollabResolutionNote('😀' * 3), isFalse);
    expect(isValidCollabResolutionNote('😀' * 5), isTrue);
    expect(isValidCollabResolutionNote('😀' * 500), isTrue);
    expect(isValidCollabResolutionNote('😀' * 501), isFalse);
  });

  for (final decision in CollabReportDecision.values) {
    test('submits ${decision.apiValue} against reviewed version', () async {
      final api = RecordingApiClient((_) => _report(decision: decision));
      final repository = CollabReportAdminRepository(api, sessions);
      final result = await repository.review(
        CollabAdminReport.fromJson(_report()),
        decision: decision,
        note: '  $_note  ',
      );
      expect(api.lastRequest.method, RecordedHttpMethod.post);
      expect(api.lastRequest.path, '$_base/$_id/review');
      expect(api.lastRequest.body, {
        'expectedVersion': 1,
        'decision': decision.apiValue,
        'resolutionNote': _note,
      });
      expect(result.data!.reviewDecision, decision);
    });
  }

  test(
    'rejects invalid notes, pages, IDs and closed reports before dispatch',
    () async {
      final api = RecordingApiClient((_) => null);
      final repository = CollabReportAdminRepository(api, sessions);
      expect((await repository.load(page: -1)).isSuccess, isFalse);
      expect((await repository.detail('../elsewhere')).isSuccess, isFalse);
      final open = CollabAdminReport.fromJson(_report());
      for (final note in ['    1234 ', 'X' * 501]) {
        expect(
          (await repository.review(
            open,
            decision: CollabReportDecision.dismiss,
            note: note,
          )).isSuccess,
          isFalse,
        );
      }
      final closed = CollabAdminReport.fromJson(
        _report(decision: CollabReportDecision.removeListing),
      );
      expect(
        (await repository.review(
          closed,
          decision: CollabReportDecision.dismiss,
          note: _note,
        )).isSuccess,
        isFalse,
      );
      expect(api.requests, isEmpty);
    },
  );

  test(
    'revoked authority vetoes requests and drops a late result after account switching',
    () async {
      final response = Completer<Object?>();
      final api = RecordingApiClient((_) => response.future);
      final repository = CollabReportAdminRepository(api, sessions);
      final original = sessions.session;
      final pending = repository.detail(_id);
      sessions.replace(_admin(roles: ['ROLE_LISTENER', 'ROLE_ADMIN']));
      expect(
        isCollabReportAccessError((await repository.detail(_id)).error),
        isTrue,
      );
      sessions.replace(original);
      response.complete(_report());
      expect(isCollabReportAccessError((await pending).error), isTrue);
      expect(api.requests, hasLength(1));
    },
  );

  test(
    'preserves server conflict and permission codes for refresh and redaction',
    () async {
      for (final code in ['9317', '9324', '9301', '1102']) {
        final api = RecordingApiClient(
          (_) => throw ApiException(AppError(code: code, message: 'API')),
        );
        final error = (await CollabReportAdminRepository(api, sessions).review(
          CollabAdminReport.fromJson(_report()),
          decision: CollabReportDecision.dismiss,
          note: _note,
        )).error;
        expect(error?.code, code);
        expect(isCollabReportConflict(error), ['9317', '9324'].contains(code));
        expect(
          isCollabReportAccessError(error),
          ['9301', '1102'].contains(code),
        );
      }
    },
  );
}
