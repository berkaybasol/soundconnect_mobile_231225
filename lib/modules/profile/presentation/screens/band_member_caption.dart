import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/band_member_summary.dart';

/// The founder badge describes authority. The optional title only describes
/// this person's contribution to this band and never changes permissions.
class BandMemberCaption extends StatelessWidget {
  const BandMemberCaption({super.key, required this.member});

  final BandMemberSummary member;

  @override
  Widget build(BuildContext context) {
    final title = member.displayTitle;
    if (!member.isFounder && title == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (member.isFounder)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: AppColors.brandGradient,
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Icon(Icons.verified_outlined, size: 12),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Kurucu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        if (member.isFounder && title != null) const SizedBox(height: 3),
        if (title != null)
          Tooltip(
            message: title,
            excludeFromSemantics: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}
