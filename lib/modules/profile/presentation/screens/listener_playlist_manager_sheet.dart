import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
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

  const ListenerPlaylistSaveResult.success() : this._(succeeded: true);

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

  /// Non-null only when the server rejected a stale optimistic version and
  /// the owner profile was refreshed. Replacing the local drafts prevents a
  /// second tap from silently overwriting another session's playlist update.
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

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  late final List<_PlaylistDraft> _drafts;
  int? _editingIndex;
  String? _inputError;
  String? _saveError;
  bool _saving = false;

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
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving,
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
                                      : () => Navigator.of(context).pop(),
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
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D1421),
                      border: Border(top: BorderSide(color: Color(0xFF202B3A))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_saveError != null) ...[
                          Text(
                            _saveError!,
                            key: const Key('listener-playlist-save-error'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFF8A92),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        _SavePlaylistsButton(
                          saving: _saving,
                          onPressed: _saving ? null : _save,
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
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_editingIndex != null || _urlController.text.trim().isNotEmpty) {
      _commitUrl();
      if (_inputError != null) return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final result = await widget.onSave(
      _drafts.map((draft) => draft.spotifyUrl).toList(growable: false),
    );
    if (!mounted) return;
    if (result.succeeded) {
      setState(() => _saving = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
      return;
    }
    final latestPlaylists = result.latestPlaylists;
    setState(() {
      _saving = false;
      if (latestPlaylists != null) {
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
          ReorderableDragStartListener(
            index: index,
            enabled: enabled,
            child: SizedBox.square(
              key: Key('listener-playlist-drag-$index'),
              dimension: 48,
              child: const Icon(
                Icons.drag_indicator_rounded,
                color: Color(0xFF8490A3),
              ),
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

class _SavePlaylistsButton extends StatelessWidget {
  const _SavePlaylistsButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(
                colors: [Color(0xFF384150), Color(0xFF29313E)],
              )
            : LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(17),
      ),
      child: FilledButton(
        key: const Key('listener-playlist-save'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Değişiklikleri Kaydet',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}
