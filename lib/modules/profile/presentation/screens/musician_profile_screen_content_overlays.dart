part of 'musician_profile_screen.dart';

extension _MusicianPublicProfileContentOverlays
    on _MusicianPublicProfileContent {
  Future<void> _showOwnerQuickMenu(BuildContext context) async {
    await showProfileQuickMenu(
      context,
      settingsTileKey: const Key('musician-account-settings'),
      onSettings: () async {
        await Navigator.of(context).pushNamed(AppRoutes.settings);
        if (!context.mounted) return;
        await context.read<MusicianProfileCubit>().loadMyProfile();
      },
      onManagement: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MusicianManagementPanelScreen(
              musicianProfile: profile,
              onCreateVenueConnection: onEditVenues,
            ),
          ),
        );
      },
    );
  }
}
