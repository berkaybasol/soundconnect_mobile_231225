part of 'venue_profile_screen.dart';

extension _VenueProfileScreenContentActions on _MusicianPublicProfileContent {
  Future<void> _showOwnerQuickMenu(BuildContext context) =>
      showProfileQuickMenu(
        context,
        settingsTileKey: const Key('venue-account-settings'),
        onSettings: () async {
          final venueId = context
              .read<VenueProfileCubit>()
              .state
              .ownerProfile
              ?.venueId;
          await Navigator.of(context).pushNamed(AppRoutes.settings);
          if (!context.mounted) return;
          await context.read<VenueProfileCubit>().loadOwner(venueId: venueId);
        },
        onManagement: () => _openVenueManagementPanel(context),
        showUnavailableGroups: true,
      );

  Future<void> _openVenueManagementPanel(BuildContext context) async {
    final ownerProfile = context.read<VenueProfileCubit>().state.ownerProfile;
    if (ownerProfile == null) return;
    final session = ProfileActionSession(roles: const ['VENUE', 'ROLE_VENUE']);
    if (!session.isCurrent) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VenueManagementPanelScreen(
          ownerProfile: ownerProfile,
          openWeeklyCalendar: (context) {
            return Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) =>
                    VenueWeeklyCalendarEditorScreen(ownerProfile: ownerProfile),
              ),
            );
          },
          openConnectedArtists: (_) async {
            await onEditEvents?.call();
          },
        ),
      ),
    );
    if (context.mounted && session.isCurrent) {
      await context.read<VenueProfileCubit>().loadOwner(
        venueId: ownerProfile.venueId,
      );
    }
  }
}
