part of 'venue_management_panel_screen.dart';

class VenueApplicationsSheet extends StatefulWidget {
  final String venueId;
  final ApplicationListMode mode;

  const VenueApplicationsSheet({
    super.key,
    required this.venueId,
    required this.mode,
  });

  @override
  State<VenueApplicationsSheet> createState() => _VenueApplicationsSheetState();
}

class _VenueApplicationsSheetState extends State<VenueApplicationsSheet> {
  final _session = ProfileActionSession(roles: const ['VENUE', 'ROLE_VENUE']);
  int _loadGeneration = 0;
  final _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 0;
  int _totalElements = 0;
  String? _pageError;
  bool _loading = true;
  bool _actionLoading = false;
  bool _accessRevoked = false;
  String? _error;
  List<ArtistVenueApplication> _items = [];

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  bool get _showOutgoing => widget.mode == ApplicationListMode.outgoing;
  bool get _showConnections => widget.mode == ApplicationListMode.connections;

  @override
  void initState() {
    super.initState();
    _session.manager?.addListener(_onSessionChanged);
    _load();
  }

  @override
  void dispose() {
    _session.manager?.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    _loadGeneration++;
    _updateState(() {
      _items = [];
      _hasMore = false;
      _loadingMore = false;
      _pageError = null;
      _loading = false;
      _actionLoading = false;
      _error = 'Hesabın değişti. İstekleri yeniden aç.';
    });
  }

  void _revokeAccess(String message) {
    _loadGeneration++;
    if (!mounted) return;
    _updateState(() {
      _accessRevoked = true;
      _items = [];
      _hasMore = false;
      _loading = false;
      _loadingMore = false;
      _actionLoading = false;
      _pageError = null;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _showConnections
        ? 'Bağlantılarım'
        : _showOutgoing
        ? 'Gönderdiğim İstekler'
        : 'Gelen İstekler';
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
                          _showConnections
                              ? 'Henüz bağlı olduğun bir sanatçı veya grup yok.'
                              : _showOutgoing
                              ? 'Gönderdiğin istek bulunmuyor.'
                              : 'Gelen istek bulunmuyor.',
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
              ApplicationPagingFooter(
                loading: _loadingMore,
                hasMore: _hasMore && !_loading,
                error: _pageError,
                onMore: _actionLoading || !_session.isCurrent
                    ? null
                    : () => _load(append: true),
                onRetry: !_session.isCurrent || _actionLoading || _accessRevoked
                    ? null
                    : _error != null
                    ? () => _load()
                    : _pageError != null
                    ? () => _load(append: true)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
