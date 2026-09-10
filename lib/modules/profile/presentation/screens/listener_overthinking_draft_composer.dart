import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../overthinking/domain/entities/overthinking_post.dart';
import '../../../overthinking/domain/overthinking_profile_share_repository.dart';
import '../../../overthinking/domain/overthinking_repository.dart';
import '../../../overthinking/presentation/overthinking_profile_draft.dart';
import '../../domain/entities/listener_profile.dart';
import 'listener_overthinking_share_card.dart';
import 'listener_profile_theme.dart';

/// An in-memory profile card. Reading or editing this draft never publishes it.
class ListenerOverthinkingDraftComposer extends StatefulWidget {
  const ListenerOverthinkingDraftComposer({
    super.key,
    required this.draft,
    required this.profile,
    required this.onFinished,
    this.onStateChanged,
    this.repository,
    this.postsRepository,
    this.sessions,
  });

  final OverthinkingProfileDraftArgs draft;
  final ListenerProfile profile;
  final ValueChanged<bool> onFinished;
  final VoidCallback? onStateChanged;
  final OverthinkingProfileShareRepository? repository;
  final OverthinkingRepository? postsRepository;
  final AuthSessionManager? sessions;

  @override
  State<ListenerOverthinkingDraftComposer> createState() =>
      ListenerOverthinkingDraftComposerState();
}

class ListenerOverthinkingDraftComposerState
    extends State<ListenerOverthinkingDraftComposer>
    with AutomaticKeepAliveClientMixin<ListenerOverthinkingDraftComposer> {
  @override
  bool get wantKeepAlive => true;

  final _note = TextEditingController();
  late final AuthSessionManager _sessions;
  late final OverthinkingProfileShareRepository _repository;
  late final OverthinkingRepository _posts;
  OverthinkingPost? _source;
  OverthinkingProfileShareState? _share;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  bool _invalidated = false;
  bool _finished = false;
  bool _uncertain = false;
  bool _confirmingLeave = false;
  bool _reviewed = false;
  bool _parentNotificationPending = false;
  int _generation = 0;
  String? _attemptedNote;
  String? _attemptedRemoval;
  ModalRoute<dynamic>? _leaveDialog;

  bool get _allowed =>
      mounted &&
      !_invalidated &&
      identical(_sessions.session, widget.draft.expectedSession) &&
      canShareOverthinkingOnProfile(widget.draft.expectedSession) &&
      widget.profile.userId == widget.draft.expectedSession.userId &&
      widget.profile.id.trim().isNotEmpty &&
      widget.profile.visibilityChoiceCompleted &&
      !widget.profile.isGhost &&
      widget.profile.profileContentVisible &&
      widget.profile.profileContentEditable;
  bool get _current => _allowed && ModalRoute.of(context)?.isCurrent == true;
  bool get busy => _loading || _saving;
  bool get saving => _saving;
  bool get readyForReveal => !_loading && (_source != null || _error != null);
  bool get dirty =>
      _allowed && !_finished && (_note.text.isNotEmpty || _uncertain);
  bool get requiresLeaveGuard => saving || dirty;

  @override
  void initState() {
    super.initState();
    _sessions = widget.sessions ?? serviceLocator<AuthSessionManager>();
    _repository =
        widget.repository ??
        serviceLocator<OverthinkingProfileShareRepository>();
    _posts = widget.postsRepository ?? serviceLocator<OverthinkingRepository>();
    _sessions.addListener(_sessionChanged);
    _note.addListener(_changed);
    if (_allowed) {
      _load();
    } else {
      _invalidated = true;
    }
  }

  @override
  void didUpdateWidget(covariant ListenerOverthinkingDraftComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_allowed ||
        oldWidget.draft.postId != widget.draft.postId ||
        !identical(
          oldWidget.draft.expectedSession,
          widget.draft.expectedSession,
        ) ||
        oldWidget.profile.id != widget.profile.id ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.postsRepository, widget.postsRepository) ||
        !identical(oldWidget.sessions, widget.sessions)) {
      invalidate();
    }
  }

  void _sessionChanged() {
    if (!_allowed) invalidate();
  }

  /// Clears the draft before a parent rebuild can expose another account/profile.
  void invalidate() {
    if (_invalidated) return;
    _invalidated = true;
    ++_generation;
    _source = null;
    _share = null;
    _error = null;
    _attemptedNote = null;
    _attemptedRemoval = null;
    _loading = false;
    _saving = false;
    _uncertain = false;
    _dismissLeaveDialog();
    _note.clear();
    _changed();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_parentNotificationPending) return;
    _parentNotificationPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _parentNotificationPending = false;
      if (mounted) widget.onStateChanged?.call();
    });
  }

  Future<void> _load() async {
    if (!_allowed || busy || _finished) return;
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _changed();
    try {
      final results = await Future.wait<Object?>([
        _posts.getDetail(postId: widget.draft.postId),
        _repository.getState(
          postId: widget.draft.postId,
          expectedSession: widget.draft.expectedSession,
        ),
      ]);
      if (!_allowed || _finished || generation != _generation) return;
      final source = results[0] as Result<OverthinkingPost>;
      final share = results[1] as Result<OverthinkingProfileShareState>;
      _source = source.isSuccess && source.data?.id == widget.draft.postId
          ? source.data
          : null;
      _share = share.isSuccess && share.data?.postId == widget.draft.postId
          ? share.data
          : null;
      _loading = false;
      _error = _source == null
          ? source.error?.message ?? 'Asıl yazı yüklenemedi.'
          : _share == null
          ? share.error?.message ?? 'Profil paylaşımı yüklenemedi.'
          : null;
      if (_source != null && _share != null && _uncertain) {
        final confirmed = _share!;
        if (_attemptedRemoval != null && !confirmed.publishedOnProfile) {
          _finish(false);
          return;
        }
        if (_attemptedRemoval == null &&
            confirmed.publishedOnProfile &&
            _normalized(confirmed.note) == _attemptedNote) {
          _finish(true);
          return;
        }
        _uncertain = false;
        _reviewed = true;
      }
      _changed();
    } catch (_) {
      if (!_allowed || _finished || generation != _generation) return;
      _loading = false;
      _source = null;
      _share = null;
      _error =
          'Yazı ve profil paylaşımı yüklenemedi. Yeniden kontrol edebilirsin.';
      _changed();
    }
  }

  static String? _normalized(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  bool get _publishable =>
      _allowed &&
      _source?.id == widget.draft.postId &&
      _share?.postId == widget.draft.postId &&
      _share?.canPublish == true &&
      _share?.publishedOnProfile == false;

  Future<void> _publish() async {
    if (!_current ||
        _finished ||
        busy ||
        _uncertain ||
        !_publishable ||
        _note.text.runes.length > 500) {
      return;
    }
    _saving = true;
    _error = null;
    _attemptedNote = _normalized(_note.text);
    _attemptedRemoval = null;
    _changed();
    try {
      final result = await _repository.publish(
        postId: widget.draft.postId,
        note: _attemptedNote,
        expectedSession: widget.draft.expectedSession,
      );
      if (!_allowed) return;
      _saving = false;
      final value = result.data;
      if (result.isSuccess &&
          value?.postId == widget.draft.postId &&
          value?.publishedOnProfile == true &&
          value?.shareId != null &&
          value?.publishedAt != null &&
          _normalized(value?.note) == _attemptedNote) {
        _finish(true);
      } else {
        _uncertain = true;
        _error = result.error?.message;
        _changed();
      }
    } catch (_) {
      if (!_allowed) return;
      _saving = false;
      _uncertain = true;
      _error = null;
      _changed();
    }
  }

  Future<void> _remove() async {
    final id = _share?.shareId;
    if (!_current ||
        _finished ||
        busy ||
        _uncertain ||
        id == null ||
        _share?.publishedOnProfile != true) {
      return;
    }
    _saving = true;
    _error = null;
    _attemptedRemoval = id;
    _attemptedNote = null;
    _changed();
    try {
      final result = await _repository.deleteShare(
        shareId: id,
        expectedSession: widget.draft.expectedSession,
      );
      if (!_allowed) return;
      _saving = false;
      if (result.isSuccess) {
        _finish(false);
      } else {
        _uncertain = true;
        _error = result.error?.message;
        _changed();
      }
    } catch (_) {
      if (!_allowed) return;
      _saving = false;
      _uncertain = true;
      _error = null;
      _changed();
    }
  }

  void _finish(bool published) {
    if (!_allowed || _finished) return;
    _finished = true;
    _uncertain = false;
    _changed();
    widget.onFinished(published);
  }

  Future<bool> canLeave() async {
    if (!_allowed) return false;
    final ownerRoute = ModalRoute.of(context);
    if (saving || _confirmingLeave || ownerRoute?.isCurrent != true) {
      return false;
    }
    if (!dirty) return true;
    _confirmingLeave = true;
    ModalRoute<dynamic>? dialogRoute;
    var responded = false;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          dialogRoute = ModalRoute.of(dialogContext);
          _leaveDialog = dialogRoute;
          if (!_allowed) _dismissLeaveDialog();
          void respond(bool discard) {
            if (responded ||
                !_allowed ||
                !dialogContext.mounted ||
                dialogRoute?.isCurrent != true) {
              return;
            }
            responded = true;
            Navigator.of(dialogContext).pop(discard);
          }

          return AlertDialog(
            scrollable: true,
            key: const Key('listener-overthinking-draft-leave-dialog'),
            title: Text(
              _uncertain
                  ? 'Paylaşımı kontrol etmeden ayrıl?'
                  : 'Taslağı bırakmak istiyor musun?',
            ),
            content: Text(
              _uncertain
                  ? 'Son işlemin sonucu doğrulanamadı. Paylaşımın profilinde görünmüş olabilir. Açıklama taslağın bu ekrandan ayrılınca silinir.'
                  : 'Yazdığın açıklama kaydedilmedi.',
            ),
            actions: [
              TextButton(
                onPressed: () => respond(false),
                child: const Text('Düzenlemeye devam et'),
              ),
              GradientOutlineButton(
                label: 'Taslağı bırak',
                strokeWidth: .7,
                onPressed: () => respond(true),
              ),
            ],
          );
        },
      );
      await dialogRoute?.completed;
      return mounted &&
          _allowed &&
          discard == true &&
          !saving &&
          ownerRoute?.isCurrent == true;
    } finally {
      _confirmingLeave = false;
      if (identical(_leaveDialog, dialogRoute)) _leaveDialog = null;
    }
  }

  void _dismissLeaveDialog() {
    final route = _leaveDialog;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _cancel() async {
    if (await canLeave()) _finish(false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_allowed) return const SizedBox.shrink();
    final source = _source;
    final published = _share?.publishedOnProfile == true;
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null || _uncertain) ...[
          const SizedBox(height: 12),
          Text(
            _uncertain
                ? 'Son işlemin doğrulanamadı. Açıklamanı koruduk. Devam etmeden önce güncel durumu kontrol et.'
                : _error!,
            key: const Key('listener-overthinking-draft-error'),
            style: TextStyle(color: AppColors.socialPink),
          ),
          TextButton(
            key: const Key('listener-overthinking-draft-reload'),
            onPressed: busy ? null : _load,
            child: const Text('Güncel durumu kontrol et'),
          ),
        ],
        if (_reviewed && !_uncertain)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Güncel durum yüklendi. Açıklamanı gözden geçirip devam edebilirsin.',
            ),
          ),
        if (source != null && _share != null && !published && !_publishable)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Bu yazı şu anda profilinde paylaşılamıyor. Profil görünürlüğünü kontrol et.',
            ),
          ),
        if (published)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Profilinden kaldırdığında asıl yazı ve beğenileri korunur.',
            ),
          ),
        const SizedBox(height: 12),
        GradientOutlineButton(
          key: Key(
            published
                ? 'listener-overthinking-draft-remove'
                : 'listener-overthinking-draft-publish',
          ),
          label: published ? 'Profilimden kaldır' : 'Paylaş',
          strokeWidth: .7,
          loading: saving,
          leading: Icon(
            published ? Icons.delete_outline_rounded : Icons.publish_rounded,
            size: 18,
          ),
          onPressed:
              !busy &&
                  !_uncertain &&
                  !_finished &&
                  source != null &&
                  (published
                      ? _share?.shareId != null
                      : _publishable && _note.text.runes.length <= 500)
              ? published
                    ? _remove
                    : _publish
              : null,
        ),
        TextButton(
          key: const Key('listener-overthinking-draft-cancel'),
          onPressed: saving || _finished ? null : _cancel,
          child: const Text('Vazgeç'),
        ),
      ],
    );
    if (source == null) {
      return Container(
        key: const Key('listener-overthinking-draft-loading'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: listenerProfileSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Taslak · Henüz paylaşılmadı',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            actions,
          ],
        ),
      );
    }
    return ListenerOverthinkingShareCard.draft(
      post: source,
      username: widget.profile.username ?? '',
      avatarUrl: widget.profile.profilePictureUrl,
      visibilityLabel: published
          ? 'Profilinde paylaşıldı'
          : 'Taslak · Henüz paylaşılmadı',
      busy: busy,
      maskAnonymousAuthor: true,
      isCurrent: () => _current,
      noteEditor: published
          ? _share?.note?.isNotEmpty == true
                ? Text(
                    _share!.note!,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  )
                : const SizedBox.shrink()
          : TextField(
              key: const Key('listener-overthinking-draft-note'),
              controller: _note,
              enabled: !saving && !_finished,
              minLines: 3,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = newValue.text
                      .replaceAll('\r\n', '\n')
                      .replaceAll('\r', '\n');
                  if (text.runes.length > 500) return oldValue;
                  return text == newValue.text
                      ? newValue
                      : TextEditingValue(
                          text: text,
                          selection: TextSelection.collapsed(
                            offset: text.length,
                          ),
                        );
                }),
              ],
              decoration: InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
                hintText: 'Bu satırlar için birkaç söz ekle…',
                counterText: '${_note.text.runes.length}/500',
                alignLabelWithHint: true,
              ),
            ),
      actions: actions,
    );
  }

  @override
  void dispose() {
    ++_generation;
    _dismissLeaveDialog();
    _sessions.removeListener(_sessionChanged);
    _note.dispose();
    super.dispose();
  }
}
