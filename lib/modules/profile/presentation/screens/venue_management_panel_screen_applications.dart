part of 'venue_management_panel_screen.dart';

class _MusicianApplicationProfile {
  final String displayName;
  final String? profilePictureUrl;

  const _MusicianApplicationProfile({
    required this.displayName,
    required this.profilePictureUrl,
  });
}

class _VenueApplicationsSheet extends StatefulWidget {
  final String venueId;
  final _ApplicationListMode mode;

  const _VenueApplicationsSheet({required this.venueId, required this.mode});

  @override
  State<_VenueApplicationsSheet> createState() =>
      _VenueApplicationsSheetState();
}

class _VenueApplicationsSheetState extends State<_VenueApplicationsSheet> {
  final _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  final _musicianProfileRepository =
      serviceLocator<MusicianProfileRepository>();
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<ArtistVenueApplication> _items = const [];
  Map<String, _MusicianApplicationProfile> _musicianProfiles = const {};

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  bool get _showOutgoing => widget.mode == _ApplicationListMode.outgoing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = _showOutgoing ? 'Basvurular' : 'Gelen Basvurular';
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.84,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_actionLoading) const LinearProgressIndicator(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : _items.isEmpty
                    ? Center(
                        child: Text(
                          _showOutgoing
                              ? 'Gonderdigin basvuru bulunmuyor.'
                              : 'Gelen basvuru bulunmuyor.',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _buildApplicationItem(item);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
