part of 'register_screen.dart';

extension _RegisterScreenStateIsBusinessRoleMethods on _RegisterScreenState {
  bool get _isBusinessRole =>
      _selectedRole == 'ROLE_VENUE' || _selectedRole == 'ROLE_STUDIO';

  bool get _isStudioRole => _selectedRole == 'ROLE_STUDIO';

  int get _totalSteps => _isBusinessRole ? 5 : 4;

  void _showError(
    String message, {
    AppSnackBarTone tone = AppSnackBarTone.warning,
  }) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(appSnackBar(context, tone: tone, content: Text(message)));
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
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

  void _updateUsernameAvailability() {
    _usernameAvailabilityDebounce?.cancel();
    final username = UsernamePolicy.normalize(_usernameController.text);
    if (mounted) {
      _updateView(() {
        _usernameTouched = true;
      });
    }
    if (!UsernamePolicy.isValid(username)) return;

    _usernameAvailabilityDebounce = Timer(
      const Duration(milliseconds: 450),
      () {
        if (!mounted) return;
        _lastUsernameCheckRequested = username;
        context.read<AuthCubit>().checkUsernameAvailability(username: username);
      },
    );
  }

  void _canonicalizeBusinessName() {
    final normalized = BusinessNamePolicy.normalize(_venueNameController.text);
    if (_venueNameController.text == normalized) return;
    _venueNameController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  Future<bool> _ensureUsernameAvailable() async {
    final username = _canonicalizeUsername();
    final state = context.read<AuthCubit>().state;
    final cached = state.usernameAvailability;
    if (state.action == AuthAction.usernameAvailability &&
        state.status == AuthStatus.success &&
        cached?.username == username) {
      return cached!.available;
    }

    _usernameAvailabilityDebounce?.cancel();
    _lastUsernameCheckRequested = username;
    final result = await context.read<AuthCubit>().checkUsernameAvailability(
      username: username,
    );
    return mounted && result?.username == username && result!.available;
  }

  bool _validateStep(int index) {
    switch (index) {
      case 0:
        return UsernamePolicy.isValid(_usernameController.text);
      case 1:
        final email = _emailController.text.trim();
        return email.isNotEmpty && _isValidEmail(email);
      case 2:
        final password = _passwordController.text;
        final rePassword = _rePasswordController.text;
        return PasswordPolicy.isValidForRegistration(password) &&
            !PasswordPolicy.isBlank(rePassword) &&
            password == rePassword;
      case 3:
        return (_selectedRole ?? '').isNotEmpty;
      case 4:
        final businessFieldsComplete =
            _venueNameController.text.trim().isNotEmpty &&
            _venueAddressController.text.trim().isNotEmpty &&
            _venuePhoneController.text.trim().isNotEmpty &&
            (_selectedCityId ?? '').isNotEmpty &&
            (_selectedDistrictId ?? '').isNotEmpty &&
            (_selectedNeighborhoodId ?? '').isNotEmpty;
        return businessFieldsComplete &&
            (!_isStudioRole ||
                StudioRegistrationPolicy.isValid(
                  studioName: _venueNameController.text,
                  studioAddress: _venueAddressController.text,
                  phone: _venuePhoneController.text,
                ));
      default:
        return false;
    }
  }

  Future<void> _next() async {
    if (_stepIndex == 0) {
      _canonicalizeUsername();
    } else if (_stepIndex == 4) {
      _canonicalizeBusinessName();
    }
    if (!_validateStep(_stepIndex)) {
      if (_stepIndex == 0) {
        final username = UsernamePolicy.normalize(_usernameController.text);
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
        final password = _passwordController.text;
        final rePassword = _rePasswordController.text;
        if (PasswordPolicy.isBlank(password)) {
          _showError('Şifre boş olamaz.');
        } else if (password.length < PasswordPolicy.registrationMinimumLength) {
          _showError('Şifren en az 8 karakterden oluşmalı.');
        } else if (PasswordPolicy.exceedsBcryptLimit(password)) {
          _showError('Şifren çok uzun. Biraz kısaltıp tekrar dene.');
        } else if (PasswordPolicy.isBlank(rePassword)) {
          _showError('Şifre tekrarı boş olamaz.');
        } else {
          _showError('Şifreler eşleşmeli.');
        }
      } else if (_stepIndex == 3) {
        _showError('Rol seçilmelidir.');
      } else if (_isStudioRole) {
        _showError(
          StudioRegistrationPolicy.validationMessage(
                studioName: _venueNameController.text,
                studioAddress: _venueAddressController.text,
                phone: _venuePhoneController.text,
              ) ??
              'Şehir, ilçe ve mahalle seçimini tamamla.',
        );
      } else {
        _showError(
          'Şehir, ilçe, mahalle ve Açık Adres dahil mekan bilgilerini eksiksiz doldur.',
        );
      }
      return;
    }

    if (_stepIndex == 0) {
      final available = await _ensureUsernameAvailable();
      if (!mounted || !available) return;
    }

    if (_stepIndex < _totalSteps - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }

    final username = _canonicalizeUsername();
    if (_isBusinessRole) {
      context.read<AuthCubit>().register(
        username: username,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rePassword: _rePasswordController.text,
        role: _selectedRole ?? '',
        venueName: _isStudioRole ? null : _venueNameController.text.trim(),
        venueAddress: _isStudioRole
            ? null
            : _venueAddressController.text.trim(),
        phone: _isStudioRole ? null : _venuePhoneController.text.trim(),
        studioName: _isStudioRole ? _venueNameController.text.trim() : null,
        studioAddress: _isStudioRole
            ? _venueAddressController.text.trim()
            : null,
        studioPhone: _isStudioRole
            ? StudioRegistrationPolicy.normalizePhone(
                _venuePhoneController.text,
              )
            : null,
        cityId: _selectedCityId,
        districtId: _selectedDistrictId,
        neighborhoodId: _selectedNeighborhoodId,
      );
      return;
    }

    context.read<AuthCubit>().register(
      username: username,
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rePassword: _rePasswordController.text,
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
    _updateView(() {
      _selectedRole = roleId;
    });
  }

  Widget _buildProgressIndicator(double progressValue) {
    final steps = _totalSteps == 5
        ? [
            Icons.headphones,
            Icons.favorite_border,
            Icons.link,
            _isStudioRole ? Icons.mic_none : Icons.storefront_outlined,
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
                    gradient: LinearGradient(
                      colors: AppColors.decorativeGradient,
                    ),
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
                colors: AppColors.isLight
                    ? AppColors.brandGradient
                    : [
                        AppColors.decorativeNeonPurpleGradient[0],
                        AppColors.decorativeNeonPurpleGradient[1],
                        AppColors.decorativeNeonPurpleGradient[2],
                        AppColors.decorativeNeonPurpleGradient[3],
                      ],
              )
            : null,
        color: (fill > 0) ? null : Theme.of(context).dividerColor,
        boxShadow: isActive || isComplete
            ? [
                BoxShadow(
                  color: AppColors.decorativeNeonPurpleGradient[1].withValues(
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
              AppColors.isLight
                  ? AppColors.decorativeGradient.last
                  : AppColors.coralAlt,
              fill,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameStep(AuthState state) {
    final username = UsernamePolicy.normalize(_usernameController.text);
    final availability = state.usernameAvailability;
    final isCurrentCheck = _lastUsernameCheckRequested == username;
    final isChecking =
        isCurrentCheck &&
        state.action == AuthAction.usernameAvailability &&
        state.status == AuthStatus.loading;
    final hasResult =
        isCurrentCheck &&
        state.action == AuthAction.usernameAvailability &&
        state.status == AuthStatus.success &&
        availability?.username == username;
    final hasCheckFailure =
        isCurrentCheck &&
        state.action == AuthAction.usernameAvailability &&
        state.status == AuthStatus.failure;

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
          key: const Key('register-username-field'),
          controller: _usernameController,
          label: 'Kullanıcı adı',
          prefixIcon: Icons.person_outline,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isChecking
              ? const Padding(
                  key: Key('register-username-checking'),
                  padding: EdgeInsets.only(top: 10),
                  child: _UsernameAvailabilityMessage(
                    icon: Icons.hourglass_top_rounded,
                    message: 'Kullanıcı adı kontrol ediliyor...',
                  ),
                )
              : hasResult
              ? Padding(
                  key: Key(
                    availability!.available
                        ? 'register-username-available'
                        : 'register-username-taken',
                  ),
                  padding: const EdgeInsets.only(top: 10),
                  child: _UsernameAvailabilityMessage(
                    icon: availability.available
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    message: availability.available
                        ? '@${availability.username} kullanılabilir.'
                        : 'Bu kullanıcı adı zaten kullanılıyor.',
                    positive: availability.available,
                    negative: !availability.available,
                  ),
                )
              : hasCheckFailure
              ? Padding(
                  key: const Key('register-username-check-failed'),
                  padding: const EdgeInsets.only(top: 10),
                  child: _UsernameAvailabilityMessage(
                    icon: Icons.info_outline,
                    message:
                        state.error?.message ??
                        'Kullanıcı adı şu anda kontrol edilemiyor.',
                    negative: true,
                  ),
                )
              : _usernameTouched && username.isNotEmpty && username.length < 3
              ? const Padding(
                  key: Key('register-username-length-hint'),
                  padding: EdgeInsets.only(top: 10),
                  child: _UsernameAvailabilityMessage(
                    icon: Icons.info_outline,
                    message: 'Kullanıcı adı en az 3 karakter olmalı.',
                  ),
                )
              : const SizedBox.shrink(),
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
          'Şifren en az 8 karakter olmalı.',
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
              _updateView(() {
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
              _updateView(() {
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
    final applicationOptions = _roleOptions
        .where(
          (option) => option.id == 'ROLE_VENUE' || option.id == 'ROLE_STUDIO',
        )
        .toList(growable: false);
    final otherOptions = _roleOptions
        .where(
          (option) => option.id != 'ROLE_VENUE' && option.id != 'ROLE_STUDIO',
        )
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
                ...applicationOptions.map(_buildRoleOption),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
