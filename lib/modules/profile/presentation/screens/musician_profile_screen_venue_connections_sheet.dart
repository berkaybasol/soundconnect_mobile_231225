part of 'musician_profile_screen.dart';

enum _MusicianVenueApplicationListMode { connections, outgoing, incoming }

class MusicianManagementPanelScreen extends StatelessWidget {
  final MusicianProfile musicianProfile;
  final VoidCallback? onCreateVenueConnection;

  const MusicianManagementPanelScreen({
    super.key,
    required this.musicianProfile,
    this.onCreateVenueConnection,
  });

  @override
  Widget build(BuildContext context) {
    final profileName = musicianProfile.stageName?.trim().isNotEmpty == true
        ? musicianProfile.stageName!.trim()
        : musicianProfile.username?.trim().isNotEmpty == true
        ? musicianProfile.username!.trim()
        : 'Sanatçı';
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim Paneli'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      Theme.of(context).colorScheme.surfaceContainer,
                    ],
                  ),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      text: profileName,
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.brandGradient,
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Buradan profilini destekleyen yönetim araçlarına erişebilirsin.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildMusicianVenueManagementCard(
                context: context,
                icon: Icons.groups_outlined,
                title: 'Bandlerim',
                message: 'Bağlı olduğun bandleri buradan yönet.',
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.myBands,
                  arguments: MyBandsScreenArgs(bands: musicianProfile.bands),
                ),
              ),
              const SizedBox(height: 14),
              _buildMusicianVenueManagementCard(
                context: context,
                icon: Icons.queue_music_outlined,
                title: 'Setlist Oluşturucu',
                message: 'Kendi setlistini bandsiz olarak oluştur.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BandSetlistBuilderScreen(
                        initialTitle: '$profileName Setlist',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildMusicianVenueManagementCard(
                context: context,
                icon: Icons.hub_outlined,
                title: 'Mekan Bağlantıları',
                message: 'Bağlantılarını ve isteklerini yönet.',
                onTap: () => _showMusicianVenueConnectionHub(
                  context: context,
                  musicianProfileId: musicianProfile.id,
                  onCreateVenueConnection: onCreateVenueConnection,
                ),
              ),
              const SizedBox(height: 14),
              _buildMusicianVenueManagementCard(
                context: context,
                icon: Icons.event_available_outlined,
                title: 'Etkinlik Yönetimi',
                message: 'Davetlerini, etkinliklerini ve geçmişini yönet.',
                onTap: musicianProfile.id.trim().isEmpty
                    ? null
                    : () => openEventManagement(
                        context,
                        targetType: EventPerformerTargetType.musician,
                        targetId: musicianProfile.id,
                      ),
              ),
              const SizedBox(height: 14),
              _buildMusicianVenueManagementCard(
                context: context,
                icon: Icons.mode_comment_outlined,
                title: 'Yorumlar ve Geri Bildirimler',
                message: 'Yorum yönetimi yakında burada açılacak.',
                trailingLabel: 'Yakında!',
              ),
              const SizedBox(height: 14),
              _buildMusicianVenueManagementCard(
                context: context,
                icon: Icons.insights_outlined,
                title: 'Profil İstatistikleri',
                message: 'Profil istatistikleri yakında burada açılacak.',
                trailingLabel: 'Yakında!',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showMusicianVenueConnectionHub({
  required BuildContext context,
  required String musicianProfileId,
  required VoidCallback? onCreateVenueConnection,
}) async {
  final originRoute = ModalRoute.of(context);
  final session = ProfileActionSession(
    roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
  );
  if (!session.isCurrent) return;
  final destination = await showVenueConnectionManagementHub(context);
  if (destination == null ||
      !context.mounted ||
      !session.isCurrent ||
      originRoute?.isCurrent == false) {
    return;
  }
  switch (destination) {
    case VenueConnectionManagementDestination.connections:
      await _showMusicianVenueApplicationList(
        context: context,
        musicianProfileId: musicianProfileId,
        mode: _MusicianVenueApplicationListMode.connections,
      );
      break;
    case VenueConnectionManagementDestination.create:
      if (onCreateVenueConnection != null) {
        onCreateVenueConnection();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.warning,
            content: const Text('Mekan bağlantısı şu an başlatılamıyor.'),
          ),
        );
      }
      break;
    case VenueConnectionManagementDestination.incoming:
      await _showMusicianVenueApplicationList(
        context: context,
        musicianProfileId: musicianProfileId,
        mode: _MusicianVenueApplicationListMode.incoming,
      );
      break;
    case VenueConnectionManagementDestination.outgoing:
      await _showMusicianVenueApplicationList(
        context: context,
        musicianProfileId: musicianProfileId,
        mode: _MusicianVenueApplicationListMode.outgoing,
      );
      break;
  }
}

Widget _buildMusicianVenueManagementCard({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  String? trailingLabel,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap:
        onTap ??
        () {
          ScaffoldMessenger.of(context).showSnackBar(
            appSnackBar(
              context,
              tone: AppSnackBarTone.info,
              content: Text(message),
            ),
          );
        },
    borderRadius: BorderRadius.circular(18),
    child: _MusicianVenueGradientOutline(
      radius: 18,
      strokeWidth: 1,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            if (trailingLabel != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  trailingLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MusicianVenueGradientOutline extends StatelessWidget {
  final Widget child;
  final double radius;
  final double strokeWidth;

  const _MusicianVenueGradientOutline({
    required this.child,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MusicianVenueGradientOutlinePainter(
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _MusicianVenueGradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;

  const _MusicianVenueGradientOutlinePainter({
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(
    covariant _MusicianVenueGradientOutlinePainter oldDelegate,
  ) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

Future<void> _showMusicianVenueApplicationList({
  required BuildContext context,
  required String musicianProfileId,
  required _MusicianVenueApplicationListMode mode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navBlueDeep,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _MusicianVenueApplicationsSheet(
      musicianProfileId: musicianProfileId,
      mode: mode,
    ),
  );
}

class _MusicianVenueApplicationsSheet extends StatefulWidget {
  final String musicianProfileId;
  final _MusicianVenueApplicationListMode mode;

  const _MusicianVenueApplicationsSheet({
    required this.musicianProfileId,
    required this.mode,
  });

  @override
  State<_MusicianVenueApplicationsSheet> createState() =>
      _MusicianVenueApplicationsSheetState();
}

class _MusicianVenueApplicationsSheetState
    extends State<_MusicianVenueApplicationsSheet> {
  final _session = ProfileActionSession(
    roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
  );
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

  bool get _showOutgoing =>
      widget.mode == _MusicianVenueApplicationListMode.outgoing;
  bool get _showConnections =>
      widget.mode == _MusicianVenueApplicationListMode.connections;

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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                              ? 'Henüz bağlı olduğun bir mekan yok.'
                              : _showOutgoing
                              ? 'Gönderdiğin mekan isteği bulunmuyor.'
                              : 'Gelen mekan isteği bulunmuyor.',
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _buildApplicationItem(_items[index]),
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
      final result = await _artistVenueRepository.listApplicationPage(
        target: ArtistVenueApplicationTarget.musician,
        targetId: widget.musicianProfileId,
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

  Widget _buildApplicationItem(ArtistVenueApplication item) {
    final venueName = item.venueName.trim().isNotEmpty
        ? item.venueName.trim()
        : 'Mekan';
    final canAccept =
        !_showConnections && !_showOutgoing && item.status == 'PENDING';
    final canReject =
        !_showConnections && !_showOutgoing && item.status == 'PENDING';
    final canCancel = _showOutgoing && item.status == 'PENDING';
    final canDisconnect = item.status == 'ACCEPTED';

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
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: item.venueId.isEmpty
                      ? null
                      : () {
                          if (!_session.isCurrent) return;
                          Navigator.of(context).pushNamed(
                            AppRoutes.venuePublicProfile,
                            arguments: VenuePublicProfileArgs(
                              venueId: item.venueId,
                            ),
                          );
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
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
                                    imageUrl: item.venueProfilePictureUrl,
                                    width: 40,
                                    height: 40,
                                    cacheWidth: 120,
                                    cacheHeight: 120,
                                    errorBuilder: (context) => Icon(
                                      Icons.storefront_outlined,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : Icon(
                                    Icons.storefront_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(item.status).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _statusColor(item.status)),
                ),
                child: Text(
                  _showConnections ? 'Bağlı' : _statusLabel(item.status),
                  style: TextStyle(
                    color: _statusColor(item.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!_showConnections) ...[
            const SizedBox(height: 8),
            _showOutgoing
                ? Text(
                    'Hedef mekan: $venueName',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  )
                : RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      children: [
                        const TextSpan(text: 'Mekan notu: '),
                        TextSpan(
                          text:
                              item.message != null &&
                                  item.message!.trim().isNotEmpty
                              ? item.message!.trim()
                              : 'Mekan notu yok',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canAccept)
                _buildGradientActionButton(
                  icon: Icons.check_rounded,
                  label: 'Onayla',
                  onTap: _actionLoading
                      ? null
                      : () => _runAction(
                          methodLabel: 'Mekan isteği onaylandı.',
                          action: () => _artistVenueRepository.acceptRequest(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
                        ),
                ),
              if (canReject)
                _buildGradientActionButton(
                  icon: Icons.close_rounded,
                  label: 'Reddet',
                  onTap: _actionLoading
                      ? null
                      : () => _runAction(
                          methodLabel: 'Mekan isteği reddedildi.',
                          action: () => _artistVenueRepository.rejectRequest(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
                        ),
                ),
              if (canCancel)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          methodLabel: 'Mekan isteği iptal edildi.',
                          action: () => _artistVenueRepository.cancelRequest(
                            item.id,
                            expectedSessionKey: _session.userId,
                          ),
                        ),
                  child: const Text('İptal et'),
                ),
              if (canDisconnect)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          methodLabel: 'Bağlantı kaldırıldı.',
                          action: () => _artistVenueRepository.disconnect(
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

  Widget _buildGradientActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: _MusicianVenueGradientOutline(
        radius: 12,
        strokeWidth: 1,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: AppColors.brandGradient,
                ).createShader(bounds),
                child: Icon(icon, size: 18, color: AppColors.white),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runAction({
    required String methodLabel,
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
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: Text(methodLabel),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted || !_session.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text('İşlem başarısız: $e'),
        ),
      );
    } finally {
      if (mounted && _session.isCurrent) {
        setState(() => _actionLoading = false);
      }
    }
  }

  bool _isValidImageUrl(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACCEPTED':
        return const Color(0xFF4CD47A);
      case 'REJECTED':
        return Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        return const Color(0xFFE7B65A);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACCEPTED':
        return 'Onaylandı';
      case 'REJECTED':
        return 'Reddedildi';
      default:
        return 'Beklemede';
    }
  }
}
