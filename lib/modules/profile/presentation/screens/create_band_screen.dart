import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/band_repository.dart';

class CreateBandScreen extends StatefulWidget {
  CreateBandScreen({super.key});

  @override
  State<CreateBandScreen> createState() => _CreateBandScreenState();
}

class _CreateBandScreenState extends State<CreateBandScreen> {
  late final BandRepository _bandRepository = serviceLocator<BandRepository>();
  final _nameController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorText = 'Band adı zorunlu.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final result = await _bandRepository.createBand(
      name: name,
      description: null,
    );

    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      setState(() {
        _submitting = false;
        _errorText = result.error?.message ?? 'Band oluşturulamadı.';
      });
      return;
    }

    Navigator.of(context).pop(result.data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Band Oluştur'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    enabled: !_submitting,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _inputDecoration(
                      hintText: 'Band adı',
                      icon: Icons.groups_2_outlined,
                    ),
                  ),
                  if (_errorText != null) ...[
                    SizedBox(height: 12),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFB4B4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  SizedBox(height: 18),
                  _BrandGradientOutlineButton(
                    label: _submitting ? 'Oluşturuluyor...' : 'Bandı oluştur',
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      prefixIcon: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.brandGradient[1]),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
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
    final isEnabled = onPressed != null;
    final borderRadius = BorderRadius.circular(18);

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
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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
