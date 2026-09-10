part of 'overthinking_feed_screen.dart';

class _MusicChip extends StatefulWidget {
  const _MusicChip({super.key, required this.post});
  final OverthinkingPost post;
  @override
  State<_MusicChip> createState() => _MusicChipState();
}

class _MusicChipState extends State<_MusicChip> {
  late Future<SpotifyTrackPreview?> _trackFuture = _loadTrack();

  @override
  void didUpdateWidget(covariant _MusicChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.spotifyTrackUrl != widget.post.spotifyTrackUrl ||
        oldWidget.post.spotifyTrackName != widget.post.spotifyTrackName) {
      _trackFuture = _loadTrack();
    }
  }

  Future<SpotifyTrackPreview?> _loadTrack() async {
    if (widget.post.spotifyTrackName?.trim().isNotEmpty == true) return null;
    final uri = Uri.tryParse(widget.post.spotifyTrackUrl ?? '');
    if (uri == null || uri.host != 'open.spotify.com') return null;
    final segments = uri.pathSegments;
    final index = segments.indexOf('track');
    if (index < 0 || index + 1 >= segments.length) return null;
    final result = await serviceLocator<SpotifyRepository>().getTracksByIds([
      segments[index + 1],
    ]);
    return result.isSuccess && result.data?.isNotEmpty == true
        ? result.data!.first
        : null;
  }

  Future<void> _openSpotify(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'open.spotify.com') {
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Spotify açılamadı');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: const Text(
              'Spotify açılamadı. Daha sonra yeniden deneyebilirsin.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final url = post.spotifyTrackUrl?.trim() ?? '';
    return FutureBuilder<SpotifyTrackPreview?>(
      future: _trackFuture,
      builder: (context, snapshot) {
        final title = post.spotifyTrackName?.trim();
        final artist = post.spotifyArtistName?.trim();
        final fallback = post.bandTrackId != null
            ? 'Grubun paylaştığı parça'
            : 'Müzisyenin paylaştığı parça';
        return Material(
          color: OverthinkingPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: url.isEmpty ? null : () => _openSpotify(url),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  _SpotifyArtwork(
                    url:
                        post.spotifyAlbumImageUrl ??
                        snapshot.data?.albumImageUrl,
                    size: 44,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title?.isNotEmpty == true
                              ? title!
                              : snapshot.data?.name ??
                                    (url.isNotEmpty
                                        ? 'Spotify parçası'
                                        : fallback),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: OverthinkingPalette.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artist?.isNotEmpty == true
                              ? artist!
                              : snapshot.data?.artistNames.join(', ') ??
                                    'Bu yazıya eşlik ediyor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: OverthinkingPalette.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (url.isNotEmpty)
                    FaIcon(
                      FontAwesomeIcons.spotify,
                      size: 20,
                      color: AppColors.spotifyGreen,
                    )
                  else
                    const Icon(
                      Icons.music_note_rounded,
                      size: 20,
                      color: OverthinkingPalette.lilac,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpotifyArtwork extends StatelessWidget {
  const _SpotifyArtwork({required this.url, required this.size});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final safeUrl = trustedSpotifyArtworkUrl(url);
    const fallback = Icon(
      Icons.music_note_rounded,
      color: OverthinkingPalette.lilac,
      size: 22,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OverthinkingPalette.lilac.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(9),
      ),
      clipBehavior: Clip.antiAlias,
      child: safeUrl != null
          ? Image.network(
              safeUrl,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              cacheHeight: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({required this.track, required this.onTap, this.trailing});
  final SpotifyTrackPreview track;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _SpotifyArtwork(url: track.albumImageUrl, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: OverthinkingPalette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track.artistNames.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: OverthinkingPalette.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ??
              const Icon(
                Icons.add_circle_outline_rounded,
                color: OverthinkingPalette.accent,
                size: 21,
              ),
        ],
      ),
    ),
  );
}

class _OverthinkingSpotifyPickerSheet extends StatefulWidget {
  const _OverthinkingSpotifyPickerSheet();
  @override
  State<_OverthinkingSpotifyPickerSheet> createState() =>
      _OverthinkingSpotifyPickerSheetState();
}

class _OverthinkingSpotifyPickerSheetState
    extends State<_OverthinkingSpotifyPickerSheet> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  int _searchToken = 0;
  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<SpotifyTrackPreview> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    ++_searchToken; // Invalidate a response as soon as its query changes.
    setState(() {
      _results = const [];
      _error = null;
      _loading = false;
      _searched = false;
    });
    if (value.trim().length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 320), _search);
    }
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final query = _queryController.text.trim();
    final token = ++_searchToken;
    if (query.length < 2) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await serviceLocator<SpotifyRepository>().searchTracks(
      query,
      limit: 10,
    );
    if (!mounted || token != _searchToken) return;
    setState(() {
      _loading = false;
      _searched = true;
      _results = result.isSuccess ? result.data ?? [] : [];
      _error = result.isSuccess
          ? null
          : result.error?.message ?? 'Şarkılar getirilemedi.';
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height * .76 -
                    MediaQuery.viewInsetsOf(context).bottom)
                .clamp(220.0, 680.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OverthinkingPalette.border,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 23),
              const OverthinkingEyebrow(
                'Spotify',
                color: OverthinkingPalette.lilac,
              ),
              const SizedBox(height: 8),
              const Text(
                'Şarkı seç',
                style: TextStyle(
                  color: OverthinkingPalette.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('overthinking-spotify-search'),
                controller: _queryController,
                onChanged: _onChanged,
                onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Şarkı veya sanatçı ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: OverthinkingPalette.surfaceRaised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: OverthinkingPalette.lilac,
                ),
              Expanded(
                child: _results.isNotEmpty
                    ? ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: OverthinkingPalette.border,
                        ),
                        itemBuilder: (context, index) => _TrackTile(
                          track: _results[index],
                          onTap: () =>
                              Navigator.of(context).pop(_results[index]),
                        ),
                      )
                    : ListView(
                        children: [
                          if (!_loading)
                            OverthinkingEmptyState(
                              icon: _error != null
                                  ? Icons.wifi_off_rounded
                                  : Icons.music_note_outlined,
                              title: _error != null
                                  ? 'Şarkılara ulaşamadık'
                                  : _searched
                                  ? 'Bu aramada şarkı yok'
                                  : 'Yazına bir şarkı eşlik etsin.',
                              message:
                                  _error ??
                                  (_searched
                                      ? 'Başka bir şarkı ya da sanatçı adı deneyebilirsin.'
                                      : 'Aramak için en az iki karakter yaz.'),
                              action: _error != null
                                  ? TextButton(
                                      onPressed: _search,
                                      child: const Text('Yeniden dene'),
                                    )
                                  : null,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
