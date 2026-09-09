import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/domain/entities/comment_item.dart';
import '../../../engagement/domain/entities/comment_like_state.dart';
import '../../../engagement/domain/entities/comment_page.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../../engagement/presentation/widgets/comment_thread_view.dart';

/// One publication owns one thread. The embedded event has its own comments.
class ListenerEventPostCommentsSheet extends StatefulWidget {
  const ListenerEventPostCommentsSheet({
    super.key,
    required this.postId,
    required this.repository,
    required this.sessions,
    required this.expectedSession,
    this.publicationAvailable,
  });

  static const targetType = 'EVENT_POST';
  final String postId;
  final EngagementRepository repository;
  final AuthSessionManager sessions;
  final AuthSession expectedSession;
  final ValueListenable<bool>? publicationAvailable;

  @override
  State<ListenerEventPostCommentsSheet> createState() =>
      _ListenerEventPostCommentsSheetState();
}

class _ListenerEventPostCommentsSheetState
    extends State<ListenerEventPostCommentsSheet> {
  late _PublicationCommentsRepository _repository;
  CommentThreadCubit? _thread;
  bool _unavailable = false;
  int _generation = 0;

  bool get _eligible =>
      mounted &&
      identical(widget.sessions.session, widget.expectedSession) &&
      widget.expectedSession.isAuthenticated &&
      widget.expectedSession.isActive &&
      widget.expectedSession.userId?.trim().isNotEmpty == true &&
      !widget.expectedSession.requiresListenerProfileChoice;

  @override
  void initState() {
    super.initState();
    widget.sessions.addListener(_sessionChanged);
    widget.publicationAvailable?.addListener(_publicationChanged);
    _bind();
  }

  void _bind() {
    _closeThread();
    final generation = ++_generation;
    _unavailable = widget.publicationAvailable?.value == false;
    _repository = _PublicationCommentsRepository(
      widget.repository,
      postId: widget.postId,
      current: () =>
          generation == _generation &&
          _eligible &&
          !_unavailable &&
          widget.publicationAvailable?.value != false,
      onUnavailable: _revoke,
    );
    if (_eligible && !_unavailable) {
      _thread = CommentThreadCubit(_repository, sessions: widget.sessions);
    }
  }

  @override
  void didUpdateWidget(covariant ListenerEventPostCommentsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sessions, widget.sessions)) {
      oldWidget.sessions.removeListener(_sessionChanged);
      widget.sessions.addListener(_sessionChanged);
    }
    if (!identical(
      oldWidget.publicationAvailable,
      widget.publicationAvailable,
    )) {
      oldWidget.publicationAvailable?.removeListener(_publicationChanged);
      widget.publicationAvailable?.addListener(_publicationChanged);
      _publicationChanged();
    }
    if (oldWidget.postId != widget.postId ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.sessions, widget.sessions) ||
        !identical(oldWidget.expectedSession, widget.expectedSession)) {
      _bind();
    }
  }

  void _closeThread() {
    final thread = _thread;
    _thread = null;
    if (thread != null) unawaited(thread.close());
  }

  void _revoke() {
    if (!_eligible || _unavailable) return;
    setState(() {
      _unavailable = true;
      _closeThread();
    });
  }

  void _sessionChanged() {
    if (!mounted || _eligible) return;
    setState(_closeThread);
  }

  void _publicationChanged() {
    if (widget.publicationAvailable?.value != false) return;
    // Feed rebinding can invalidate the route while its parent is building.
    // The guard blocks pending operations immediately; defer UI disposal only.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (generation == _generation &&
            widget.publicationAvailable?.value == false) {
          _revoke();
        }
      });
    } else {
      _revoke();
    }
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_sessionChanged);
    widget.publicationAvailable?.removeListener(_publicationChanged);
    _generation++;
    _closeThread();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_eligible) {
      return const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Oturum değişti. Paylaşımı yeniden açabilirsin.'),
        ),
      );
    }
    if (_unavailable || widget.publicationAvailable?.value == false) {
      return SafeArea(
        top: false,
        child: Padding(
          key: const Key('listener-event-post-comments-unavailable'),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bu paylaşım artık görüntülenemiyor.'),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ],
          ),
        ),
      );
    }
    return BlocProvider.value(
      value: _thread!,
      child: ColoredBox(
        color: const Color(0xFF101722),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final keyboard = MediaQuery.viewInsetsOf(context).bottom;
              final available = math.max(0.0, constraints.maxHeight - keyboard);
              return Padding(
                // This is the only keyboard inset. Both the thread and its
                // docked composer are sized within the remaining viewport.
                padding: EdgeInsets.only(bottom: keyboard),
                child: BlocBuilder<CommentThreadCubit, CommentThreadState>(
                  builder: (context, state) => SizedBox(
                    key: const Key('listener-event-post-comments-panel'),
                    height: math.min(
                      state.comments.isEmpty
                          ? 360
                          : MediaQuery.sizeOf(context).height * .72,
                      available,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            width: 32,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              const SizedBox(width: 48),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Yorumlar',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (state.totalElements > 0) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '${state.totalElements}',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Yorumları kapat',
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  maximumSize: const Size(48, 48),
                                  padding: const EdgeInsets.all(15),
                                  foregroundColor: AppColors.textMuted,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.border.withValues(alpha: .6),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: CommentThreadView(
                              // The view owns its repository and draft for its
                              // lifetime. Rebinding must replace that lifetime.
                              key: ObjectKey(_repository),
                              targetType:
                                  ListenerEventPostCommentsSheet.targetType,
                              targetId: widget.postId,
                              scrollable: true,
                              compactSheet: true,
                              repository: _repository,
                              sessions: widget.sessions,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A definitive publication-access rejection invalidates this entire mounted
/// thread, including reply and like operations managed outside its cubit.
/// Transport errors and missing/forbidden individual comments are recoverable.
class _PublicationCommentsRepository implements EngagementRepository {
  _PublicationCommentsRepository(
    this.delegate, {
    required this.postId,
    required this.current,
    required this.onUnavailable,
  });

  final EngagementRepository delegate;
  final String postId;
  final bool Function() current;
  final VoidCallback onUnavailable;
  bool _revoked = false;
  static const _unavailable = AppError(
    code: 'event_post_comments_unavailable',
    message: 'Bu paylaşım artık görüntülenemiyor.',
  );
  static const _wrongScope = AppError(
    code: 'event_post_comment_scope_invalid',
    message: 'Paylaşım yorumları doğrulanamadı.',
  );

  bool _scope(String type, String id) =>
      type == ListenerEventPostCommentsSheet.targetType && id == postId;

  Future<Result<T>> _guard<T>(Future<Result<T>> Function() action) async {
    if (_revoked || !current()) return const Result.failure(_unavailable);
    final result = await action();
    if (_revoked || !current()) return const Result.failure(_unavailable);
    // Dio preserves the API error code when supplied, otherwise HTTP status.
    // 9350/9353 concern one missing/non-owned comment, not the publication.
    if (!result.isSuccess &&
        const {'9700', '1102', '403', '404'}.contains(result.error?.code)) {
      _revoked = true;
      onUnavailable();
      return const Result.failure(_unavailable);
    }
    return result;
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) => !_scope(targetType, targetId)
      ? Future.value(const Result.failure(_wrongScope))
      : _guard(
          () => delegate.listComments(
            targetType: targetType,
            targetId: targetId,
            page: page,
            size: size,
          ),
        );

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) => !_scope(targetType, targetId)
      ? Future.value(const Result.failure(_wrongScope))
      : _guard(
          () => delegate.createComment(
            targetType: targetType,
            targetId: targetId,
            text: text,
            parentCommentId: parentCommentId,
          ),
        );

  @override
  Future<Result<CommentPage>> listReplyPage(
    String commentId, {
    String? eventId,
    int page = 0,
    int size = 20,
  }) => eventId != null
      ? Future.value(const Result.failure(_wrongScope))
      : _guard(() => delegate.listReplyPage(commentId, page: page, size: size));

  @override
  Future<Result<List<CommentItem>>> listReplies(
    String commentId, {
    String? eventId,
  }) => eventId != null
      ? Future.value(const Result.failure(_wrongScope))
      : _guard(() => delegate.listReplies(commentId));

  @override
  Future<Result<void>> deleteComment({required String commentId}) =>
      _guard(() => delegate.deleteComment(commentId: commentId));

  @override
  Future<Result<CommentLikeState>> setCommentLike({
    required String commentId,
    required bool liked,
  }) =>
      _guard(() => delegate.setCommentLike(commentId: commentId, liked: liked));

  @override
  Future<Result<CommentLikeState>> readCommentLike({
    required String commentId,
  }) => _guard(() => delegate.readCommentLike(commentId: commentId));

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) => !_scope(targetType, targetId)
      ? Future.value(const Result.failure(_wrongScope))
      : _guard(
          () =>
              delegate.getLikeCount(targetType: targetType, targetId: targetId),
        );

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) => !_scope(targetType, targetId)
      ? Future.value(const Result.failure(_wrongScope))
      : _guard(
          () => delegate.isLiked(targetType: targetType, targetId: targetId),
        );

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) => !_scope(targetType, targetId)
      ? Future.value(const Result.failure(_wrongScope))
      : _guard(() => delegate.like(targetType: targetType, targetId: targetId));

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) => !_scope(targetType, targetId)
      ? Future.value(const Result.failure(_wrongScope))
      : _guard(
          () => delegate.unlike(targetType: targetType, targetId: targetId),
        );
}
