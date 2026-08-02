part of 'venue_profile_screen.dart';

extension _VenueProfileScreenContentActions on _MusicianPublicProfileContent {
  Future<void> _showOwnerQuickMenu(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.58,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.surface,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  left: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        ListTile(
                          key: const Key('venue-account-settings'),
                          leading: const Icon(Icons.settings_outlined),
                          title: const Text('Ayarlar'),
                          onTap: () async {
                            final venueId = context
                                .read<VenueProfileCubit>()
                                .state
                                .ownerProfile
                                ?.venueId;
                            Navigator.of(dialogContext).pop();
                            await Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.settings);
                            if (!context.mounted) return;
                            await context.read<VenueProfileCubit>().loadOwner(
                              venueId: venueId,
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.dashboard_customize_outlined,
                          ),
                          title: const Text('Yönetim Paneli'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _openVenueManagementPanel(context);
                          },
                        ),
                        ListTile(
                          key: profileMenuThemeTileKey,
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('Tema'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            showProfileMenuThemePicker(context);
                          },
                        ),
                        ListTile(
                          key: profileMenuSupportTileKey,
                          leading: const Icon(Icons.support_agent_rounded),
                          title: const Text('Destek'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            showProfileMenuSupport(context);
                          },
                        ),
                        const Opacity(
                          opacity: 0.72,
                          child: ListTile(
                            enabled: false,
                            leading: Icon(Icons.groups_outlined),
                            title: Text('Gruplarim'),
                          ),
                        ),
                        const Spacer(),
                        SessionLogoutMenuTile(
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await confirmAndLogoutSession(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openVenueManagementPanel(BuildContext context) async {
    final ownerProfile = context.read<VenueProfileCubit>().state.ownerProfile;
    if (ownerProfile == null) return;
    final changed = await Navigator.of(context).push<bool>(
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
    if (changed == true && context.mounted) {
      await context.read<VenueProfileCubit>().loadOwner(
        venueId: ownerProfile.venueId,
      );
    }
  }
}
