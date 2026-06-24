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

  @override
  void initState() {
    super.initState();
    _visibleTracks = List<SpotifyTrackPreview>.from(widget.initialTracks);
  }

  Future<bool> _saveTracks(
    List<SpotifyTrackPreview> nextTracks, {
    required String failureMessage,
  }) async {
    final nextTrackIds = nextTracks.map((e) => e.id).toList();
    final nextTrackMaps = nextTracks
        .map((track) => widget.tab._trackToSaveJson(track))
        .toList();
    final cubit = widget.hostContext.read<MusicianProfileCubit>();
    await cubit.updateProfile(
      MusicianProfileSaveRequest(
        spotifyTrackIds: nextTrackIds,
        spotifyTracks: nextTrackMaps,
      ),
    );
    if (!mounted) return false;
    if (cubit.state.status == MusicianProfileStatus.failure) {
      setState(() {
        _feedbackText = cubit.state.error?.message ?? failureMessage;
        _feedbackIsError = true;
      });
      return false;
    }
    return true;
  }

  Future<void> _addTrack() async {
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
    final success = await widget.tab._removeSpotifyTrackFromCatalog(
      widget.hostContext,
      track.id,
      sourceTracks: _visibleTracks,
      showSnackbar: false,
    );
    if (!success || !mounted) return;
    setState(() {
      _visibleTracks.removeWhere((e) => e.id == track.id);
      _feedbackText = 'Spotify parçası kaldırıldı.';
      _feedbackIsError = false;
    });
  }

  Future<bool> _confirmDismiss(SpotifyTrackPreview track) async {
    final success = await widget.tab._removeSpotifyTrackFromCatalog(
      widget.hostContext,
      track.id,
      sourceTracks: _visibleTracks,
      showSnackbar: false,
    );
    if (!success || !mounted) return false;
    setState(() {
      _visibleTracks.removeWhere((e) => e.id == track.id);
      _feedbackText = 'Spotify parçası kaldırıldı.';
      _feedbackIsError = false;
    });
    return true;
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
                      'Sanatçının Spotify Kataloğu',
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
                      onPressed: _addTrack,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
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
              Flexible(
                child: _visibleTracks.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz Spotify parçası eklemediniz.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _visibleTracks.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final track = _visibleTracks[index];
                          return _SpotifyCatalogTrackTile(
                            track: track,
                            ownerMode: widget.tab.ownerMode,
                            onConfirmDismiss: () => _confirmDismiss(track),
                            onOpenOnSpotify: () => widget.tab._openExternalUrl(
                              widget.hostContext,
                              track.spotifyUrl,
                            ),
                            onRemove: () => _removeTrack(track),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
