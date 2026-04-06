// ignore_for_file: use_build_context_synchronously

part of 'profile_audio_tab_shared.dart';

class _SpotifyCatalogSheet extends StatefulWidget {
  final ProfileAudioTab tab;
  final BuildContext hostContext;
  final List<SpotifyTrackPreview> initialTracks;

  const _SpotifyCatalogSheet({
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
    final selected = await widget.tab._showSpotifyTrackPicker(
      widget.hostContext,
      _visibleTracks,
    );
    if (selected == null || !mounted) return;
    if (_visibleTracks.any((element) => element.id == selected.id)) {
      setState(() {
        _feedbackText = 'Bu parca zaten ekli.';
        _feedbackIsError = true;
      });
      return;
    }
    final nextTracks = [..._visibleTracks, selected];
    final ok = await _saveTracks(
      nextTracks,
      failureMessage: 'Spotify parcasi eklenemedi.',
    );
    if (!ok || !mounted) return;
    setState(() {
      _visibleTracks.add(selected);
      _feedbackText = 'Spotify parcasi eklendi.';
      _feedbackIsError = false;
    });
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
      _feedbackText = 'Spotify parcasi kaldirildi.';
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
      _feedbackText = 'Spotify parcasi kaldirildi.';
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sanatcinin Spotify Katalogu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (widget.tab.ownerMode)
                    IconButton(
                      tooltip: 'Spotify parcasi ekle',
                      onPressed: _addTrack,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              if (_feedbackText != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _feedbackIsError
                        ? const Color(0xFF3A1F1F)
                        : AppColors.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _feedbackIsError
                          ? const Color(0xFF8B3A3A)
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    _feedbackText!,
                    style: TextStyle(
                      color: _feedbackIsError
                          ? const Color(0xFFFFB4B4)
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: _visibleTracks.isEmpty
                    ? const Center(
                        child: Text(
                          'Henuz Spotify parcasi eklemediniz.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _visibleTracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
