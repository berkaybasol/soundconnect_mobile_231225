part of 'musician_profile_screen.dart';

enum _MusicianVenueApplicationListMode { outgoing, incoming }

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
                title: 'Mekan Bağlantılarını Yönet',
                message: 'Mekan bağlantıları ve başvuru akışları burada.',
                onTap: () => _showMusicianVenueConnectionHub(
                  context: context,
                  musicianProfileId: musicianProfile.id,
                  onCreateVenueConnection: onCreateVenueConnection,
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
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.navBlueDeep,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  'Mekan Bağlantılarını Yönet',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildMusicianVenueManagementCard(
                context: sheetContext,
                icon: Icons.add_business_outlined,
                title: 'Mekan Bağlantısı Oluştur',
                message: 'Yeni bir mekana bağlantı isteği gönder.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (onCreateVenueConnection != null) {
                    onCreateVenueConnection();
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mekan bağlantısı şu an başlatılamıyor.'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildMusicianVenueManagementCard(
                context: sheetContext,
                icon: Icons.inbox_outlined,
                title: 'Gelen Mekan İstekleri',
                message: 'Mekanlardan gelen bağlantı istekleri burada.',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _showMusicianVenueApplicationList(
                    context: context,
                    musicianProfileId: musicianProfileId,
                    mode: _MusicianVenueApplicationListMode.incoming,
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildMusicianVenueManagementCard(
                context: sheetContext,
                icon: Icons.send_outlined,
                title: 'Gönderdiğim İstekler',
                message: 'Mekanlara gönderdiğin başvurular burada.',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _showMusicianVenueApplicationList(
                    context: context,
                    musicianProfileId: musicianProfileId,
                    mode: _MusicianVenueApplicationListMode.outgoing,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
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
  final _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<ArtistVenueApplication> _items = [];

  bool get _showOutgoing =>
      widget.mode == _MusicianVenueApplicationListMode.outgoing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = _showOutgoing
        ? 'Gönderdiğim İstekler'
        : 'Gelen Mekan İstekleri';
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
                          _showOutgoing
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
            ],
          ),
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
    try {
      final result = await _artistVenueRepository.listMusicianVenueApplications(
        widget.musicianProfileId,
      );
      final response = result.data ?? <ArtistVenueApplication>[];
      final filtered = response.where((item) {
        if (_showOutgoing) return item.requestByType == 'ARTIST';
        return item.requestByType == 'VENUE';
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Mekan istekleri getirilemedi: $e';
      });
    }
  }

  Widget _buildApplicationItem(ArtistVenueApplication item) {
    final venueName = item.venueName.trim().isNotEmpty
        ? item.venueName.trim()
        : 'Mekan';
    final canAccept = !_showOutgoing && item.status == 'PENDING';
    final canReject = !_showOutgoing && item.status == 'PENDING';
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
                          backgroundImage:
                              _isValidImageUrl(item.venueProfilePictureUrl)
                              ? NetworkImage(item.venueProfilePictureUrl!)
                              : null,
                          child: !_isValidImageUrl(item.venueProfilePictureUrl)
                              ? Icon(
                                  Icons.storefront_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                )
                              : null,
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
                  _statusLabel(item.status),
                  style: TextStyle(
                    color: _statusColor(item.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              children: [
                TextSpan(text: _showOutgoing ? 'Notun: ' : 'Mekan notu: '),
                TextSpan(
                  text: item.message != null && item.message!.trim().isNotEmpty
                      ? item.message!.trim()
                      : (_showOutgoing ? 'Not eklenmedi' : 'Mekan notu yok'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canAccept)
                _buildPrimaryActionButton(
                  icon: Icons.check_rounded,
                  label: 'Onayla',
                  onTap: _actionLoading
                      ? null
                      : () => _runAction(
                          methodLabel: 'Mekan isteği onaylandı.',
                          action: () =>
                              _artistVenueRepository.acceptRequest(item.id),
                        ),
                ),
              if (canReject)
                _buildPrimaryActionButton(
                  icon: Icons.close_rounded,
                  label: 'Reddet',
                  onTap: _actionLoading
                      ? null
                      : () => _runAction(
                          methodLabel: 'Mekan isteği reddedildi.',
                          action: () =>
                              _artistVenueRepository.rejectRequest(item.id),
                        ),
                ),
              if (canCancel)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          methodLabel: 'Mekan isteği iptal edildi.',
                          action: () =>
                              _artistVenueRepository.cancelRequest(item.id),
                        ),
                  child: const Text('İptal et'),
                ),
              if (canDisconnect)
                OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => _runAction(
                          methodLabel: 'Bağlantı kaldırıldı.',
                          action: () =>
                              _artistVenueRepository.disconnect(item.id),
                        ),
                  child: const Text('Bağlantıyı kaldır'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Future<void> _runAction({
    required String methodLabel,
    required Future<dynamic> Function() action,
  }) async {
    if (!mounted) return;
    setState(() => _actionLoading = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(methodLabel)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) {
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
