import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/comment_item.dart';
import '../../domain/entities/comment_page.dart';
import '../../domain/entities/comment_text.dart';
import '../../domain/engagement_repository.dart';
import 'comment_thread_state.dart';

class CommentThreadCubit extends Cubit<CommentThreadState> {
  CommentThreadCubit(this._repository, {AuthSessionManager? sessions})
    : _sessions = sessions,
      super(const CommentThreadState.initial()) {
    _session = sessions?.session;
    sessions?.addListener(_sessionChanged);
  }

  final EngagementRepository _repository;
  final AuthSessionManager? _sessions;
  AuthSession? _session;
  int _loadGeneration = 0;
  int _targetGeneration = 0;
  int _page = 0;
  String? _targetType;
  String? _targetId;
  static const _pageSize = 50;
  static const _loadError = AppError(
    code: 'engagement_comments_unknown',
    message: 'Yorumlar getirilemedi. Yeniden dene.',
  );

  bool get _canWrite =>
      _sessions == null ||
      (_sessions.session.isAuthenticated &&
          _sessions.session.isActive &&
          _sessions.session.userId?.trim().isNotEmpty == true &&
          !_sessions.session.requiresListenerProfileChoice);

  bool _canRead(String type) => type == 'EVENT' || _canWrite;

  void _sessionChanged() {
    if (isClosed || identical(_session, _sessions?.session)) return;
    _session = _sessions?.session;
    _targetGeneration++;
    _loadGeneration++;
    _page = 0;
    emit(const CommentThreadState.initial());
    final type = _targetType;
    final id = _targetId;
    if (type != null && id != null && _canRead(type)) {
      unawaited(load(targetType: type, targetId: id, clearExisting: true));
    }
  }

  Future<void> load({
    required String targetType,
    required String targetId,
    bool clearExisting = false,
  }) async {
    if (isClosed) return;
    final changed = _selectTarget(targetType, targetId);
    if (clearExisting && !changed) _targetGeneration++;
    final targetGeneration = _targetGeneration;
    final generation = ++_loadGeneration;
    final session = _sessions?.session;
    _page = 0;
    emit(
      state.copyWith(
        loading: _canRead(targetType),
        loadingMore: false,
        error: null,
        reloadError: null,
        comments: changed || clearExisting ? const [] : null,
        totalElements: changed || clearExisting ? 0 : null,
        hasMore: false,
        submitting: changed || clearExisting ? false : null,
        deletingCommentId: changed || clearExisting
            ? null
            : state.deletingCommentId,
        lastCreated: changed || clearExisting ? null : state.lastCreated,
      ),
    );
    if (!_canRead(targetType)) return;
    final result = await _readPage(targetType, targetId, 0);
    if (!_current(targetGeneration, session) || generation != _loadGeneration) {
      return;
    }
    final data = result.data;
    if (result.isSuccess && data != null) {
      emit(
        state.copyWith(
          loading: false,
          comments: List.unmodifiable(data.items),
          totalElements: data.totalElements,
          hasMore: _pageSize < data.totalElements,
          error: null,
        ),
      );
    } else {
      emit(state.copyWith(loading: false, error: result.error ?? _loadError));
    }
  }

  Future<void> loadMore() async {
    final type = _targetType;
    final id = _targetId;
    if (isClosed ||
        type == null ||
        id == null ||
        !_canRead(type) ||
        state.loading ||
        state.loadingMore ||
        state.submitting ||
        state.deletingCommentId != null ||
        !state.hasMore ||
        _page >= 1000) {
      return;
    }
    final targetGeneration = _targetGeneration;
    final generation = ++_loadGeneration;
    final session = _sessions?.session;
    final next = _page + 1;
    emit(state.copyWith(loadingMore: true, error: null));
    final result = await _readPage(type, id, next);
    if (!_current(targetGeneration, session) || generation != _loadGeneration) {
      return;
    }
    final data = result.data;
    if (result.isSuccess && data != null) {
      _page = next;
      final items = {for (final item in state.comments) item.id: item};
      for (final item in data.items) {
        // Offset pages can overlap after new roots are inserted. Keep their
        // original position, but honor a newer deletion or author projection.
        items[item.id] = item;
      }
      emit(
        state.copyWith(
          loadingMore: false,
          comments: List.unmodifiable(items.values),
          totalElements: data.totalElements,
          hasMore: next < 1000 && (next + 1) * _pageSize < data.totalElements,
        ),
      );
    } else {
      emit(
        state.copyWith(loadingMore: false, error: result.error ?? _loadError),
      );
    }
  }

  Future<Result<CommentPage>> _readPage(
    String type,
    String id,
    int page,
  ) async {
    try {
      return await _repository.listComments(
        targetType: type,
        targetId: id,
        page: page,
        size: _pageSize,
      );
    } catch (_) {
      return const Result.failure(_loadError);
    }
  }

  Future<bool> create({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    if (isClosed ||
        state.submitting ||
        state.deletingCommentId != null ||
        !_canWrite ||
        (_targetType != null &&
            (_targetType != targetType || _targetId != targetId))) {
      return false;
    }
    final normalized = text.trim();
    if (!CommentText.isValid(normalized)) {
      emit(
        state.copyWith(
          error: const AppError(
            code: 'engagement_comment_invalid',
            message: 'Yorum 1–500 karakter olmalı.',
          ),
        ),
      );
      return false;
    }
    final changed = _selectTarget(targetType, targetId);
    final targetGeneration = _targetGeneration;
    final session = _sessions?.session;
    // A pre-submission snapshot must not overwrite the result of this write.
    _loadGeneration++;
    emit(
      state.copyWith(
        submitting: true,
        loading: false,
        loadingMore: false,
        error: null,
        reloadError: null,
        lastCreated: null,
        comments: changed ? const [] : null,
      ),
    );
    Result<CommentItem> result;
    try {
      result = await _repository.createComment(
        targetType: targetType,
        targetId: targetId,
        text: normalized,
        parentCommentId: parentCommentId,
      );
    } catch (_) {
      result = const Result.failure(
        AppError(
          code: 'engagement_comment_create_unknown',
          message:
              'Yorum gönderilemedi. Gönderilmiş olabilir. Yeniden göndermeden önce yorumları kontrol et.',
        ),
      );
    }
    if (!_current(targetGeneration, session)) return false;
    if (!result.isSuccess ||
        result.data == null ||
        result.data!.id.trim().isEmpty) {
      emit(
        state.copyWith(
          submitting: false,
          error:
              result.error ??
              const AppError(
                code: 'engagement_comment_create_unknown',
                message:
                    'Yorumun kaydedildiği doğrulanamadı. Yeniden göndermeden önce yorumları kontrol et.',
              ),
        ),
      );
      return false;
    }
    final created = result.data!;
    emit(state.copyWith(lastCreated: created));
    await load(targetType: targetType, targetId: targetId);
    if (!_current(targetGeneration, session)) return false;
    emit(
      state.copyWith(submitting: false, reloadError: state.error, error: null),
    );
    return true;
  }

  Future<bool> delete({required String commentId}) async {
    final type = _targetType;
    final id = _targetId;
    if (isClosed ||
        type == null ||
        id == null ||
        !_canWrite ||
        state.submitting ||
        state.deletingCommentId != null ||
        commentId.trim().isEmpty) {
      return false;
    }
    final generation = _targetGeneration;
    final session = _sessions?.session;
    _loadGeneration++;
    emit(
      state.copyWith(
        deletingCommentId: commentId,
        loading: false,
        loadingMore: false,
        error: null,
        reloadError: null,
      ),
    );
    Result<void> result;
    try {
      result = await _repository.deleteComment(commentId: commentId);
    } catch (_) {
      result = const Result.failure(
        AppError(
          code: 'engagement_comment_delete_unknown',
          message: 'Yorum silinemedi. Yeniden dene.',
        ),
      );
    }
    if (!_current(generation, session)) return false;
    if (!result.isSuccess) {
      emit(state.copyWith(deletingCommentId: null, error: result.error));
      return false;
    }
    // The delete is confirmed even if the following read fails. Never retain
    // the deleted text while offering a safe list refresh.
    emit(
      state.copyWith(
        comments: List.unmodifiable([
          for (final comment in state.comments)
            if (comment.id == commentId)
              CommentItem(
                id: comment.id,
                user: comment.user,
                anonymousAuthor: comment.anonymousAuthor,
                text: '',
                deleted: true,
                parentCommentId: comment.parentCommentId,
                replyCount: comment.replyCount,
                createdAt: comment.createdAt,
              )
            else
              comment,
        ]),
      ),
    );
    await load(targetType: type, targetId: id);
    if (!_current(generation, session)) return false;
    emit(
      state.copyWith(
        deletingCommentId: null,
        reloadError: state.error,
        error: null,
      ),
    );
    return true;
  }

  bool _selectTarget(String type, String id) {
    if (_targetType == type && _targetId == id) return false;
    _targetType = type;
    _targetId = id;
    _targetGeneration++;
    return true;
  }

  bool _current(int generation, AuthSession? session) =>
      !isClosed &&
      generation == _targetGeneration &&
      (_sessions == null || identical(_sessions.session, session));

  @override
  Future<void> close() {
    _sessions?.removeListener(_sessionChanged);
    _targetGeneration++;
    _loadGeneration++;
    return super.close();
  }
}
