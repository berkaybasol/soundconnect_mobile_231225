part of 'musician_public_profile_screen.dart';

class _SocialButtonRow extends StatelessWidget {
  final MusicianProfile profile;

  _SocialButtonRow({required this.profile});

  Future<void> _launchExternalUrl(BuildContext context, String? url) async {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final String normalized = trimmed.contains('://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gecersiz link')));
      return;
    }

    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Link acilamadi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialButtons = <Widget>[];
    if (_isSocialUrlUsable(profile.soundcloudUrl)) {
      socialButtons.add(
        _SocialPill(
          icon: FontAwesomeIcons.soundcloud,
          active: true,
          onTap: () => _launchExternalUrl(context, profile.soundcloudUrl),
        ),
      );
    }
    if (_isSocialUrlUsable(profile.instagramUrl)) {
      socialButtons.add(
        _SocialPill(
          icon: FontAwesomeIcons.instagram,
          active: true,
          onTap: () => _launchExternalUrl(context, profile.instagramUrl),
        ),
      );
    }
    if (_isSocialUrlUsable(profile.youtubeUrl)) {
      socialButtons.add(
        _SocialPill(
          icon: FontAwesomeIcons.youtube,
          active: true,
          onTap: () => _launchExternalUrl(context, profile.youtubeUrl),
        ),
      );
    }
    if (_isSocialUrlUsable(profile.spotifyEmbedUrl)) {
      socialButtons.add(
        _SocialPill(
          icon: FontAwesomeIcons.spotify,
          active: true,
          onTap: () => _launchExternalUrl(context, profile.spotifyEmbedUrl),
        ),
      );
    }

    if (socialButtons.isEmpty) return SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: socialButtons,
    );
  }
}

bool _isSocialUrlUsable(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) return false;
  return value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('www.');
}

class _SocialPill extends StatefulWidget {
  final FaIconData icon;
  final bool active;
  final VoidCallback? onTap;

  _SocialPill({required this.icon, required this.active, this.onTap});

  @override
  State<_SocialPill> createState() => _SocialPillState();
}

class _SocialPillState extends State<_SocialPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.socialOrange,
        AppColors.socialPink,
        AppColors.socialPurple,
      ],
    );

    final borderColor = _pressed
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).dividerColor;
    final shadowOpacity = _pressed ? 0.12 : 0.05;

    return GestureDetector(
      onTapDown: widget.active ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.active
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: widget.active ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: 64,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: shadowOpacity),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => iconGradient.createShader(bounds),
              child: FaIcon(widget.icon, size: 20, color: AppColors.white),
            ),
          ),
        ),
      ),
    );
  }
}
