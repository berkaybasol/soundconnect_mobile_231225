import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
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
      description: '',
    ),
    _RoleOption(
      id: 'ROLE_MUSICIAN',
      title: 'Müzisyenim',
      description: '',
    ),
    _RoleOption(
      id: 'ROLE_VENUE',
      title: 'Bir mekani temsil ediyorum',
      description: '',
    ),
    _RoleOption(
      id: 'ROLE_STUDIO',
      title: 'Bir stüdyoyu temsil ediyorum',
      description: '',
    ),
    _RoleOption(
      id: 'ROLE_PRODUCER',
      title: 'Prodüktörüm',
      description: '',
    ),
    _RoleOption(
      id: 'ROLE_ORGANIZER',
      title: 'Organizatörüm',
      description: '',
    ),
  ];

  String? _selectedRole;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedRole = _roles.first;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rePasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _validateStep() {
    switch (_stepIndex) {
      case 0:
        return _usernameController.text.trim().isNotEmpty;
      case 1:
        return _emailController.text.trim().isNotEmpty;
      case 2:
        final password = _passwordController.text.trim();
        final rePassword = _rePasswordController.text.trim();
        return password.isNotEmpty && rePassword.isNotEmpty && password == rePassword;
      case 3:
        return (_selectedRole ?? '').isNotEmpty;
      default:
        return false;
    }
  }

  void _next() {
    if (!_validateStep()) {
      if (_stepIndex == 0) {
        _showError('Kullanici adi gerekli.');
      } else if (_stepIndex == 1) {
        _showError('Email gerekli.');
      } else if (_stepIndex == 2) {
        _showError('Sifreler bos olamaz ve eslesmeli.');
      } else {
        _showError('Rol secimi gerekli.');
      }
      return;
    }

    if (_stepIndex < 3) {
      setState(() {
        _stepIndex += 1;
      });
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
    setState(() {
      _stepIndex -= 1;
    });
  }

  Widget _buildProgressIndicator() {
    const steps = [
      Icons.headphones,
      Icons.favorite_border,
      Icons.link,
      Icons.check_circle,
    ];

    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      children.add(_buildStepIcon(i, steps[i]));
      if (i < steps.length - 1) {
        children.add(_buildStepConnector(i));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _buildStepConnector(int index) {
    final isComplete = index < _stepIndex;
    return Container(
      width: 22,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isComplete ? AppColors.coralAlt : AppColors.border,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _buildStepIcon(int index, IconData icon) {
    final isActive = index == _stepIndex;
    final isComplete = index < _stepIndex;
    final borderRadius = BorderRadius.circular(999);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: (isActive || isComplete)
            ? const LinearGradient(
                colors: [
                  Color(0xFF7B2FF7),
                  Color(0xFF9B5DE5),
                  Color(0xFFC65BF0),
                  Color(0xFFF26CA7),
                ],
              )
            : null,
        color: (isActive || isComplete) ? null : AppColors.border,
        boxShadow: isActive
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
            color: (isActive || isComplete)
                ? AppColors.coralAlt
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_stepIndex) {
      case 0:
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
      case 1:
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
      case 2:
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
              obscureText: true,
              suffixIcon: const Icon(Icons.visibility_off_outlined),
            ),
            const SizedBox(height: 16),
            GradientTextField(
              controller: _rePasswordController,
              label: 'Sifre tekrar',
              prefixIcon: Icons.lock_outline,
              obscureText: true,
            ),
          ],
        );
      case 3:
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
            ..._roleOptions.map(_buildRoleOption),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.action != AuthAction.register) return;
        if (state.status == AuthStatus.success) {
          final email = state.registerResult?.email;
          Navigator.pushNamed(context, AppRoutes.otpVerify, arguments: email);
        } else if (state.status == AuthStatus.failure) {
          final message = state.error?.message ?? 'Register failed';
          _showError(message);
        }
      },
      builder: (context, state) {
        final isLoading =
            state.status == AuthStatus.loading && state.action == AuthAction.register;

        return AppScaffold(
          title: 'Kaydol',
          centerContent: true,
          centerAlignment: const Alignment(0, -0.48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(child: _buildProgressIndicator()),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildStep(),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  TextButton(
                    onPressed: isLoading ? null : _back,
                    child: const Text('Geri'),
                  ),
                  const Spacer(),
                  GradientOutlineButton(
                    onPressed: isLoading ? null : _next,
                    label: _stepIndex == 3
                        ? (isLoading ? 'Kaydediliyor...' : 'Tamamla')
                        : 'Devam et',
                  ),
                ],
              ),
            ],
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
          setState(() {
            _selectedRole = option.id;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: borderRadius,
            border: Border.all(
              color: isSelected ? AppColors.coralAlt : AppColors.border,
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.coralAlt.withOpacity(0.18),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (option.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  option.description,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
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
  final String description;

  const _RoleOption({
    required this.id,
    required this.title,
    required this.description,
  });
}
