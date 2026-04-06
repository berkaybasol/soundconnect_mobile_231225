import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/band_repository.dart';

class CreateBandScreen extends StatefulWidget {
  const CreateBandScreen({super.key});

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
        _errorText = 'Band adi zorunlu.';
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
        _errorText = result.error?.message ?? 'Band olusturulamadi.';
      });
      return;
    }

    Navigator.of(context).pop(result.data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Band Olustur'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    enabled: !_submitting,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _inputDecoration(
                      hintText: 'Band adi',
                      icon: Icons.groups_2_outlined,
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFB4B4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _BrandGradientOutlineButton(
                    label: _submitting ? 'Olusturuluyor...' : 'Bandi olustur',
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
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.inputFill,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.brandGradient[1]),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _BrandGradientOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _BrandGradientOutlineButton({
    required this.label,
    required this.onPressed,
  });

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
              : [AppColors.border, AppColors.border],
        ),
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
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
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
