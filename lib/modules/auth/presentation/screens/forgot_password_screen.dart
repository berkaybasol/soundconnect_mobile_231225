import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../../domain/password_policy.dart';
import '../../domain/password_reset_identifier_policy.dart';
import '../../domain/entities/password_reset_account.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

enum _PasswordResetStep { identifier, confirmation, password, code, success }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _requestSuccessMessage = 'Şifre sıfırlama kodu gönderildi.';

  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rePasswordController = TextEditingController();

  _PasswordResetStep _step = _PasswordResetStep.identifier;
  PasswordResetAccount? _resolvedAccount;
  String? _lookupError;
  String? _requestError;
  bool _isPasswordObscured = true;
  bool _isRePasswordObscured = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _rePasswordController.dispose();
    super.dispose();
  }

  String _canonicalizeIdentifier() {
    final identifier = PasswordResetIdentifierPolicy.normalize(
      _identifierController.text,
    );
    if (_identifierController.text != identifier) {
      _identifierController.value = TextEditingValue(
        text: identifier,
        selection: TextSelection.collapsed(offset: identifier.length),
      );
    }
    return identifier;
  }

  String? _validateIdentifier(String identifier) {
    if (identifier.isEmpty) {
      return 'Kullanıcı adı veya e-posta boş olamaz.';
    }
    if (PasswordResetIdentifierPolicy.isValid(identifier)) {
      return null;
    }
    if (PasswordResetIdentifierPolicy.looksLikeEmail(identifier)) {
      return 'Geçerli bir e-posta veya kullanıcı adı gir.';
    }
    return 'Kullanıcı adı 3 ile 30 karakter arasında olmalıdır.';
  }

  String? _validatePasswords() {
    final password = _passwordController.text;
    final rePassword = _rePasswordController.text;

    if (PasswordPolicy.isBlank(password)) {
      return 'Yeni şifre boş olamaz.';
    }
    if (password.length < PasswordPolicy.registrationMinimumLength) {
      return 'Yeni şifren en az 8 karakterden oluşmalı.';
    }
    if (PasswordPolicy.exceedsBcryptLimit(password)) {
      return 'Yeni şifren çok uzun. Biraz kısaltıp tekrar dene.';
    }
    if (PasswordPolicy.isBlank(rePassword)) {
      return 'Şifre tekrarı boş olamaz.';
    }
    if (password != rePassword) {
      return 'Şifreler eşleşmeli.';
    }
    return null;
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reviewIdentifier() async {
    final identifier = _canonicalizeIdentifier();
    final validationMessage = _validateIdentifier(identifier);
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }
    setState(() {
      _lookupError = null;
      _resolvedAccount = null;
    });
    final account = await context.read<AuthCubit>().resolvePasswordResetAccount(
      identifier: identifier,
    );
    if (!mounted) return;
    if (account == null) {
      setState(() {
        _lookupError =
            context.read<AuthCubit>().state.error?.message ??
            'Böyle bir hesap bulunamadı.';
      });
      return;
    }
    setState(() {
      _resolvedAccount = account;
      _requestError = null;
      _step = _PasswordResetStep.confirmation;
    });
  }

  void _confirmIdentifier() {
    setState(() {
      _step = _PasswordResetStep.password;
    });
  }

  void _requestCodeAfterPasswords() {
    final identifier = _canonicalizeIdentifier();
    final identifierError = _validateIdentifier(identifier);
    if (identifierError != null) {
      _showMessage(identifierError);
      return;
    }
    final passwordError = _validatePasswords();
    if (passwordError != null) {
      _showMessage(passwordError);
      return;
    }
    if (_requestError != null) {
      setState(() {
        _requestError = null;
      });
    }
    context.read<AuthCubit>().requestPasswordReset(identifier: identifier);
  }

  void _resetPassword() {
    final identifier = _canonicalizeIdentifier();
    final code = _codeController.text.trim();
    final identifierError = _validateIdentifier(identifier);
    if (identifierError != null) {
      _showMessage(identifierError);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Sıfırlama kodu 6 haneli olmalı.');
      return;
    }
    final passwordError = _validatePasswords();
    if (passwordError != null) {
      _showMessage(passwordError);
      return;
    }

    context.read<AuthCubit>().resetPassword(
      identifier: identifier,
      code: code,
      password: _passwordController.text,
      rePassword: _rePasswordController.text,
    );
  }

  void _goToIdentifier() {
    setState(() {
      _lookupError = null;
      _step = _PasswordResetStep.identifier;
    });
  }

  void _goToConfirmation() {
    setState(() {
      _step = _PasswordResetStep.confirmation;
    });
  }

  void _returnToLogin() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.action == AuthAction.forgotPassword) {
          if (state.status == AuthStatus.success) {
            setState(() {
              _requestError = null;
              if (_step == _PasswordResetStep.password) {
                _step = _PasswordResetStep.code;
              }
            });
            _showMessage(state.message ?? _requestSuccessMessage);
          } else if (state.status == AuthStatus.failure) {
            final message =
                state.error?.message ??
                'İstek tamamlanamadı. Lütfen tekrar dene.';
            setState(() {
              _requestError = message;
            });
          }
          return;
        }

        if (state.action != AuthAction.resetPassword) return;
        if (state.status == AuthStatus.success) {
          _codeController.clear();
          _passwordController.clear();
          _rePasswordController.clear();
          setState(() {
            _step = _PasswordResetStep.success;
          });
        } else if (state.status == AuthStatus.failure) {
          _showMessage(
            state.error?.message ??
                'Şifre güncellenemedi. Kodu kontrol edip tekrar dene.',
          );
        }
      },
      builder: (context, state) {
        final requestLoading =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.forgotPassword;
        final resetLoading =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.resetPassword;
        final accountLookupLoading =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.passwordResetAccount;

        return AppScaffold(
          title: 'Şifremi Unuttum',
          child: Align(
            alignment: _step == _PasswordResetStep.success
                ? const Alignment(0, -0.55)
                : Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: switch (_step) {
                  _PasswordResetStep.identifier => _buildIdentifierStep(
                    loading: accountLookupLoading,
                  ),
                  _PasswordResetStep.confirmation => _buildConfirmationStep(),
                  _PasswordResetStep.password => _buildPasswordStep(
                    requestLoading: requestLoading,
                    requestError: _requestError,
                  ),
                  _PasswordResetStep.code => _buildCodeStep(
                    requestLoading: requestLoading,
                    resetLoading: resetLoading,
                    requestError: _requestError,
                  ),
                  _PasswordResetStep.success => _buildSuccess(),
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdentifierStep({required bool loading}) {
    return _buildShell(
      key: const ValueKey('password-reset-identifier'),
      step: 1,
      title: 'Şifreni güvenle yenile',
      description:
          'Hesabına bağlı kullanıcı adını veya e-posta adresini girerek başla.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientTextField(
              key: const Key('forgot-password-identifier-field'),
              controller: _identifierController,
              label: 'Kullanıcı adı veya e-posta',
              prefixIcon: Icons.alternate_email,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              enabled: !loading,
              onSubmitted: (_) => _reviewIdentifier(),
            ),
            if (_lookupError != null) ...[
              const SizedBox(height: 14),
              _buildRequestError(_lookupError!),
            ],
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: GradientOutlineButton(
                key: const Key('forgot-password-request-button'),
                onPressed: loading ? null : _reviewIdentifier,
                label: loading ? 'Hesap aranıyor...' : 'Devam et',
                loading: loading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return _buildShell(
      key: const ValueKey('password-reset-confirmation'),
      step: 1,
      title: 'Doğru hesap bu mu?',
      description:
          'Şifre sıfırlama işlemine aşağıdaki hesapla devam edeceksin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAccountSummary(
            key: const Key('forgot-password-confirmation-account'),
          ),
          const SizedBox(height: 18),
          Text(
            'Bu hesapla devam etmek istiyor musun?',
            key: const Key('forgot-password-confirmation-question'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                key: const Key('forgot-password-confirmation-back-button'),
                onPressed: _goToIdentifier,
                child: const Text('Geri'),
              ),
              const Spacer(),
              GradientOutlineButton(
                key: const Key('forgot-password-confirm-button'),
                onPressed: _confirmIdentifier,
                label: 'Devam et',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep({
    required bool requestLoading,
    required String? requestError,
  }) {
    return _buildShell(
      key: const ValueKey('password-reset-password'),
      step: 2,
      title: 'Güçlü bir şifre oluştur',
      description:
          'Devam ettiğinde 6 haneli doğrulama kodunu hesabında kayıtlı '
          'e-posta adresine göndereceğiz.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAccountSummary(
              key: const Key('forgot-password-password-account'),
              compact: true,
            ),
            if (requestError != null) ...[
              const SizedBox(height: 14),
              _buildRequestError(requestError),
            ],
            const SizedBox(height: 18),
            GradientTextField(
              key: const Key('forgot-password-new-password-field'),
              controller: _passwordController,
              label: 'Yeni şifre',
              prefixIcon: Icons.lock_outline,
              obscureText: _isPasswordObscured,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !requestLoading,
              suffixIcon: IconButton(
                onPressed: requestLoading
                    ? null
                    : () {
                        setState(() {
                          _isPasswordObscured = !_isPasswordObscured;
                        });
                      },
                icon: Icon(
                  _isPasswordObscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            const SizedBox(height: 12),
            GradientTextField(
              key: const Key('forgot-password-repeat-password-field'),
              controller: _rePasswordController,
              label: 'Yeni şifre tekrar',
              prefixIcon: Icons.lock_reset_outlined,
              obscureText: _isRePasswordObscured,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !requestLoading,
              onSubmitted: (_) {
                if (!requestLoading) _requestCodeAfterPasswords();
              },
              suffixIcon: IconButton(
                onPressed: requestLoading
                    ? null
                    : () {
                        setState(() {
                          _isRePasswordObscured = !_isRePasswordObscured;
                        });
                      },
                icon: Icon(
                  _isRePasswordObscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Şifren en az 8 karakter olmalı.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  key: const Key('forgot-password-password-back-button'),
                  onPressed: requestLoading ? null : _goToConfirmation,
                  child: const Text('Geri'),
                ),
                const Spacer(),
                GradientOutlineButton(
                  key: const Key('forgot-password-password-continue-button'),
                  onPressed: requestLoading ? null : _requestCodeAfterPasswords,
                  label: requestLoading ? 'Kod gönderiliyor...' : 'Devam et',
                  loading: requestLoading,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeStep({
    required bool requestLoading,
    required bool resetLoading,
    required String? requestError,
  }) {
    final busy = requestLoading || resetLoading;
    return _buildShell(
      key: const ValueKey('password-reset-code'),
      step: 3,
      title: 'E-postanı kontrol et',
      description:
          'Kayıtlı e-posta adresine gönderdiğimiz 6 haneli kodu gir. '
          'Kod kısa bir süre için geçerlidir.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAccountSummary(
              key: const Key('forgot-password-selected-identifier'),
              compact: true,
            ),
            if (requestError != null) ...[
              const SizedBox(height: 14),
              _buildRequestError(requestError),
            ],
            const SizedBox(height: 18),
            GradientTextField(
              key: const Key('forgot-password-code-field'),
              controller: _codeController,
              label: '6 haneli doğrulama kodu',
              prefixIcon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              enabled: !busy,
              onSubmitted: (_) {
                if (!busy) _resetPassword();
              },
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: GradientOutlineButton(
                    key: const Key('forgot-password-reset-button'),
                    onPressed: busy ? null : _resetPassword,
                    label: resetLoading
                        ? 'Şifre güncelleniyor...'
                        : 'Şifreyi güncelle',
                    loading: resetLoading,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    key: const Key('forgot-password-resend-button'),
                    onPressed: busy ? null : _requestCodeAfterPasswords,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      requestLoading
                          ? 'Kod gönderiliyor...'
                          : 'Kodu tekrar gönder',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShell({
    required Key key,
    required int step,
    required String title,
    required String description,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(child: _buildStepBadge(step)),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(description, style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildStepBadge(int currentStep) {
    const icons = [
      Icons.person_search_outlined,
      Icons.lock_outline,
      Icons.mark_email_read_outlined,
    ];

    return Semantics(
      label: '$currentStep / 3 adım',
      child: Row(
        key: const Key('forgot-password-step-indicator'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < icons.length; index++) ...[
            _buildStepIcon(
              icon: icons[index],
              active: index < currentStep,
              current: index == currentStep - 1,
            ),
            if (index < icons.length - 1)
              _buildStepConnector(active: index < currentStep - 1),
          ],
        ],
      ),
    );
  }

  Widget _buildStepConnector({required bool active}) {
    return Container(
      width: 22,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: active
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: active ? null : Theme.of(context).dividerColor,
      ),
    );
  }

  Widget _buildStepIcon({
    required IconData icon,
    required bool active,
    required bool current,
  }) {
    final borderRadius = BorderRadius.circular(999);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: active
            ? LinearGradient(
                colors: [
                  AppColors.neonPurpleGradient[0],
                  AppColors.neonPurpleGradient[1],
                  AppColors.neonPurpleGradient[2],
                  AppColors.neonPurpleGradient[3],
                ],
              )
            : null,
        color: active ? null : Theme.of(context).dividerColor,
        boxShadow: current
            ? [
                BoxShadow(
                  color: AppColors.neonPurpleGradient[1].withValues(
                    alpha: 0.16,
                  ),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: borderRadius,
          ),
          child: Icon(
            icon,
            size: 18,
            color: active
                ? AppColors.coralAlt
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSummary({required Key key, bool compact = false}) {
    final colors = Theme.of(context).colorScheme;
    final identifier = _identifierController.text;
    final isEmail = PasswordResetIdentifierPolicy.isValidEmail(identifier);
    final username =
        _resolvedAccount?.username ??
        (isEmail ? '' : PasswordResetIdentifierPolicy.normalize(identifier));
    final avatarUrl = _resolvedAccount?.profilePictureUrl;
    final fallbackLetter = username.isEmpty
        ? '?'
        : String.fromCharCode(username.runes.first).toUpperCase();
    return Container(
      key: key,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            key: const Key('forgot-password-account-avatar'),
            width: compact ? 40 : 46,
            height: compact ? 40 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: avatarUrl == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.brandGradient.first,
                        AppColors.brandGradient[3],
                      ],
                    )
                  : null,
              color: avatarUrl == null ? null : colors.surfaceContainerHighest,
            ),
            child: avatarUrl == null
                ? Center(
                    child: Text(
                      fallbackLetter,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ClipOval(
                    child: AppCachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: compact ? 40 : 46,
                      height: compact ? 40 : 46,
                      cacheWidth: compact ? 80 : 92,
                      cacheHeight: compact ? 80 : 92,
                      placeholderBuilder: (_) => Center(
                        child: Text(
                          fallbackLetter,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      errorBuilder: (_) => Center(
                        child: Text(
                          fallbackLetter,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kullanıcı adı',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (isEmail) ...[
                  const SizedBox(height: 2),
                  Text(
                    identifier,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: AppColors.brandGradient),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.2),
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.coralLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestError(String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('forgot-password-request-error'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('password-reset-success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: AppColors.brandGradient),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandGradient[2].withValues(alpha: 0.18),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.2),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 30,
                  color: AppColors.coralAlt,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Şifren güncellendi',
          key: Key('forgot-password-success-title'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Yeni şifren hazır. Hesabına güvenle giriş yapabilirsin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        GradientOutlineButton(
          key: const Key('forgot-password-login-button'),
          onPressed: _returnToLogin,
          label: 'Girişe dön',
        ),
      ],
    );
  }
}
