import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _quotaMessage =
    'Bu içerikte art arda birkaç yorum gönderdin. 12 saniye bekleyip tekrar deneyebilirsin.';
const _quotaFallback =
    'Bu içerikte art arda birkaç yorum gönderdin. Biraz bekleyip tekrar deneyebilirsin.';
const _unavailableMessage =
    'Yorum şu anda gönderilemiyor. Biraz sonra tekrar deneyebilirsin.';

void main() {
  for (final target in ['EVENT', 'MEDIA', 'OVERTHINKING_POST']) {
    for (final parent in <String?>[null, 'root']) {
      for (final code in [9356, 9357]) {
        test(
          '$target ${parent == null ? 'root' : 'reply'} guard $code '
          'preserves failure and Retry-After without retrying POST',
          () async {
            final adapter = _GuardAdapter(code: code);
            final dio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
              ..httpClientAdapter = adapter;
            final cubit = CommentThreadCubit(
              EngagementRepositoryImpl(
                DioApiClient(dio: dio, tokenStore: _TokenStore()),
              ),
            );
            addTearDown(() async {
              await cubit.close();
              dio.close(force: true);
            });

            Future<bool> submit() => cubit.create(
              targetType: target,
              targetId: 'target',
              text: 'Taslağım',
              parentCommentId: parent,
            );

            // The adapter permits the next POST. An automatic retry would
            // incorrectly turn this definite rejection into a successful write.
            expect(await submit(), isFalse);
            expect(cubit.state.error!.code, '$code');
            expect(
              cubit.state.error!.message,
              code == 9356 ? _quotaMessage : _unavailableMessage,
            );
            expect(
              cubit.state.error!.retryAfter,
              Duration(seconds: code == 9356 ? 12 : 5),
            );
            expect(cubit.state.submitting, isFalse);
            expect(cubit.state.lastCreated, isNull);
            expect(cubit.state.reloadError, isNull);
            expect(adapter.requests, hasLength(1));
            expect(adapter.requests.single.method, 'POST');
            expect(
              adapter.requests.single.path,
              '/api/v1/comments/$target/target',
            );
            expect(adapter.requests.single.data, {
              'text': 'Taslağım',
              'parentCommentId': parent,
            });

            // No client cooldown is invented. Only an explicit new submission
            // asks the server again, and only confirmed success clears error.
            expect(await submit(), isTrue);
            expect(cubit.state.error, isNull);
            expect(cubit.state.lastCreated!.text, 'Taslağım');
            expect(adapter.requests.map((request) => request.method), [
              'POST',
              'POST',
              'GET',
            ]);
          },
        );
      }
    }
  }

  for (final hint in <Duration?>[
    null,
    Duration.zero,
    const Duration(seconds: -1),
    const Duration(microseconds: 1),
    const Duration(milliseconds: 12001),
  ]) {
    test('quota Retry-After $hint uses a safe rounded wait hint', () async {
      final api = RecordingApiClient(
        (_) => throw ApiException(
          AppError(
            code: '9356',
            message: 'Request failed',
            details: const ['guard rejected before write'],
            retryAfter: hint,
          ),
        ),
      );
      final result = await EngagementRepositoryImpl(api).createComment(
        targetType: 'EVENT',
        targetId: 'target',
        text: 'Taslağım',
      );
      final seconds = hint == null
          ? 0
          : (hint.inMicroseconds / Duration.microsecondsPerSecond).ceil();
      expect(
        result.error!.message,
        seconds <= 0
            ? _quotaFallback
            : 'Bu içerikte art arda birkaç yorum gönderdin. '
                  '$seconds saniye bekleyip tekrar deneyebilirsin.',
      );
      expect(result.error!.retryAfter, hint);
      expect(result.error!.details, ['guard rejected before write']);
      expect(api.requests, hasLength(1));
    });
  }

  for (final parent in <String?>[null, 'root']) {
    test('HTTP 500 internal code 9999 ${parent == null ? 'root' : 'reply'} '
        'remains ambiguous and never retries POST', () async {
      final adapter = _GuardAdapter(code: 9999);
      final dio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
        ..httpClientAdapter = adapter;
      final cubit = CommentThreadCubit(
        EngagementRepositoryImpl(
          DioApiClient(dio: dio, tokenStore: _TokenStore()),
        ),
      );
      addTearDown(() async {
        await cubit.close();
        dio.close(force: true);
      });

      expect(
        await cubit.create(
          targetType: 'EVENT',
          targetId: 'target',
          text: 'Taslağım',
          parentCommentId: parent,
        ),
        isFalse,
      );
      expect(cubit.state.error!.code, '9999');
      expect(
        cubit.state.error!.message,
        'Sonuç doğrulanamadı. Tekrar göndermeden yorumları kontrol et.',
      );
      expect(cubit.state.lastCreated, isNull);
      expect(cubit.state.submitting, isFalse);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, {
        'text': 'Taslağım',
        'parentCommentId': parent,
      });
    });
  }

  for (final code in ['9356', '9357']) {
    test('late guard $code cannot leak feedback to another session', () async {
      final pending = Completer<Object?>();
      final sessions = AudienceTestSessions(audienceSession());
      final api = RecordingApiClient((_) => pending.future);
      final repository = EngagementRepositoryImpl(api, sessions: sessions);
      final write = repository.createComment(
        targetType: 'EVENT',
        targetId: 'target',
        text: 'Taslağım',
      );
      sessions.replace(audienceSession(user: 'other', token: 'other'));
      pending.completeError(
        ApiException(AppError(code: code, message: 'Request failed')),
      );
      expect((await write).error!.code, 'engagement_comment_session_changed');
      expect(api.requests, hasLength(1));
    });
  }

  test('unspecified HTTP 429 remains a definite server rejection', () async {
    const error = AppError(
      code: '429',
      message: 'İstek sınırına ulaşıldı. Biraz bekle.',
      retryAfter: Duration(seconds: 9),
    );
    final api = RecordingApiClient((_) => throw ApiException(error));
    final result = await EngagementRepositoryImpl(
      api,
    ).createComment(targetType: 'EVENT', targetId: 'target', text: 'Taslağım');
    expect(result.error, same(error));
    expect(api.requests, hasLength(1));
  });
}

class _TokenStore extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => 'test-token';
}

class _GuardAdapter implements HttpClientAdapter {
  _GuardAdapter({required this.code});

  final int code;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length == 1) {
      return ResponseBody.fromString(
        jsonEncode({
          'success': false,
          'code': code,
          'message': 'Request failed',
        }),
        code == 9356
            ? 429
            : code == 9357
            ? 503
            : 500,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          if (code == 9356 || code == 9357)
            'retry-after': [code == 9356 ? '12' : '5'],
        },
      );
    }
    final comment = {
      'id': 'created',
      'text': 'Taslağım',
      'user': {'id': 'user', 'username': 'Ada'},
      if (options.method == 'POST')
        'parentCommentId': (options.data as Map)['parentCommentId'],
    };
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'code': 200,
        'data': options.method == 'POST'
            ? comment
            : {'content': [], 'totalElements': 0, 'number': 0, 'size': 50},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
