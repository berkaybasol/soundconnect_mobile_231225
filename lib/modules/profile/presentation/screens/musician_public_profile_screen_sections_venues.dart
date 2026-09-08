part of 'musician_public_profile_screen.dart';

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;

  _SectionHeader({required this.title, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Spacer(),
          if (actionLabel != null)
            Text(
              actionLabel!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _VenueCarousel extends StatelessWidget {
  final List<VenueConnection> items;

  _VenueCarousel({required this.items});

  @override
  Widget build(BuildContext context) => VenueNameCarousel(items: items);
}
