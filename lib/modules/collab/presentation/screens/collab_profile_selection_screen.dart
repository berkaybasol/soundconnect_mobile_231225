import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_actor.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';

class CollabProfileSelectionScreen extends StatefulWidget {
  const CollabProfileSelectionScreen({
    required this.actors,
    required this.wantedType,
    this.initialActor,
    this.showBottomNavigation = true,
    super.key,
  });

  final List<CollabActor> actors;
  final CollabProfileKind wantedType;
  final CollabActor? initialActor;
  final bool showBottomNavigation;

  @override
  State<CollabProfileSelectionScreen> createState() =>
      _CollabProfileSelectionScreenState();
}

class _CollabProfileSelectionScreenState
    extends State<CollabProfileSelectionScreen> {
  CollabActor? _selectedActor;

  List<CollabActor> get _eligibleActors => widget.actors
      .where((actor) => actor.profileType == widget.wantedType)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final eligible = _eligibleActors;
    final initial = widget.initialActor;
    _selectedActor =
        initial != null &&
            eligible.any((actor) => actor.actorId == initial.actorId)
        ? initial
        : eligible.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actors = _eligibleActors;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Seç')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                children: [
                  Text(
                    'Başvuruda kullanacağın ${widget.wantedType.label.toLowerCase()} profilini seç.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 25),
                  const CollabSectionTitle('Uygun Profillerim'),
                  const SizedBox(height: 11),
                  if (actors.isEmpty)
                    _EmptyProfilesCard(wantedType: widget.wantedType)
                  else
                    ...actors.map(
                      (actor) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SelectableProfileCard(
                          actor: actor,
                          selected: actor.actorId == _selectedActor?.actorId,
                          onTap: () => setState(() => _selectedActor = actor),
                        ),
                      ),
                    ),
                  const SizedBox(height: 9),
                  const _ProfileInfoBanner(),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: CollabPrimaryAction(
                key: const ValueKey<String>('collab-profile-continue'),
                label: 'Devam Et',
                onPressed: _selectedActor == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedActor),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? ProfilePublicBottomBar(currentIndex: 1)
          : null,
    );
  }
}

class _SelectableProfileCard extends StatelessWidget {
  const _SelectableProfileCard({
    required this.actor,
    required this.selected,
    required this.onTap,
  });

  final CollabActor actor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: actor.displayName,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: CollabGradientFrame(
          highlighted: selected,
          radius: 20,
          strokeWidth: selected ? 1.5 : 1,
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CollabIdentityAvatar(
                initials: actor.initials,
                profileKind: actor.profileType,
                avatarUrl: actor.avatarUrl,
                size: 72,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            actor.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SelectionIndicator(selected: selected),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      actor.profileType.label,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Divider(height: 1, color: theme.dividerColor),
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _ProfileMetric(
                          icon: Icons.star_rounded,
                          label: 'Puan',
                          value: actor.reviewCount == 0
                              ? 'Yeni'
                              : actor.rating.toStringAsFixed(1),
                          supporting: actor.reviewCount == 0
                              ? null
                              : '${actor.reviewCount} yorum',
                        ),
                        _ProfileMetric(
                          icon: Icons.work_outline_rounded,
                          label: 'Tamamlanan İş',
                          value: '${actor.completedJobCount}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? AppColors.socialPink
              : Theme.of(context).colorScheme.onSurfaceVariant,
          width: 2,
        ),
      ),
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppColors.brandGradient),
              ),
            )
          : null,
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.supporting,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? supporting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.socialPink, size: 19),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 9.5,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (supporting != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    supporting!,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileInfoBanner extends StatelessWidget {
  const _ProfileInfoBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabGradientFrame(
      highlighted: true,
      radius: 18,
      strokeWidth: 1,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.socialPurple),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Başvurun seçtiğin profil ile gönderilecek.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Profil bilgilerin karşı tarafa görünür; telefon numaran yalnızca başvurunun taraflarıyla paylaşılır.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
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

class _EmptyProfilesCard extends StatelessWidget {
  const _EmptyProfilesCard({required this.wantedType});

  final CollabProfileKind wantedType;

  @override
  Widget build(BuildContext context) {
    return CollabGradientFrame(
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Text(
        'Bu ilana başvurabilecek bir ${wantedType.label.toLowerCase()} profilin bulunmuyor.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }
}
