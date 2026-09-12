import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/backstage_palette.dart';

/// Musician-only presentation. Upload, playback and engagement stay with the
/// existing profile callbacks; other profile families retain their own UI.
class MusicianAudioUploadCard extends StatelessWidget {
  const MusicianAudioUploadCard({
    super.key,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: BackstagePalette.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: BackstagePalette.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _AudioAccentIcon(icon: Icons.add_rounded, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: BackstagePalette.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.north_east_rounded,
                  color: BackstagePalette.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                color: BackstagePalette.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MusicianAudioCardSurface extends StatelessWidget {
  const MusicianAudioCardSurface({
    super.key,
    required this.title,
    required this.waveform,
    this.trailing,
    this.bottomControls,
    this.actionLabel,
    this.actionColor,
    this.onActionTap,
    this.timeLabel,
  });

  final String title;
  final Widget waveform;
  final Widget? trailing;
  final Widget? bottomControls;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onActionTap;
  final String? timeLabel;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: BackstagePalette.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: BackstagePalette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, 14, trailing == null ? 18 : 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: _AudioAccentIcon(
                  icon: Icons.graphic_eq_rounded,
                  size: 36,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SES KAYDI',
                        style: TextStyle(
                          color: BackstagePalette.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BackstagePalette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        if (actionLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: onActionTap == null
                ? Text(
                    actionLabel!,
                    style: TextStyle(
                      color: actionColor ?? BackstagePalette.textMuted,
                      fontSize: 12,
                    ),
                  )
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: onActionTap,
                      child: Text(
                        actionLabel!,
                        style: TextStyle(color: actionColor),
                      ),
                    ),
                  ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
          child: waveform,
        ),
        if (timeLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              timeLabel!,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: BackstagePalette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (bottomControls != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: bottomControls!,
          )
        else
          const SizedBox(height: 18),
      ],
    ),
  );
}

class MusicianAudioTransport extends StatelessWidget {
  const MusicianAudioTransport({
    super.key,
    required this.isPlaying,
    this.onPlayPause,
    this.onBack10,
    this.onForward10,
  });

  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onBack10;
  final VoidCallback? onForward10;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: '10 saniye geri',
        onPressed: onBack10,
        color: BackstagePalette.textMuted,
        disabledColor: BackstagePalette.textMuted.withValues(alpha: .35),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.replay_10_rounded, size: 24),
      ),
      const SizedBox(width: 20),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppColors.brandGradient),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.2),
          child: Material(
            color: BackstagePalette.surfaceRaised,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: isPlaying ? 'Duraklat' : 'Oynat',
              onPressed: onPlayPause,
              color: BackstagePalette.textPrimary,
              constraints: const BoxConstraints.tightFor(width: 54, height: 54),
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 30,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 20),
      IconButton(
        tooltip: '10 saniye ileri',
        onPressed: onForward10,
        color: BackstagePalette.textMuted,
        disabledColor: BackstagePalette.textMuted.withValues(alpha: .35),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.forward_10_rounded, size: 24),
      ),
    ],
  );
}

class _AudioAccentIcon extends StatelessWidget {
  const _AudioAccentIcon({required this.icon, required this.size});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BackstagePalette.surfaceRaised,
          borderRadius: BorderRadius.circular(size * .3 - 1),
        ),
        child: Icon(icon, size: size * .5, color: BackstagePalette.textPrimary),
      ),
    ),
  );
}

String musicianAudioTimeLabel(Duration position, int? durationSeconds) {
  String format(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  final total = durationSeconds != null && durationSeconds > 0
      ? durationSeconds
      : null;
  final elapsed = position.inSeconds.clamp(0, total ?? 2147483647);
  return '${format(elapsed)} / ${total == null ? '—:—' : format(total)}';
}
