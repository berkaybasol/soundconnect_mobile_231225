import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/gradient_text_field.dart';
import '../../../location/presentation/cubit/location_cubit.dart';
import '../../../location/presentation/cubit/location_state.dart';
import '../../domain/business_registration_details.dart';

class BusinessRegistrationController {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  String? cityId;
  String? districtId;
  String? neighborhoodId;

  BusinessRegistrationDetails details({required bool isStudio}) =>
      BusinessRegistrationDetails(
        isStudio: isStudio,
        name: name.text,
        phone: phone.text,
        address: address.text,
        cityId: cityId,
        districtId: districtId,
        neighborhoodId: neighborhoodId,
      );

  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
  }
}

class BusinessRegistrationFields extends StatefulWidget {
  const BusinessRegistrationFields({
    super.key,
    required this.controller,
    required this.isStudio,
    required this.enabled,
  });
  final BusinessRegistrationController controller;
  final bool isStudio;
  final bool enabled;

  @override
  State<BusinessRegistrationFields> createState() =>
      _BusinessRegistrationFieldsState();
}

class _BusinessRegistrationFieldsState
    extends State<BusinessRegistrationFields> {
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
  Widget build(BuildContext context) {
    final fields = widget.controller;
    final locations = context.read<LocationCubit>();
    final state = context.watch<LocationCubit>().state;
    final districts = state.districts.where((d) => d.cityId == fields.cityId);
    final neighborhoods = state.neighborhoods.where(
      (n) => n.districtId == fields.districtId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientTextField(
          key: const Key('business-name-field'),
          controller: fields.name,
          enabled: widget.enabled,
          label: widget.isStudio ? 'Stüdyo adı' : 'Mekan adı',
          prefixIcon: widget.isStudio
              ? Icons.mic_none
              : Icons.storefront_outlined,
        ),
        const SizedBox(height: 12),
        GradientTextField(
          key: const Key('business-phone-field'),
          controller: fields.phone,
          enabled: widget.enabled,
          label: 'Telefon',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        if (state.status == LocationStatus.failure) ...[
          Text(
            state.error?.message ?? 'Konum bilgileri yüklenemedi.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: !widget.enabled
                  ? null
                  : () {
                      if (fields.districtId != null) {
                        locations.loadNeighborhoods(fields.districtId!);
                      } else if (fields.cityId != null) {
                        locations.loadDistricts(fields.cityId!);
                      } else {
                        locations.loadCities();
                      }
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ),
        ],
        _locationDropdown(
          'business-city-dropdown',
          'Şehir seç',
          Icons.location_city_outlined,
          fields.cityId,
          state.cities.map(
            (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
          ),
          (id) {
            setState(() {
              fields.cityId = id;
              fields.districtId = null;
              fields.neighborhoodId = null;
            });
            if (id == null) {
              locations.resetDistricts();
            } else {
              locations.loadDistricts(id);
            }
          },
        ),
        const SizedBox(height: 12),
        _locationDropdown(
          'business-district-dropdown',
          'İlçe seç',
          Icons.map_outlined,
          fields.districtId,
          districts.map(
            (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
          ),
          (id) {
            setState(() {
              fields.districtId = id;
              fields.neighborhoodId = null;
            });
            if (id != null) locations.loadNeighborhoods(id);
          },
        ),
        const SizedBox(height: 12),
        _locationDropdown(
          'business-neighborhood-dropdown',
          'Mahalle seç',
          Icons.place_outlined,
          fields.neighborhoodId,
          neighborhoods.map(
            (n) => DropdownMenuItem(value: n.id, child: Text(n.name)),
          ),
          (id) => setState(() => fields.neighborhoodId = id),
        ),
        const SizedBox(height: 12),
        GradientTextField(
          key: const Key('business-address-field'),
          controller: fields.address,
          enabled: widget.enabled,
          label: 'Açık Adres',
          prefixIcon: Icons.location_on_outlined,
        ),
      ],
    );
  }

  Widget _locationDropdown(
    String key,
    String hint,
    IconData icon,
    String? value,
    Iterable<DropdownMenuItem<String>> choices,
    ValueChanged<String?> change,
  ) {
    final colors = Theme.of(context).colorScheme;
    final items = choices.toList();
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Theme.of(context).dividerColor),
    );
    return DropdownButtonFormField<String>(
      key: Key(key),
      initialValue: items.any((item) => item.value == value) ? value : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: border,
        enabledBorder: border,
        prefixIcon: Icon(icon),
        hintText: hint,
      ),
      dropdownColor: colors.surfaceContainer,
      items: items,
      onChanged: widget.enabled && items.isNotEmpty ? change : null,
    );
  }
}
