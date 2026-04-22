import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class ProfileCountRow extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final bool light;
  final bool isLiked;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;

  ProfileCountRow({
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
    final color = light
        ? AppColors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final likeColor = light
        ? AppColors.white
        : (isLiked
              ? AppColors.coralAlt
              : Theme.of(context).colorScheme.onSurfaceVariant);
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
              SizedBox(width: 6),
              Text(
                likeCount.toString(),
                style: TextStyle(color: likeColor, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onCommentTap,
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: color),
              SizedBox(width: 6),
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
