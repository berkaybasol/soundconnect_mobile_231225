import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../profile/presentation/screens/account_profile_settings_section.dart';
import '../../domain/username_policy.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  static const _dangerRed = Color(0xFFFF5C6C);

  final _usernameController = TextEditingController();
  String _currentUsername = '';
  bool _editingUsername = false;

  @override
  void initState() {
    super.initState();
    final username =
        serviceLocator<AuthSessionManager>().session.username ?? '';
    _currentUsername = UsernamePolicy.normalize(username);
    _usernameController.text = _currentUsername;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Widget _soonBadge(BuildContext context, {Color? color}) {
    final badgeColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Yakında',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _canonicalizeUsername() {
    final username = UsernamePolicy.normalize(_usernameController.text);
    if (_usernameController.text != username) {
      _usernameController.value = TextEditingValue(
        text: username,
        selection: TextSelection.collapsed(offset: username.length),
      );
    }
    return username;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startEditingUsername() {
    _usernameController.text = _currentUsername;
    setState(() => _editingUsername = true);
  }

  void _cancelEditingUsername() {
    FocusManager.instance.primaryFocus?.unfocus();
    _usernameController.text = _currentUsername;
    setState(() => _editingUsername = false);
  }

  void _submit() {
    final username = _canonicalizeUsername();
    if (username.isEmpty) {
      _showMessage('Kullanıcı adı boş olamaz.');
      return;
    }
    if (!UsernamePolicy.isValid(username)) {
      _showMessage('Kullanıcı adı 3 ile 30 karakter arasında olmalı.');
      return;
    }
    if (username == _currentUsername) {
      _showMessage('Bu kullanıcı adını zaten kullanıyorsun.');
      return;
    }
    context.read<AuthCubit>().updateUsername(username: username);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.action != AuthAction.updateUsername) return;
        if (state.status == AuthStatus.success) {
          final canonicalUsername = UsernamePolicy.normalize(
            state.message ?? _usernameController.text,
          );
          setState(() {
            _currentUsername = canonicalUsername;
            _usernameController.text = canonicalUsername;
            _editingUsername = false;
          });
          _showMessage(
            'Kullanıcı adın @$canonicalUsername olarak güncellendi.',
          );
        } else if (state.status == AuthStatus.failure) {
          _showMessage(
            state.error?.message ??
                'Kullanıcı adı güncellenemedi. Lütfen tekrar dene.',
          );
        }
      },
      builder: (context, state) {
        final isLoading =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.updateUsername;

        return AppScaffold(
          title: 'Hesap Ayarları',
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AutofillGroup(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _usernameController,
                  builder: (context, value, _) {
                    final hasChange =
                        UsernamePolicy.normalize(value.text) !=
                        _currentUsername;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AccountProfileSettingsSection(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Hesap bilgileri',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ListTile(
                          key: const Key('account-settings-username-tile'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => LinearGradient(
                                colors: AppColors.brandGradient,
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.alternate_email_rounded,
                                color: AppColors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          title: const Text(
                            'Kullanıcı adı',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('@$_currentUsername'),
                          trailing: TextButton(
                            key: const Key(
                              'account-settings-edit-username-button',
                            ),
                            onPressed: isLoading
                                ? null
                                : _editingUsername
                                ? _cancelEditingUsername
                                : _startEditingUsername,
                            child: Text(_editingUsername ? 'Kapat' : 'Düzenle'),
                          ),
                          onTap: isLoading || _editingUsername
                              ? null
                              : _startEditingUsername,
                        ),
                        Divider(color: Theme.of(context).dividerColor),
                        if (_editingUsername) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Yeni kullanıcı adı',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  key: const Key(
                                    'account-settings-username-field',
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _usernameController,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    enabled: !isLoading,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    onSubmitted: (_) {
                                      if (!isLoading && hasChange) {
                                        _submit();
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Yeni kullanıcı adını yaz',
                                      prefixIcon: Icon(
                                        Icons.alternate_email_rounded,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: hasChange
                                      ? Container(
                                          key: const Key(
                                            'account-settings-username-cooldown-warning',
                                          ),
                                          margin: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.coral.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: AppColors.coral.withValues(
                                                alpha: 0.18,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.info_outline_rounded,
                                                size: 18,
                                                color: AppColors.coralLight,
                                              ),
                                              const SizedBox(width: 9),
                                              Expanded(
                                                child: Text(
                                                  'Kullanıcı adını '
                                                  'değiştirdikten sonra 30 '
                                                  'gün boyunca yeniden '
                                                  'değiştiremezsin.',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(height: 1.35),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    key: const Key(
                                      'account-settings-save-button',
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.coralAlt,
                                      foregroundColor: AppColors.white,
                                      disabledBackgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      disabledForegroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: isLoading || !hasChange
                                        ? null
                                        : _submit,
                                    icon: isLoading
                                        ? const SizedBox(
                                            width: 17,
                                            height: 17,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check_rounded,
                                            size: 19,
                                          ),
                                    label: Text(
                                      isLoading
                                          ? 'Kaydediliyor...'
                                          : 'Kullanıcı adını kaydet',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_editingUsername)
                          Divider(color: Theme.of(context).dividerColor),
                        ListTile(
                          key: const Key('account-settings-password-reminder'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => LinearGradient(
                                colors: AppColors.brandGradient,
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          title: const Text(
                            'Şifre',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Şifre değiştirme özelliği yakında',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Yakında',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Hesap yönetimi',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ListTile(
                          key: const Key(
                            'account-settings-delete-account-reminder',
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _dangerRed.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: _dangerRed,
                              size: 22,
                            ),
                          ),
                          title: const Text(
                            'Hesabı sil',
                            style: TextStyle(
                              color: _dangerRed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'Hesap silme özelliği yakında',
                            style: TextStyle(
                              color: _dangerRed.withValues(alpha: 0.78),
                            ),
                          ),
                          trailing: _soonBadge(context, color: _dangerRed),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
