part of 'band_management_panel_screen.dart';

class _MemberCard extends StatelessWidget {
  final BandMemberSummary member;
  final VoidCallback? onOpenProfile;
  final String? avatarOverrideUrl;
  final VoidCallback? onOptions;
  final bool hasOptions;
  final bool savingTitle;

  _MemberCard({
    super.key,
    required this.member,
    required this.onOpenProfile,
    required this.avatarOverrideUrl,
    required this.onOptions,
    required this.hasOptions,
    this.savingTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = _resolveMemberAvatarUrl(
      avatarOverrideUrl ?? member.profilePictureUrl,
    );
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey('band-member-identity-${member.userId}'),
                borderRadius: BorderRadius.circular(12),
                onTap: onOpenProfile,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      _MemberAvatar(imageUrl: avatarUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          key: ValueKey(
                            'band-member-identity-copy-${member.userId}',
                          ),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (member.isFounder ||
                                member.displayTitle != null) ...[
                              const SizedBox(height: 4),
                              BandMemberCaption(member: member),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasOptions) ...[
              const SizedBox(width: 8),
              IconButton(
                key: ValueKey('member-options-${member.userId}'),
                tooltip: 'Üye seçenekleri',
                onPressed: onOptions,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: savingTitle
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.more_horiz_rounded,
                        size: 22,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final String? imageUrl;

  _MemberAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : AppCachedNetworkImage(
              imageUrl: imageUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              cacheWidth: 132,
              cacheHeight: 132,
              errorBuilder: (context) => Icon(
                Icons.person_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

String? _resolveMemberAvatarUrl(String? raw) {
  final String value = raw?.trim() ?? '';
  if (value.isEmpty) return null;

  if (value.startsWith('//')) {
    return 'https:$value';
  }

  final Uri? parsed = Uri.tryParse(value);
  if (parsed == null) return null;

  final bool isHttp =
      parsed.hasScheme &&
      (parsed.scheme.toLowerCase() == 'http' ||
          parsed.scheme.toLowerCase() == 'https') &&
      parsed.host.isNotEmpty;
  if (isHttp) return value;

  final Uri? baseUri = Uri.tryParse(NetworkConfig.baseUrl);
  if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
    return null;
  }

  final Uri resolved = value.startsWith('/')
      ? baseUri.resolve(value)
      : baseUri.resolve('/$value');
  final String scheme = resolved.scheme.toLowerCase();
  if ((scheme != 'http' && scheme != 'https') || resolved.host.isEmpty) {
    return null;
  }
  return resolved.toString();
}

class _EmptyCard extends StatelessWidget {
  final String text;

  _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _GradientOutline extends StatelessWidget {
  final Widget child;
  final double radius;
  final double strokeWidth;
  final bool paintOverChild;

  _GradientOutline({
    required this.child,
    required this.radius,
    required this.strokeWidth,
    this.paintOverChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: paintOverChild
          ? null
          : _GradientOutlinePainter(radius: radius, strokeWidth: strokeWidth),
      foregroundPainter: paintOverChild
          ? _GradientOutlinePainter(radius: radius, strokeWidth: strokeWidth)
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _GradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;

  _GradientOutlinePainter({required this.radius, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
