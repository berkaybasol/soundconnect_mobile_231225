part of 'studio_profile_screen.dart';

class _StudioReservationsHubScreen extends StatelessWidget {
  const _StudioReservationsHubScreen();

  @override
  Widget build(BuildContext context) {
    final rooms = List<_StudioRoomItem>.unmodifiable(_studioRoomMockItems);
    if (rooms.isEmpty) return const _StudioReservationsEmptyState();
    return _StudioRoomDetailScreen(
      room: rooms.first,
      canReserve: false,
      ownerRooms: rooms,
    );
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
