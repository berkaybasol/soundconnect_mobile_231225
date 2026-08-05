part of 'register_screen.dart';

class _UsernameAvailabilityMessage extends StatelessWidget {
  const _UsernameAvailabilityMessage({
    required this.icon,
    required this.message,
    this.positive = false,
    this.negative = false,
  });

  final IconData icon;
  final String message;
  final bool positive;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = positive
        ? AppColors.spotifyGreen
        : negative
        ? colors.error
        : colors.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _RoleOption {
  _RoleOption({
    required this.id,
    required this.title,
    required this.icon,
    this.badge,
  });

  final String id;
  final String title;
  final IconData icon;
  final String? badge;
}
