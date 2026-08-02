import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../../../location/presentation/cubit/location_cubit.dart';
import '../../../location/presentation/cubit/location_state.dart';
import '../../domain/business_name_policy.dart';
import 'otp_verify_screen.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class VenueApplicationArgs {
  final String username;
  final String email;
  final String password;
  final String rePassword;
  final String role;

  VenueApplicationArgs({
    required this.username,
    required this.email,
    required this.password,
    required this.rePassword,
    required this.role,
  });
}

class VenueApplicationScreen extends StatefulWidget {
  final VenueApplicationArgs? args;

  VenueApplicationScreen({super.key, required this.args});

  @override
  State<VenueApplicationScreen> createState() => _VenueApplicationScreenState();
}

class _VenueApplicationScreenState extends State<VenueApplicationScreen> {
  final _venueNameController = TextEditingController();
  final _venueAddressController = TextEditingController();
  final _venuePhoneController = TextEditingController();
  String? _selectedCityId;
  String? _selectedDistrictId;
  String? _selectedNeighborhoodId;

  @override
  void initState() {
    super.initState();
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
    _venueNameController.dispose();
    _venueAddressController.dispose();
    _venuePhoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final args = widget.args;
    if (args == null) {
      _showError('Kayıt bilgileri eksik.');
      return;
    }

    final venueName = BusinessNamePolicy.normalize(_venueNameController.text);
    if (_venueNameController.text != venueName) {
      _venueNameController.value = TextEditingValue(
        text: venueName,
        selection: TextSelection.collapsed(offset: venueName.length),
      );
    }

    if (venueName.isEmpty ||
        _venueAddressController.text.trim().isEmpty ||
        _venuePhoneController.text.trim().isEmpty ||
        (_selectedCityId ?? '').isEmpty ||
        (_selectedDistrictId ?? '').isEmpty ||
        (_selectedNeighborhoodId ?? '').isEmpty) {
      _showError(
        'Şehir, ilçe, mahalle ve Açık Adres dahil mekan bilgilerini eksiksiz doldur.',
      );
      return;
    }

    context.read<AuthCubit>().register(
      username: args.username,
      email: args.email,
      password: args.password,
      rePassword: args.rePassword,
      role: args.role,
      venueName: venueName,
      venueAddress: _venueAddressController.text.trim(),
      phone: _venuePhoneController.text.trim(),
      cityId: _selectedCityId,
      districtId: _selectedDistrictId,
      neighborhoodId: _selectedNeighborhoodId,
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
            arguments: OtpVerifyArgs(email: email, role: widget.args?.role),
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

        return AppScaffold(
          title: 'Mekan bilgileri',
          child: Column(
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
              GradientTextField(
                key: const Key('venue-application-name-field'),
                controller: _venueNameController,
                label: 'Mekan adı',
                prefixIcon: Icons.storefront_outlined,
              ),
              SizedBox(height: 12),
              GradientTextField(
                key: const Key('venue-application-phone-field'),
                controller: _venuePhoneController,
                label: 'Telefon',
                prefixIcon: Icons.phone_outlined,
              ),
              SizedBox(height: 12),
              BlocBuilder<LocationCubit, LocationState>(
                builder: (context, locationState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (locationState.status == LocationStatus.failure &&
                          locationState.cities.isEmpty) ...[
                        Text(
                          locationState.error?.message ??
                              'Sehirler yuklenemedi.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                context.read<LocationCubit>().loadCities(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tekrar dene'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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
                            context.read<LocationCubit>().loadDistricts(value);
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
                          hintText: 'Mahalle seç',
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
              SizedBox(height: 12),
              GradientTextField(
                key: const Key('venue-application-address-field'),
                controller: _venueAddressController,
                label: 'Açık Adres',
                prefixIcon: Icons.location_on_outlined,
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: Text('Geri'),
                  ),
                  Spacer(),
                  GradientOutlineButton(
                    onPressed: isLoading ? null : _submit,
                    label: isLoading ? 'Kaydediliyor...' : 'Tamamla',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
