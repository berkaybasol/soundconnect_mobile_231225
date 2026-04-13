import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_summary.dart';
import 'band_profile_screen.dart';

class MyBandsScreenArgs {
  final List<String> bands;

  const MyBandsScreenArgs({required this.bands});
}

class MyBandsScreen extends StatefulWidget {
  const MyBandsScreen({super.key});

  @override
  State<MyBandsScreen> createState() => _MyBandsScreenState();
}

class _MyBandsScreenState extends State<MyBandsScreen> {
  late final BandRepository _bandRepository = serviceLocator<BandRepository>();
  List<BandSummary> _bands = const [];
  bool _initialized = false;
  bool _loading = false;
  String? _errorText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _loadBands();
  }

  Future<void> _loadBands() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    final result = await _bandRepository.getMyBands();

    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      setState(() {
        _loading = false;
        _errorText = result.error?.message ?? 'Bandler getirilemedi.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _bands = result.data!;
    });
  }

  Future<void> _openCreateBandScreen() async {
    final createdBand = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.createBand);

    if (!mounted || createdBand is! BandSummary) return;

    setState(() {
      _bands = [..._bands, createdBand];
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${createdBand.name} olusturuldu.')));
  }

  Future<void> _openBandProfile(BandSummary band) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.bandMemberProfile,
      arguments: BandProfileScreenArgs(
        bandId: band.id,
        openEditMode: false,
        viewMode: BandProfileViewMode.auto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bandlerim'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bandlerini bu panel uzerinden yonetebilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorText != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else if (_bands.isEmpty) ...[
                const Text(
                  'Henuz bandiniz yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 16),
                _BrandGradientOutlineButton(
                  label: 'Band olustur',
                  onPressed: _openCreateBandScreen,
                ),
              ] else ...[
                Expanded(
                  child: ListView(
                    children: [
                      ..._bands.map(
                        (band) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.groups_outlined),
                            title: Text(
                              band.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _openBandProfile(band),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _BrandGradientOutlineButton(
                  label: 'Yeni band olustur',
                  onPressed: _openCreateBandScreen,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandGradientOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _BrandGradientOutlineButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(colors: AppColors.brandGradient),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Material(
            color: AppColors.navBlueDeep,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
