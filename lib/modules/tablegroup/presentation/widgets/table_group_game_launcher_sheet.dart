import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/table_group_game.dart';

Future<TableGroupGameMode?> showTableGroupGameLauncherSheet(
  BuildContext context,
) {
  return showModalBottomSheet<TableGroupGameMode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.pureBlack.withValues(alpha: 0.72),
    builder: (context) => const _TableGroupGameLauncherSheet(),
  );
}

class _TableGroupGameLauncherSheet extends StatelessWidget {
  const _TableGroupGameLauncherSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.topRight,
            colors: AppColors.brandGradient
                .map((color) => color.withValues(alpha: 0.78))
                .toList(growable: false),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.pureBlack.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF0A1526),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.72,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppColors.brandGradient,
                          ),
                        ),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF101D31),
                          ),
                          child: Center(
                            child: Text('🎮', style: TextStyle(fontSize: 22)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎮 Hesap Kimde?',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Bu gecenin kararını oyun belirlesin.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _GameModeTile(
                    key: const ValueKey<String>('game-mode-rps'),
                    emoji: '✊',
                    title: 'Taş Kağıt Makas',
                    subtitle: 'Klasik kapışma, hızlı sonuç',
                    onTap: () => Navigator.of(
                      context,
                    ).pop(TableGroupGameMode.rockPaperScissors),
                  ),
                  const SizedBox(height: 10),
                  _GameModeTile(
                    key: const ValueKey<String>('game-mode-dice'),
                    emoji: '🎲',
                    title: 'Zar',
                    subtitle: 'Şansı masaya bırak',
                    onTap: () =>
                        Navigator.of(context).pop(TableGroupGameMode.dice),
                  ),
                  const SizedBox(height: 10),
                  _GameModeTile(
                    key: const ValueKey<String>('game-mode-vote'),
                    emoji: '🗳️',
                    title: 'Oylama',
                    subtitle: 'Masadakiler karar versin',
                    onTap: () =>
                        Navigator.of(context).pop(TableGroupGameMode.vote),
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

class _GameModeTile extends StatelessWidget {
  const _GameModeTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xFF071321),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF263A52)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF111F34),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFF2A4059)),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 23)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
