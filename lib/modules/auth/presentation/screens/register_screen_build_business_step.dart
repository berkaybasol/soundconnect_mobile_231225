part of 'register_screen.dart';

extension _RegisterScreenStateBuildBusinessStepMethods on _RegisterScreenState {
  Widget _buildBusinessStep({required bool enabled}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isStudioRole
              ? 'Stüdyo bilgilerini paylaş'
              : 'Mekan bilgilerini paylaş',
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
                  key: const Key('business-name-field'),
                  controller: _venueNameController,
                  label: _isStudioRole ? 'Stüdyo adı' : 'Mekan adı',
                  prefixIcon: _isStudioRole
                      ? Icons.mic_none
                      : Icons.storefront_outlined,
                ),
                SizedBox(height: 12),
                GradientTextField(
                  key: const Key('business-phone-field'),
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
                          key: const Key('business-city-dropdown'),
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
                          onChanged: !enabled
                              ? null
                              : (value) {
                                  _updateView(() {
                                    _selectedCityId = value;
                                    _selectedDistrictId = null;
                                    _selectedNeighborhoodId = null;
                                  });
                                  if (value != null) {
                                    context.read<LocationCubit>().loadDistricts(
                                      value,
                                    );
                                  } else {
                                    context
                                        .read<LocationCubit>()
                                        .resetDistricts();
                                  }
                                },
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: const Key('business-district-dropdown'),
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
                          onChanged: !enabled
                              ? null
                              : (value) {
                                  _updateView(() {
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
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: const Key('business-neighborhood-dropdown'),
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
                          onChanged: !enabled
                              ? null
                              : (value) {
                                  _updateView(() {
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
                  key: const Key('business-address-field'),
                  controller: _venueAddressController,
                  label: 'Açık Adres',
                  prefixIcon: Icons.location_on_outlined,
                ),
              ],
            ),
          ),
        ),
      ],
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
                ? LinearGradient(colors: AppColors.decorativeGradient)
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
                      color: AppColors.decorativeGradient[2].withValues(
                        alpha: 0.25,
                      ),
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
                                color: AppColors.decorativeGradient[2]
                                    .withValues(alpha: 0.25),
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
                                colors: AppColors.decorativeGradient,
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
                              colors: AppColors.decorativeGradient,
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
