part of 'studio_profile_screen.dart';

class _StudioReservationsHubScreen extends StatefulWidget {
  const _StudioReservationsHubScreen({
    required this.studioProfileId,
    required this.timeZone,
  });

  final String studioProfileId;
  final String timeZone;

  @override
  State<_StudioReservationsHubScreen> createState() =>
      _StudioReservationsHubScreenState();
}

class _StudioReservationsHubScreenState
    extends State<_StudioReservationsHubScreen> {
  final StudioRoomRepository _repository =
      serviceLocator<StudioRoomRepository>();
  List<_StudioRoomItem> _rooms = const [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rezervasyon Yönetimi'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rezervasyon Yönetimi'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _StudioRoomsErrorState(
              message: _errorMessage!,
              onRetry: _loadRooms,
            ),
          ),
        ),
      );
    }
    if (_rooms.isEmpty) return const _StudioReservationsEmptyState();
    return _StudioRoomDetailScreen(
      room: _rooms.first,
      studioProfileId: widget.studioProfileId,
      canReserve: false,
      ownerRooms: _rooms,
    );
  }

  Future<void> _loadRooms() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    final result = await _repository.listOwnerRooms(
      size: _maximumStudioRoomCount,
    );
    if (!mounted) return;
    final page = result.data;
    if (!result.isSuccess || page == null) {
      setState(() {
        _loading = false;
        _errorMessage = result.error?.message ?? 'Odalar getirilemedi.';
      });
      return;
    }
    setState(() {
      _rooms = page.items
          .map(
            (room) =>
                _StudioRoomItem.fromDomain(room, timeZone: widget.timeZone),
          )
          .toList(growable: false);
      _loading = false;
    });
  }
}

class _StudioReservationsEmptyState extends StatelessWidget {
  const _StudioReservationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervasyon Yönetimi'),
        centerTitle: true,
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Rezervasyonları yönetebilmek için önce bir oda oluşturmalısın.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
