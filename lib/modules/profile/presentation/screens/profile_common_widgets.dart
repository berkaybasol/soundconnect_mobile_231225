import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import 'profile_section_support.dart';

class ProfileIdentityHeader extends StatelessWidget {
  final String? username;
  final String? secondaryText;
  final String fallbackName;

  const ProfileIdentityHeader({
    super.key,
    required this.username,
    required this.secondaryText,
    this.fallbackName = 'Kullanıcı',
  });

  @override
  Widget build(BuildContext context) {
    final name = username?.trim().isNotEmpty == true
        ? username!.trim()
        : fallbackName;
    final resolvedSecondary = secondaryText?.trim();

    return Column(
      children: [
        GradientText(
          text: name,
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.brandGradient,
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (resolvedSecondary != null && resolvedSecondary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            resolvedSecondary,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class ProfileFollowerSummary extends StatelessWidget {
  final int? followersCount;
  final int? followingCount;
  final String followersLabel;
  final String followingLabel;
  final bool showFollowing;

  const ProfileFollowerSummary({
    super.key,
    required this.followersCount,
    required this.followingCount,
    this.followersLabel = 'Takipçi',
    this.followingLabel = 'Takip',
    this.showFollowing = true,
  });

  String _formatCount(int? value, String label) {
    if (value == null) return '... $label';
    return '$value $label';
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      ProfilePillBadge(text: _formatCount(followersCount, followersLabel)),
    ];
    if (showFollowing) {
      children.add(const SizedBox(width: 12));
      children.add(
        ProfilePillBadge(text: _formatCount(followingCount, followingLabel)),
      );
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
  }
}

class ProfileTopSection extends StatelessWidget {
  final Widget header;
  final Widget identity;
  final Widget followerSummary;
  final Widget actionButtons;
  final Widget bioSection;
  final Widget? afterBio;

  const ProfileTopSection({
    super.key,
    required this.header,
    required this.identity,
    required this.followerSummary,
    required this.actionButtons,
    required this.bioSection,
    this.afterBio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Align(alignment: Alignment.center, child: header),
        const SizedBox(height: 16),
        identity,
        const SizedBox(height: 14),
        followerSummary,
        const SizedBox(height: 12),
        actionButtons,
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: bioSection,
        ),
        if (afterBio != null) ...[const SizedBox(height: 12), afterBio!],
      ],
    );
  }
}

class EditableBioSection extends StatefulWidget {
  final String? bio;
  final bool editable;
  final Future<void> Function(String)? onSave;
  final String emptyText;
  final String addLabel;
  final String hintText;

  const EditableBioSection({
    super.key,
    required this.bio,
    required this.editable,
    required this.onSave,
    this.emptyText = 'Henüz bir açıklama eklenmedi.',
    this.addLabel = 'Açıklama ekle',
    this.hintText = 'Kendinden bahset...',
  });

  @override
  State<EditableBioSection> createState() => _EditableBioSectionState();
}

class _EditableBioSectionState extends State<EditableBioSection> {
  bool _isEditing = false;
  bool _saving = false;
  String _draft = '';

  @override
  void didUpdateWidget(covariant EditableBioSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.bio != widget.bio) {
      _draft = widget.bio?.trim() ?? '';
    }
  }

  Future<void> _handleSave() async {
    if (widget.onSave == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave!(_draft);
      if (!mounted) return;
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBio = widget.bio?.trim().isNotEmpty == true;
    final resolvedBio = hasBio ? widget.bio!.trim() : '';

    if (!widget.editable) {
      return Text(
        hasBio ? resolvedBio : widget.emptyText,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, height: 1.6),
      );
    }

    if (!_isEditing) {
      if (!hasBio) {
        return TextButton(
          onPressed: () {
            setState(() {
              _draft = '';
              _isEditing = true;
            });
          },
          child: Text(widget.addLabel),
        );
      }

      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 20),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                resolvedBio,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, height: 1.6),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _draft = widget.bio?.trim() ?? '';
                  _isEditing = true;
                });
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.edit, size: 14, color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        TextFormField(
          initialValue: _draft,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.coralAlt),
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (value) => _draft = value,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _isEditing = false),
              child: const Text('İptal'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _saving ? null : _handleSave,
              child: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ],
    );
  }
}

class ProfileSpotifyPreviewCard extends StatelessWidget {
  final double ringSize;

  const ProfileSpotifyPreviewCard({super.key, this.ringSize = 64});

  @override
  Widget build(BuildContext context) {
    const spotifyGradient = [
      Color(0xFF1ED760),
      Color(0xFF1DB954),
      Color(0xFF18A34A),
    ];

    return ProfileAudioPreviewCard(
      title: 'Spotify Preview',
      actionLabel: "Tamamını Spotify'da Dinle",
      actionColor: const Color(0xFF1DB954),
      ringSize: ringSize,
      waveform: const WaveformStub(
        gradientColors: spotifyGradient,
        iconColor: Color(0xFF1ED760),
        playIconColor: Color(0xFF1DB954),
        leading: Icon(
          FontAwesomeIcons.spotify,
          size: 16,
          color: Color(0xFF1DB954),
        ),
        height: 92,
        waveformHeight: 44,
      ),
    );
  }
}

class ProfileAudioPreviewCard extends StatefulWidget {
  final String title;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onTap;
  final VoidCallback? onActionTap;
  final VoidCallback? onDoubleTap;
  final Widget waveform;
  final Widget? bottomControls;
  final double ringSize;

  const ProfileAudioPreviewCard({
    super.key,
    required this.title,
    required this.waveform,
    this.actionLabel,
    this.actionColor,
    this.onTap,
    this.onActionTap,
    this.onDoubleTap,
    this.bottomControls,
    this.ringSize = 64,
  });

  @override
  State<ProfileAudioPreviewCard> createState() =>
      _ProfileAudioPreviewCardState();
}

class _ProfileAudioPreviewCardState extends State<ProfileAudioPreviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );
  late final Animation<double> _heartScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.6,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.08,
        end: 0.84,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.84,
        end: 0.52,
      ).chain(CurveTween(curve: Curves.easeInQuart)),
      weight: 20,
    ),
  ]).animate(_heartController);
  late final Animation<double> _heartOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 30),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 35),
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 35),
  ]).animate(_heartController);
  late final Animation<double> _ringScale = Tween<double>(begin: 0.7, end: 1.9)
      .animate(
        CurvedAnimation(
          parent: _heartController,
          curve: const Interval(0.08, 0.9, curve: Curves.easeOutCubic),
        ),
      );
  late final Animation<double> _ringOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: 0.5), weight: 22),
    TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 0), weight: 78),
  ]).animate(_heartController);

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (widget.onDoubleTap == null) return;
    widget.onDoubleTap?.call();
    _heartController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.actionLabel != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: widget.onActionTap,
                    child: Text(
                      widget.actionLabel!,
                      style: TextStyle(
                        color: widget.actionColor ?? AppColors.textMuted,
                        fontSize: 12,
                        decoration: widget.onActionTap != null
                            ? TextDecoration.underline
                            : null,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                widget.waveform,
                if (widget.bottomControls != null) ...[
                  const SizedBox(height: 8),
                  widget.bottomControls!,
                ],
              ],
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _heartController,
              builder: (context, _) {
                if (_heartController.value == 0) {
                  return const SizedBox.shrink();
                }
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: _ringOpacity.value,
                      child: Transform.scale(
                        scale: _ringScale.value,
                        child: Container(
                          width: widget.ringSize,
                          height: widget.ringSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.coralAlt.withValues(alpha: 0.9),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _heartOpacity.value,
                      child: Transform.scale(
                        scale: _heartScale.value,
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: AppColors.brandGradient,
                            ).createShader(bounds);
                          },
                          child: const Icon(Icons.favorite, size: 76),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _heartOpacity.value * 0.45,
                      child: Transform.scale(
                        scale: _heartScale.value * 1.05,
                        child: const Icon(
                          Icons.favorite,
                          size: 82,
                          color: Color(0x66FF5F8F),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
