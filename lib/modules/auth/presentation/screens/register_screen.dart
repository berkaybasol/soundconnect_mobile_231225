import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../../../location/presentation/cubit/location_cubit.dart';
import '../../../location/presentation/cubit/location_state.dart';
import '../../domain/business_name_policy.dart';
import '../../domain/password_policy.dart';
import '../../domain/studio_registration_policy.dart';
import '../../domain/username_policy.dart';
import 'otp_verify_screen.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

part 'register_screen_support.dart';

part 'register_screen_is_business_role.dart';
part 'register_screen_build_business_step.dart';

class RegisterScreen extends StatefulWidget {
  RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rePasswordController = TextEditingController();
  final _venueNameController = TextEditingController();
  final _venueAddressController = TextEditingController();
  final _venuePhoneController = TextEditingController();

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
  String? _selectedCityId;
  String? _selectedDistrictId;
  String? _selectedNeighborhoodId;

  int _stepIndex = 0;
  late final PageController _pageController;
  late final ValueNotifier<double> _pageProgress;
  Timer? _usernameAvailabilityDebounce;
  String? _lastUsernameCheckRequested;
  bool _usernameTouched = false;
  bool _registrationNavigationScheduled = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<LocationCubit>();
      if (cubit.state.cities.isEmpty &&
          cubit.state.status != LocationStatus.loading) {
        cubit.loadCities();
      }
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
    _venueNameController.dispose();
    _venueAddressController.dispose();
    _venuePhoneController.dispose();
    _pageController.dispose();
    _pageProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.action != AuthAction.register) return;
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
        final isLoading =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.register;
        final isUsernameChecking =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.usernameAvailability &&
            _lastUsernameCheckRequested ==
                UsernamePolicy.normalize(_usernameController.text);
        final registrationLocked =
            isLoading || _registrationNavigationScheduled;

        final pages = <Widget>[
          _buildUsernameStep(state),
          _buildEmailStep(),
          _buildPasswordStep(),
          _buildRoleStep(),
          if (_isBusinessRole) _buildBusinessStep(enabled: !registrationLocked),
        ];

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
                        return Center(child: _buildProgressIndicator(value));
                      },
                    ),
                    SizedBox(height: 24),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: pages.length,
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
                            child: pages[index],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: registrationLocked || isUsernameChecking
                              ? null
                              : _back,
                          child: Text('Geri'),
                        ),
                        Spacer(),
                        GradientOutlineButton(
                          onPressed: registrationLocked || isUsernameChecking
                              ? null
                              : _next,
                          label: _stepIndex == _totalSteps - 1
                              ? (isLoading ? 'Kaydediliyor...' : 'Tamamla')
                              : 'Devam et',
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

  // Keep notifier registration and removal on the same instance callback.
  void _handleUsernameChanged() => _updateUsernameAvailability();
}
