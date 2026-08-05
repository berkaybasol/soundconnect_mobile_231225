part of 'profile_audio_tab_shared.dart';

class _SpotifyCatalogSheet extends StatefulWidget {
  final ProfileAudioTab tab;
  final BuildContext hostContext;
  final List<SpotifyTrackPreview> initialTracks;

  _SpotifyCatalogSheet({
    required this.tab,
    required this.hostContext,
    required this.initialTracks,
  });

  @override
  State<_SpotifyCatalogSheet> createState() => _SpotifyCatalogSheetState();
}

class _SpotifyCatalogSheetState extends State<_SpotifyCatalogSheet> {
  late final List<SpotifyTrackPreview> _visibleTracks;
  String? _feedbackText;
  bool _feedbackIsError = false;
  bool _persisting = false;

  @override
  void initState() {
    super.initState();
    _visibleTracks = List<SpotifyTrackPreview>.from(widget.initialTracks);
  }

  Future<bool> _saveTracks(
    List<SpotifyTrackPreview> nextTracks, {
    required String failureMessage,
  }) async {
    if (_persisting) return false;
    setState(() {
      _persisting = true;
      _feedbackText = null;
    });
    var saved = false;
    try {
      saved = await widget.tab.persistSpotifyTracks(
        widget.hostContext,
        nextTracks,
      );
    } catch (_) {
      saved = false;
    }
    if (!mounted) return false;
    setState(() => _persisting = false);
    if (!saved) {
      setState(() {
        _feedbackText = failureMessage;
        _feedbackIsError = true;
      });
      return false;
    }
    return true;
  }

  Future<void> _addTrack() async {
    if (_persisting) return;
    await widget.tab._showSpotifyTrackPicker(
      widget.hostContext,
      _visibleTracks,
      onTrackSelected: (selected) async {
        if (_visibleTracks.any((element) => element.id == selected.id)) {
          if (mounted) {
            setState(() {
              _feedbackText = 'Bu parça zaten ekli.';
              _feedbackIsError = true;
            });
          }
          return true;
        }
        final nextTracks = [..._visibleTracks, selected];
        final ok = await _saveTracks(
          nextTracks,
          failureMessage: 'Spotify parçası eklenemedi.',
        );
        if (!ok || !mounted) return false;
        setState(() {
          _visibleTracks.add(selected);
          _feedbackText = 'Spotify parçası eklendi.';
          _feedbackIsError = false;
        });
        return true;
      },
    );
  }

  Future<void> _removeTrack(SpotifyTrackPreview track) async {
    if (_persisting) return;
    final nextTracks = _visibleTracks
        .where((item) => item.id != track.id)
        .toList(growable: false);
    final success = await _saveTracks(
      nextTracks,
      failureMessage: 'Spotify parçası kaldırılamadı.',
    );
    if (!success || !mounted) return;
    setState(() {
      _visibleTracks.removeWhere((item) => item.id == track.id);
      _feedbackText = 'Spotify parçası kaldırıldı.';
      _feedbackIsError = false;
    });
  }

  Future<bool> _confirmDismiss(SpotifyTrackPreview track) async {
    if (_persisting) return false;
    final nextTracks = _visibleTracks
        .where((item) => item.id != track.id)
        .toList(growable: false);
    final success = await _saveTracks(
      nextTracks,
      failureMessage: 'Spotify parçası kaldırılamadı.',
    );
    if (!success || !mounted) return false;
    setState(() {
      _visibleTracks.removeWhere((item) => item.id == track.id);
      _feedbackText = 'Spotify parçası kaldırıldı.';
      _feedbackIsError = false;
    });
    return true;
  }

  Future<void> _reorderTracks(int oldIndex, int newIndex) async {
    if (_persisting ||
        oldIndex < 0 ||
        oldIndex >= _visibleTracks.length ||
        newIndex < 0 ||
        newIndex > _visibleTracks.length) {
      return;
    }
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex) return;

    final previousTracks = List<SpotifyTrackPreview>.from(_visibleTracks);
    setState(() {
      final track = _visibleTracks.removeAt(oldIndex);
      _visibleTracks.insert(newIndex, track);
    });
    final saved = await _saveTracks(
      List<SpotifyTrackPreview>.unmodifiable(_visibleTracks),
      failureMessage:
          'Spotify sıralaması kaydedilemedi. Güncel listeyi kontrol edip tekrar dene.',
    );
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _visibleTracks
          ..clear()
          ..addAll(previousTracks);
      });
      return;
    }
    setState(() {
      _feedbackText = 'Spotify sıralaması kaydedildi.';
      _feedbackIsError = false;
    });
  }

  _SpotifyCatalogTrackTile _trackTile(
    SpotifyTrackPreview track, {
    required bool ownerMode,
    int? reorderIndex,
  }) {
    return _SpotifyCatalogTrackTile(
      track: track,
      ownerMode: ownerMode,
      actionsEnabled: !_persisting,
      reorderIndex: reorderIndex,
      onConfirmDismiss: () => _confirmDismiss(track),
      onOpenOnSpotify: () =>
          widget.tab._openExternalUrl(widget.hostContext, track.spotifyUrl),
      onRemove: () => _removeTrack(track),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.tab.spotifyCatalogTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (widget.tab.ownerMode)
                    IconButton(
                      tooltip: 'Spotify parçası ekle',
                      onPressed: _persisting ? null : _addTrack,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (_persisting) ...[
                SizedBox(height: 8),
                LinearProgressIndicator(
                  key: Key('spotify-catalog-saving'),
                  color: AppColors.spotifyGreen,
                ),
              ],
              if (widget.tab.ownerMode && _visibleTracks.length > 1) ...[
                SizedBox(height: 8),
                Text(
                  'Parçaları tutup sürükleyerek yayın sırasını değiştirebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
              if (_feedbackText != null) ...[
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _feedbackIsError
                        ? Color(0xFF3A1F1F)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _feedbackIsError
                          ? Color(0xFF8B3A3A)
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Text(
                    _feedbackText!,
                    style: TextStyle(
                      color: _feedbackIsError
                          ? Color(0xFFFFB4B4)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 12),
              Flexible(child: _buildTrackList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackList() {
    if (_visibleTracks.isEmpty) {
      return Center(
        child: Text(
          'Henüz Spotify parçası eklemediniz.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (!widget.tab.ownerMode) {
      return ListView.separated(
        itemCount: _visibleTracks.length,
        separatorBuilder: (_, __) => SizedBox(height: 10),
        itemBuilder: (_, index) =>
            _trackTile(_visibleTracks[index], ownerMode: false),
      );
    }
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: _visibleTracks.length,
      onReorder: _reorderTracks,
      itemBuilder: (_, index) {
        final track = _visibleTracks[index];
        return Padding(
          key: ValueKey('spotify-order-item-${track.id}'),
          padding: const EdgeInsets.only(bottom: 10),
          child: _trackTile(track, ownerMode: true, reorderIndex: index),
        );
      },
    );
  }
}
