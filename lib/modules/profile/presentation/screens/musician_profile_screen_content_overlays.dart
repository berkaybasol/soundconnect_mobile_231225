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
        final session = ProfileActionSession(
          roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
        );
        if (!session.isCurrent) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MusicianManagementPanelScreen(
              musicianProfile: profile,
              onCreateVenueConnection: onEditVenues,
            ),
          ),
        );
        if (context.mounted && session.isCurrent) await onRefresh();
      },
    );
  }
}
