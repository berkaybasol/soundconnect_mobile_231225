import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../event_audience/domain/event_audience_repository.dart';
import '../../../event_audience/presentation/event_audience_controller.dart';
import '../../../event_audience/presentation/event_audience_profile_draft.dart';
import '../../domain/entities/listener_profile.dart';
import 'listener_event_post_card.dart';

/// In-memory only. Creating or editing this card never writes publication state.
class ListenerEventDraftComposer extends StatefulWidget {
  const ListenerEventDraftComposer({
    super.key,
    required this.draft,
    required this.profile,
    required this.onFinished,
    this.onStateChanged,
    this.repository,
    this.sessions,
  });

  final EventAudienceProfileDraftArgs draft;
  final ListenerProfile profile;
  final ValueChanged<bool> onFinished;
  final VoidCallback? onStateChanged;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;

  @override
  State<ListenerEventDraftComposer> createState() =>
      ListenerEventDraftComposerState();
}

class ListenerEventDraftComposerState extends State<ListenerEventDraftComposer>
    with AutomaticKeepAliveClientMixin<ListenerEventDraftComposer> {
  @override
  bool get wantKeepAlive => true;
  final _note = TextEditingController();
  late final AuthSessionManager _sessions;
  EventAudienceController? _controller;
  bool _invalidated = false;
  bool _initializedNote = false;
  bool _confirmingLeave = false;
  bool _uncertain = false;
  bool _finished = false;
  String _initialNote = '';
  String? _attemptedNote;
  int? _attemptedVersion;
  EventAudienceStatus? _attemptedIntent;
  EventAudienceState? _baseline;
  bool _requiresReview = false;
  bool _reviewed = false;
  bool _publishing = false;
  ModalRoute<dynamic>? _leaveDialog;

  bool get _allowed =>
      mounted &&
      !_invalidated &&
      canPublishAudienceProfile(_sessions.session) &&
      sameEventAudienceSession(
        _sessions.session,
        widget.draft.expectedSession,
      ) &&
      widget.profile.userId == widget.draft.expectedSession.userId &&
      widget.profile.visibilityChoiceCompleted &&
      !widget.profile.isGhost &&
      widget.profile.profileContentVisible &&
      widget.profile.profileContentEditable;
  bool get busy => _controller?.busy == true;
  bool get saving => _controller?.saving == true;
  bool get readyForReveal =>
      _controller?.loading == false &&
      (_controller?.state != null || _controller?.error != null);
  bool get dirty => _allowed && (_note.text != _initialNote || _uncertain);
  bool get requiresLeaveGuard => saving || dirty;

  @override
  void initState() {
    super.initState();
    _sessions = widget.sessions ?? serviceLocator<AuthSessionManager>();
    // Register before the shared controller so an identity change disposes it
    // before it can automatically read a replacement account for this draft.
    _sessions.addListener(_sessionChanged);
    _note.addListener(_changed);
    if (_allowed) {
      _controller = EventAudienceController(
        eventId: widget.draft.eventId,
        repository:
            widget.repository ?? serviceLocator<EventAudienceRepository>(),
        sessions: _sessions,
      )..addListener(_changed);
    } else {
      _invalidated = true;
    }
  }

  @override
  void didUpdateWidget(covariant ListenerEventDraftComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_allowed || oldWidget.draft.eventId != widget.draft.eventId) {
      invalidate();
    }
  }

  void _sessionChanged() {
    if (!_allowed) invalidate();
  }

  /// Clears sensitive text immediately, even before the parent rebuilds.
  void invalidate() {
    if (_invalidated) return;
    _invalidated = true;
    _dismissLeaveDialog();
    _controller?.removeListener(_changed);
    _controller?.dispose();
    _controller = null;
    _initialNote = '';
    _attemptedNote = null;
    _note.clear();
    _changed();
  }

  void _changed() {
    if (!mounted) return;
    final state = _controller?.state;
    if (!_initializedNote && state != null && _allowed) {
      _initializedNote = true;
      _initialNote = state.note ?? '';
      _note.value = TextEditingValue(text: _initialNote);
      _baseline = state;
    }
    final baseline = _baseline;
    if (state != null &&
        baseline != null &&
        !_publishing &&
        (state.version != baseline.version ||
            state.intent != baseline.intent ||
            state.publishedOnProfile != baseline.publishedOnProfile ||
            state.note != baseline.note)) {
      _requiresReview = true;
    }
    setState(() {});
    // Controller callbacks can run while a lazy profile child is mounting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onStateChanged?.call();
    });
  }

  Future<void> _reload() async {
    if (!_allowed || busy) return;
    await _controller?.refresh();
    if (!mounted || !_allowed) return;
    final state = _controller?.state;
    if (_controller?.needsRefresh == false && state != null) {
      if (_uncertain &&
          state.publishedOnProfile &&
          state.publicationVisible &&
          state.intent == _attemptedIntent &&
          state.version > (_attemptedVersion ?? state.version) &&
          _normalized(state.note) == _attemptedNote) {
        _finish(true);
        return;
      }
      // A fresh response resolves ambiguity, but does not discard authored
      // text or silently overwrite a newer server version on the user's behalf.
      _uncertain = false;
      _baseline = state;
      _requiresReview = false;
      _reviewed = true;
      _changed();
    }
  }

  String? _normalized(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  bool _publishable(EventAudienceState? value) =>
      _allowed &&
      value != null &&
      value.eventId == widget.draft.eventId &&
      value.event?.id == widget.draft.eventId &&
      value.eventAvailable &&
      !value.eventEnded &&
      value.canPublish &&
      value.intent != EventAudienceStatus.none;

  Future<void> _publish() async {
    final controller = _controller;
    final value = controller?.state;
    if (_finished ||
        _uncertain ||
        controller == null ||
        !_publishable(value) ||
        busy ||
        _requiresReview ||
        value?.version != _baseline?.version ||
        controller.needsRefresh ||
        _note.text.runes.length > 500 ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _attemptedNote = _normalized(_note.text);
    _attemptedVersion = value!.version;
    _attemptedIntent = value.intent;
    _publishing = true;
    final saved = await controller.publish(
      _attemptedNote,
      expectedRevision: controller.revision,
    );
    _publishing = false;
    if (!mounted || !_allowed) return;
    if (saved != null &&
        saved.publishedOnProfile &&
        saved.publicationVisible &&
        _normalized(saved.note) == _attemptedNote) {
      _finish(true);
    } else {
      _uncertain = true;
      _changed();
    }
  }

  void _finish(bool published) {
    if (!mounted || _finished) return;
    _finished = true;
    _uncertain = false;
    _initialNote = _note.text;
    widget.onFinished(published);
  }

  /// Shared by back, bottom navigation, settings, and the cancel action.
  Future<bool> canLeave() async {
    if (!mounted) return false;
    final ownerRoute = ModalRoute.of(context);
    if (!mounted ||
        saving ||
        _confirmingLeave ||
        ownerRoute?.isCurrent != true) {
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
            key: const Key('listener-event-draft-leave-dialog'),
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
    final controller = _controller;
    final value = controller?.state;
    final event = value?.event;
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller?.error != null || _uncertain || _requiresReview) ...[
          const SizedBox(height: 12),
          Text(
            _requiresReview && !_uncertain
                ? 'Etkinlik seçimin başka bir ekranda değişti. Açıklamanı koruduk. Güncel durumu kontrol ederek devam et.'
                : _uncertain
                ? 'Paylaşımın doğrulanamadı. Açıklamanı koruduk. Devam etmeden önce güncel durumu kontrol et.'
                : 'Etkinlik seçimin yüklenemedi. Yeniden kontrol edebilirsin.',
            key: const Key('listener-event-draft-error'),
            style: TextStyle(color: AppColors.socialPink),
          ),
          TextButton(
            onPressed: busy ? null : _reload,
            child: const Text('Güncel durumu kontrol et'),
          ),
        ],
        if (_reviewed && !_requiresReview && !_uncertain)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Güncel durum yüklendi. Açıklamanı gözden geçirip Paylaş’a basabilirsin.',
            ),
          ),
        if (value != null && !_publishable(value)) ...[
          const SizedBox(height: 12),
          const Text(
            'Bu etkinlik şu anda profilinde paylaşılamıyor. Etkinlik seçimini ve profil görünürlüğünü kontrol et.',
          ),
        ],
        const SizedBox(height: 12),
        GradientOutlineButton(
          key: const Key('listener-event-draft-publish'),
          label: 'Paylaş',
          strokeWidth: .7,
          loading: saving,
          leading: const Icon(Icons.publish_rounded, size: 18),
          onPressed:
              _publishable(value) &&
                  !busy &&
                  !_uncertain &&
                  !_requiresReview &&
                  controller?.needsRefresh == false &&
                  _note.text.runes.length <= 500
              ? _publish
              : null,
        ),
        TextButton(
          key: const Key('listener-event-draft-cancel'),
          onPressed: saving ? null : _cancel,
          child: const Text('Vazgeç'),
        ),
      ],
    );
    if (event == null) {
      return Container(
        key: const Key('listener-event-draft-loading'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF101722),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Taslak · Henüz paylaşılmadı',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (controller?.loading == true)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            actions,
          ],
        ),
      );
    }
    return ListenerEventPostCard(
      event: event,
      username: widget.profile.username ?? '',
      avatarUrl: widget.profile.profilePictureUrl,
      intentLabel: value!.intent.label,
      visibilityLabel: value.publishedOnProfile
          ? 'Taslak · Değişiklikler paylaşılmadı'
          : 'Taslak · Henüz paylaşılmadı',
      owner: true,
      onOpen: null,
      onIntent: null,
      noteEditor: TextField(
        key: const Key('listener-event-draft-note'),
        controller: _note,
        enabled: !saving,
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
                    selection: TextSelection.collapsed(offset: text.length),
                  );
          }),
        ],
        decoration: InputDecoration(
          labelText: 'Açıklama (isteğe bağlı)',
          hintText: 'Bu etkinlik için birkaç söz ekle…',
          counterText: '${_note.text.runes.length}/500',
          alignLabelWithHint: true,
        ),
      ),
      actions: actions,
    );
  }

  @override
  void dispose() {
    _dismissLeaveDialog();
    _sessions.removeListener(_sessionChanged);
    _controller?.removeListener(_changed);
    _controller?.dispose();
    _note.dispose();
    super.dispose();
  }
}
