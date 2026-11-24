import 'dart:async';

import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/page.dart';

class UserBlockStatus {
  const UserBlockStatus({
    required this.blockedByMe,
    required this.interactionBlocked,
  });
  final bool blockedByMe;
  final bool interactionBlocked;

  factory UserBlockStatus.fromJson(Object? json) {
    if (json case {
      'blockedByMe': bool mine,
      'interactionBlocked': bool either,
    } when !mine || either) {
      return UserBlockStatus(blockedByMe: mine, interactionBlocked: either);
    }
    throw const FormatException('Invalid block status');
  }
}

class UserBlockChange {
  const UserBlockChange({
    required this.actorId,
    required this.userId,
    required this.status,
  });
  final String actorId;
  final String userId;
  final UserBlockStatus status;
}

class BlockedAccount {
  const BlockedAccount(this.id, this.username);
  final String id;
  final String username;
}

class UserBlockRepository {
  UserBlockRepository(this._api, this._sessions);
  final ApiClient _api;
  final AuthSessionManager _sessions;
  static const _path = '/api/v1/users/me/blocks';
  static const _sessionError = AppError(
    code: 'block_session',
    message: 'Bu işlem için yeniden giriş yap.',
  );
  static const _requestError = AppError(
    code: 'block_request',
    message: 'İşlem tamamlanamadı. Lütfen tekrar dene.',
  );

  final _changes = StreamController<UserBlockChange>.broadcast(sync: true);
  Stream<UserBlockChange> get changes => _changes.stream;
  Future<void> dispose() => _changes.close();

  Future<Result<UserBlockStatus>> status(String userId) =>
      _target(ApiHttpMethod.get, userId);
  Future<Result<UserBlockStatus>> block(String userId) =>
      _target(ApiHttpMethod.put, userId);
  Future<Result<UserBlockStatus>> unblock(String userId) =>
      _target(ApiHttpMethod.delete, userId);

  Future<Result<UserBlockStatus>> _target(
    ApiHttpMethod method,
    String userId,
  ) async {
    final actor = _sessions.session;
    final revision = _sessions.credentialRevision;
    if (userId.trim().isEmpty || actor.userId == userId) {
      return const Result.failure(
        AppError(
          code: 'block_target',
          message: 'Bu hesap için işlem yapılamıyor.',
        ),
      );
    }
    final result = await _request(
      method,
      '$_path/${Uri.encodeComponent(userId)}',
      (json) {
        final status = UserBlockStatus.fromJson(json);
        if (method != ApiHttpMethod.get &&
            status.blockedByMe != (method == ApiHttpMethod.put)) {
          throw const FormatException('Unexpected block decision');
        }
        return status;
      },
    );
    if (!identical(_sessions.session, actor) ||
        revision != _sessions.credentialRevision) {
      return const Result.failure(_sessionError);
    }
    if (result.isSuccess && method != ApiHttpMethod.get) {
      _changes.add(
        UserBlockChange(
          actorId: actor.userId!,
          userId: userId,
          status: result.data!,
        ),
      );
    }
    return result;
  }

  Future<Result<Page<BlockedAccount>>> list({int page = 0}) {
    const size = 20;
    return _request(ApiHttpMethod.get, _path, (json) {
      if (json case {
        'content': List items,
        'number': int number,
        'size': size,
        'hasNext': bool hasNext,
      } when number == page && items.length <= size) {
        final accounts = items
            .map((item) {
              if (item case {
                'id': String id,
                'username': String username,
              } when id.isNotEmpty && username.trim().isNotEmpty) {
                return BlockedAccount(id, username);
              }
              throw const FormatException('Invalid blocked account');
            })
            .toList(growable: false);
        return Page(items: accounts, hasNext: hasNext);
      }
      throw const FormatException('Invalid blocked accounts page');
    }, query: {'page': page, 'size': size});
  }

  Future<Result<T>> _request<T>(
    ApiHttpMethod method,
    String path,
    T Function(Object?) decode, {
    Map<String, dynamic>? query,
  }) async {
    final session = _sessions.session;
    final revision = _sessions.credentialRevision;
    if (!session.isActive ||
        !session.isAuthenticated ||
        session.userId?.isNotEmpty != true) {
      return const Result.failure(_sessionError);
    }
    bool current() =>
        identical(session, _sessions.session) &&
        revision == _sessions.credentialRevision;
    try {
      final result = await _api.request(
        method,
        path,
        query: query,
        decoder: decode,
        requestContext: ApiRequestContext(
          expectedSessionKey: session.userId,
          expectedToken: session.token,
          expectedCredentialRevision: revision,
        ),
      );
      return current()
          ? Result.success(result)
          : const Result.failure(_sessionError);
    } on ApiException catch (error) {
      return Result.failure(current() ? error.error : _sessionError);
    } catch (_) {
      return Result.failure(current() ? _requestError : _sessionError);
    }
  }
}
