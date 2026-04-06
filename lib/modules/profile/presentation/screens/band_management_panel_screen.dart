import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_member_summary.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/entities/musician_search_option.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/musician_search_repository.dart';

part 'band_management_panel_screen_widgets.dart';
part 'band_management_panel_screen_member_actions.dart';
part 'band_management_panel_screen_member_picker.dart';
part 'band_management_panel_screen_ui_helpers.dart';

class BandManagementPanelScreen extends StatefulWidget {
  final BandProfile profile;

  const BandManagementPanelScreen({super.key, required this.profile});

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

  late BandProfile _profile = widget.profile;
  bool _loading = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Band Yonetimi'), centerTitle: true),
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
                      text: _profile.name,
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
                      'Buradan band profilini destekleyecek yonetim araclarina erisebilirsin.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _actionCard(
                context: context,
                icon: Icons.group_add_outlined,
                title: 'Uyeleri Yonet',
                message: 'Uye yonetimi aciliyor.',
                trailingLabel: '${_profile.members.length} uye',
                onTap: _submitting ? null : _openMembersSheet,
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.edit_note_outlined,
                title: 'Band Bilgilerini Duzenle',
                message:
                    'Band bilgilerini yonetme paneli siradaki adimda eklenecek.',
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.perm_media_outlined,
                title: 'Medya ve Icerik Yonetimi',
                message: 'Band medya akislari siradaki adimda eklenecek.',
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.analytics_outlined,
                title: 'Etkilesim ve Istatistikler',
                message: 'Band istatistik paneli siradaki adimda eklenecek.',
              ),
              const SizedBox(height: 18),
              _adPlaceholderCard(),
            ],
          ),
        ),
      ),
    );
  }
}
