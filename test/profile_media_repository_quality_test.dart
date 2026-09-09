import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_media_repository_impl.dart';
import 'support/recording_api_client.dart';

void main() {
  for (final code in ['401', '403', '1307', 'network_error', '500']) {
    test(
      'primary $code failure cannot become successful empty media',
      () async {
        final error = AppError(code: code, message: 'Failed');
        final api = RecordingApiClient((_) => throw ApiException(error));
        final result = await ProfileMediaRepositoryImpl(
          api,
        ).getProfileMedia(profileType: 'MUSICIAN', profileId: 'profile');
        expect(result.error, same(error));
        expect(api.requests.length, 1);
      },
    );
  }

  test('legacy route 404 permits a valid empty compatibility page', () async {
    final api = RecordingApiClient((request) {
      if (!request.path.contains('/public/media/')) {
        throw ApiException(
          const AppError(code: '404', message: 'Route missing'),
        );
      }
      return {'content': <Object?>[]};
    });
    final result = await ProfileMediaRepositoryImpl(
      api,
    ).getProfileMedia(profileType: 'BAND', profileId: 'band');
    expect(result.isSuccess, isTrue);
    expect(api.requests.length, 2);
  });

  for (final primaryMissing in [true, false]) {
    test(
      'malformed fallback page fails instead of pretending media is empty ($primaryMissing)',
      () async {
        final api = RecordingApiClient((request) {
          if (request.path.contains('/public/media/')) {
            return {'content': 'corrupt'};
          }
          if (primaryMissing) {
            throw ApiException(
              const AppError(code: '404', message: 'Route missing'),
            );
          }
          return {'featuredVideo': null, 'videos': [], 'audios': []};
        });
        final result = await ProfileMediaRepositoryImpl(
          api,
        ).getProfileMedia(profileType: 'VENUE', profileId: 'profile');
        expect(result.error?.code, 'profile_media_invalid_response');
      },
    );
  }
}
