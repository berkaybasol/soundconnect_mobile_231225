import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../spotify/domain/entities/spotify_playlist_preview.dart';

const _playlistDeepSurface = Color(0xFF070B13);
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: _EmptyPlaylistCallout(onTap: onEdit),
            ),
          )
        else
          Builder(
            builder: (context) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final accessibleLayout = textScale > 1.3;
              return SizedBox(
                key: const Key('listener-playlist-row'),
                height: accessibleLayout ? 78 : 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: playlists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _PlaylistTile(
                    playlist: playlists[index],
                    index: index,
                    width: accessibleLayout ? 196 : 170,
                    artworkSize: accessibleLayout ? 42 : 36,
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
    return Semantics(
      button: onTap != null,
      excludeSemantics: true,
      label: 'Çalma listesi ekle',
      onTap: onTap,
      child: SizedBox.square(
        dimension: 62,
        child: CustomPaint(
          foregroundPainter: const _DashedPlaylistBorderPainter(),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: const Key('listener-playlist-empty-add'),
              onTap: onTap,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(18),
              child: const Center(
                child: Icon(Icons.add_rounded, color: _playlistMuted, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedPlaylistBorderPainter extends CustomPainter {
  const _DashedPlaylistBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.3;
    final bounds = Offset.zero & size;
    final borderBounds = bounds.deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(borderBounds, const Radius.circular(18)),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: AppColors.brandGradient
            .map((color) => color.withValues(alpha: 0.72))
            .toList(growable: false),
      ).createShader(bounds);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 7).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPlaylistBorderPainter oldDelegate) {
    return false;
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.index,
    required this.width,
    required this.artworkSize,
    required this.onTap,
  });

  final SpotifyPlaylistPreview playlist;
  final int index;
  final double width;
  final double artworkSize;
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
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surfaceContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    key: Key('listener-playlist-artwork-$index'),
                    width: artworkSize,
                    height: artworkSize,
                    padding: const EdgeInsets.all(1.3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: LinearGradient(colors: AppColors.brandGradient),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.socialPurple.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: -3,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7.7),
                      child: ColoredBox(
                        color: _playlistDeepSurface,
                        child: AppCachedNetworkImage(
                          imageUrl: playlist.coverImageUrl,
                          width: artworkSize - 2.6,
                          height: artworkSize - 2.6,
                          fit: BoxFit.cover,
                          cacheWidth: (artworkSize * 2 * pixelRatio).round(),
                          errorBuilder: (_) => const _PlaylistArtworkFallback(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      playlist.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FaIcon(
                    FontAwesomeIcons.spotify,
                    key: Key('listener-playlist-card-spotify-icon-$index'),
                    color: Color(0xFF1ED760),
                    size: 16,
                  ),
                ],
              ),
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
