import 'package:flutter/material.dart';

import '../../../../shared/widgets/brand_gradient_icon.dart';

/// A visual cue, not a separate tiny tap target. The containing card or
/// [MusicianFeedDetailLink] owns navigation and accessibility.
class MusicianFeedDetailChevron extends StatelessWidget {
  const MusicianFeedDetailChevron({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: BrandGradientIcon.social(Icons.chevron_right_rounded, size: 24),
  );
}

class MusicianFeedDetailLink extends StatelessWidget {
  const MusicianFeedDetailLink({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: child,
        ),
      ),
    ),
  );
}

class MusicianFeedDetailHeading extends StatelessWidget {
  const MusicianFeedDetailHeading({
    super.key,
    required this.title,
    required this.onTap,
    required this.semanticLabel,
  });

  final Widget title;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => MusicianFeedDetailLink(
    onTap: onTap,
    semanticLabel: semanticLabel,
    child: Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 8),
        const MusicianFeedDetailChevron(),
      ],
    ),
  );
}
