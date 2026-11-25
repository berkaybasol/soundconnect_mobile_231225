import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/auth_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/google_auth_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/business_registration_details.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'venue_application_session_test.dart'
    show applicantToken, applicantId, applicationId;

void main() {
  late _GoogleApi api;
  late GoogleAuthRepository repository;
  setUp(() {
    api = _GoogleApi();
    repository = GoogleAuthRepository(api);
  });

  test('new and interrupted signups have no SoundConnect credential', () async {
    api.response = {'requiresGoogleProfileCompletion': true, 'token': null};
    expect(await repository.signIn('mock-provider-token', 4), isNull);
    expect(api.path, AuthEndpoints.googleSignIn);
    expect(api.body, {'idToken': 'mock-provider-token'});
    expect(api.context?.requireGuestSession, isTrue);
    expect(api.context?.expectedCredentialRevision, 4);
  });

  for (final studio in [true, false]) {
    test(
      'business signup and later sign-in decode the same pending status, studio=$studio',
      () async {
        final role = studio ? 'ROLE_STUDIO' : 'ROLE_VENUE';
        api.response = {
          'requiresGoogleProfileCompletion': false,
          'requiresListenerProfileChoice': false,
          'status': studio ? 'PENDING_STUDIO_REQUEST' : 'PENDING_VENUE_REQUEST',
          'roles': <String>[],
          'permissions': <String>[],
          'admin': false,
          'userId': applicantId,
          'applicationId': applicationId,
          'token': studio ? null : applicantToken(),
          'sessionScope': studio ? null : 'VENUE_APPLICATION',
        };
        final business = BusinessRegistrationDetails(
          isStudio: studio,
          name: '  My Place ',
          address: ' Moda ',
          phone: '5551234567',
          cityId: 'city',
          districtId: 'district',
          neighborhoodId: 'neighborhood',
        );
        final submitted = await repository.complete(
          idToken: 'proof',
          username: 'myuser',
          role: role,
          consent: true,
          revision: 7,
          business: business,
        );
        expect(api.body, {
          'idToken': 'proof',
          'username': 'myuser',
          'role': role,
          'consent': true,
          if (studio) ...{
            'studioName': 'my place',
            'studioAddress': 'Moda',
            'studioPhone': '05551234567',
          } else ...{
            'venueName': 'my place',
            'venueAddress': 'Moda',
            'phone': '5551234567',
          },
          'cityId': 'city',
          'districtId': 'district',
          'neighborhoodId': 'neighborhood',
        });
        final resumed = await repository.signIn('proof', 10);
        expect(api.body, {'idToken': 'proof'});
        for (final result in [submitted, resumed!]) {
          expect(result.applicationId, applicationId);
          expect(result.token.isEmpty, studio);
          expect(
            result.status,
            studio
                ? UserStatus.pendingStudioRequest
                : UserStatus.pendingVenueRequest,
          );
        }
        if (studio) {
          api.response = {...api.response as Map, 'token': 'unexpected bearer'};
          await expectLater(
            repository.signIn('proof', 10),
            throwsFormatException,
          );
        }
      },
    );
  }

  test(
    'completion uses the same identity, consent and guest session',
    () async {
      api.response = {
        'requiresGoogleProfileCompletion': false,
        'requiresListenerProfileChoice': true,
        'token': 'mock-soundconnect-token',
        'userId': 'user-1',
        'username': 'listener',
        'status': 'ACTIVE',
        'roles': ['ROLE_LISTENER'],
      };
      final session = await repository.complete(
        idToken: 'mock-provider-token',
        username: 'listener',
        role: 'ROLE_LISTENER',
        consent: true,
        revision: 5,
      );
      expect(api.path, AuthEndpoints.completeGoogleProfile);
      expect(api.body, {
        'idToken': 'mock-provider-token',
        'username': 'listener',
        'role': 'ROLE_LISTENER',
        'consent': true,
      });
      expect(api.context?.requireGuestSession, isTrue);
      expect(api.context?.expectedCredentialRevision, 5);
      expect(session.token, 'mock-soundconnect-token');
      expect(session.requiresListenerProfileChoice, isTrue);
    },
  );

  test(
    'malformed completion markers cannot become sessions or trigger signup',
    () async {
      for (final response in [
        {'requiresGoogleProfileCompletion': true, 'token': 'unexpected'},
        {'requiresGoogleProfileCompletion': false, 'token': null},
        {'token': null},
      ]) {
        api.response = response;
        await expectLater(
          repository.signIn('mock-provider-token', 1),
          throwsFormatException,
        );
      }
    },
  );
}

class _GoogleApi extends Fake implements ApiClient {
  Object? response;
  Object? body;
  ApiRequestContext? context;
  String? path;

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    expect(method, ApiHttpMethod.post);
    this.body = body;
    this.path = path;
    context = requestContext;
    return decoder!(response);
  }
}
