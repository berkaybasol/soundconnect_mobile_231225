import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'support/recording_api_client.dart';

void main() {
  for (final target in ['EVENT', 'MEDIA', 'OVERTHINKING_POST']) {
    test(
      '$target list maps route without changing first-page decoder',
      () async {
        final api = RecordingApiClient((_) => _page());
        final result = await EngagementRepositoryImpl(
          api,
        ).listComments(targetType: target, targetId: 'one', page: 2, size: 50);
        expect(
          api.lastRequest.path,
          target == 'EVENT'
              ? '/api/v1/events/one/comments'
              : '/api/v1/comments/$target/one',
        );
        expect(api.lastRequest.query, {
          'page': 2,
          'size': 50,
          'sort': 'createdAt,desc',
        });
        expect(result.data!.items.single.id, 'comment');
        expect(result.data!.totalElements, 101);
      },
    );
  }
  for (final wrapped in [false, true]) {
    test(
      'event-scoped replies decode ${wrapped ? 'page' : 'list'} response',
      () async {
        final api = RecordingApiClient((_) => wrapped ? _page() : [_comment()]);
        final result = await EngagementRepositoryImpl(
          api,
        ).listReplies('root', eventId: 'event');
        expect(
          api.lastRequest.path,
          '/api/v1/events/event/comments/root/replies',
        );
        expect(result.data!.single.id, 'comment');
      },
    );
  }
  test('generic replies remain on authenticated legacy path', () async {
    final api = RecordingApiClient((_) => [_comment()]);
    final result = await EngagementRepositoryImpl(api).listReplies('root');
    expect(api.lastRequest.path, '/api/v1/comments/replies/root');
    expect(result.isSuccess, isTrue);
  });
  test('event context and parent ids cannot inject path segments', () async {
    final api = RecordingApiClient((_) => _page());
    final repo = EngagementRepositoryImpl(api);
    await repo.listComments(targetType: 'EVENT', targetId: 'event/one');
    expect(api.lastRequest.path, '/api/v1/events/event%2Fone/comments');
    await repo.listReplies('root/one', eventId: 'event/one');
    expect(
      api.lastRequest.path,
      '/api/v1/events/event%2Fone/comments/root%2Fone/replies',
    );
  });
  test('comment creates and deletes retain existing private routes', () async {
    final api = RecordingApiClient(
      (request) =>
          request.method == RecordedHttpMethod.post ? _comment() : null,
    );
    final repo = EngagementRepositoryImpl(api);
    await repo.createComment(
      targetType: 'EVENT',
      targetId: 'event',
      text: 'Merhaba',
      parentCommentId: 'root',
    );
    expect(api.lastRequest.path, '/api/v1/comments/EVENT/event');
    expect(api.lastRequest.body, {
      'text': 'Merhaba',
      'parentCommentId': 'root',
    });
    await repo.deleteComment(commentId: 'comment');
    expect(api.lastRequest.path, '/api/v1/comments/comment');
    expect(api.lastRequest.method, RecordedHttpMethod.delete);
  });
  for (final status in ['401', '403', '404']) {
    test('event list and replies preserve $status errors', () async {
      final error = AppError(code: status, message: 'Etkinlik bulunamadı.');
      final api = RecordingApiClient((_) => throw ApiException(error));
      final repo = EngagementRepositoryImpl(api);
      expect(
        (await repo.listComments(targetType: 'EVENT', targetId: 'event')).error,
        same(error),
      );
      expect(
        (await repo.listReplies('parent', eventId: 'event')).error,
        same(error),
      );
    });
  }
  test(
    'only event read routes are anonymous at the actual Dio boundary',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://soundconnect.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repo = EngagementRepositoryImpl(
        DioApiClient(dio: dio, tokenStore: _TokenStore()),
      );
      await repo.listComments(targetType: 'EVENT', targetId: 'event');
      await repo.listReplies('root', eventId: 'event');
      await repo.listComments(targetType: 'MEDIA', targetId: 'media');
      await repo.listReplies('root');
      await repo.createComment(
        targetType: 'EVENT',
        targetId: 'event',
        text: 'Merhaba',
      );
      expect(adapter.requests, hasLength(5));
      for (final request in adapter.requests.take(2)) {
        expect(request.headers.containsKey('Authorization'), isFalse);
      }
      for (final request in adapter.requests.skip(2)) {
        expect(request.headers['Authorization'], 'Bearer test-token');
      }
    },
  );
}

Map<String, Object?> _comment() => {
  'id': 'comment',
  'text': 'Merhaba',
  'user': {'id': 'user', 'username': 'User'},
  'replyCount': 0,
};
Map<String, Object?> _page() => {
  'content': [_comment()],
  'totalElements': 101,
};

class _TokenStore extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => 'test-token';
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'code': 200,
        'data': options.method == 'POST'
            ? _comment()
            : options.path.endsWith('/replies')
            ? [_comment()]
            : _page(),
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
