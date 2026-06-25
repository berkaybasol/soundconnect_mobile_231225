part of 'venue_management_panel_screen.dart';

class _MusicianApplicationProfile {
  final String displayName;
  final String? profilePictureUrl;

  _MusicianApplicationProfile({
    required this.displayName,
    required this.profilePictureUrl,
  });
}

class VenueApplicationsSheet extends StatefulWidget {
  final String venueId;
  final ApplicationListMode mode;

  VenueApplicationsSheet({required this.venueId, required this.mode});

  @override
  State<VenueApplicationsSheet> createState() =>
      _VenueApplicationsSheetState();
}

class _VenueApplicationsSheetState extends State<VenueApplicationsSheet> {
  final _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  final _musicianProfileRepository =
      serviceLocator<MusicianProfileRepository>();
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<ArtistVenueApplication> _items = [];
  Map<String, _MusicianApplicationProfile> _musicianProfiles = {};

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  bool get _showOutgoing => widget.mode == ApplicationListMode.outgoing;

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
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              SizedBox(height: 14),
              if (_actionLoading) LinearProgressIndicator(),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _items.isEmpty
                    ? Center(
                        child: Text(
                          _showOutgoing
                              ? 'Gonderdigin basvuru bulunmuyor.'
                              : 'Gelen basvuru bulunmuyor.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12),
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
