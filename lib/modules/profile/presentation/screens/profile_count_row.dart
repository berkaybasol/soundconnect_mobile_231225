import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class ProfileCountRow extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final bool light;
  final bool isLiked;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;

  const ProfileCountRow({
    super.key,
    required this.likeCount,
    required this.commentCount,
    this.light = false,
    this.isLiked = false,
    this.onLikeTap,
    this.onCommentTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.white : AppColors.textMuted;
    final likeColor = light
        ? AppColors.white
        : (isLiked ? AppColors.coralAlt : AppColors.textMuted);
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onLikeTap,
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: likeColor,
              ),
              const SizedBox(width: 6),
              Text(
                likeCount.toString(),
                style: TextStyle(color: likeColor, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onCommentTap,
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                commentCount.toString(),
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
