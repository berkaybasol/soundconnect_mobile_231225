import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../overthinking/domain/overthinking_profile_share_repository.dart';
import '../../../overthinking/presentation/screens/overthinking_open_source.dart';
import '../share/overthinking_share_flow.dart';
import 'listener_overthinking_share_card.dart';
import 'listener_profile_theme.dart';
import 'listener_share_delete_dialog.dart';

class ListenerOverthinkingPostsSection extends StatefulWidget {
  const ListenerOverthinkingPostsSection({
    super.key,
    required this.listenerProfileId,
    required this.username,
    this.avatarUrl,
    this.ownerUserId,
    this.profileContentVisible = true,
    this.repository,
    this.sessions,
    this.refreshSignal,
    this.onOpenSource,
  });
  final String listenerProfileId;
  final String username;
  final String? avatarUrl;
  final String? ownerUserId;
  final bool profileContentVisible;
  final OverthinkingProfileShareRepository? repository;
  final AuthSessionManager? sessions;
  final ValueListenable<int>? refreshSignal;
  final Future<void> Function(String postId)? onOpenSource;

  @override
  State<ListenerOverthinkingPostsSection> createState() =>
      _ListenerOverthinkingPostsSectionState();
}

class _ListenerOverthinkingPostsSectionState
    extends State<ListenerOverthinkingPostsSection>
    with WidgetsBindingObserver {
  OverthinkingProfileShareRepository? _repository;
  AuthSessionManager? _sessions;
  AuthSession _session = const AuthSession.guest();
  List<OverthinkingProfileShare> _items = [];
  final Set<String> _removed = {};
  int _generation = 0;
  final _shareValidity = ValueNotifier<int>(0);
  int _page = 0;
  bool _hasNext = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _busyShareId;
  DialogRoute<bool>? _confirmation;

  bool get _allowed =>
      _repository != null &&
      widget.profileContentVisible &&
      widget.listenerProfileId.trim().isNotEmpty &&
      _session.isAuthenticated &&
      _session.isActive &&
      !_session.requiresListenerProfileChoice &&
      (widget.ownerUserId == null || widget.ownerUserId == _session.userId) &&
      identical(_sessions?.session, _session);
  bool get _owner =>
      widget.ownerUserId == _session.userId &&
      canShareOverthinkingOnProfile(_session);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.refreshSignal?.addListener(_refresh);
    _bind();
  }

  void _bind() {
    _repository?.changes.removeListener(_refresh);
    _sessions?.removeListener(_sessionChanged);
    _repository =
        widget.repository ?? _registered<OverthinkingProfileShareRepository>();
    _sessions = widget.sessions ?? _registered<AuthSessionManager>();
    _repository?.changes.addListener(_refresh);
    _sessions?.addListener(_sessionChanged);
    _session = _sessions?.session ?? const AuthSession.guest();
    _reset();
    unawaited(_load());
  }

  void _reset() {
    ++_generation;
    _shareValidity.value = _generation;
    _items = [];
    _removed.clear();
    _page = 0;
    _hasNext = false;
    _loading = false;
    _loadingMore = false;
    _error = null;
    _busyShareId = null;
    _dismissConfirmation();
  }

  void _sessionChanged() {
    if (identical(_sessions?.session, _session)) return;
    _session = _sessions!.session;
    _reset();
    if (mounted) setState(() {});
    unawaited(_load());
  }

  @override
  void didUpdateWidget(ListenerOverthinkingPostsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.refreshSignal, widget.refreshSignal)) {
      oldWidget.refreshSignal?.removeListener(_refresh);
      widget.refreshSignal?.addListener(_refresh);
    }
    if (oldWidget.listenerProfileId != widget.listenerProfileId ||
        oldWidget.ownerUserId != widget.ownerUserId ||
        oldWidget.profileContentVisible != widget.profileContentVisible ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.sessions, widget.sessions)) {
      _bind();
    }
  }

  void _refresh() => unawaited(_load());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _load({bool append = false}) async {
    if (!mounted ||
        !_allowed ||
        (append && (_loading || _loadingMore || !_hasNext))) {
      return;
    }
    final session = _session;
    final repository = _repository!;
    final generation = ++_generation;
    _shareValidity.value = generation;
    final page = append ? _page + 1 : 0;
    setState(() {
      _loading = !append;
      _loadingMore = append;
      _error = null;
    });
    try {
      final result = await repository.listProfile(
        profileId: widget.listenerProfileId,
        expectedSession: session,
        page: page,
        size: 6,
      );
      if (!mounted ||
          generation != _generation ||
          !_allowed ||
          !identical(session, _session)) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (result.isSuccess && result.data != null) {
          _items = <String, OverthinkingProfileShare>{
            if (append)
              for (final item in _items) item.shareId: item,
            for (final item in result.data!.items)
              if (!_removed.contains(item.shareId)) item.shareId: item,
          }.values.toList();
          _page = page;
          _hasNext = result.data!.hasNext;
        } else {
          // Never keep a private viewer projection after its read was denied.
          // A later retry will restore the server's current public projection.
          if (!append ||
              const {
                '401',
                '403',
                '404',
                '9401',
                '9415',
              }.contains(result.error?.code)) {
            _items = [];
          }
          _error = result.error?.message ?? 'Paylaşımlar yüklenemedi.';
        }
      });
    } catch (_) {
      if (!mounted ||
          generation != _generation ||
          !identical(session, _session)) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (!append) _items = [];
        _error = 'Paylaşımlar yüklenemedi.';
      });
    }
  }

  bool _current(AuthSession session, OverthinkingProfileShare item) =>
      mounted &&
      _allowed &&
      identical(session, _session) &&
      ModalRoute.of(context)?.isCurrent == true &&
      _items.any((row) => identical(row, item));

  Future<void> _open(OverthinkingProfileShare item) async {
    final session = _session;
    if (_busyShareId != null || !_current(session, item)) return;
    setState(() => _busyShareId = item.shareId);
    try {
      if (widget.onOpenSource case final open?) {
        await open(item.post.id);
      } else {
        await openOverthinkingSource(
          context,
          item.post.id,
          isCurrent: () => _current(session, item),
        );
      }
    } finally {
      if (mounted && identical(session, _session)) {
        setState(() => _busyShareId = null);
        await _load();
      }
    }
  }

  Future<void> _remove(OverthinkingProfileShare item) async {
    final session = _session;
    if (!_owner || _busyShareId != null || !_current(session, item)) return;
    setState(() => _busyShareId = item.shareId);
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (_) => const ListenerShareDeleteDialog.overthinking(
        confirmKey: Key('listener-overthinking-remove-confirm'),
      ),
    );
    _confirmation = dialog;
    try {
      final confirmed = await Navigator.of(context).push<bool>(dialog);
      if (identical(_confirmation, dialog)) _confirmation = null;
      if (confirmed != true || !_current(session, item) || !_owner) return;
      final result = await _repository!.deleteShare(
        shareId: item.shareId,
        expectedSession: session,
      );
      if (!mounted || !identical(session, _session) || !_allowed) return;
      if (result.isSuccess) {
        _removed.add(item.shareId);
        setState(
          () => _items = _items
              .where((row) => row.shareId != item.shareId)
              .toList(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: Text(result.error?.message ?? 'Paylaşım kaldırılamadı.'),
          ),
        );
      }
      await _load();
    } finally {
      if (identical(_confirmation, dialog)) _dismissConfirmation();
      if (mounted && identical(session, _session)) {
        setState(() => _busyShareId = null);
      }
    }
  }

  Future<void> _share(OverthinkingProfileShare item) async {
    final session = _session;
    if (_busyShareId != null || !_current(session, item)) return;
    final repository = _repository!;
    final revision = repository.changes.value;
    final generation = _generation;
    setState(() => _busyShareId = item.shareId);
    try {
      await shareOverthinkingPost(
        context,
        postId: item.post.id,
        sessions: _sessions,
        expectedSession: session,
        validityChanges: Listenable.merge([repository.changes, _shareValidity]),
        isValid: () =>
            mounted &&
            _allowed &&
            generation == _generation &&
            identical(_session, session) &&
            identical(_repository, repository) &&
            repository.changes.value == revision &&
            _items.any((row) => identical(row, item)),
      );
    } finally {
      if (mounted && identical(_session, session)) {
        setState(() => _busyShareId = null);
      }
    }
  }

  void _dismissConfirmation() {
    final dialog = _confirmation;
    _confirmation = null;
    if (dialog == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
    });
  }

  @override
  void dispose() {
    ++_generation;
    _shareValidity.value = _generation;
    _shareValidity.dispose();
    _dismissConfirmation();
    WidgetsBinding.instance.removeObserver(this);
    widget.refreshSignal?.removeListener(_refresh);
    _repository?.changes.removeListener(_refresh);
    _sessions?.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const SizedBox.shrink();
    final session = _session;
    return Column(
      key: const Key('listener-overthinking-posts'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListenerOverthinkingShareCard(
              share: item,
              username: widget.username,
              avatarUrl: widget.avatarUrl,
              busy: _busyShareId == item.shareId,
              isCurrent: () => _current(session, item),
              onOpen: _busyShareId == null
                  ? () => unawaited(_open(item))
                  : null,
              onRemove: _owner ? () => unawaited(_remove(item)) : null,
              onShare: () => unawaited(_share(item)),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  _error!,
                  style: const TextStyle(
                    color: listenerProfileMuted,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: _loading || _loadingMore
                      ? null
                      : () => unawaited(_load()),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        if (_hasNext && _error == null)
          TextButton.icon(
            key: const Key('listener-overthinking-more'),
            onPressed: _loading || _loadingMore
                ? null
                : () => unawaited(_load(append: true)),
            icon: _loadingMore
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: const Text('Daha fazla göster'),
          ),
      ],
    );
  }
}

T? _registered<T extends Object>() =>
    serviceLocator.isRegistered<T>() ? serviceLocator<T>() : null;
