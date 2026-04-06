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

  const VenueManagementPanelScreen({
    super.key,
    required this.ownerProfile,
    required this.openWeeklyCalendar,
    required this.openConnectedArtists,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mekan Yonetimi'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.inputFill, AppColors.navBlueSoft],
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      text: ownerProfile.venueName,
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.brandGradient,
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Buradan mekan profilini destekleyen yonetim araclarina erisebilirsin.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              _buildManagementActionCard(
                context: context,
                icon: Icons.mode_comment_outlined,
                title: 'Isletmene Gelen Yorumlari Goruntule',
                message: 'Isletmene gelen yorumlar burada listelenecek.',
              ),
              const SizedBox(height: 14),
              _buildManagementActionCard(
                context: context,
                icon: Icons.dashboard_customize_outlined,
                title: 'Istatistikler',
                message: 'Istatistikler modulu yakinda burada acilacak.',
                trailingLabel: 'Yakinda!',
              ),
              const SizedBox(height: 14),
              _buildManagementActionCard(
                context: context,
                icon: Icons.extension_outlined,
                title: 'Kampanyalar / Tanitim',
                message: 'Kampanya ve tanitim alani yakinda burada acilacak.',
                trailingLabel: 'Yakinda!',
              ),
              const SizedBox(height: 18),
              _buildManagementPromotionCard(context),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ApplicationListMode { outgoing, incoming }
