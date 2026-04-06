// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

part of 'musician_profile_screen.dart';

extension _MusicianProfileViewStateVenueActions
    on _MusicianPublicProfileViewState {
  Future<void> _editVenues(String profileId) async {
    try {
      final acceptedIntro =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const VenueIntroScreen(),
            ),
          ) ??
          false;
      if (!acceptedIntro || !mounted) return;

      final allVenues = await _fetchAllVenues();
      final cities = await _fetchCities();
      final accepted = await _fetchAcceptedVenueConnections(profileId);
      final pending = await _fetchPendingVenueConnections(profileId);

      final selected = await showVenueRequestBottomSheet(
        context: context,
        allVenues: allVenues,
        cities: cities,
        acceptedIds: accepted.map((item) => item.venueId).toSet(),
        pendingIds: pending.map((item) => item.venueId).toSet(),
        fetchDistricts: _fetchDistricts,
        fetchNeighborhoods: _fetchNeighborhoods,
        isMounted: () => mounted,
      );

      if (selected == null) return;

      final requestResult = await _artistVenueRepository.createArtistRequest(
        musicianProfileId: profileId,
        venueId: selected.venueId,
        message: selected.message,
      );
      if (!requestResult.isSuccess) {
        throw requestResult.error?.message ?? 'Request failed';
      }

      if (!mounted) return;
      await context.read<ArtistVenueConnectionsCubit>().loadAcceptedVenues(
        profileId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mekan baglanti istegi gonderildi (onay bekliyor).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mekanlar guncellenemedi: $e')));
    }
  }
}
