part of 'profile_venue_request_sheet.dart';

extension _VenueRequestSheetStateSections on _VenueRequestSheetState {
  Widget _buildSearchInput() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
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
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _filtersExpanded
                    ? Icons.filter_alt_off
                    : Icons.filter_alt_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
              SizedBox(width: 6),
              Text(
                'Filtrele',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _resetFilters,
                icon: Icon(
                  Icons.refresh,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  'Filtreyi Sifirla',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            value: _selectedCityId,
            decoration: InputDecoration(
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
          SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedDistrictId,
            decoration: InputDecoration(
              hintText: _loadingDistricts ? 'Ilce yukleniyor...' : 'Ilce sec',
              prefixIcon: Icon(Icons.map_outlined),
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
          SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedNeighborhoodId,
            decoration: InputDecoration(
              hintText: _loadingNeighborhoods
                  ? 'Semt yukleniyor...'
                  : 'Semt sec',
              prefixIcon: Icon(Icons.place_outlined),
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
      return Center(
        child: Text(
          'Mekan bulunamadi.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked
                ? AppColors.coralAlt
                : Theme.of(context).dividerColor,
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
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            isAccepted
                ? 'Bu mekan zaten bagli.'
                : isPending
                ? 'Bu mekan icin onay bekleniyor.'
                : (location.isNotEmpty ? location : 'Konum bilgisi yok'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
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
            child: Text('Vazgec'),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: _selectedVenueId == null ? null : _submit,
            child: Text('Devam'),
          ),
        ),
      ],
    );
  }
}
