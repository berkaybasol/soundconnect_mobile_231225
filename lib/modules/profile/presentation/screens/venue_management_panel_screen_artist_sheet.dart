part of 'venue_management_panel_screen.dart';

Future<void> _showArtistAndApplicationSheet({
  required BuildContext context,
  required VenueOwnerProfile ownerProfile,
  required Future<void> Function(BuildContext context) openConnectedArtists,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.navBlueDeep,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  'Sanatci Baglantilarini Yonet',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildManagementActionCard(
                context: sheetContext,
                icon: Icons.group_outlined,
                title: 'Sanatci Baglantisi Olustur',
                message: 'Sanatci baglantilarini buradan yonetecegiz.',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await openConnectedArtists(context);
                },
              ),
              SizedBox(height: 12),
              _buildManagementActionCard(
                context: sheetContext,
                icon: Icons.send_outlined,
                title: 'Baglanti Isteklerim',
                message: 'Gonderdigin basvurular burada yonetilecek.',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.navBlueDeep,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (_) => _VenueApplicationsSheet(
                      venueId: ownerProfile.venueId,
                      mode: _ApplicationListMode.outgoing,
                    ),
                  );
                },
              ),
              SizedBox(height: 12),
              _buildManagementActionCard(
                context: sheetContext,
                icon: Icons.inbox_outlined,
                title: 'Gelen Baglanti Istekleri',
                message: 'Sana gelen basvurular burada yonetilecek.',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.navBlueDeep,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (_) => _VenueApplicationsSheet(
                      venueId: ownerProfile.venueId,
                      mode: _ApplicationListMode.incoming,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
