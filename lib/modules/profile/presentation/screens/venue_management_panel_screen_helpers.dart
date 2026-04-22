part of 'venue_management_panel_screen.dart';

Widget _buildManagementActionCard({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  String? trailingLabel,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap:
        onTap ??
        () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
    borderRadius: BorderRadius.circular(18),
    child: _GradientOutline(
      radius: 18,
      strokeWidth: 1,
      child: Ink(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            if (trailingLabel != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  trailingLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              SizedBox(width: 10),
            ],
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}
