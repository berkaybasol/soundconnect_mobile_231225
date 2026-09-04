import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../spotify/domain/entities/spotify_playlist_preview.dart';

const _playlistDeepSurface = Color(0xFF070B13);
const _playlistSurface = Color(0xFF101722);
const _playlistBorder = Color(0xFF202B3A);
const _playlistMuted = Color(0xFFA0A9B6);

class ListenerPlaylistSection extends StatelessWidget {
  const ListenerPlaylistSection({
    super.key,
    required this.playlists,
    required this.onPlaylistTap,
    this.onEdit,
    this.showWhenEmpty = false,
  });

  final List<SpotifyPlaylistPreview> playlists;
  final ValueChanged<SpotifyPlaylistPreview> onPlaylistTap;
  final VoidCallback? onEdit;
  final bool showWhenEmpty;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty && !showWhenEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('listener-playlist-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Çalma Listeleri',
                  style: TextStyle(
                    color: Color(0xFFD8DEE8),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              if (onEdit != null)
                TextButton(
                  key: const Key('listener-playlist-edit'),
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    playlists.isEmpty ? 'Ekle' : 'Düzenle',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyPlaylistCallout(onTap: onEdit),
          )
        else
          Builder(
            builder: (context) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final accessibleLayout = textScale > 1.3;
              return SizedBox(
                key: const Key('listener-playlist-row'),
                height: accessibleLayout ? 184 : 126,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: playlists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _PlaylistTile(
                    playlist: playlists[index],
                    index: index,
                    width: accessibleLayout ? 112 : 76,
                    onTap: () => onPlaylistTap(playlists[index]),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _EmptyPlaylistCallout extends StatelessWidget {
  const _EmptyPlaylistCallout({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _playlistSurface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        key: const Key('listener-playlist-empty-add'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _playlistBorder),
          ),
          child: const Row(
            children: [
              _SpotifyMarkBox(),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Müziğini profiline taşı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Spotify çalma listesi bağlantısı ekle.',
                      style: TextStyle(
                        color: _playlistMuted,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_rounded, color: Color(0xFFF47C7C), size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotifyMarkBox extends StatelessWidget {
  const _SpotifyMarkBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF15251F),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.spotifyGreen.withValues(alpha: 0.26),
        ),
      ),
      child: const FaIcon(
        FontAwesomeIcons.spotify,
        color: Color(0xFF1ED760),
        size: 21,
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.index,
    required this.width,
    required this.onTap,
  });

  final SpotifyPlaylistPreview playlist;
  final int index;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${playlist.title}, Spotify’da aç',
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('listener-playlist-$index'),
            onTap: onTap,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(1.3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: AppColors.brandGradient),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.socialPurple.withValues(alpha: 0.2),
                          blurRadius: 16,
                          spreadRadius: -5,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.7),
                      child: ColoredBox(
                        color: _playlistDeepSurface,
                        child: AppCachedNetworkImage(
                          imageUrl: playlist.coverImageUrl,
                          width: 73,
                          height: 73,
                          fit: BoxFit.cover,
                          cacheWidth: (146 * pixelRatio).round(),
                          errorBuilder: (_) => const _PlaylistArtworkFallback(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  playlist.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.spotify,
                      color: Color(0xFF1ED760),
                      size: 10,
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Spotify',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _playlistMuted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistArtworkFallback extends StatelessWidget {
  const _PlaylistArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF32213D), Color(0xFF1B2435), Color(0xFF101722)],
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note_rounded, color: Color(0xFFD98BDC)),
      ),
    );
  }
}
