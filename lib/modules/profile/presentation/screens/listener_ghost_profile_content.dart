import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text.dart';
import 'profile_screen_support.dart';

const _ghostDeepSurface = Color(0xFF070B13);
const _ghostSurface = Color(0xFF101A2A);
const _ghostBorder = Color(0xFF24334A);
const _ghostMuted = Color(0xFFA8B2C2);
const _ghostAssetPath = 'assets/ghost (1).png';

class ListenerGhostProfileContent extends StatelessWidget {
  const ListenerGhostProfileContent({
    super.key,
    required this.username,
    required this.profilePictureUrl,
    required this.owner,
    required this.busy,
    required this.onRefresh,
    this.onEditAvatar,
    this.onSwitchToStandard,
    this.onMessage,
  });

  final String username;
  final String? profilePictureUrl;
  final bool owner;
  final bool busy;
  final Future<void> Function() onRefresh;
  final VoidCallback? onEditAvatar;
  final VoidCallback? onSwitchToStandard;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final normalizedUsername = username.trim().replaceFirst(RegExp(r'^@+'), '');
    assert(
      normalizedUsername.isNotEmpty,
      'Ghost listener identity requires an authoritative username.',
    );
    final displayUsername = normalizedUsername.isEmpty
        ? '—'
        : normalizedUsername;
    final displayHandle = normalizedUsername.isEmpty
        ? displayUsername
        : '@$displayUsername';
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _ghostDeepSurface)),
          Positioned(
            top: 90,
            left: -34,
            right: -34,
            child: IgnorePointer(
              child: Icon(
                Icons.visibility_off_outlined,
                size: 270,
                color: Colors.white.withValues(alpha: 0.018),
              ),
            ),
          ),
          ListView(
            key: Key(
              owner
                  ? 'listener-owner-ghost-content'
                  : 'listener-public-ghost-content',
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 34),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GhostAvatar(
                        username: displayUsername,
                        imageUrl: profilePictureUrl,
                        owner: owner,
                        onEdit: busy ? null : onEditAvatar,
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: GradientText(
                          text: displayHandle,
                          gradient: LinearGradient(
                            colors: AppColors.brandGradient,
                          ),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Center(
                        child: GhostProfileBadge(
                          compact: false,
                          showLabel: true,
                        ),
                      ),
                      if (owner) ...[
                        const SizedBox(height: 24),
                        _OwnerGhostStatusCard(
                          busy: busy,
                          onSwitchToStandard: onSwitchToStandard,
                        ),
                      ] else ...[
                        const SizedBox(height: 25),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Bu kullanıcı SoundConnect’i daha az görünür kullanmayı tercih ediyor.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFCCD3DE),
                              fontSize: 12.5,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const _PublicLimitedVisibilityCard(),
                      ],
                      if (!owner && onMessage != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: GradientOutlineButton(
                              label: 'Mesaj Gönder',
                              loading: busy,
                              onPressed: busy ? null : onMessage,
                              backgroundColor: _ghostSurface,
                              leading: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (owner || onMessage != null) ...[
                        const SizedBox(height: 16),
                        _GhostFootnote(owner: owner),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerGhostStatusCard extends StatelessWidget {
  const _OwnerGhostStatusCard({
    required this.busy,
    required this.onSwitchToStandard,
  });

  final bool busy;
  final VoidCallback? onSwitchToStandard;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Container(
      key: const Key('listener-owner-ghost-status-card'),
      constraints: const BoxConstraints(minHeight: 252),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF21172D), Color(0xFF141C2D), Color(0xFF101A28)],
          stops: [0, 0.54, 1],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF704B78)),
        boxShadow: [
          BoxShadow(
            color: AppColors.socialPurple.withValues(alpha: 0.16),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
          const BoxShadow(
            color: Color(0x42000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -68,
            bottom: -88,
            child: IgnorePointer(
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.socialPurple.withValues(alpha: 0.18),
                      AppColors.socialPurple.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 28,
            right: 28,
            child: _GhostCardAccent(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  key: const Key('listener-owner-ghost-status-summary'),
                  container: true,
                  excludeSemantics: true,
                  label:
                      'Hayalet profil aktif. SoundConnect’in bütün özelliklerinden faydalanabilirsin ancak profil içeriğin saklı kalır ve bu moddayken yeni profil içeriği kaydedilmez. Yeni takipçi alımı kapalı.',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stackContent =
                          constraints.maxWidth < 285 || textScale > 1.35;
                      final icon = _GhostAssetHalo(
                        dimension: stackContent ? 82 : 92,
                      );
                      const copy = _OwnerGhostStatusCopy();

                      if (stackContent) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [icon, const SizedBox(height: 18), copy],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          icon,
                          const SizedBox(width: 18),
                          const Expanded(child: copy),
                        ],
                      );
                    },
                  ),
                ),
                if (onSwitchToStandard != null) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: GradientOutlineButton(
                        label: 'Sosyal Profile Dön',
                        loading: busy,
                        onPressed: busy ? null : onSwitchToStandard,
                        backgroundColor: _ghostSurface,
                        leading: const Icon(
                          Icons.visibility_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostCardAccent extends StatelessWidget {
  const _GhostCardAccent();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.coralAlt.withValues(alpha: 0),
            AppColors.socialPink.withValues(alpha: 0.9),
            AppColors.socialPurple.withValues(alpha: 0.9),
            AppColors.socialPurple.withValues(alpha: 0),
          ],
        ),
      ),
      child: const SizedBox(height: 1),
    );
  }
}

class _GhostAssetHalo extends StatelessWidget {
  const _GhostAssetHalo({required this.dimension});

  final double dimension;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dimension,
      height: dimension,
      padding: EdgeInsets.all(dimension * 0.2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF39223F), Color(0xFF202743)],
        ),
        borderRadius: BorderRadius.circular(dimension * 0.3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.socialPink.withValues(alpha: 0.16),
            blurRadius: 20,
            spreadRadius: -3,
          ),
        ],
      ),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ).createShader(bounds),
        child: Image.asset(
          _ghostAssetPath,
          key: const Key('listener-owner-ghost-icon'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _OwnerGhostStatusCopy extends StatelessWidget {
  const _OwnerGhostStatusCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GhostStatusDot(),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                'HAYALET PROFİL AKTİF',
                style: TextStyle(
                  color: Color(0xFFF4B7F0),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.65,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Hayalet modun açık',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'SoundConnect’in bütün özelliklerinden faydalanabilirsin ancak profil içeriğin saklı kalır ve bu moddayken yeni profil içeriği kaydedilmez.',
          style: TextStyle(
            color: Color(0xFFC4CDDA),
            fontSize: 10.5,
            height: 1.48,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(
              child: _GhostStatusPill(
                icon: Icons.lock_outline_rounded,
                label: 'İçerikler gizli',
              ),
            ),
            SizedBox(width: 7),
            Expanded(
              child: _GhostStatusPill(
                icon: Icons.person_off_outlined,
                label: 'Takipçi alımı kapalı',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GhostStatusDot extends StatelessWidget {
  const _GhostStatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.socialPink,
        boxShadow: [
          BoxShadow(
            color: AppColors.socialPink.withValues(alpha: 0.5),
            blurRadius: 7,
          ),
        ],
      ),
    );
  }
}

class _GhostStatusPill extends StatelessWidget {
  const _GhostStatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFFE6A8E7)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD6DCE6),
                  fontSize: 9,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicLimitedVisibilityCard extends StatelessWidget {
  const _PublicLimitedVisibilityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('listener-ghost-limited-visibility'),
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
      decoration: BoxDecoration(
        color: _ghostSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ghostBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.socialPurple.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: AppColors.socialPink,
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Görünürlüğü sınırlı',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Paylaşımları, takip bağlantıları ve profil içerikleri gösterilmez.',
                  style: TextStyle(
                    color: _ghostMuted,
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostFootnote extends StatelessWidget {
  const _GhostFootnote({required this.owner});

  final bool owner;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          owner
              ? Icons.info_outline_rounded
              : Icons.chat_bubble_outline_rounded,
          color: _ghostMuted,
          size: 14,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            owner
                ? 'Hayalet moda geçerken kaldırılan takipçiler otomatik olarak geri gelmez.'
                : 'Bu profile doğrudan mesaj gönderebilirsin.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ghostMuted,
              fontSize: 9.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _GhostAvatar extends StatelessWidget {
  const _GhostAvatar({
    required this.username,
    required this.imageUrl,
    required this.owner,
    required this.onEdit,
  });

  final String username;
  final String? imageUrl;
  final bool owner;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();
    final hasImage = isValidNetworkImageUrl(normalizedUrl);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Center(
      child: SizedBox.square(
        dimension: 116,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF7468),
                      Color(0xFFD851CB),
                      Color(0xFF8238E8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.socialPurple.withValues(alpha: 0.27),
                      blurRadius: 26,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: _ghostDeepSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: hasImage
                            ? AppCachedNetworkImage(
                                imageUrl: normalizedUrl,
                                width: 104,
                                height: 104,
                                fit: BoxFit.cover,
                                cacheWidth: (104 * pixelRatio).round(),
                                errorBuilder: (_) => _GhostAvatarFallback(
                                  initials: _initials(username),
                                ),
                              )
                            : _GhostAvatarFallback(
                                initials: _initials(username),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Semantics(
                button: owner && onEdit != null,
                enabled: owner && onEdit != null,
                label: owner ? 'Profil fotoğrafını düzenle' : 'Hayalet profil',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: Key(
                      owner
                          ? 'listener-ghost-edit-avatar'
                          : 'listener-public-ghost-marker',
                    ),
                    onTap: owner ? onEdit : null,
                    customBorder: const CircleBorder(),
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: Transform.translate(
                          // Keep the established visual overlap while the
                          // complete 48 px interaction target stays inside the
                          // Stack's hit-test bounds.
                          offset: const Offset(5, 5),
                          child: Ink(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: AppColors.brandGradient,
                              ),
                              border: Border.all(
                                color: _ghostDeepSurface,
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x45000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              owner
                                  ? Icons.edit_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostAvatarFallback extends StatelessWidget {
  const _GhostAvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2A54), Color(0xFF27233D), Color(0xFF171B2C)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _initials(String username) {
  final normalized = username.trim();
  if (normalized.isEmpty || normalized == '—') return '?';
  final pieces = normalized
      .split(RegExp(r'[\s._-]+'))
      .where((piece) => piece.isNotEmpty)
      .toList(growable: false);
  if (pieces.length > 1) {
    return '${pieces.first[0]}${pieces.last[0]}'.toUpperCase();
  }
  final first = pieces.first[0].toUpperCase();
  return '$first$first';
}
