part of 'band_management_panel_screen.dart';

enum _BandVenueApplicationListMode { connections, outgoing, incoming }

extension _BandManagementPanelVenueConnectionHub
    on _BandManagementPanelScreenState {
  Future<void> _openVenueConnectionHub() async {
    final originRoute = ModalRoute.of(context);
    final session = ProfileActionSession(
      roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
    );
    if (!session.isCurrent) return;
    final bandId = _profile.id;
    final destination = await showVenueConnectionManagementHub(context);
    if (!mounted ||
        !session.isCurrent ||
        destination == null ||
        _profile.id != bandId ||
        originRoute?.isCurrent == false) {
      return;
    }
    switch (destination) {
      case VenueConnectionManagementDestination.connections:
        await _showBandVenueApplicationList(
          mode: _BandVenueApplicationListMode.connections,
        );
        break;
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
  final _session = ProfileActionSession(
    roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
  );
  int _loadGeneration = 0;
  final _repository = serviceLocator<ArtistVenueConnectionRepository>();
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 0;
  int _totalElements = 0;
  String? _pageError;
  bool _loading = true;
  bool _actionLoading = false;
  bool _accessRevoked = false;
  String? _error;
  List<ArtistVenueApplication> _items = const [];

  bool get _showOutgoing =>
      widget.mode == _BandVenueApplicationListMode.outgoing;
  bool get _showConnections =>
      widget.mode == _BandVenueApplicationListMode.connections;

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
    if (!mounted) return;
    setState(() {
      _items = const [];
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
    setState(() {
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
                  _showConnections
                      ? 'Bağlantılarım'
                      : _showOutgoing
                      ? 'Gönderdiğim İstekler'
                      : 'Gelen İstekler',
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
          _showConnections
              ? 'Henüz bağlı olduğun bir mekan yok.'
              : _showOutgoing
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
                : () {
                    if (!_session.isCurrent) return;
                    Navigator.of(context).pushNamed(
                      AppRoutes.venuePublicProfile,
                      arguments: VenuePublicProfileArgs(venueId: item.venueId),
                    );
                  },
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
          if (!_showConnections && item.message?.trim().isNotEmpty == true) ...[
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
              if (!_showConnections && !_showOutgoing && pending)
                ElevatedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          successMessage: 'Mekan isteği onaylandı.',
                          action: () => _repository.acceptRequest(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
                        ),
                  child: const Text('Onayla'),
                ),
              if (!_showConnections && !_showOutgoing && pending)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          successMessage: 'Mekan isteği reddedildi.',
                          action: () => _repository.rejectRequest(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
                        ),
                  child: const Text('Reddet'),
                ),
              if (_showOutgoing && pending)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          successMessage: 'Mekan isteği iptal edildi.',
                          action: () => _repository.cancelRequest(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
                        ),
                  child: const Text('İptal et'),
                ),
              if (accepted)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          successMessage: 'Bağlantı kaldırıldı.',
                          action: () => _repository.disconnect(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
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
        ? (_showConnections ? 'Bağlı' : 'Onaylandı')
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

  Future<void> _load({bool append = false}) async {
    if (!mounted || _accessRevoked) return;
    if (!_session.isCurrent) {
      _onSessionChanged();
      return;
    }
    if (append && (_loading || _loadingMore || _actionLoading || !_hasMore)) {
      return;
    }
    final generation = ++_loadGeneration;
    final page = append ? _nextPage : 0;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
        _error = null;
      }
      _pageError = null;
    });
    try {
      final result = await _repository.listApplicationPage(
        target: ArtistVenueApplicationTarget.band,
        targetId: widget.bandId,
        incoming: !_showOutgoing,
        connectionsOnly: _showConnections,
        page: page,
        expectedSessionKey: _session.userId,
      );
      if (!mounted || !_session.isCurrent || generation != _loadGeneration) {
        return;
      }
      if (!result.isSuccess || result.data == null) {
        if (artistVenueAccessLost(result.error)) {
          _revokeAccess(
            result.error?.message ?? 'Bu isteklere erişim iznin kalmadı.',
          );
          return;
        }
        throw result.error?.message ?? 'İstekler getirilemedi.';
      }
      final response = result.data!;
      final overlaps =
          append &&
          response.items.any(
            (item) => _items.any((loaded) => loaded.id == item.id),
          );
      if (append && (response.totalElements != _totalElements || overlaps)) {
        await _load();
        return;
      }
      final unique = {
        if (append)
          for (final item in _items) item.id: item,
        for (final item in response.items) item.id: item,
      };
      setState(() {
        _items = unique.values.toList(growable: false);
        _totalElements = response.totalElements;
        _nextPage = response.page + 1;
        _hasMore = !response.last;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || !_session.isCurrent || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (append) {
          _pageError = 'İstekler getirilemedi: $error';
        } else {
          _items = [];
          _hasMore = false;
          _error = 'İstekler getirilemedi: $error';
        }
      });
    }
  }

  Future<void> _runAction({
    required String successMessage,
    required Future<Result<void>> Function() action,
  }) async {
    if (!mounted ||
        !_session.isCurrent ||
        _accessRevoked ||
        _actionLoading ||
        _loading ||
        _loadingMore) {
      return;
    }
    _loadGeneration++;
    setState(() => _actionLoading = true);
    try {
      final result = await action();
      if (!mounted || !_session.isCurrent) return;
      if (!result.isSuccess) {
        if (artistVenueAccessLost(result.error)) {
          _revokeAccess(
            result.error?.message ?? 'Bu isteklere erişim iznin kalmadı.',
          );
        } else if (artistVenueDecisionChanged(result.error)) {
          await _load();
        }
        throw result.error?.message ?? 'İşlem başarısız.';
      }
      if (!mounted || !_session.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: Text(successMessage),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted || !_session.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text('İşlem başarısız: $error'),
        ),
      );
    } finally {
      if (mounted && _session.isCurrent) setState(() => _actionLoading = false);
    }
  }

  bool _isValidImageUrl(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }
}
