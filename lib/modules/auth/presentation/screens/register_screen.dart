import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../widgets/business_registration_fields.dart';
import '../../data/google_auth_repository.dart';
import '../../domain/business_registration_details.dart';
import '../../domain/entities/login_result.dart';
import '../../domain/password_policy.dart';
import '../../domain/username_policy.dart';
import 'otp_verify_screen.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

part 'register_screen_support.dart';

part 'register_screen_is_business_role.dart';
part 'register_screen_build_business_step.dart';

typedef GoogleRegistrationSubmit =
    Future<LoginResult> Function(
      String username,
      String role,
      BusinessRegistrationDetails? business,
    );

enum _RegistrationStep { username, email, password, role, business }

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key}) : completeGoogleRegistration = null;

  const RegisterScreen.google({
    super.key,
    required GoogleRegistrationSubmit this.completeGoogleRegistration,
  });

  final GoogleRegistrationSubmit? completeGoogleRegistration;

  @override
  Widget build(BuildContext context) => AppSurfaceThemeScope(
    child: _RegistrationForm(
      completeGoogleRegistration: completeGoogleRegistration,
    ),
  );
}

class _RegistrationForm extends StatefulWidget {
  const _RegistrationForm({required this.completeGoogleRegistration});

  final GoogleRegistrationSubmit? completeGoogleRegistration;

  @override
  State<_RegistrationForm> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<_RegistrationForm> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rePasswordController = TextEditingController();
  final _business = BusinessRegistrationController();

  bool _isPasswordObscured = true;
  bool _isRePasswordObscured = true;

  final List<String> _roles = [
    'ROLE_LISTENER',
    'ROLE_MUSICIAN',
    'ROLE_VENUE',
    'ROLE_STUDIO',
  ];
  final List<_RoleOption> _roleOptions = [
    _RoleOption(
      id: 'ROLE_LISTENER',
      title: 'Sosyal Deneyim',
      icon: Icons.headphones,
    ),
    _RoleOption(
      id: 'ROLE_MUSICIAN',
      title: 'Muzisyenim',
      icon: Icons.music_note,
    ),
    _RoleOption(
      id: 'ROLE_VENUE',
      title: 'Mekan temsilcisiyim',
      icon: Icons.storefront_outlined,
      badge: 'Başvuru',
    ),
    _RoleOption(
      id: 'ROLE_STUDIO',
      title: 'Stüdyo temsilcisiyim',
      icon: Icons.mic_none,
      badge: 'Başvuru',
    ),
  ];

  String? _selectedRole;

  int _stepIndex = 0;
  late final PageController _pageController;
  late final ValueNotifier<double> _pageProgress;
  Timer? _usernameAvailabilityDebounce;
  String? _lastUsernameCheckRequested;
  bool _usernameTouched = false;
  bool _registrationNavigationScheduled = false;
  bool _submittingGoogle = false;
  String? _googleUsernameError;

  bool get _isGoogle => widget.completeGoogleRegistration != null;

  List<_RegistrationStep> get _steps => [
    if (_isGoogle) _RegistrationStep.role,
    _RegistrationStep.username,
    if (!_isGoogle) ...[
      _RegistrationStep.email,
      _RegistrationStep.password,
      _RegistrationStep.role,
    ],
    if (_isBusinessRole) _RegistrationStep.business,
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = _roles.first;
    _usernameController.addListener(_handleUsernameChanged);
    _pageController = PageController(initialPage: 0);
    _pageProgress = ValueNotifier<double>(0.0);
    _pageController.addListener(() {
      _pageProgress.value = _pageController.page ?? _stepIndex.toDouble();
    });
  }

  @override
  void dispose() {
    _usernameAvailabilityDebounce?.cancel();
    _usernameController.removeListener(_handleUsernameChanged);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rePasswordController.dispose();
    _business.dispose();
    _pageController.dispose();
    _pageProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (_isGoogle || state.action != AuthAction.register) return;
        if (state.status == AuthStatus.success) {
          final route = ModalRoute.of(context);
          if (_registrationNavigationScheduled || route?.isCurrent != true) {
            return;
          }
          _registrationNavigationScheduled = true;
          final email = state.registerResult?.email;
          final navigator = Navigator.of(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !navigator.mounted || route?.isCurrent != true) {
              return;
            }
            navigator.pushNamed(
              AppRoutes.otpVerify,
              arguments: OtpVerifyArgs(email: email, role: _selectedRole),
            );
          });
        } else if (state.status == AuthStatus.failure) {
          final message = state.error?.message ?? 'Kayıt başarısız.';
          _showError(message, tone: AppSnackBarTone.error);
        }
      },
      builder: (context, state) {
        final isLoading = _isGoogle
            ? _submittingGoogle
            : state.status == AuthStatus.loading &&
                  state.action == AuthAction.register;
        final isUsernameChecking =
            !_isGoogle &&
            state.status == AuthStatus.loading &&
            state.action == AuthAction.usernameAvailability &&
            _lastUsernameCheckRequested ==
                UsernamePolicy.normalize(_usernameController.text);
        final registrationLocked =
            isLoading || _registrationNavigationScheduled;

        final steps = _steps;

        return PopScope(
          canPop: !registrationLocked,
          child: AppScaffold(
            title: 'Kaydol',
            centerContent: true,
            centerAlignment: Alignment(0, -0.48),
            scrollable: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 12),
                    ValueListenableBuilder<double>(
                      valueListenable: _pageProgress,
                      builder: (context, value, child) {
                        return Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildProgressIndicator(value),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 24),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: steps.length,
                        onPageChanged: (index) {
                          setState(() {
                            _stepIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              final page =
                                  _pageController.position.haveDimensions
                                  ? (_pageController.page ??
                                        _stepIndex.toDouble())
                                  : _stepIndex.toDouble();
                              final distance = (page - index).abs();
                              final opacity = (1 - (distance * 0.35)).clamp(
                                0.0,
                                1.0,
                              );
                              final scale = (1 - (distance * 0.06)).clamp(
                                0.94,
                                1.0,
                              );

                              return Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: SingleChildScrollView(
                              key: PageStorageKey(steps[index]),
                              primary: false,
                              child: switch (steps[index]) {
                                _RegistrationStep.username =>
                                  _buildUsernameStep(state),
                                _RegistrationStep.email => _buildEmailStep(),
                                _RegistrationStep.password =>
                                  _buildPasswordStep(),
                                _RegistrationStep.role => _buildRoleStep(
                                  enabled: !registrationLocked,
                                ),
                                _RegistrationStep.business =>
                                  _buildBusinessStep(
                                    enabled: !registrationLocked,
                                  ),
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: registrationLocked || isUsernameChecking
                              ? null
                              : _back,
                          child: Text('Geri'),
                        ),
                        Flexible(
                          child: GradientOutlineButton(
                            maxLines: 2,
                            onPressed: registrationLocked || isUsernameChecking
                                ? null
                                : _next,
                            label: _stepIndex == steps.length - 1
                                ? _submitLabel(isLoading)
                                : 'Devam et',
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _updateView(VoidCallback change) => setState(change);

  String _submitLabel(bool isLoading) {
    if (isLoading) return 'Kaydediliyor...';
    if (!_isGoogle) return 'Tamamla';
    return _isBusinessRole ? 'Başvurumu gönder' : 'Hesabımı oluştur';
  }

  // Keep notifier registration and removal on the same instance callback.
  void _handleUsernameChanged() => _updateUsernameAvailability();
}
