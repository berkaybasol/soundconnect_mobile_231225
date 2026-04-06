part of 'profile_venue_request_sheet.dart';

extension _VenueRequestSheetStateSections on _VenueRequestSheetState {
  Widget _buildSearchInput() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        hintText: 'Mekan ara...',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) {
        _updateState(() {
          _searchQuery = value.trim();
        });
      },
    );
  }

  Widget _buildFilterToggle() {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          _updateState(() {
            _filtersExpanded = !_filtersExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _filtersExpanded
                    ? Icons.filter_alt_off
                    : Icons.filter_alt_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                'Filtrele',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(
                  Icons.refresh,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                label: const Text(
                  'Filtreyi Sifirla',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            value: _selectedCityId,
            decoration: const InputDecoration(
              hintText: 'Sehir sec',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            items: widget.cities
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: (value) => _onCityChanged(value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedDistrictId,
            decoration: InputDecoration(
              hintText: _loadingDistricts ? 'Ilce yukleniyor...' : 'Ilce sec',
              prefixIcon: const Icon(Icons.map_outlined),
            ),
            items: _districtOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: _loadingDistricts
                ? null
                : (value) => _onDistrictChanged(value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedNeighborhoodId,
            decoration: InputDecoration(
              hintText: _loadingNeighborhoods
                  ? 'Semt yukleniyor...'
                  : 'Semt sec',
              prefixIcon: const Icon(Icons.place_outlined),
            ),
            items: _neighborhoodOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: _loadingNeighborhoods
                ? null
                : (value) =>
                      _updateState(() => _selectedNeighborhoodId = value),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueList(List<VenueOption> filteredVenues) {
    if (filteredVenues.isEmpty) {
      return const Center(
        child: Text(
          'Mekan bulunamadi.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      itemCount: filteredVenues.length,
      itemBuilder: (context, index) {
        final venue = filteredVenues[index];
        return _buildVenueTile(venue);
      },
    );
  }

  Widget _buildVenueTile(VenueOption venue) {
    final isAccepted = widget.acceptedIds.contains(venue.id);
    final isPending = widget.pendingIds.contains(venue.id);
    final disabled = isAccepted || isPending;
    final checked = _selectedVenueId == venue.id;
    final location = [
      venue.neighborhoodName,
      venue.districtName,
      venue.cityName,
    ].where((item) => item != null && item.trim().isNotEmpty).join(' / ');

    return Opacity(
      opacity: disabled ? 0.65 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked ? AppColors.coralAlt : AppColors.border,
          ),
        ),
        child: RadioListTile<String>(
          value: venue.id,
          groupValue: _selectedVenueId,
          onChanged: disabled
              ? null
              : (value) {
                  _updateState(() => _selectedVenueId = value);
                },
          title: Text(
            venue.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            isAccepted
                ? 'Bu mekan zaten bagli.'
                : isPending
                ? 'Bu mekan icin onay bekleniyor.'
                : (location.isNotEmpty ? location : 'Konum bilgisi yok'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          activeColor: AppColors.coralAlt,
          controlAffinity: ListTileControlAffinity.trailing,
        ),
      ),
    );
  }

  Widget _buildFooterButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgec'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: _selectedVenueId == null ? null : _submit,
            child: const Text('Devam'),
          ),
        ),
      ],
    );
  }
}
