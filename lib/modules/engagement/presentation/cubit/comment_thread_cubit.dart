import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/comment_item.dart';
import '../../domain/entities/comment_page.dart';
import '../../domain/engagement_repository.dart';
import 'comment_thread_state.dart';

class CommentThreadCubit extends Cubit<CommentThreadState> {
  final EngagementRepository _repository;
  int _loadGeneration = 0;
  int _targetGeneration = 0;
  String? _targetType;
  String? _targetId;

  CommentThreadCubit(this._repository)
    : super(const CommentThreadState.initial());

  Future<void> load({
    required String targetType,
    required String targetId,
    bool clearExisting = false,
  }) async {
    if (isClosed) return;
    final changed = _selectTarget(targetType, targetId);
    final targetGeneration = _targetGeneration;
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        loading: true,
        error: null,
        comments: changed || clearExisting ? const [] : null,
        submitting: changed ? false : null,
      ),
    );
    Result<CommentPage> result;
    try {
      result = await _repository.listComments(
        targetType: targetType,
        targetId: targetId,
        page: 0,
        size: 50,
      );
    } catch (_) {
      result = const Result.failure(
        AppError(
          code: 'engagement_comments_unknown',
          message: 'Yorumlar getirilemedi',
        ),
      );
    }
    if (!_isCurrentTarget(targetGeneration) || generation != _loadGeneration) {
      return;
    }
    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          loading: false,
          comments: result.data!.items,
          error: null,
        ),
      );
      return;
    }
    emit(state.copyWith(loading: false, error: result.error));
  }

  Future<void> create({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    if (isClosed || state.submitting) return;
    final changed = _selectTarget(targetType, targetId);
    final targetGeneration = _targetGeneration;
    // A pre-submission snapshot must not overwrite the result of this write.
    _loadGeneration++;
    emit(
      state.copyWith(
        submitting: true,
        loading: false,
        error: null,
        comments: changed ? const [] : null,
      ),
    );
    Result<CommentItem> result;
    try {
      result = await _repository.createComment(
        targetType: targetType,
        targetId: targetId,
        text: text,
        parentCommentId: parentCommentId,
      );
    } catch (_) {
      result = const Result.failure(
        AppError(
          code: 'engagement_comment_create_unknown',
          message: 'Yorum gönderilemedi',
        ),
      );
    }
    if (!_isCurrentTarget(targetGeneration)) return;
    if (result.isSuccess) {
      await load(targetType: targetType, targetId: targetId);
      if (!_isCurrentTarget(targetGeneration)) return;
      emit(state.copyWith(submitting: false, error: null));
      return;
    }
    emit(state.copyWith(submitting: false, error: result.error));
  }

  bool _selectTarget(String targetType, String targetId) {
    if (_targetType == targetType && _targetId == targetId) return false;
    _targetType = targetType;
    _targetId = targetId;
    _targetGeneration++;
    return true;
  }

  bool _isCurrentTarget(int generation) =>
      !isClosed && generation == _targetGeneration;
}
