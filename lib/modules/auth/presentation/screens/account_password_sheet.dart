import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../data/account_password_repository.dart';
import '../../domain/password_policy.dart';

class AccountPasswordSheet extends StatefulWidget {
  const AccountPasswordSheet({
    super.key,
    required this.repository,
    required this.sessions,
    required this.session,
    required this.revision,
  });

  final AccountPasswordRepository repository;
  final AuthSessionManager sessions;
  final AuthSession session;
  final int revision;

  @override
  State<AccountPasswordSheet> createState() => _AccountPasswordSheetState();
}

class _AccountPasswordSheetState extends State<AccountPasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  final _visible = <TextEditingController>{};
  bool _busy = false;
  bool _submitted = false;
  String? _error;
  String? _currentError;

  bool get _current =>
      widget.sessions.credentialRevision == widget.revision &&
      widget.sessions.session.token == widget.session.token;

  @override
  void initState() {
    super.initState();
    widget.sessions.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_current || (_busy && widget.sessions.isRotatingCurrentLogin)) return;
    _currentPassword.clear();
    _newPassword.clear();
    _confirmation.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _close();
    });
  }

  void _close([AuthSession? renewed]) {
    final route = ModalRoute.of<AuthSession>(context);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop(renewed);
    } else {
      navigator.removeRoute(route, renewed);
    }
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_sessionChanged);
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_current || _busy || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repository.change(
      session: widget.session,
      revision: widget.revision,
      currentPassword: _currentPassword.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;
    final renewed = result.data;
    if (result.isSuccess &&
        renewed != null &&
        widget.sessions.session.token == renewed.token &&
        widget.sessions.credentialRevision == widget.revision + 1) {
      TextInput.finishAutofillContext();
      _close(renewed);
      return;
    }
    if (!_current) {
      _close();
      return;
    }
    setState(() {
      _busy = false;
      switch (result.error?.code) {
        case '1123':
          _currentError = 'Mevcut şifren doğru değil.';
        case '1121':
          _error = 'Bu hesaba Google ile giriş yapıyorsun.';
        case '1122':
          _error = 'Yeni şifren mevcut şifrenden farklı olmalı.';
        case '1104' || '429':
          _error = 'Çok fazla deneme yaptın. Bir süre sonra tekrar dene.';
        default:
          _error =
              'Sonuç alınamadı. Yeniden giriş istenirse yeni şifreni dene.';
      }
    });
  }

  String? _validateCurrent(String? input) {
    if (!PasswordPolicy.isValidForLogin(input ?? '')) {
      return 'Mevcut şifreni gir.';
    }
    return _currentError;
  }

  String? _validateNew(String? input) {
    final password = input ?? '';
    if (PasswordPolicy.isBlank(password)) return 'Yeni şifreni gir.';
    if (password.length < PasswordPolicy.registrationMinimumLength) {
      return 'Şifren en az 8 karakter olmalı.';
    }
    if (PasswordPolicy.exceedsBcryptLimit(password)) {
      return 'Yeni şifren çok uzun. Biraz kısaltıp tekrar dene.';
    }
    if (password == _currentPassword.text) {
      return 'Yeni şifren mevcut şifrenden farklı olmalı.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark
        ? AppColors.originalDark
        : AppColors.lightPalette;
    return PopScope<AuthSession>(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Form(
                key: _form,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      child: Text(
                        'Şifreni değiştir',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          height: 1.13,
                          letterSpacing: -.8,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bu cihazda oturumun açık kalır. Diğer cihazlarda yeniden giriş yapman gerekir.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.42,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _field(_currentPassword, 'Mevcut şifre', _validateCurrent),
                    const SizedBox(height: 14),
                    _field(_newPassword, 'Yeni şifre', _validateNew),
                    const SizedBox(height: 14),
                    _field(
                      _confirmation,
                      'Yeni şifre tekrar',
                      (value) =>
                          (value ?? '').isEmpty || value != _newPassword.text
                          ? 'Şifreler eşleşmeli.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GradientOutlineButton(
                      label: 'Şifreyi değiştir',
                      strokeWidth: 1,
                      loading: _busy,
                      onPressed: _busy || !_current ? null : _submit,
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _busy ? null : () => _close(),
                      child: const Text('Vazgeç'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    FormFieldValidator<String> validator,
  ) {
    final visible = _visible.contains(controller);
    final isLast = identical(controller, _confirmation);
    final current = identical(controller, _currentPassword);
    return TextFormField(
      controller: controller,
      enabled: !_busy,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: [
        current ? AutofillHints.password : AutofillHints.newPassword,
      ],
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: isLast ? (_) => _submit() : null,
      validator: validator,
      onChanged: (_) {
        if (_error != null || (current && _currentError != null)) {
          setState(() {
            _error = null;
            if (current) _currentError = null;
          });
        }
      },
      decoration: InputDecoration(
        labelText: label,
        helperText: identical(controller, _newPassword)
            ? 'En az 8 karakter'
            : null,
        errorMaxLines: 2,
        suffixIcon: IconButton(
          tooltip: '$label: ${visible ? "gizle" : "göster"}',
          icon: Icon(
            visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: _busy
              ? null
              : () => setState(() {
                  if (visible) {
                    _visible.remove(controller);
                  } else {
                    _visible.add(controller);
                  }
                }),
        ),
      ),
    );
  }
}
