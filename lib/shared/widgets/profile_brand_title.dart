import 'package:flutter/material.dart';

/// Compact horizontal brand mark shared by owner and public profile app bars.
class ProfileBrandTitle extends StatelessWidget {
  const ProfileBrandTitle({super.key});

  @override
  Widget build(BuildContext context) => ClipRect(
    // The bundled image has large transparent top/bottom margins. Fit its
    // width and clip those margins instead of shrinking the visible wordmark.
    child: SizedBox(
      width: 212,
      height: 40,
      child: Image.asset(
        'assets/Logoyanyana.png',
        fit: BoxFit.fitWidth,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        semanticLabel: 'SoundConnect',
      ),
    ),
  );
}
