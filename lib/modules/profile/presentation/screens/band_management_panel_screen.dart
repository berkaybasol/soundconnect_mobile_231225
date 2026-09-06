import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/network_config.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../artist_venue/domain/artist_venue_connection_repository.dart';
import '../../../location/domain/location_repository.dart';
import '../../../setlist/presentation/screens/band_setlist_builder_screen.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_member_summary.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/entities/artist_venue_application.dart';
import '../../domain/entities/profile_venue_models.dart';
import '../../domain/entities/musician_search_option.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/musician_search_repository.dart';
import '../../domain/venue_directory_repository.dart';
import 'profile_route_args.dart';
import 'event_invitation_navigation.dart';
import 'venue_connection_management_hub.dart';
import '../../domain/entities/event_performer_request.dart';
import 'profile_venue_request_sheet.dart';
import 'profile_venue_support.dart';

part 'band_management_panel_screen_widgets.dart';
part 'band_management_panel_screen_member_actions.dart';
part 'band_management_panel_screen_member_picker.dart';
part 'band_management_panel_screen_members_workspace.dart';
part 'band_management_panel_screen_ui_helpers.dart';
part 'band_management_panel_screen_venue_actions.dart';
part 'band_management_panel_screen_venue_connections_sheet.dart';

class BandManagementPanelScreen extends StatefulWidget {
  final BandProfile profile;

  BandManagementPanelScreen({super.key, required this.profile});

  @override
  State<BandManagementPanelScreen> createState() =>
      _BandManagementPanelScreenState();
}

class _BandManagementPanelScreenState extends State<BandManagementPanelScreen> {
  late final BandRepository _bandRepository = serviceLocator<BandRepository>();
  late final MusicianSearchRepository _musicianSearchRepository =
      serviceLocator<MusicianSearchRepository>();
  late final MusicianProfileRepository _musicianProfileRepository =
      serviceLocator<MusicianProfileRepository>();
  late final VenueDirectoryRepository _venueDirectoryRepository =
      serviceLocator<VenueDirectoryRepository>();
  late final LocationRepository _locationRepository =
      serviceLocator<LocationRepository>();
  late final ArtistVenueConnectionRepository _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();

  late BandProfile _profile = widget.profile;
  bool _loading = false;
  bool _submitting = false;
  String? _errorText;

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Band Yönetimi'), centerTitle: true),
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
                      text: _profile.name,
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
                      'Buradan band profilini destekleyecek yönetim araçlarına erişebilirsin.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              _actionCard(
                context: context,
                icon: Icons.group_add_outlined,
                title: 'Üyeleri Yönet',
                message: 'Üye yönetimi açılıyor.',
                trailingLabel: '${_profile.members.length} üye',
                onTap: _submitting ? null : _openMembersPage,
              ),
              SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.edit_note_outlined,
                title: 'Setlist Oluştur',
                message: 'Setlist oluşturucu açılıyor.',
                onTap: _submitting
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                BandSetlistBuilderScreen(bandProfile: _profile),
                          ),
                        );
                      },
              ),
              SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.hub_outlined,
                title: 'Mekan Bağlantılarını Yönet',
                message: 'Mekan bağlantıları ve başvuru akışları burada.',
                onTap: _submitting ? null : _openVenueConnectionHub,
              ),
              SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.event_available_outlined,
                title: 'Etkinlik Yönetimi',
                message:
                    'Grubunun davetlerini, etkinliklerini ve geçmişini yönet.',
                onTap: _submitting || _profile.id.trim().isEmpty
                    ? null
                    : () => openEventManagement(
                        context,
                        targetType: EventPerformerTargetType.band,
                        targetId: _profile.id,
                      ),
              ),
              SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.analytics_outlined,
                title: 'Etkileşim ve İstatistikler',
                trailingLabel: 'Yakında!',
                message: 'Band istatistik paneli sıradaki adımda eklenecek.',
              ),
              SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.delete_forever_outlined,
                title: 'Bandı Sil',
                message: 'Band silme onayı açılıyor.',
                trailingLabel: 'Kalıcı',
                useGradientIcon: true,
                onTap: _submitting ? null : _confirmDeleteBand,
              ),
              SizedBox(height: 18),
              _adPlaceholderCard(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteBand() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bandı sil'),
        content: Text(
          'Bu bandı silmek istediğine emin misin? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final result = await _bandRepository.deleteBand(bandId: _profile.id);
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _errorText = result.error?.message ?? 'Band silinemedi.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText!)));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${_profile.name} silindi.')));
    Navigator.of(context).pop(true);
  }
}
