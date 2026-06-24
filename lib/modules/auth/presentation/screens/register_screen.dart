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
    'ROLE_PRODUCER',
    'ROLE_ORGANIZER',
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
    ),
    _RoleOption(
      id: 'ROLE_PRODUCER',
      title: 'Prodüktörüm',
      icon: Icons.graphic_eq,
    ),
    _RoleOption(
      id: 'ROLE_ORGANIZER',
      title: 'Organizatörüm',
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  bool _validateStep(int index) {
    switch (index) {
      case 0:
        final username = _usernameController.text.trim();
        return username.isNotEmpty &&
            username.length >= 3 &&
            username.length <= 30;
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
          _showError('Kullanıcı adı boş olamaz.');
        } else {
          _showError('Kullanıcı adı 3 ile 30 karakter arasında olmalı.');
        }
      } else if (_stepIndex == 1) {
        final email = _emailController.text.trim();
        if (email.isEmpty) {
          _showError('E-posta boş olamaz.');
        } else {
          _showError('Geçerli bir e-posta gir.');
        }
      } else if (_stepIndex == 2) {
        final password = _passwordController.text.trim();
        final rePassword = _rePasswordController.text.trim();
        if (password.isEmpty) {
          _showError('Şifre boş olamaz.');
        } else if (password.length < 8 || password.length > 20) {
          _showError('Şifren en az 8, en fazla 20 karakterden oluşmalı.');
        } else if (rePassword.isEmpty) {
          _showError('Şifre tekrarı boş olamaz.');
        } else {
          _showError('Şifreler eşleşmeli.');
        }
      } else if (_stepIndex == 3) {
        _showError('Rol seçilmelidir.');
      } else {
        _showError('Mekan bilgilerini eksiksiz doldur.');
      }
      return;
    }

    if (_stepIndex < _totalSteps - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 260),
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
      duration: Duration(milliseconds: 220),
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
          duration: Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _buildProgressIndicator(double progressValue) {
    final steps = _totalSteps == 5
        ? [
            Icons.headphones,
            Icons.favorite_border,
            Icons.link,
            Icons.storefront_outlined,
            Icons.check_circle,
          ]
        : [
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

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
  }

  Widget _buildStepConnector(int index, double progressValue) {
    final double fill = (progressValue - index).clamp(0.0, 1.0).toDouble();
    return Container(
      width: 22,
      height: 2,
      margin: EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Stack(
          children: [
            Container(color: Theme.of(context).dividerColor),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.brandGradient),
                  ),
                ),
              ),
            ),
          ],
        ),
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
            ? LinearGradient(
                colors: [
                  AppColors.neonPurpleGradient[0],
                  AppColors.neonPurpleGradient[1],
                  AppColors.neonPurpleGradient[2],
                  AppColors.neonPurpleGradient[3],
                ],
              )
            : null,
        color: (fill > 0) ? null : Theme.of(context).dividerColor,
        boxShadow: isActive || isComplete
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
        padding: EdgeInsets.all(1.2),
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
            color: Color.lerp(
              Theme.of(context).colorScheme.onSurfaceVariant,
              AppColors.coralAlt,
              fill,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kullanıcı adı oluştur',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        Text(
          'Hesap oluşturmak için bir kullanıcı adı ekle.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 12),
        GradientTextField(
          controller: _usernameController,
          label: 'Kullanıcı adı',
          prefixIcon: Icons.person_outline,
        ),
      ],
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'E-posta adresini ekle',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        Text(
          'Doğrulama kodunu bu adrese göndereceğiz.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 12),
        GradientTextField(
          controller: _emailController,
          label: 'E-posta',
          prefixIcon: Icons.email_outlined,
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Şifre belirle',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        Text(
          'Şifren en az 8, en fazla 20 karakter olmalı.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 12),
        GradientTextField(
          controller: _passwordController,
          label: 'Şifre',
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
        SizedBox(height: 16),
        GradientTextField(
          controller: _rePasswordController,
          label: 'Şifre tekrar',
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
    final venueOption = _roleOptions.firstWhere(
      (option) => option.id == 'ROLE_VENUE',
    );
    final otherOptions = _roleOptions
        .where((option) => option.id != 'ROLE_VENUE')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "SoundConnect'te ne yapmak istiyorsun?",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        Text(
          'Müziği nasıl yaşayacağını seç. SoundConnect\'i sana göre şekillendirelim.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...otherOptions.map(_buildRoleOption),
                SizedBox(height: 16),
                Divider(color: Theme.of(context).dividerColor),
                SizedBox(height: 16),
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
        Text(
          'Mekan bilgilerini paylaş',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        Text(
          'Bilgileri doldurduktan sonra kısa sürede sizinle iletişime geçeceğiz.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GradientTextField(
                  controller: _venueNameController,
                  label: 'Mekan adı',
                  prefixIcon: Icons.storefront_outlined,
                ),
                SizedBox(height: 12),
                GradientTextField(
                  controller: _venueAddressController,
                  label: 'Adres',
                  prefixIcon: Icons.location_on_outlined,
                ),
                SizedBox(height: 12),
                GradientTextField(
                  controller: _venuePhoneController,
                  label: 'Telefon',
                  prefixIcon: Icons.phone_outlined,
                ),
                SizedBox(height: 12),
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
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            prefixIcon: Icon(Icons.location_city_outlined),
                            hintText: 'Şehir seç',
                          ),
                          dropdownColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
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
                              context.read<LocationCubit>().loadDistricts(
                                value,
                              );
                            } else {
                              context.read<LocationCubit>().resetDistricts();
                            }
                          },
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedDistrictId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            prefixIcon: Icon(Icons.map_outlined),
                            hintText: 'İlçe seç',
                          ),
                          dropdownColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
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
                              context.read<LocationCubit>().loadNeighborhoods(
                                value,
                              );
                            }
                          },
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedNeighborhoodId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            prefixIcon: Icon(Icons.place_outlined),
                            hintText: 'Mahalle seç (opsiyonel)',
                          ),
                          dropdownColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
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
          final message = state.error?.message ?? 'Kayıt başarısız.';
          _showError(message);
        }
      },
      builder: (context, state) {
        final isLoading =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.register;

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
                            final page = _pageController.position.haveDimensions
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
                        onPressed: isLoading ? null : _back,
                        child: Text('Geri'),
                      ),
                      Spacer(),
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
      padding: EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () {
          _handleRoleSelect(option.id);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(colors: AppColors.brandGradient)
                : null,
            color: isSelected
                ? null
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: borderRadius,
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Theme.of(context).dividerColor,
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.brandGradient[2].withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(isSelected ? 1.0 : 0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: isSelected ? 0.98 : 1),
                borderRadius: borderRadius,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.brandGradient[2].withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                colors: AppColors.brandGradient,
                              ).createShader(bounds);
                            },
                            child: Icon(option.icon, color: AppColors.white),
                          )
                        : Icon(
                            option.icon,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (option.badge != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Text(
                        option.badge!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                  ],
                  isSelected
                      ? ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (Rect bounds) {
                            return LinearGradient(
                              colors: AppColors.brandGradient,
                            ).createShader(bounds);
                          },
                          child: Icon(
                            Icons.chevron_right,
                            color: AppColors.white,
                          ),
                        )
                      : Icon(
                          Icons.chevron_right,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                ],
              ),
            ),
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

  _RoleOption({
    required this.id,
    required this.title,
    required this.icon,
    this.badge,
  });
}
