import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class ProfilePillBadge extends StatelessWidget {
  final String text;

  const ProfilePillBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ProfileActionButtons extends StatelessWidget {
  final bool isFollowing;
  final bool isEnabled;
  final bool isLoading;
  final bool ownerMode;
  final VoidCallback? onEditProfilePressed;
  final VoidCallback? onMessagePressed;
  final VoidCallback onFollowToggle;

  const ProfileActionButtons({
    super.key,
    required this.isFollowing,
    required this.isEnabled,
    required this.isLoading,
    required this.ownerMode,
    required this.onEditProfilePressed,
    this.onMessagePressed,
    required this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (ownerMode) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isEnabled && !isLoading ? onFollowToggle : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                isLoading
                    ? 'Bekle...'
                    : (isFollowing ? 'Takip Ediliyor' : 'Takip Et'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onMessagePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coralAlt,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Mesaj Gonder'),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSectionTitle extends StatelessWidget {
  final String title;

  const ProfileSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ProfileSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? actionOnTap;

  const ProfileSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionOnTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            InkWell(
              onTap: actionOnTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    color: actionOnTap != null
                        ? AppColors.coralAlt
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
