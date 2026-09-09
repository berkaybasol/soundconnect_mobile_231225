import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import 'listener_profile_header.dart';

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
    this.privatePlansAction,
  });

  final String username;
  final String? profilePictureUrl;
  final bool owner;
  final bool busy;
  final Future<void> Function() onRefresh;
  final VoidCallback? onEditAvatar;
  final VoidCallback? onSwitchToStandard;
  final VoidCallback? onMessage;
  final Widget? privatePlansAction;

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
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: Key(
          owner
              ? 'listener-owner-ghost-content'
              : 'listener-public-ghost-content',
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 34),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListenerProfileHeader(
                    username: displayUsername,
                    imageUrl: profilePictureUrl,
                    editableAvatar: owner,
                    avatarBusy: busy,
                    onEditAvatar: onEditAvatar,
                    editAvatarKey: const Key('listener-ghost-edit-avatar'),
                    avatarMarkerIcon: owner
                        ? null
                        : Icons.visibility_off_outlined,
                    identityBadge: const GhostProfileBadge(
                      compact: false,
                      showLabel: true,
                    ),
                    actionButtons: const SizedBox.shrink(),
                    bio: owner
                        ? ''
                        : 'Bu kullanıcı SoundConnect’i daha az görünür kullanmayı tercih ediyor.',
                    afterBio: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: owner
                          ? _OwnerGhostStatusCard(
                              busy: busy,
                              onSwitchToStandard: onSwitchToStandard,
                            )
                          : const _PublicLimitedVisibilityCard(),
                    ),
                  ),
                  if (owner && privatePlansAction != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: privatePlansAction!,
                    ),
                  ],
                  if (!owner && onMessage != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: GradientOutlineButton(
                          label: 'Mesaj Gönder',
                          loading: busy,
                          onPressed: busy ? null : onMessage,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          horizontalPadding: 12,
                          strokeWidth: 0.7,
                          maxLines: null,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _GhostFootnote(owner: owner),
                    ),
                  ],
                ],
              ),
            ),
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
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Container(
      key: const Key('listener-owner-ghost-status-card'),
      constraints: const BoxConstraints(minHeight: 252),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
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
                final icon = _GhostAssetHalo(dimension: stackContent ? 64 : 72);
                const copy = _OwnerGhostStatusCopy();

                if (stackContent) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [icon, const SizedBox(height: 16), copy],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 16),
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
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  horizontalPadding: 12,
                  strokeWidth: 0.7,
                  maxLines: null,
                  leading: const Icon(Icons.visibility_outlined, size: 18),
                ),
              ),
            ),
          ],
        ],
      ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GhostStatusDot(),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                'HAYALET PROFİL AKTİF',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.65,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Hayalet modun açık',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 17,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'SoundConnect’in bütün özelliklerinden faydalanabilirsin ancak profil içeriğin saklı kalır ve bu moddayken yeni profil içeriği kaydedilmez.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12.5,
            height: 1.48,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 7,
          runSpacing: 8,
          children: [
            _GhostStatusPill(
              icon: Icons.lock_outline_rounded,
              label: 'İçerikler gizli',
            ),
            _GhostStatusPill(
              icon: Icons.person_off_outlined,
              label: 'Takipçi alımı kapalı',
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10.5,
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Paylaşımları, takip bağlantıları ve profil içerikleri gösterilmez.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
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
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 14,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            owner
                ? 'Hayalet moda geçerken kaldırılan takipçiler otomatik olarak geri gelmez.'
                : 'Bu profile doğrudan mesaj gönderebilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
