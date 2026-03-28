import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/engagement_repository.dart';
import 'comment_thread_state.dart';

class CommentThreadCubit extends Cubit<CommentThreadState> {
  final EngagementRepository _repository;

  CommentThreadCubit(this._repository)
    : super(const CommentThreadState.initial());

  Future<void> load({
    required String targetType,
    required String targetId,
  }) async {
    emit(state.copyWith(loading: true, error: null));
    final result = await _repository.listComments(
      targetType: targetType,
      targetId: targetId,
      page: 0,
      size: 50,
    );
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
    emit(state.copyWith(submitting: true, error: null));
    final result = await _repository.createComment(
      targetType: targetType,
      targetId: targetId,
      text: text,
      parentCommentId: parentCommentId,
    );
    if (result.isSuccess) {
      await load(targetType: targetType, targetId: targetId);
      emit(state.copyWith(submitting: false, error: null));
      return;
    }
    emit(state.copyWith(submitting: false, error: result.error));
  }
}
