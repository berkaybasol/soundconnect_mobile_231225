part of 'venue_management_panel_screen.dart';

Future<void> _showArtistAndApplicationSheet({
  required BuildContext context,
  required VenueOwnerProfile ownerProfile,
  required Future<void> Function(BuildContext context) openConnectedArtists,
}) async {
  final originRoute = ModalRoute.of(context);
  final session = ProfileActionSession(roles: const ['VENUE', 'ROLE_VENUE']);
  if (!session.isCurrent) return;
  final destination = await showVenueConnectionManagementHub(
    context,
    artistConnections: true,
  );
  if (!context.mounted ||
      !session.isCurrent ||
      destination == null ||
      originRoute?.isCurrent == false) {
    return;
  }
  if (destination == VenueConnectionManagementDestination.create) {
    await openConnectedArtists(context);
    return;
  }
  final mode = switch (destination) {
    VenueConnectionManagementDestination.connections =>
      ApplicationListMode.connections,
    VenueConnectionManagementDestination.incoming =>
      ApplicationListMode.incoming,
    VenueConnectionManagementDestination.outgoing =>
      ApplicationListMode.outgoing,
    VenueConnectionManagementDestination.create => throw StateError(
      'Create already handled',
    ),
  };
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        VenueApplicationsSheet(venueId: ownerProfile.venueId, mode: mode),
  );
}
