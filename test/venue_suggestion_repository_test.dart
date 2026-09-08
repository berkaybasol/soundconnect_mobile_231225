import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/event/data/venue_suggestion_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/venue_suggestion_repository.dart';
import 'support/recording_api_client.dart';

const _requestId = '83c1c8bc-e4b0-444f-b758-55c6ad5e68f6';

void main() {
  for (final music in VenueSuggestionLiveMusic.values) {
    test(
      'public submission maps $music and carries stable request id',
      () async {
        final api = RecordingApiClient((_) => {'accepted': true});
        final repo = VenueSuggestionRepositoryImpl(api);
        for (var i = 0; i < 2; i++) {
          final result = await repo.submit(
            requestId: _requestId,
            venueName: '  Şehir Sahnesi  ',
            cityId: ' city ',
            districtId: ' district ',
            liveMusic: music,
          );
          expect(result.isSuccess, isTrue);
        }
        expect(api.requests.length, 2);
        expect(api.lastRequest.path, '/api/v1/venue-suggestions');
        expect(api.lastRequest.method, RecordedHttpMethod.post);
        expect(api.lastRequest.body, {
          'requestId': _requestId,
          'venueName': 'Şehir Sahnesi',
          'cityId': 'city',
          'districtId': 'district',
          'liveMusic': music.name.toUpperCase(),
        });
        expect(api.requests.first.body, api.lastRequest.body);
      },
    );
  }
  for (final raw in <Object?>[
    null,
    [],
    {},
    {'accepted': false},
    {'accepted': 'true'},
    {'accepted': 1},
  ]) {
    test('malformed acknowledgement $raw cannot claim accepted', () async {
      final api = RecordingApiClient((_) => raw);
      final result = await VenueSuggestionRepositoryImpl(api).submit(
        requestId: _requestId,
        venueName: 'Mekan',
        cityId: 'c',
        districtId: 'd',
        liveMusic: VenueSuggestionLiveMusic.unknown,
      );
      expect(result.error?.code, 'venue_suggestion_unconfirmed');
    });
  }
  for (final invalid in [
    'short',
    'long',
    'blank city',
    'blank district',
    'request id',
  ]) {
    test('invalid $invalid never dispatches', () async {
      final api = RecordingApiClient((_) => {'accepted': true});
      final result = await VenueSuggestionRepositoryImpl(api).submit(
        requestId: invalid == 'request id' ? 'wrong' : _requestId,
        venueName: invalid == 'short'
            ? ' A '
            : invalid == 'long'
            ? 'a' * 101
            : 'Mekan',
        cityId: invalid == 'blank city' ? ' ' : 'c',
        districtId: invalid == 'blank district' ? ' ' : 'd',
        liveMusic: VenueSuggestionLiveMusic.yes,
      );
      expect(result.error?.code, 'venue_suggestion_invalid');
      expect(api.requests, isEmpty);
    });
  }
  for (final code in ['400', '409', '429', '503']) {
    test('API error $code is preserved for a safe retry', () async {
      final error = AppError(code: code, message: 'Tekrar deneyebilirsin.');
      final api = RecordingApiClient((_) => throw ApiException(error));
      final result = await VenueSuggestionRepositoryImpl(api).submit(
        requestId: _requestId,
        venueName: 'Mekan',
        cityId: 'c',
        districtId: 'd',
        liveMusic: VenueSuggestionLiveMusic.no,
      );
      expect(result.error, same(error));
    });
  }
  test(
    'unknown transport outcome is not marked as rejected or accepted',
    () async {
      final api = RecordingApiClient((_) => throw StateError('offline'));
      final result = await VenueSuggestionRepositoryImpl(api).submit(
        requestId: _requestId,
        venueName: 'Mekan',
        cityId: 'c',
        districtId: 'd',
        liveMusic: VenueSuggestionLiveMusic.no,
      );
      expect(result.error?.code, 'venue_suggestion_unconfirmed');
    },
  );
}
