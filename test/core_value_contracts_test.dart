import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/network/base_response.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/realtime_client_error.dart';
import 'package:soundconnect_23_12_25codx/core/realtime/realtime_event.dart';

void main() {
  group('BaseResponse', () {
    test('decodes typed data and converts numeric response codes', () {
      final BaseResponse<int> response = BaseResponse<int>.fromJson(
        <String, dynamic>{
          'success': true,
          'message': 'ok',
          'code': 200.9,
          'data': '42',
        },
        (Object? value) => int.parse(value! as String),
      );

      expect(response.success, isTrue);
      expect(response.message, 'ok');
      expect(response.code, 200);
      expect(response.data, 42);
    });

    test('passes a null data field through the supplied decoder', () {
      var decoderCalled = false;
      final BaseResponse<String> response = BaseResponse<String>.fromJson(
        <String, dynamic>{'success': true, 'data': null},
        (Object? value) {
          decoderCalled = true;
          expect(value, isNull);
          return 'fallback';
        },
      );

      expect(decoderCalled, isTrue);
      expect(response.data, 'fallback');
    });

    test('supports raw nullable data when no decoder is supplied', () {
      final BaseResponse<Map<String, dynamic>> response =
          BaseResponse<Map<String, dynamic>>.fromJson(<String, dynamic>{
            'success': null,
            'message': null,
            'code': null,
            'data': <String, dynamic>{'id': 'item-1'},
          }, null);

      expect(response.success, isNull);
      expect(response.code, isNull);
      expect(response.data, <String, dynamic>{'id': 'item-1'});
    });

    test(
      'fails loudly when the envelope violates its declared scalar types',
      () {
        expect(
          () => BaseResponse<Object?>.fromJson(<String, dynamic>{
            'success': 'yes',
            'data': null,
          }, null),
          throwsA(isA<TypeError>()),
        );
      },
    );
  });

  group('Result and error values', () {
    test('success can intentionally carry null without becoming a failure', () {
      const Result<void> result = Result<void>.success(null);

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
    });

    test('failure preserves code, message, and immutable default details', () {
      const AppError error = AppError(code: 'conflict', message: 'Conflict');
      const Result<int> result = Result<int>.failure(error);

      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
      expect(result.error, same(error));
      expect(error.details, isEmpty);
      expect(() => error.details.add('late detail'), throwsUnsupportedError);
    });

    test('ApiException renders a sanitized diagnostic summary', () {
      final ApiException exception = ApiException(
        const AppError(code: '401', message: 'Unauthorized'),
      );

      expect(exception.toString(), 'ApiException(401): Unauthorized');
    });
  });

  group('Page and realtime values', () {
    test('page exposes items and cursor boundary metadata', () {
      const Page<String> page = Page<String>(
        items: <String>['a', 'b'],
        hasNext: true,
        nextCursor: 'cursor-2',
      );

      expect(page.items, <String>['a', 'b']);
      expect(page.hasNext, isTrue);
      expect(page.nextCursor, 'cursor-2');
    });

    test('realtime event keeps its typed name and structured payload', () {
      const RealtimeEvent event = RealtimeEvent(
        type: 'badge.updated',
        payload: <String, dynamic>{'count': 3},
      );

      expect(event.type, 'badge.updated');
      expect(event.payload['count'], 3);
    });

    test('realtime errors expose only type and safe message', () {
      const RealtimeClientError error = RealtimeClientError(
        type: RealtimeClientErrorType.invalidPayload,
        message: 'Invalid realtime payload',
      );

      expect(error.type, RealtimeClientErrorType.invalidPayload);
      expect(
        error.toString(),
        'RealtimeClientError(invalidPayload): Invalid realtime payload',
      );
    });
  });

  group('public API request classification boundaries', () {
    test(
      'normalizes method case, whitespace, absolute urls, and query strings',
      () {
        expect(
          isPublicApiRequest(
            ' post ',
            'https://api.example.com/api/v1/auth/login?source=mobile',
          ),
          isTrue,
        );
        expect(
          isPublicApiRequest(' get ', '/api/v1/events/upcoming?page=0'),
          isTrue,
        );
      },
    );

    test('does not confuse sibling prefixes with public descendants', () {
      expect(isPublicApiRequest('GET', '/api/v1/cities-archive'), isFalse);
      expect(isPublicApiRequest('GET', '/api/v1/districts-private'), isFalse);
      expect(isPublicApiRequest('GET', '/api/v1/neighborhoods2'), isFalse);
      expect(isPublicApiRequest('GET', '/api/v1/venue/item-1'), isFalse);
    });

    test('requires the exact public profile-media route shape', () {
      expect(
        isPublicApiRequest('GET', '/api/v1/profiles/MUSICIAN/id-1/media'),
        isTrue,
      );
      expect(
        isPublicApiRequest('GET', '/api/v1/profiles/MUSICIAN/media'),
        isFalse,
      );
      expect(
        isPublicApiRequest(
          'GET',
          '/api/v1/profiles/MUSICIAN/id-1/media/private',
        ),
        isFalse,
      );
    });

    test('authenticates mutable listener identity projections', () {
      expect(
        isPublicApiRequest(
          'GET',
          '/api/v1/public/listener-profiles/listener-1?view=compact',
        ),
        isFalse,
      );
      expect(
        isPublicApiRequest('GET', '/api/v1/public/profiles/by-user/user-1'),
        isFalse,
      );
      expect(
        isPublicApiRequest('GET', '/api/v1/public/musician-profiles/id-1'),
        isTrue,
      );
    });

    test('never treats write methods to discovery routes as public', () {
      expect(isPublicApiRequest('POST', '/api/v1/events'), isFalse);
      expect(isPublicApiRequest('PUT', '/api/v1/venues/item-1'), isFalse);
      expect(isPublicApiRequest('DELETE', '/api/v1/cities/item-1'), isFalse);
      expect(isPublicApiRequest('PATCH', '/api/v1/public/item-1'), isFalse);
    });
  });
}
