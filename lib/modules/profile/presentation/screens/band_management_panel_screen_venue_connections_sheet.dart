part of 'band_management_panel_screen.dart';

enum _BandVenueApplicationListMode { outgoing, incoming }

extension _BandManagementPanelVenueConnectionHub
    on _BandManagementPanelScreenState {
  Future<void> _openVenueConnectionHub() async {
    final originRoute = ModalRoute.of(context);
    final bandId = _profile.id;
    final destination = await showVenueConnectionManagementHub(context);
    if (!mounted ||
        destination == null ||
        _profile.id != bandId ||
        originRoute?.isCurrent == false) {
      return;
    }
    switch (destination) {
      case VenueConnectionManagementDestination.create:
        await _editBandVenues();
        break;
      case VenueConnectionManagementDestination.incoming:
        await _showBandVenueApplicationList(
          mode: _BandVenueApplicationListMode.incoming,
        );
        break;
      case VenueConnectionManagementDestination.outgoing:
        await _showBandVenueApplicationList(
          mode: _BandVenueApplicationListMode.outgoing,
        );
        break;
    }
  }

  Future<void> _showBandVenueApplicationList({
    required _BandVenueApplicationListMode mode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _BandVenueApplicationsSheet(bandId: _profile.id, mode: mode),
    );
  }
}

class _BandVenueApplicationsSheet extends StatefulWidget {
  final String bandId;
  final _BandVenueApplicationListMode mode;

  const _BandVenueApplicationsSheet({required this.bandId, required this.mode});

  @override
  State<_BandVenueApplicationsSheet> createState() =>
      _BandVenueApplicationsSheetState();
}

class _BandVenueApplicationsSheetState
    extends State<_BandVenueApplicationsSheet> {
  final _repository = serviceLocator<ArtistVenueConnectionRepository>();
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<ArtistVenueApplication> _items = const [];

  bool get _showOutgoing =>
      widget.mode == _BandVenueApplicationListMode.outgoing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
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
                  _showOutgoing
                      ? 'Gönderdiğim İstekler'
                      : 'Gelen Mekan İstekleri',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_actionLoading) const LinearProgressIndicator(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _showOutgoing
              ? 'Gönderdiğin mekan isteği bulunmuyor.'
              : 'Gelen mekan isteği bulunmuyor.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _buildItem(_items[index]),
      ),
    );
  }

  Widget _buildItem(ArtistVenueApplication item) {
    final pending = item.status.trim().toUpperCase() == 'PENDING';
    final accepted = item.status.trim().toUpperCase() == 'ACCEPTED';
    final venueName = item.venueName.trim().isEmpty ? 'Mekan' : item.venueName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: item.venueId.isEmpty
                ? null
                : () => Navigator.of(context).pushNamed(
                    AppRoutes.venuePublicProfile,
                    arguments: VenuePublicProfileArgs(venueId: item.venueId),
                  ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainer,
                  child: ClipOval(
                    child: _isValidImageUrl(item.venueProfilePictureUrl)
                        ? AppCachedNetworkImage(
                            imageUrl: item.venueProfilePictureUrl!,
                            width: 40,
                            height: 40,
                            cacheWidth: 120,
                            cacheHeight: 120,
                            errorBuilder: (_) =>
                                const Icon(Icons.storefront_outlined),
                          )
                        : const Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    venueName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                _statusBadge(item.status),
              ],
            ),
          ),
          if (item.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              item.message!.trim(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_showOutgoing && pending)
                ElevatedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          successMessage: 'Mekan isteği onaylandı.',
                          action: () => _repository.acceptRequest(item.id),
                        ),
                  child: const Text('Onayla'),
                ),
              if (!_showOutgoing && pending)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          successMessage: 'Mekan isteği reddedildi.',
                          action: () => _repository.rejectRequest(item.id),
                        ),
                  child: const Text('Reddet'),
                ),
              if (_showOutgoing && pending)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          successMessage: 'Mekan isteği iptal edildi.',
                          action: () => _repository.cancelRequest(item.id),
                        ),
                  child: const Text('İptal et'),
                ),
              if (accepted)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          successMessage: 'Bağlantı kaldırıldı.',
                          action: () => _repository.disconnect(item.id),
                        ),
                  child: const Text('Bağlantıyı kaldır'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String rawStatus) {
    final status = rawStatus.trim().toUpperCase();
    final color = status == 'ACCEPTED'
        ? const Color(0xFF4CD47A)
        : status == 'REJECTED'
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : const Color(0xFFE7B65A);
    final label = status == 'ACCEPTED'
        ? 'Onaylandı'
        : status == 'REJECTED'
        ? 'Reddedildi'
        : 'Beklemede';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repository.listBandVenueApplications(widget.bandId);
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _loading = false;
        _error = result.error?.message ?? 'Mekan istekleri getirilemedi.';
      });
      return;
    }
    final expectedType = _showOutgoing ? 'BAND' : 'VENUE';
    setState(() {
      _items = result.data!
          .where(
            (item) => item.requestByType.trim().toUpperCase() == expectedType,
          )
          .toList(growable: false);
      _loading = false;
    });
  }

  Future<void> _runAction({
    required String successMessage,
    required Future<dynamic> Function() action,
  }) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      final result = await action();
      if (result is Result && !result.isSuccess) {
        throw result.error?.message ?? 'İşlem başarısız.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız: $error')));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  bool _isValidImageUrl(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }
}
