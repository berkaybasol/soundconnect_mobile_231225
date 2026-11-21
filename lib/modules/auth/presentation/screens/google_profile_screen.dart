import 'package:flutter/material.dart';

import '../../../../core/error/result.dart';
import '../../data/google_auth_repository.dart';
import '../../domain/entities/login_result.dart';
import '../../domain/username_policy.dart';
import '../../domain/business_registration_details.dart';
import '../widgets/business_registration_fields.dart';

class GoogleProfileScreen extends StatefulWidget {
  const GoogleProfileScreen({super.key, required this.complete});

  final Future<LoginResult> Function(
    String username,
    String role,
    bool consent,
    BusinessRegistrationDetails? business,
  )
  complete;

  @override
  State<GoogleProfileScreen> createState() => _GoogleProfileScreenState();
}

class _GoogleProfileScreenState extends State<GoogleProfileScreen> {
  final _username = TextEditingController();
  final _business = BusinessRegistrationController();
  bool get _isBusiness => _role == 'ROLE_STUDIO' || _role == 'ROLE_VENUE';
  String? _role;
  bool _consent = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _business.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final role = _role;
    final username = UsernamePolicy.normalize(_username.text);
    if (_submitting ||
        role == null ||
        !_consent ||
        !UsernamePolicy.isValid(username)) {
      return;
    }
    final business = _isBusiness
        ? _business.details(isStudio: role == 'ROLE_STUDIO')
        : null;
    final issue = business?.googleValidationMessage;
    if (issue != null) {
      setState(() => _error = issue);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await widget.complete(username, role, _consent, business);
      if (mounted) Navigator.pop(context, Result<LoginResult>.success(session));
    } catch (e) {
      if (!mounted) return;
      final error = googleAuthError(e);
      if (const {
        '401',
        '1101',
        '1004',
        '1116',
        '1118',
        '1102',
        'auth_studio_application_rejected',
      }.contains(error.code)) {
        Navigator.pop(context, Result<LoginResult>.failure(error));
        return;
      }
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Google ile kayıt')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                key: const Key('google-username'),
                controller: _username,
                enabled: !_submitting,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı adı',
                  helperText: '3–30 karakter',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Profil türü',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text('Seçtiğin profil türü sonradan değiştirilemez.'),
              RadioGroup<String>(
                groupValue: _role,
                onChanged: (value) => setState(() {
                  _role = value;
                  _consent = false;
                  _error = null;
                }),
                child: Column(
                  children: [
                    RadioListTile(
                      value: 'ROLE_LISTENER',
                      enabled: !_submitting,
                      title: const Text('Dinleyici'),
                    ),
                    RadioListTile(
                      value: 'ROLE_MUSICIAN',
                      enabled: !_submitting,
                      title: const Text('Müzisyen'),
                    ),
                    RadioListTile(
                      value: 'ROLE_VENUE',
                      enabled: !_submitting,
                      title: const Text('Mekân'),
                    ),
                    RadioListTile(
                      value: 'ROLE_STUDIO',
                      enabled: !_submitting,
                      title: const Text('Stüdyo'),
                    ),
                  ],
                ),
              ),
              if (_isBusiness) ...[
                const Text(
                  'İşletme başvurunu yönetim ekibi inceleyecek. Onaylandığında profilini kullanabilirsin.',
                ),
                const SizedBox(height: 12),
                BusinessRegistrationFields(
                  controller: _business,
                  isStudio: _role == 'ROLE_STUDIO',
                  enabled: !_submitting,
                ),
              ],
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consent,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _consent = value == true),
                title: Text(
                  _isBusiness
                      ? 'Seçtiğim Google hesabıyla işletme başvurumun gönderilmesini onaylıyorum.'
                      : 'Seçtiğim Google hesabıyla SoundConnect hesabımın oluşturulmasını onaylıyorum.',
                ),
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    _submitting ||
                        !_consent ||
                        _role == null ||
                        !UsernamePolicy.isValid(_username.text)
                    ? null
                    : _submit,
                child: Text(
                  _isBusiness
                      ? (_submitting
                            ? 'Başvuru gönderiliyor…'
                            : 'Başvurumu gönder')
                      : (_submitting
                            ? 'Hesap oluşturuluyor…'
                            : 'Hesabımı oluştur'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
