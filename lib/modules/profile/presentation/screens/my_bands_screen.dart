import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_summary.dart';
import 'band_profile_screen.dart';

class MyBandsScreenArgs {
  final List<String> bands;

  MyBandsScreenArgs({required this.bands});
}

class MyBandsScreen extends StatefulWidget {
  MyBandsScreen({super.key});

  @override
  State<MyBandsScreen> createState() => _MyBandsScreenState();
}

class _MyBandsScreenState extends State<MyBandsScreen> {
  static const int _maxBandCount = 3;
  late final BandRepository _bandRepository = serviceLocator<BandRepository>();
  List<BandSummary> _bands = [];
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
        _errorText = result.error?.message ?? 'Bandlerin getirilemedi.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _bands = result.data!;
    });
  }

  Future<void> _openCreateBandScreen() async {
    if (_bands.length >= _maxBandCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yalnızca $_maxBandCount band oluşturabilirsin.'),
        ),
      );
      return;
    }

    final createdBand = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.createBand);

    if (!mounted || createdBand is! BandSummary) return;

    setState(() {
      _bands = [..._bands, createdBand];
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${createdBand.name} oluşturuldu.')));
  }

  Future<void> _openBandProfile(BandSummary band) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.bandProfile,
      arguments: BandProfileScreenArgs(
        bandId: band.id,
        openEditMode: false,
        viewMode: BandProfileViewMode.auto,
      ),
    );

    if (!mounted || result != true) return;
    setState(() {
      _bands = _bands.where((item) => item.id != band.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canCreateBand = _bands.length < _maxBandCount;
    return Scaffold(
      appBar: AppBar(title: Text('Bandlerim'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bandlerini buradan yönetebilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Yalnızca $_maxBandCount band oluşturabilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 24),
              if (_loading)
                Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_errorText != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else if (_bands.isEmpty) ...[
                Text(
                  'Henüz bir band hesabın yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                _BrandGradientOutlineButton(
                  label: 'Band oluştur',
                  onPressed: _openCreateBandScreen,
                ),
              ] else ...[
                Expanded(
                  child: ListView(
                    children: [
                      ..._bands.map(
                        (band) => Container(
                          margin: EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.groups_outlined),
                            title: Text(
                              band.name,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded),
                            onTap: () => _openBandProfile(band),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                _BrandGradientOutlineButton(
                  label: 'Yeni band oluştur',
                  onPressed: canCreateBand ? _openCreateBandScreen : null,
                ),
                if (!canCreateBand) ...[
                  SizedBox(height: 10),
                  Text(
                    'Band oluşturma limitine ulaştın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
  final VoidCallback? onPressed;

  _BrandGradientOutlineButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    final isEnabled = onPressed != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: isEnabled
              ? AppColors.brandGradient
              : [
                  Theme.of(context).dividerColor,
                  Theme.of(context).dividerColor,
                ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(1.2),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Material(
            color: AppColors.navBlueDeep,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
