import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../artist_venue/domain/artist_venue_connection_repository.dart';
import '../../../promotion/domain/entities/promotion_item.dart';
import '../../../promotion/domain/promotion_repository.dart';
import '../../domain/entities/artist_venue_application.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/entities/venue_owner_profile.dart';
import 'band_profile_screen.dart';

part 'venue_management_panel_screen_applications.dart';
part 'venue_management_panel_screen_application_actions.dart';
part 'venue_management_panel_screen_application_tiles.dart';
part 'venue_management_panel_screen_helpers.dart';
part 'venue_management_panel_screen_promotion_helpers.dart';
part 'venue_management_panel_screen_artist_sheet.dart';
part 'venue_management_panel_screen_outline.dart';

class VenueManagementPanelScreen extends StatelessWidget {
  final VenueOwnerProfile ownerProfile;
  final Future<bool?> Function(BuildContext context) openWeeklyCalendar;
  final Future<void> Function(BuildContext context) openConnectedArtists;

  VenueManagementPanelScreen({
    super.key,
    required this.ownerProfile,
    required this.openWeeklyCalendar,
    required this.openConnectedArtists,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mekan Yonetimi'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      Theme.of(context).colorScheme.surfaceContainer,
                    ],
                  ),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      text: ownerProfile.venueName,
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.brandGradient,
                      ),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Buradan mekan profilini destekleyen yonetim araclarina erisebilirsin.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              _buildManagementActionCard(
                context: context,
                icon: Icons.calendar_month_outlined,
                title: 'Etkinlik Yonetimi',
                message: 'Etkinlik takvimini yonet',
                onTap: () async {
                  final changed = await openWeeklyCalendar(context);
                  if (changed == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
              SizedBox(height: 14),
              _buildManagementActionCard(
                context: context,
                icon: Icons.hub_outlined,
                title: 'Sanatci Baglantilarini Yonet',
                message: 'Baglantili sanatcilar ve basvuru akislari burada.',
                onTap: () => _showArtistAndApplicationSheet(
                  context: context,
                  ownerProfile: ownerProfile,
                  openConnectedArtists: openConnectedArtists,
                ),
              ),
              SizedBox(height: 14),
              _buildManagementActionCard(
                context: context,
                icon: Icons.mode_comment_outlined,
                title: 'Isletmene Gelen Yorumlari Goruntule',
                message: 'Isletmene gelen yorumlar burada listelenecek.',
              ),
              SizedBox(height: 14),
              _buildManagementActionCard(
                context: context,
                icon: Icons.dashboard_customize_outlined,
                title: 'Istatistikler',
                message: 'Istatistikler modulu yakinda burada acilacak.',
                trailingLabel: 'Yakinda!',
              ),
              SizedBox(height: 14),
              _buildManagementActionCard(
                context: context,
                icon: Icons.extension_outlined,
                title: 'Kampanyalar / Tanitim',
                message: 'Kampanya ve tanitim alani yakinda burada acilacak.',
                trailingLabel: 'Yakinda!',
              ),
              SizedBox(height: 18),
              _buildManagementPromotionCard(context),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ApplicationListMode { outgoing, incoming }
