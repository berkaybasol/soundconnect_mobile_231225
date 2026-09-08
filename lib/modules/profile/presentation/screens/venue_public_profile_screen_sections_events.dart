part of 'venue_public_profile_screen.dart';

class _ActiveMusicianCarousel extends StatelessWidget {
  final List<VenueActiveMusician> items;

  _ActiveMusicianCarousel({required this.items});

  @override
  Widget build(BuildContext context) => ActiveMusicianCarousel(items: items);
}
