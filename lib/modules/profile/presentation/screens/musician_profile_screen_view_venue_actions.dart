part of 'musician_profile_screen.dart';

extension _MusicianProfileViewStateVenueActions
    on _MusicianPublicProfileViewState {
  Future<void> _editVenues(String profileId) async {
    final session = ProfileActionSession(
      roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
    );
    bool current() => mounted && session.isCurrent;
    if (!mounted || !session.isCurrent) return;
    try {
      if (await shouldShowVenueConnectionIntro()) {
        if (!mounted || !session.isCurrent) return;
        final acceptedIntro =
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => VenueIntroScreen(),
              ),
            ) ??
            false;
        if (!acceptedIntro || !mounted || !session.isCurrent) return;
      }
      if (!mounted || !session.isCurrent) return;
      final allVenues = await _fetchAllVenues();
      if (!mounted || !session.isCurrent) return;
      final cities = await _fetchCities();
      if (!mounted || !session.isCurrent) return;
      final accepted = await _fetchAcceptedVenueConnections(profileId);
      if (!mounted || !session.isCurrent) return;
      final pending = await _fetchPendingVenueConnections(profileId);
      if (!mounted || !session.isCurrent) return;

      final selected = await showVenueRequestBottomSheet(
        context: context,
        allVenues: allVenues,
        cities: cities,
        acceptedIds: accepted.map((item) => item.venueId).toSet(),
        pendingIds: pending.map((item) => item.venueId).toSet(),
        fetchDistricts: _fetchDistricts,
        fetchNeighborhoods: _fetchNeighborhoods,
        isMounted: current,
      );

      if (selected == null || !mounted || !session.isCurrent) return;

      final requestResult = await _artistVenueRepository.createArtistRequest(
        musicianProfileId: profileId,
        venueId: selected.venueId,
        message: selected.message,
        expectedSessionKey: session.userId,
      );
      if (!mounted || !session.isCurrent) return;
      if (!requestResult.isSuccess) {
        throw requestResult.error?.message ?? 'Request failed';
      }

      if (!mounted || !session.isCurrent) return;
      await context.read<ArtistVenueConnectionsCubit>().loadAcceptedVenues(
        profileId,
      );
      if (!mounted || !session.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: const Text(
            'Mekan bağlantı isteği gönderildi (onay bekliyor).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted || !session.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text('Mekanlar güncellenemedi: $e'),
        ),
      );
    }
  }
}
