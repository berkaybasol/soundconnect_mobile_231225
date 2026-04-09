part of 'band_management_panel_screen.dart';

class _MemberCard extends StatelessWidget {
  final BandMemberSummary member;
  final VoidCallback onOpenProfile;
  final String? avatarOverrideUrl;
  final VoidCallback? onRemove;

  const _MemberCard({
    required this.member,
    required this.onOpenProfile,
    required this.avatarOverrideUrl,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = _resolveMemberAvatarUrl(
      avatarOverrideUrl ?? member.profilePictureUrl,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.username,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member.localizedRoleLabel,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (member.isFounder)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Text(
                    'Kurucu',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kurucu kaldırılamaz',
                  onPressed: null,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent.withValues(alpha: 0.45),
                  ),
                ),
              ],
            )
          else
            IconButton(
              tooltip: 'Üyeyi çıkar',
              onPressed: onRemove,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final String? imageUrl;

  const _MemberAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navBlueSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? const Icon(Icons.person_outline, color: AppColors.textMuted)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person_outline, color: AppColors.textMuted),
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

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}

class _GradientOutline extends StatelessWidget {
  final Widget child;
  final double radius;
  final double strokeWidth;

  const _GradientOutline({
    required this.child,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GradientOutlinePainter(
        radius: radius,
        strokeWidth: strokeWidth,
      ),
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

  const _GradientOutlinePainter({
    required this.radius,
    required this.strokeWidth,
  });

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
      ..shader = const LinearGradient(
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
