part of 'register_screen.dart';

extension _RegisterScreenStateIsBusinessRoleMethods on _RegisterScreenState {
  bool get _isBusinessRole =>
      _selectedRole == 'ROLE_VENUE' || _selectedRole == 'ROLE_STUDIO';

  bool get _isStudioRole => _selectedRole == 'ROLE_STUDIO';

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
        _googleUsernameError = null;
      });
    }
    // Google completion can reclaim the same username on an unfinished account.
    // Only the authenticated completion endpoint can decide that case.
    if (_isGoogle || !UsernamePolicy.isValid(username)) return;

    _usernameAvailabilityDebounce = Timer(
      const Duration(milliseconds: 450),
      () {
        if (!mounted) return;
        _lastUsernameCheckRequested = username;
        context.read<AuthCubit>().checkUsernameAvailability(username: username);
      },
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
    return mounted &&
        result?.username == username &&
        result!.available &&
        UsernamePolicy.normalize(_usernameController.text) == username;
  }

  String? _validationMessage(_RegistrationStep step) {
    switch (step) {
      case _RegistrationStep.username:
        final username = _canonicalizeUsername();
        if (username.isEmpty) return 'Kullanıcı adı boş olamaz.';
        return UsernamePolicy.isValid(username)
            ? null
            : 'Kullanıcı adı 3 ile 30 karakter arasında olmalı.';
      case _RegistrationStep.email:
        final email = _emailController.text.trim();
        if (email.isEmpty) return 'E-posta boş olamaz.';
        return _isValidEmail(email) ? null : 'Geçerli bir e-posta gir.';
      case _RegistrationStep.password:
        final password = _passwordController.text;
        final repeat = _rePasswordController.text;
        if (PasswordPolicy.isBlank(password)) return 'Şifre boş olamaz.';
        if (password.length < PasswordPolicy.registrationMinimumLength) {
          return 'Şifren en az 8 karakterden oluşmalı.';
        }
        if (PasswordPolicy.exceedsBcryptLimit(password)) {
          return 'Şifren çok uzun. Biraz kısaltıp tekrar dene.';
        }
        if (PasswordPolicy.isBlank(repeat)) return 'Şifre tekrarı boş olamaz.';
        return password == repeat ? null : 'Şifreler eşleşmeli.';
      case _RegistrationStep.role:
        return _selectedRole == null ? 'Rol seçilmelidir.' : null;
      case _RegistrationStep.business:
        final details = _business.details(isStudio: _isStudioRole);
        return _isGoogle
            ? details.googleValidationMessage
            : details.validationMessage;
    }
  }

  Future<void> _next() async {
    if (_submittingGoogle) return;
    final steps = _steps;
    final step = steps[_stepIndex];
    final issue = _validationMessage(step);
    if (issue != null) {
      _showError(issue);
      return;
    }
    if (step == _RegistrationStep.username && !_isGoogle) {
      final available = await _ensureUsernameAvailable();
      if (!mounted ||
          !available ||
          _steps[_stepIndex] != step ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
    }
    if (_stepIndex < steps.length - 1) {
      FocusScope.of(context).unfocus();
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }

    final completeGoogle = widget.completeGoogleRegistration;
    if (completeGoogle != null) {
      await _completeGoogle(completeGoogle);
      return;
    }

    final username = _canonicalizeUsername();
    if (_isBusinessRole) {
      final details = _business.details(isStudio: _isStudioRole);
      context.read<AuthCubit>().register(
        username: username,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rePassword: _rePasswordController.text,
        role: _selectedRole ?? '',
        venueName: _isStudioRole ? null : details.name,
        venueAddress: _isStudioRole ? null : details.address,
        phone: _isStudioRole ? null : details.phone,
        studioName: _isStudioRole ? details.name : null,
        studioAddress: _isStudioRole ? details.address : null,
        studioPhone: _isStudioRole ? details.phone : null,
        cityId: details.cityId,
        districtId: details.districtId,
        neighborhoodId: details.neighborhoodId,
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

  Future<void> _completeGoogle(GoogleRegistrationSubmit submit) async {
    _updateView(() => _submittingGoogle = true);
    try {
      final result = await submit(
        _canonicalizeUsername(),
        _selectedRole!,
        _isBusinessRole ? _business.details(isStudio: _isStudioRole) : null,
      );
      if (mounted) {
        Navigator.of(context).pop(Result<LoginResult>.success(result));
      }
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
        Navigator.of(context).pop(Result<LoginResult>.failure(error));
        return;
      }
      _updateView(() => _submittingGoogle = false);
      if (error.code == '1002') {
        _updateView(() => _googleUsernameError = error.message);
        _pageController.jumpToPage(_steps.indexOf(_RegistrationStep.username));
        return;
      }
      _showError(error.message, tone: AppSnackBarTone.error);
    }
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
    final steps = [
      for (final step in _steps)
        switch (step) {
          _RegistrationStep.username => Icons.headphones,
          _RegistrationStep.email => Icons.favorite_border,
          _RegistrationStep.password => Icons.link,
          _RegistrationStep.role when _isBusinessRole =>
            _isStudioRole ? Icons.mic_none : Icons.storefront_outlined,
          _RegistrationStep.role ||
          _RegistrationStep.business => Icons.check_circle,
        },
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
          enabled: !_submittingGoogle,
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
              : hasCheckFailure || _googleUsernameError != null
              ? Padding(
                  key: const Key('register-username-check-failed'),
                  padding: const EdgeInsets.only(top: 10),
                  child: _UsernameAvailabilityMessage(
                    icon: Icons.info_outline,
                    message:
                        _googleUsernameError ??
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

  Widget _buildRoleStep({required bool enabled}) {
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
        for (final option in otherOptions)
          _buildRoleOption(option, enabled: enabled),
        SizedBox(height: 16),
        Divider(color: Theme.of(context).dividerColor),
        SizedBox(height: 16),
        for (final option in applicationOptions)
          _buildRoleOption(option, enabled: enabled),
      ],
    );
  }
}
