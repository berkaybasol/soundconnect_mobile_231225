import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/engagement_repository.dart';
import '../../domain/comment_age.dart';
import '../../domain/entities/comment_item.dart';
import '../cubit/comment_thread_cubit.dart';
import '../cubit/comment_thread_state.dart';
import 'comment_author_identity.dart';
import 'comment_entry.dart';
import 'comment_like_button.dart';
import 'comment_like_memory.dart';

/// Non-event threads share one author/privacy, paging and input implementation.
/// The owning surface supplies a route-scoped CommentThreadCubit.
class CommentThreadView extends StatefulWidget {
  const CommentThreadView({
    super.key,
    required this.targetType,
    required this.targetId,
    this.scrollable = false,
    this.autoLoad = true,
    this.sessions,
    this.repository,
    this.onCommentCreated,
    this.onCommentDeleted,
    this.compactSheet = false,
  });
  final String targetType;
  final String targetId;
  final bool scrollable;
  final bool autoLoad;
  final AuthSessionManager? sessions;
  final EngagementRepository? repository;
  final VoidCallback? onCommentCreated;
  final VoidCallback? onCommentDeleted;

  /// A compact, docked composer and centered empty state for small sheets.
  /// Inline threads retain their existing presentation by default.
  final bool compactSheet;

  @override
  State<CommentThreadView> createState() => _CommentThreadViewState();
}

class _ReplyPage {
  CommentItem? root;
  List<CommentItem> items = [];
  int? totalElements;
  int nextPage = 0;
  bool loading = false;
  bool expanded = false;
  bool hasMore = true;
  String? error;
  int generation = 0;
}

class _CommentThreadViewState extends State<CommentThreadView>
    with AutomaticKeepAliveClientMixin {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final Map<String, _ReplyPage> _replies = {};
  final _likeMemory = CommentLikeMemory();
  late final AuthSessionManager? _sessions;
  late final EngagementRepository _repository;
  AuthSession? _session;
  String? _replyRootId;
  String? _replyName;
  String? _localError;
  DialogRoute<bool>? _deleteDialog;
  bool _confirming = false;

  bool get _allowed =>
      mounted &&
      identical(_sessions?.session, _session) &&
      _session?.isAuthenticated == true &&
      _session?.isActive == true &&
      _session?.requiresListenerProfileChoice != true &&
      (_session?.userId?.trim().isNotEmpty ?? false);
  bool get _current => _allowed && (ModalRoute.of(context)?.isCurrent ?? false);
  bool _same(AuthSession? session) =>
      _allowed && identical(_sessions?.session, session);
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sessions =
        widget.sessions ??
        (serviceLocator.isRegistered<AuthSessionManager>()
            ? serviceLocator<AuthSessionManager>()
            : null);
    _repository = widget.repository ?? serviceLocator<EngagementRepository>();
    _session = _sessions?.session;
    _sessions?.addListener(_sessionChanged);
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_allowed) _reload();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CommentThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId ||
        oldWidget.targetType != widget.targetType) {
      _clearPrivateState();
      if (widget.autoLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_allowed) _reload();
        });
      }
    }
  }

  void _clearPrivateState() {
    _likeMemory.clear();
    _input.clear();
    _focus.unfocus();
    _replyRootId = null;
    _replyName = null;
    _localError = null;
    _replies.clear();
    _dismissDeleteDialog();
  }

  void _sessionChanged() {
    if (!mounted || identical(_session, _sessions?.session)) return;
    setState(() {
      _session = _sessions?.session;
      _clearPrivateState();
    });
  }

  void _dismissDeleteDialog() {
    final dialog = _deleteDialog;
    _deleteDialog = null;
    if (dialog == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _likeMemory.clear();
    _sessions?.removeListener(_sessionChanged);
    _dismissDeleteDialog();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!_allowed) return;
    final session = _session;
    await context.read<CommentThreadCubit>().load(
      targetType: widget.targetType,
      targetId: widget.targetId,
    );
    if (!_same(session)) return;
    setState(() {
      _replies.clear();
      _localError = null;
    });
  }

  Future<void> _loadReplies(CommentItem root, {bool refresh = false}) async {
    if (!_current || !_visibleItem(root, root)) return;
    final state = _replies[root.id];
    if (state == null || !state.expanded || state.loading) return;
    if (!refresh && !state.hasMore) return;
    if (!refresh && state.nextPage > 1000) return;
    final session = _session;
    final targetId = widget.targetId;
    final generation = ++state.generation;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    try {
      final page = await _repository.listReplyPage(
        root.id,
        page: refresh ? 0 : state.nextPage,
        size: 20,
      );
      if (!_same(session) ||
          widget.targetId != targetId ||
          !identical(_replies[root.id], state) ||
          state.generation != generation) {
        return;
      }
      if (!_visibleItem(root, root)) {
        setState(() => _replies.remove(root.id));
        return;
      }
      setState(() {
        state.loading = false;
        if (!page.isSuccess || page.data == null) {
          state.error = 'Yanıtlar yüklenemedi. Yeniden dene.';
          return;
        }
        final next = page.data!;
        final rows = <String, CommentItem>{
          if (!refresh)
            for (final item in state.items) item.id: item,
        };
        for (final item in next.items) {
          rows[item.id] = item;
        }
        state.items = rows.values.toList(growable: false);
        state.totalElements = next.totalElements;
        state.nextPage = next.page + 1;
        state.hasMore = next.hasMore;
      });
    } catch (_) {
      if (_same(session) &&
          widget.targetId == targetId &&
          identical(_replies[root.id], state) &&
          state.generation == generation &&
          _visibleItem(root, root)) {
        setState(() {
          state.loading = false;
          state.error = 'Yanıtlar yüklenemedi. Yeniden dene.';
        });
      }
    }
  }

  void _toggleReplies(CommentItem root) {
    if (!_current || !_visibleItem(root, root)) return;
    final page = _replies.putIfAbsent(root.id, () => _ReplyPage()..root = root);
    setState(() => page.expanded = !page.expanded);
    if (page.expanded && page.nextPage == 0 && !page.loading) {
      _loadReplies(root);
    }
  }

  bool _visibleItem(CommentItem item, CommentItem root) {
    final roots = context.read<CommentThreadCubit>().state.comments;
    if (!roots.any((value) => identical(value, root))) return false;
    return identical(item, root) ||
        (_replies[root.id]?.items.any((value) => identical(value, item)) ??
            false);
  }

  void _reply(CommentItem root, CommentItem author) {
    if (!_current ||
        !_visibleItem(author, root) ||
        root.deleted ||
        author.deleted ||
        context.read<CommentThreadCubit>().state.submitting) {
      return;
    }
    setState(() {
      _replyRootId = root.id;
      _replyName = commentAuthorLabel(author);
    });
    _focus.requestFocus();
  }

  Future<void> _send() async {
    if (!_current || _confirming) return;
    final text = _input.text.trim();
    if (text.isEmpty || text.length > 500) return;
    final cubit = context.read<CommentThreadCubit>();
    if (cubit.state.submitting || cubit.state.deletingCommentId != null) return;
    final session = _session;
    final targetId = widget.targetId;
    final rootId = _replyRootId;
    final replyView = _replies[rootId];
    final success = await cubit.create(
      targetType: widget.targetType,
      targetId: targetId,
      text: text,
      parentCommentId: rootId,
    );
    if (!_same(session) || targetId != widget.targetId || !success) return;
    setState(() {
      _input.clear();
      _replyName = null;
      _replyRootId = null;
      _localError = null;
    });
    widget.onCommentCreated?.call();
    if (rootId != null && _current) {
      final roots = cubit.state.comments.where((item) => item.id == rootId);
      if (roots.isNotEmpty) {
        final current = _replies[rootId] ?? replyView;
        final root = roots.first;
        final expanded = current?.expanded == true;
        final knownBefore =
            current?.totalElements ??
            current?.root?.replyCount ??
            root.replyCount;
        final total = cubit.state.reloadError == null
            ? root.replyCount
            : knownBefore + 1;
        setState(() {
          _replies[rootId] = _ReplyPage()
            ..root = root
            ..totalElements = total
            ..expanded = expanded;
        });
        if (expanded) await _loadReplies(root, refresh: true);
      }
    }
  }

  Future<void> _delete(CommentItem item, CommentItem root) async {
    if (!_current ||
        _confirming ||
        !_visibleItem(item, root) ||
        item.deleted ||
        item.user.id != _session?.userId) {
      return;
    }
    final cubit = context.read<CommentThreadCubit>();
    if (cubit.state.submitting || cubit.state.deletingCommentId != null) return;
    final session = _session;
    final ownerRoute = ModalRoute.of(context);
    final targetId = widget.targetId;
    var responded = false;
    late final DialogRoute<bool> dialog;
    dialog = DialogRoute<bool>(
      context: context,
      builder: (dialogContext) {
        void respond(bool value) {
          if (responded ||
              !_same(session) ||
              !dialogContext.mounted ||
              !dialog.isCurrent) {
            return;
          }
          responded = true;
          Navigator.of(dialogContext).pop(value);
        }

        return AlertDialog(
          title: const Text('Yorumu silmek istiyor musun?'),
          actions: [
            TextButton(
              onPressed: () => respond(false),
              child: const Text('Vazgeç'),
            ),
            GradientOutlineButton(label: 'Sil', onPressed: () => respond(true)),
          ],
        );
      },
    );
    _confirming = true;
    _deleteDialog = dialog;
    try {
      final confirmed = await Navigator.of(context).push(dialog);
      await dialog.completed;
      if (!_same(session) ||
          ownerRoute?.isCurrent != true ||
          targetId != widget.targetId ||
          !_visibleItem(item, root) ||
          confirmed != true) {
        return;
      }
      final deleted = await cubit.delete(commentId: item.id);
      if (!_same(session) || targetId != widget.targetId || !deleted) return;
      setState(() {
        _replies.remove(root.id);
        if (_replyRootId == root.id) {
          _replyRootId = null;
          _replyName = null;
        }
      });
      widget.onCommentDeleted?.call();
    } finally {
      if (identical(_deleteDialog, dialog)) _deleteDialog = null;
      _confirming = false;
    }
  }

  Widget _row(
    CommentItem item,
    CommentItem root,
    CommentThreadState state, {
    Widget? threadFooter,
  }) {
    void open() => openCommentAuthorProfile(
      context,
      item,
      sessions: _sessions,
      isCurrent: () => _current && _visibleItem(item, root),
    );
    final deleting = state.deletingCommentId == item.id;
    final own =
        !item.anonymousAuthor &&
        !item.deleted &&
        item.user.id == _session?.userId;
    return CommentEntry(
      key: ValueKey('comment-${item.id}'),
      comment: item,
      timeLabel: formatCommentAge(item.createdAt),
      isReply: !identical(item, root),
      onAuthorTap: open,
      onReplyTap: !item.deleted && !root.deleted
          ? () => _reply(root, item)
          : null,
      onDeleteTap: own ? () => _delete(item, root) : null,
      deleting: deleting,
      deleteKey: ValueKey('comment-delete-${item.id}'),
      actionsEnabled: !state.submitting && state.deletingCommentId == null,
      threadFooter: threadFooter,
      likeButton: item.deleted
          ? null
          : CommentLikeButton(
              key: ValueKey('comment-like-control-${item.id}'),
              comment: item,
              memory: _likeMemory,
              isCurrent: () => _current && _visibleItem(item, root),
              sessions: _sessions,
              repository: _repository,
              compact: !identical(item, root),
              enabled:
                  _current &&
                  !state.submitting &&
                  state.deletingCommentId == null,
            ),
    );
  }

  Widget _thread(CommentItem root, CommentThreadState state) {
    final replies = _replies[root.id];
    final total = replies?.totalElements ?? root.replyCount;
    final expanded = replies?.expanded == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _row(
        root,
        root,
        state,
        threadFooter: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (total > 0 ||
                expanded ||
                replies?.loading == true ||
                replies?.error != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    expanded: expanded,
                    child: TextButton.icon(
                      key: ValueKey('comment-replies-${root.id}'),
                      onPressed: () => _toggleReplies(root),
                      style: _replyButtonStyle(),
                      icon: BrandGradientIcon.social(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: Text(
                        expanded
                            ? 'Yanıtları gizle'
                            : 'Yanıtları göster ($total)',
                      ),
                    ),
                  ),
                ),
              ),
            if (expanded) ...[
              for (final reply in replies!.items)
                Container(
                  margin: const EdgeInsets.only(left: 21, bottom: 6),
                  padding: const EdgeInsets.only(left: 14),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.border)),
                  ),
                  child: _row(reply, root, state),
                ),
              if (replies.loading || replies.error != null || replies.hasMore)
                Padding(
                  padding: const EdgeInsets.only(left: 35, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: replies.loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton.icon(
                            key: ValueKey('comment-replies-more-${root.id}'),
                            onPressed: () => _loadReplies(root),
                            style: _replyButtonStyle(),
                            icon: BrandGradientIcon.social(
                              replies.error == null
                                  ? Icons.subdirectory_arrow_right_rounded
                                  : Icons.refresh_rounded,
                              size: 16,
                            ),
                            label: Text(
                              replies.error == null
                                  ? 'Daha fazla yanıt'
                                  : 'Yanıtlar yüklenemedi · Tekrar dene',
                            ),
                          ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  ButtonStyle _replyButtonStyle() => TextButton.styleFrom(
    foregroundColor: AppColors.textMuted,
    minimumSize: const Size(44, 44),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.centerLeft,
    textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12),
  );

  Widget _status(CommentThreadState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (state.loading || state.loadingMore) const LinearProgressIndicator(),
      if (state.error != null ||
          state.reloadError != null ||
          _localError != null) ...[
        Text(
          _localError ??
              (state.reloadError != null
                  ? 'İşlem tamamlandı. Yorum listesi yenilenemedi.'
                  : state.error!.message),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(
          onPressed: state.loading || state.submitting ? null : _reload,
          child: const Text('Yorumları yeniden yükle'),
        ),
      ],
      if (!state.loading &&
          state.comments.isEmpty &&
          state.error == null &&
          state.reloadError == null &&
          !widget.compactSheet)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Henüz yorum yok. İlk yorumu sen yaz.'),
        ),
      if (state.hasMore && !state.loading && !state.loadingMore)
        TextButton(
          onPressed: () {
            if (_current) context.read<CommentThreadCubit>().loadMore();
          },
          child: const Text('Daha fazla yorum'),
        ),
    ],
  );

  Widget _composer(
    CommentThreadState state, {
    int maxInputLines = 4,
  }) => Container(
    padding: EdgeInsets.only(top: widget.compactSheet ? 12 : 10, bottom: 8),
    decoration: widget.compactSheet
        ? BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: .6)),
            ),
          )
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_replyName != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Yanıtlanıyor: $_replyName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Yanıttan vazgeç',
                onPressed: state.submitting
                    ? null
                    : () => setState(() {
                        _replyName = null;
                        _replyRootId = null;
                      }),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        Row(
          crossAxisAlignment: widget.compactSheet
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _focus,
                enabled: !state.submitting,
                minLines: 1,
                maxLines: maxInputLines,
                maxLength: 500,
                style: widget.compactSheet
                    ? TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.4,
                      )
                    : null,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final normalized = newValue.text
                        .replaceAll('\r\n', '\n')
                        .replaceAll('\r', '\n');
                    if (normalized.length > 500) return oldValue;
                    return normalized == newValue.text
                        ? newValue
                        : TextEditingValue(
                            text: normalized,
                            selection: TextSelection.collapsed(
                              offset: normalized.length,
                            ),
                          );
                  }),
                ],
                decoration: widget.compactSheet
                    ? InputDecoration(
                        hintText: 'Yorum yaz...',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: .8),
                          fontSize: 14,
                        ),
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF070B13),
                        constraints: const BoxConstraints(minHeight: 48),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: .6),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: .6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.socialPink.withValues(alpha: .65),
                          ),
                        ),
                      )
                    : InputDecoration(
                        hintText: 'Yorum yaz...',
                        counterText: '',
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder(
              valueListenable: _input,
              builder: (context, value, _) => widget.compactSheet
                  ? IconButton(
                      tooltip: 'Yorumu gönder',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        maximumSize: const Size(48, 48),
                        padding: const EdgeInsets.all(13),
                        foregroundColor: AppColors.socialPink,
                        disabledForegroundColor: AppColors.textMuted.withValues(
                          alpha: .35,
                        ),
                      ),
                      onPressed: state.submitting || value.text.trim().isEmpty
                          ? null
                          : _send,
                      icon: state.submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined, size: 22),
                    )
                  : IconButton.outlined(
                      tooltip: 'Yorumu gönder',
                      onPressed: state.submitting || value.text.trim().isEmpty
                          ? null
                          : _send,
                      icon: state.submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                    ),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_allowed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Yorumları görmek ve katılmak için giriş yapmalısın.'),
          TextButton(
            onPressed: () {
              if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
                Navigator.of(context).pushNamed(AppRoutes.login);
              }
            },
            child: const Text('Giriş yap'),
          ),
        ],
      );
    }
    return BlocBuilder<CommentThreadCubit, CommentThreadState>(
      builder: (context, state) {
        // A refresh may change the privacy projection without changing IDs.
        // Never attach old reply identities to a newly projected root object.
        _replies.removeWhere(
          (id, page) => !state.comments.any(
            (root) => root.id == id && identical(root, page.root),
          ),
        );
        final empty =
            !state.loading &&
            state.comments.isEmpty &&
            state.error == null &&
            state.reloadError == null;
        final rows = widget.compactSheet && empty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      key: const Key('comment-thread-compact-empty'),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 30,
                            color: AppColors.textMuted.withValues(alpha: .55),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Henüz yorum yok',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'İlk yorumu sen yaz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted.withValues(alpha: .8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : widget.scrollable
            ? ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: state.comments.length + 1,
                itemBuilder: (context, index) => index == state.comments.length
                    ? _status(state)
                    : _thread(state.comments[index], state),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final root in state.comments) _thread(root, state),
                  _status(state),
                ],
              );
        Widget content({int maxInputLines = 4}) => Column(
          mainAxisSize: widget.scrollable ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.scrollable) Expanded(child: rows) else rows,
            _composer(state, maxInputLines: maxInputLines),
          ],
        );
        return widget.compactSheet
            ? LayoutBuilder(
                builder: (context, constraints) => content(
                  // Leave space for the reply strip and send action with a
                  // keyboard or larger system text. The draft still scrolls.
                  maxInputLines: constraints.maxHeight < 260
                      ? 1
                      : constraints.maxHeight < 350
                      ? 2
                      : 4,
                ),
              )
            : content();
      },
    );
  }
}

class CommentThreadSheet extends StatelessWidget {
  const CommentThreadSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.onCommentCreated,
    this.onCommentDeleted,
  });
  final String targetType;
  final String targetId;
  final VoidCallback? onCommentCreated;
  final VoidCallback? onCommentDeleted;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Yorumlar', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(
              child: CommentThreadView(
                targetType: targetType,
                targetId: targetId,
                scrollable: true,
                onCommentCreated: onCommentCreated,
                onCommentDeleted: onCommentDeleted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
