import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../spotify/domain/entities/spotify_playlist_preview.dart';
import '../../../spotify/domain/spotify_playlist_uri.dart';

typedef ListenerPlaylistSave =
    Future<ListenerPlaylistSaveResult> Function(List<String> spotifyUrls);

class ListenerPlaylistSaveResult {
  const ListenerPlaylistSaveResult._({
    required this.succeeded,
    this.message,
    this.latestPlaylists,
  });

  const ListenerPlaylistSaveResult.success({
    List<SpotifyPlaylistPreview>? latestPlaylists,
  }) : this._(succeeded: true, latestPlaylists: latestPlaylists);

  const ListenerPlaylistSaveResult.failure(String message)
    : this._(succeeded: false, message: message);

  const ListenerPlaylistSaveResult.conflict({
    required String message,
    required List<SpotifyPlaylistPreview> latestPlaylists,
  }) : this._(
         succeeded: false,
         message: message,
         latestPlaylists: latestPlaylists,
       );

  final bool succeeded;
  final String? message;

  /// Carries the server-authoritative snapshots after a successful save or a
  /// stale-version refresh. The sheet never invents Spotify metadata locally.
  final List<SpotifyPlaylistPreview>? latestPlaylists;
}

Future<bool?> showListenerPlaylistManagerSheet({
  required BuildContext context,
  required List<SpotifyPlaylistPreview> initialPlaylists,
  required ListenerPlaylistSave onSave,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC05070C),
    builder: (_) => ListenerPlaylistManagerSheet(
      initialPlaylists: initialPlaylists,
      onSave: onSave,
    ),
  );
}

class ListenerPlaylistManagerSheet extends StatefulWidget {
  const ListenerPlaylistManagerSheet({
    super.key,
    required this.initialPlaylists,
    required this.onSave,
  });

  final List<SpotifyPlaylistPreview> initialPlaylists;
  final ListenerPlaylistSave onSave;

  @override
  State<ListenerPlaylistManagerSheet> createState() =>
      _ListenerPlaylistManagerSheetState();
}

class _ListenerPlaylistManagerSheetState
    extends State<ListenerPlaylistManagerSheet> {
  static const int _maximumPlaylists = 4;
  static const Duration _autoSaveDelay = Duration(milliseconds: 900);

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  late final List<_PlaylistDraft> _drafts;
  late List<String> _lastSavedUrls;
  Timer? _autoSaveTimer;
  int? _editingIndex;
  String? _inputError;
  String? _saveError;
  bool _saving = false;
  _PlaylistSyncState _syncState = _PlaylistSyncState.idle;

  @override
  void initState() {
    super.initState();
    final ordered = [...widget.initialPlaylists]
      ..sort((a, b) => a.position.compareTo(b.position));
    _drafts = ordered
        .map(
          (playlist) => _PlaylistDraft(
            spotifyUrl: playlist.spotifyUrl,
            preview: playlist,
          ),
        )
        .toList(growable: true);
    _lastSavedUrls = ordered
        .map((playlist) => playlist.spotifyUrl)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving && !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Material(
            color: const Color(0xFF0B111D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.86,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A4556),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      key: const Key('listener-playlist-manager-scroll'),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 17, 12, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Çalma Listelerim',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.35,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_drafts.length}/$_maximumPlaylists · Başlık ve kapak Spotify’dan alınır.',
                                        style: const TextStyle(
                                          color: Color(0xFF9CA7B8),
                                          fontSize: 11,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  key: const Key(
                                    'listener-playlist-manager-close',
                                  ),
                                  tooltip: 'Kapat',
                                  onPressed: _saving
                                      ? null
                                      : () => unawaited(_requestClose()),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                            child: _buildUrlEditor(),
                          ),
                        ),
                        if (_syncState != _PlaylistSyncState.idle)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: _PlaylistSyncNotice(
                                state: _syncState,
                                errorMessage: _saveError,
                                onRetry:
                                    _syncState == _PlaylistSyncState.error &&
                                        _hasUnsavedChanges &&
                                        !_saving
                                    ? () => unawaited(_flushAutoSave())
                                    : null,
                              ),
                            ),
                          ),
                        if (_drafts.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _PlaylistManagerEmpty(),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            sliver: SliverReorderableList(
                              itemCount: _drafts.length,
                              onReorder: _saving ? (_, _) {} : _reorder,
                              proxyDecorator: (child, _, animation) =>
                                  AnimatedBuilder(
                                    animation: animation,
                                    builder: (context, _) => Material(
                                      color: Colors.transparent,
                                      elevation: 8 * animation.value,
                                      borderRadius: BorderRadius.circular(18),
                                      child: child,
                                    ),
                                  ),
                              itemBuilder: (context, index) => Padding(
                                key: ValueKey(_drafts[index].spotifyUrl),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ReorderableDragStartListener(
                                  key: Key(
                                    'listener-playlist-drag-area-$index',
                                  ),
                                  index: index,
                                  enabled: !_saving,
                                  child: _PlaylistDraftTile(
                                    draft: _drafts[index],
                                    index: index,
                                    enabled: !_saving,
                                    onEdit: () => _beginEdit(index),
                                    onDelete: () => _remove(index),
                                    onMoveUp: index == 0
                                        ? null
                                        : () => _move(index, index - 1),
                                    onMoveDown: index == _drafts.length - 1
                                        ? null
                                        : () => _move(index, index + 1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrlEditor() {
    final editing = _editingIndex != null;
    final atLimit = _drafts.length >= _maximumPlaylists && !editing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('listener-playlist-url-input'),
          controller: _urlController,
          focusNode: _urlFocusNode,
          enabled: !_saving && !atLimit,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _commitUrl(),
          decoration: InputDecoration(
            labelText: editing
                ? 'Yeni Spotify bağlantısı'
                : 'Spotify çalma listesi bağlantısı',
            hintText: 'https://open.spotify.com/playlist/…',
            errorText: _inputError,
            prefixIcon: const Padding(
              padding: EdgeInsets.all(13),
              child: FaIcon(
                FontAwesomeIcons.spotify,
                color: Color(0xFF1ED760),
                size: 20,
              ),
            ),
            suffixIcon: IconButton(
              key: const Key('listener-playlist-url-commit'),
              tooltip: editing ? 'Bağlantıyı güncelle' : 'Listeye ekle',
              onPressed: _saving || atLimit ? null : _commitUrl,
              icon: Icon(editing ? Icons.check_rounded : Icons.add_rounded),
            ),
            filled: true,
            fillColor: const Color(0xFF111A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: const BorderSide(color: Color(0xFF273449)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: const BorderSide(color: Color(0xFF273449)),
            ),
          ),
        ),
        if (atLimit) ...[
          const SizedBox(height: 7),
          const Text(
            'Profilinde en fazla 4 çalma listesi paylaşabilirsin.',
            key: Key('listener-playlist-limit-message'),
            style: TextStyle(color: Color(0xFF9CA7B8), fontSize: 10.5),
          ),
        ],
        if (editing) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Düzenlemeyi iptal et'),
            ),
          ),
        ],
      ],
    );
  }

  void _commitUrl() {
    if (_saving) return;
    final normalized = normalizeSpotifyPlaylistUrl(_urlController.text);
    if (normalized == null) {
      setState(() {
        _inputError =
            'Geçerli, herkese açık bir Spotify çalma listesi bağlantısı gir.';
      });
      return;
    }
    final editingIndex = _editingIndex;
    final duplicate = _drafts.indexWhere(
      (draft) => draft.spotifyUrl == normalized,
    );
    if (duplicate >= 0 && duplicate != editingIndex) {
      setState(() => _inputError = 'Bu çalma listesi zaten profilinde.');
      return;
    }
    if (editingIndex == null && _drafts.length >= _maximumPlaylists) {
      setState(() => _inputError = 'En fazla 4 çalma listesi ekleyebilirsin.');
      return;
    }

    setState(() {
      final preview = editingIndex == null
          ? null
          : _drafts[editingIndex].spotifyUrl == normalized
          ? _drafts[editingIndex].preview
          : null;
      final draft = _PlaylistDraft(spotifyUrl: normalized, preview: preview);
      if (editingIndex == null) {
        _drafts.add(draft);
      } else {
        _drafts[editingIndex] = draft;
      }
      _urlController.clear();
      _editingIndex = null;
      _inputError = null;
      _saveError = null;
    });
    _urlFocusNode.unfocus();
    _scheduleAutoSave();
  }

  void _beginEdit(int index) {
    if (_saving) return;
    setState(() {
      _editingIndex = index;
      _urlController.text = _drafts[index].spotifyUrl;
      _urlController.selection = TextSelection.collapsed(
        offset: _urlController.text.length,
      );
      _inputError = null;
    });
    _urlFocusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _urlController.clear();
      _inputError = null;
    });
    _urlFocusNode.unfocus();
  }

  void _remove(int index) {
    setState(() {
      _drafts.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _urlController.clear();
      } else if (_editingIndex != null && _editingIndex! > index) {
        _editingIndex = _editingIndex! - 1;
      }
      _inputError = null;
      _saveError = null;
    });
    _scheduleAutoSave();
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    _move(oldIndex, newIndex);
  }

  void _move(int from, int to) {
    if (_saving || from == to || to < 0 || to >= _drafts.length) return;
    setState(() {
      final draft = _drafts.removeAt(from);
      _drafts.insert(to, draft);
      _editingIndex = null;
      _urlController.clear();
      _inputError = null;
      _saveError = null;
    });
    _scheduleAutoSave();
  }

  List<String> get _draftUrls =>
      _drafts.map((draft) => draft.spotifyUrl).toList(growable: false);

  bool get _hasUnsavedChanges => !_sameUrls(_draftUrls, _lastSavedUrls);

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    if (!_hasUnsavedChanges) {
      setState(() {
        _syncState = _PlaylistSyncState.idle;
        _saveError = null;
      });
      return;
    }
    setState(() {
      _syncState = _PlaylistSyncState.pending;
      _saveError = null;
    });
    _autoSaveTimer = Timer(_autoSaveDelay, () => unawaited(_flushAutoSave()));
  }

  Future<void> _flushAutoSave({bool closeAfterSuccess = false}) async {
    if (_saving) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    if (!_hasUnsavedChanges) {
      if (closeAfterSuccess && mounted) Navigator.of(context).pop();
      return;
    }
    final submittedUrls = _draftUrls;
    setState(() {
      _saving = true;
      _syncState = _PlaylistSyncState.saving;
      _saveError = null;
    });
    final result = await widget.onSave(submittedUrls);
    if (!mounted) return;
    if (result.succeeded) {
      setState(() {
        _saving = false;
        _syncState = _PlaylistSyncState.saved;
        _saveError = null;
        _replaceDraftsFromServer(result.latestPlaylists);
        _lastSavedUrls = _draftUrls;
      });
      if (closeAfterSuccess) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
      return;
    }
    final latestPlaylists = result.latestPlaylists;
    setState(() {
      _saving = false;
      _syncState = _PlaylistSyncState.error;
      if (latestPlaylists != null) {
        _replaceDraftsFromServer(latestPlaylists);
        _lastSavedUrls = _draftUrls;
        _editingIndex = null;
        _urlController.clear();
        _inputError = null;
      }
      final message = result.message?.trim() ?? '';
      _saveError = message.isEmpty
          ? 'Çalma listeleri güncellenemedi. Lütfen tekrar dene.'
          : message;
    });
    if (latestPlaylists != null) _urlFocusNode.unfocus();
  }

  void _replaceDraftsFromServer(List<SpotifyPlaylistPreview>? latestPlaylists) {
    if (latestPlaylists == null) return;
    final ordered = [...latestPlaylists]
      ..sort((a, b) => a.position.compareTo(b.position));
    _drafts
      ..clear()
      ..addAll(
        ordered.map(
          (playlist) => _PlaylistDraft(
            spotifyUrl: playlist.spotifyUrl,
            preview: playlist,
          ),
        ),
      );
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_saveError == null) {
      await _flushAutoSave(closeAfterSuccess: true);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111A2A),
        title: const Text('Kaydedilmemiş değişiklikler'),
        content: const Text(
          'Değişiklikler kaydedilemedi. Çıkarsan son düzenlemelerin silinir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Değişiklikleri Sil'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }
}

bool _sameUrls(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

enum _PlaylistSyncState { idle, pending, saving, saved, error }

class _PlaylistSyncNotice extends StatelessWidget {
  const _PlaylistSyncNotice({
    required this.state,
    required this.errorMessage,
    required this.onRetry,
  });

  final _PlaylistSyncState state;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (message, foreground, background, border) = switch (state) {
      _PlaylistSyncState.pending => (
        'Değişiklikler otomatik kaydedilecek',
        const Color(0xFFD7B5F7),
        const Color(0x172E1F43),
        const Color(0x553E2B55),
      ),
      _PlaylistSyncState.saving => (
        'Kaydediliyor…',
        const Color(0xFFD7B5F7),
        const Color(0x172E1F43),
        const Color(0x553E2B55),
      ),
      _PlaylistSyncState.saved => (
        'Kaydedildi',
        const Color(0xFF68D9A5),
        const Color(0x1420A76A),
        const Color(0x4436C98B),
      ),
      _PlaylistSyncState.error => (
        errorMessage?.trim().isNotEmpty == true
            ? errorMessage!.trim()
            : 'Çalma listeleri güncellenemedi.',
        const Color(0xFFFF9AA1),
        const Color(0x18E55C68),
        const Color(0x55E55C68),
      ),
      _PlaylistSyncState.idle => (
        '',
        const Color(0xFF9CA7B8),
        Colors.transparent,
        Colors.transparent,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(state),
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            if (state == _PlaylistSyncState.saving)
              SizedBox.square(
                key: const Key('listener-playlist-saving'),
                dimension: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: foreground,
                ),
              )
            else
              Icon(
                state == _PlaylistSyncState.saved
                    ? Icons.cloud_done_outlined
                    : state == _PlaylistSyncState.error
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_upload_outlined,
                size: 17,
                color: foreground,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                key: state == _PlaylistSyncState.error
                    ? const Key('listener-playlist-save-error')
                    : null,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 6),
              TextButton(
                key: const Key('listener-playlist-save-retry'),
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaylistDraft {
  const _PlaylistDraft({required this.spotifyUrl, required this.preview});

  final String spotifyUrl;
  final SpotifyPlaylistPreview? preview;
}

enum _PlaylistDraftAction { edit, moveUp, moveDown, delete }

class _PlaylistDraftTile extends StatelessWidget {
  const _PlaylistDraftTile({
    required this.draft,
    required this.index,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final _PlaylistDraft draft;
  final int index;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final preview = draft.preview;
    return Container(
      key: Key('listener-playlist-draft-$index'),
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF273449)),
      ),
      child: Row(
        children: [
          _DraftArtwork(preview: preview),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preview?.title ?? 'Spotify çalma listesi',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  preview == null
                      ? 'Kaydedilince Spotify’dan doğrulanacak'
                      : 'Spotify · Profilde ${index + 1}. sıra',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9CA7B8),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<_PlaylistDraftAction>(
            key: Key('listener-playlist-draft-menu-$index'),
            enabled: enabled,
            tooltip: 'Çalma listesi seçenekleri',
            onSelected: (action) {
              switch (action) {
                case _PlaylistDraftAction.edit:
                  onEdit();
                case _PlaylistDraftAction.moveUp:
                  onMoveUp?.call();
                case _PlaylistDraftAction.moveDown:
                  onMoveDown?.call();
                case _PlaylistDraftAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _PlaylistDraftAction.edit,
                child: Text('Bağlantıyı değiştir'),
              ),
              PopupMenuItem(
                value: _PlaylistDraftAction.moveUp,
                enabled: onMoveUp != null,
                child: const Text('Yukarı taşı'),
              ),
              PopupMenuItem(
                value: _PlaylistDraftAction.moveDown,
                enabled: onMoveDown != null,
                child: const Text('Aşağı taşı'),
              ),
              const PopupMenuItem(
                value: _PlaylistDraftAction.delete,
                child: Text('Kaldır'),
              ),
            ],
          ),
          SizedBox.square(
            key: Key('listener-playlist-drag-$index'),
            dimension: 48,
            child: const Icon(
              Icons.drag_indicator_rounded,
              color: Color(0xFF8490A3),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftArtwork extends StatelessWidget {
  const _DraftArtwork({required this.preview});

  final SpotifyPlaylistPreview? preview;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preview?.coverImageUrl;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox.square(
        dimension: 58,
        child: imageUrl == null
            ? const _DraftArtworkFallback()
            : AppCachedNetworkImage(
                imageUrl: imageUrl,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                cacheWidth: (116 * pixelRatio).round(),
                errorBuilder: (_) => const _DraftArtworkFallback(),
              ),
      ),
    );
  }
}

class _DraftArtworkFallback extends StatelessWidget {
  const _DraftArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF35223F), Color(0xFF202A3B)],
        ),
      ),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.spotify,
          color: Color(0xFF1ED760),
          size: 24,
        ),
      ),
    );
  }
}

class _PlaylistManagerEmpty extends StatelessWidget {
  const _PlaylistManagerEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.spotify,
              color: Color(0xFF1ED760),
              size: 38,
            ),
            SizedBox(height: 14),
            Text(
              'Henüz çalma listesi eklemedin',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Spotify’daki herkese açık bir listenin bağlantısını yukarıya yapıştır.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9CA7B8),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
