import 'package:flutter/material.dart';

import '../../domain/pending_application.dart';

/// The illustrations are the line art from the approved venue and studio cards.
class AdminApplicationTile extends StatelessWidget {
  const AdminApplicationTile({
    super.key,
    required this.kind,
    required this.onTap,
  });
  final ApplicationKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final venue = kind == ApplicationKind.venue;
    final accent = venue
        ? (dark ? const Color(0xFFFFAD9E) : const Color(0xFF953E40))
        : (dark ? const Color(0xFFC2AEFF) : const Color(0xFF624399));
    final start = venue ? const Color(0xFF33222E) : const Color(0xFF28223E);
    final end = venue ? const Color(0xFF402D3A) : const Color(0xFF382C50);
    return Semantics(
      button: true,
      child: Material(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
          side: BorderSide(color: accent.withValues(alpha: .31)),
        ),
        clipBehavior: Clip.antiAlias,
        color: dark ? start : theme.colorScheme.surface,
        child: InkWell(
          key: Key('admin-applications-${kind.name}'),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? [start, end]
                    : [
                        accent.withValues(alpha: .05),
                        accent.withValues(alpha: .12),
                      ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: FractionallySizedBox(
                      widthFactor: .45,
                      heightFactor: .88,
                      child: Image.asset(
                        'assets/admin/${kind.name}.png',
                        alignment: Alignment.topRight,
                        fit: BoxFit.contain,
                        color: accent.withValues(alpha: .81),
                        colorBlendMode: BlendMode.srcIn,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 148),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(19, 30, 19, 17),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${kind.label} başvuruları',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.7,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Bekleyenleri aç',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminModuleTile extends StatelessWidget {
  const AdminModuleTile({
    super.key,
    required this.entryKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  final Key entryKey;
  final String title, description;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tint = theme.brightness == Brightness.dark
        ? accent
        : Color.lerp(accent, Colors.black, .45)!;
    return Semantics(
      button: true,
      child: InkWell(
        key: entryKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(icon, size: 20, color: tint),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
