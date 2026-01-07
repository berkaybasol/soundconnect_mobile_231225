import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../../../location/presentation/cubit/location_cubit.dart';
import '../../../location/presentation/cubit/location_state.dart';
import 'otp_verify_screen.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

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

  final List<String> _roles = const [
    'ROLE_LISTENER',
    'ROLE_MUSICIAN',
    'ROLE_VENUE',
    'ROLE_STUDIO',
    'ROLE_PRODUCER',
    'ROLE_ORGANIZER',
  ];
  final List<_RoleOption> _roleOptions = const [
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
      title: 'Mekan Temsilcisiyim',
      icon: Icons.storefront_outlined,
      badge: 'Basvuru',
    ),
    _RoleOption(
      id: 'ROLE_STUDIO',
      title: 'Studyo Temsilcisiyim',
      icon: Icons.mic_none,
    ),
    _RoleOption(
      id: 'ROLE_PRODUCER',
      title: 'Produktor',
      icon: Icons.graphic_eq,
    ),
    _RoleOption(
      id: 'ROLE_ORGANIZER',
      title: 'Organizatorum',
      icon: Icons.event,
    ),
  ];

  String? _selectedRole;
  String? _selectedCityId;
  String? _selectedDistrictId;
  String? _selectedNeighborhoodId;

  int _stepIndex = 0;
  late final PageController _pageController;
  late final ValueNotifier<double> _pageProgress;

  int get _totalSteps => _selectedRole == 'ROLE_VENUE' ? 5 : 4;

  @override
  void initState() {
    super.initState();
    _selectedRole = _roles.first;
    _pageController = PageController(initialPage: 0);
    _pageProgress = ValueNotifier<double>(0.0);
    _pageController.addListener(() {
      _pageProgress.value = _pageController.page ?? _stepIndex.toDouble();
    });
  }

  @override
  void dispose() {
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  bool _validateStep(int index) {
    switch (index) {
      case 0:
        final username = _usernameController.text.trim();
        return username.isNotEmpty && username.length >= 3 && username.length <= 30;
      case 1:
        final email = _emailController.text.trim();
        return email.isNotEmpty && _isValidEmail(email);
      case 2:
        final password = _passwordController.text.trim();
        final rePassword = _rePasswordController.text.trim();
        return password.isNotEmpty &&
            password.length >= 8 &&
            password.length <= 20 &&
            rePassword.isNotEmpty &&
            password == rePassword;
      case 3:
        return (_selectedRole ?? '').isNotEmpty;
      case 4:
        return _venueNameController.text.trim().isNotEmpty &&
            _venueAddressController.text.trim().isNotEmpty &&
            _venuePhoneController.text.trim().isNotEmpty &&
            (_selectedCityId ?? '').isNotEmpty &&
            (_selectedDistrictId ?? '').isNotEmpty;
      default:
        return false;
    }
  }

  void _next() {
    if (!_validateStep(_stepIndex)) {
      if (_stepIndex == 0) {
        final username = _usernameController.text.trim();
        if (username.isEmpty) {
          _showError('kullanıcı adı boş olamaz');
        } else {
          _showError('Kullanıcı adı 3 ile 30 karakter arasında olmalıdır.');
        }
      } else if (_stepIndex == 1) {
        final email = _emailController.text.trim();
        if (email.isEmpty) {
          _showError('E-posta boş olamaz.');
        } else {
          _showError('Geçerli bir e-posta girin.');
        }
      } else if (_stepIndex == 2) {
        final password = _passwordController.text.trim();
        final rePassword = _rePasswordController.text.trim();
        if (password.isEmpty) {
          _showError('Şifre boş olamaz.');
        } else if (password.length < 8 || password.length > 20) {
          _showError('Şifreniz en az 8, en fazla 20 karakterden oluşmalıdır.');
        } else if (rePassword.isEmpty) {
          _showError('Şifre tekrarı boş olamaz.');
        } else {
          _showError('Şifreler eşleşmeli.');
        }
      } else if (_stepIndex == 3) {
        _showError('Rol secilmelidir.');
      } else {
        _showError('Mekan bilgilerini eksiksiz doldur.');
      }
      return;
    }

    if (_stepIndex < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_selectedRole == 'ROLE_VENUE') {
      context.read<AuthCubit>().register(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            rePassword: _rePasswordController.text.trim(),
            role: _selectedRole ?? '',
            venueName: _venueNameController.text.trim(),
            venueAddress: _venueAddressController.text.trim(),
            phone: _venuePhoneController.text.trim(),
            cityId: _selectedCityId,
            districtId: _selectedDistrictId,
            neighborhoodId: _selectedNeighborhoodId,
          );
      return;
    }

    context.read<AuthCubit>().register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          rePassword: _rePasswordController.text.trim(),
          role: _selectedRole ?? '',
        );
  }

  void _back() {
    if (_stepIndex == 0) {
      Navigator.pop(context);
      return;
    }
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _handleRoleSelect(String roleId) {
    setState(() {
      _selectedRole = roleId;
    });
    if (roleId == 'ROLE_VENUE' && _stepIndex == 3) {
      if (_totalSteps == 5) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _buildProgressIndicator(double progressValue) {
    final steps = _totalSteps == 5
        ? const [
            Icons.headphones,
            Icons.favorite_border,
            Icons.link,
            Icons.storefront_outlined,
            Icons.check_circle,
          ]
        : const [
            Icons.headphones,
            Icons.favorite_border,
            Icons.link,
            Icons.check_circle,
          ];

    final clamped = progressValue.clamp(0, steps.length - 1).toDouble();
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      children.add(_buildStepIcon(i, steps[i], clamped));
      if (i < steps.length - 1) {
        children.add(_buildStepConnector(i, clamped));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _buildStepConnector(int index, double progressValue) {
    final double fill = (progressValue - index).clamp(0.0, 1.0).toDouble();
    return Container(
      width: 22,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.border, AppColors.coralAlt, fill),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _buildStepIcon(int index, IconData icon, double progressValue) {
    final double fill = (progressValue - index).clamp(0.0, 1.0).toDouble();
    final isActive = fill > 0.01 && fill < 0.99;
    final isComplete = fill >= 1;
    final borderRadius = BorderRadius.circular(999);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: (fill > 0)
            ? const LinearGradient(
                colors: [
                  Color(0xFF7B2FF7),
                  Color(0xFF9B5DE5),
                  Color(0xFFC65BF0),
                  Color(0xFFF26CA7),
                ],
              )
            : null,
        color: (fill > 0) ? null : AppColors.border,
        boxShadow: isActive || isComplete
            ? [
                BoxShadow(
                  color: const Color(0xFF9B5DE5).withOpacity(0.16),
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
            color: AppColors.inputFill,
            borderRadius: borderRadius,
          ),
          child: Icon(
            icon,
            size: 18,
            color: Color.lerp(AppColors.textMuted, AppColors.coralAlt, fill),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Kullanici adi olustur',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Hesap olusturmak icin bir kullanici adi ekle.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        GradientTextField(
          controller: _usernameController,
          label: 'Kullanici adi',
          prefixIcon: Icons.person_outline,
        ),
      ],
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Email adresini ekle',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Dogrulama kodunu bu adrese gonderecegiz.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        GradientTextField(
          controller: _emailController,
          label: 'Email',
          prefixIcon: Icons.email_outlined,
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sifre belirle',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sifren en az 8, en fazla 20 karakter olmali.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        GradientTextField(
          controller: _passwordController,
          label: 'Sifre',
          prefixIcon: Icons.lock_outline,
          obscureText: _isPasswordObscured,
          suffixIcon: IconButton(
            onPressed: () {
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
        const SizedBox(height: 16),
        GradientTextField(
          controller: _rePasswordController,
          label: 'Sifre tekrar',
          prefixIcon: Icons.lock_outline,
          obscureText: _isRePasswordObscured,
          suffixIcon: IconButton(
            onPressed: () {
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
      ],
    );
  }

  Widget _buildRoleStep() {
    final venueOption =
        _roleOptions.firstWhere((option) => option.id == 'ROLE_VENUE');
    final otherOptions =
        _roleOptions.where((option) => option.id != 'ROLE_VENUE').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "SoundConnect'te ne yapmak istiyorsun?",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Muzigi nasil yasayacagini sec. SoundConnect\'i sana gore sekillendirelim.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...otherOptions.map(_buildRoleOption),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border),
                const SizedBox(height: 16),
                _buildRoleOption(venueOption),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVenueStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mekan bilgilerini paylas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Bilgileri doldurduktan sonra kisa surede sizinle iletisime gececegiz.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GradientTextField(
                  controller: _venueNameController,
                  label: 'Mekan adi',
                  prefixIcon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 12),
                GradientTextField(
                  controller: _venueAddressController,
                  label: 'Adres',
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                GradientTextField(
                  controller: _venuePhoneController,
                  label: 'Telefon',
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: 12),
                BlocBuilder<LocationCubit, LocationState>(
                  builder: (context, locationState) {
                    if (locationState.cities.isEmpty &&
                        locationState.status != LocationStatus.loading) {
                      context.read<LocationCubit>().loadCities();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedCityId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            prefixIcon:
                                const Icon(Icons.location_city_outlined),
                            hintText: 'Sehir sec',
                          ),
                          dropdownColor: AppColors.navBlueSoft,
                          items: locationState.cities
                              .map(
                                (city) => DropdownMenuItem(
                                  value: city.id,
                                  child: Text(city.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCityId = value;
                              _selectedDistrictId = null;
                              _selectedNeighborhoodId = null;
                            });
                            if (value != null) {
                              context
                                  .read<LocationCubit>()
                                  .loadDistricts(value);
                            } else {
                              context.read<LocationCubit>().resetDistricts();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedDistrictId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.map_outlined),
                            hintText: 'Ilce sec',
                          ),
                          dropdownColor: AppColors.navBlueSoft,
                          items: locationState.districts
                              .map(
                                (district) => DropdownMenuItem(
                                  value: district.id,
                                  child: Text(district.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDistrictId = value;
                              _selectedNeighborhoodId = null;
                            });
                            if (value != null) {
                              context
                                  .read<LocationCubit>()
                                  .loadNeighborhoods(value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedNeighborhoodId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            prefixIcon: const Icon(Icons.place_outlined),
                            hintText: 'Mahalle sec (opsiyonel)',
                          ),
                          dropdownColor: AppColors.navBlueSoft,
                          items: locationState.neighborhoods
                              .map(
                                (neighborhood) => DropdownMenuItem(
                                  value: neighborhood.id,
                                  child: Text(neighborhood.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedNeighborhoodId = value;
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.action != AuthAction.register) return;
        if (state.status == AuthStatus.success) {
          final email = state.registerResult?.email;
          Navigator.pushNamed(
            context,
            AppRoutes.otpVerify,
            arguments: OtpVerifyArgs(email: email, role: _selectedRole),
          );
        } else if (state.status == AuthStatus.failure) {
          final message = state.error?.message ?? 'Register failed';
          _showError(message);
        }
      },
      builder: (context, state) {
        final isLoading =
            state.status == AuthStatus.loading && state.action == AuthAction.register;

        final pages = <Widget>[
          _buildUsernameStep(),
          _buildEmailStep(),
          _buildPasswordStep(),
          _buildRoleStep(),
          if (_selectedRole == 'ROLE_VENUE') _buildVenueStep(),
        ];

        return AppScaffold(
          title: 'Kaydol',
          centerContent: true,
          centerAlignment: const Alignment(0, -0.48),
          scrollable: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  ValueListenableBuilder<double>(
                    valueListenable: _pageProgress,
                    builder: (context, value, child) {
                      return Center(child: _buildProgressIndicator(value));
                    },
                  ),
                  const SizedBox(height: 24),
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
                            final page = _pageController.position.haveDimensions
                                ? (_pageController.page ??
                                    _stepIndex.toDouble())
                                : _stepIndex.toDouble();
                            final distance = (page - index).abs();
                            final opacity =
                                (1 - (distance * 0.35)).clamp(0.0, 1.0);
                            final scale =
                                (1 - (distance * 0.06)).clamp(0.94, 1.0);

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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: isLoading ? null : _back,
                        child: const Text('Geri'),
                      ),
                      const Spacer(),
                      GradientOutlineButton(
                        onPressed: isLoading ? null : _next,
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
        );
      },
    );
  }

  Widget _buildRoleOption(_RoleOption option) {
    final isSelected = _selectedRole == option.id;
    final borderRadius = BorderRadius.circular(18);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () {
          _handleRoleSelect(option.id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.inputFill.withOpacity(0.98)
                : AppColors.inputFill,
            borderRadius: borderRadius,
            border: Border.all(
              color: isSelected ? AppColors.coralAlt : AppColors.border,
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.coralAlt.withOpacity(0.22),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.navBlueSoft,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.coralAlt.withOpacity(0.25),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  option.icon,
                  color: isSelected
                      ? AppColors.coralAlt
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (option.badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navBlueSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    option.badge!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right,
                color: isSelected
                    ? AppColors.coralAlt
                    : AppColors.textMuted.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption {
  final String id;
  final String title;
  final IconData icon;
  final String? badge;

  const _RoleOption({
    required this.id,
    required this.title,
    required this.icon,
    this.badge,
  });
}
