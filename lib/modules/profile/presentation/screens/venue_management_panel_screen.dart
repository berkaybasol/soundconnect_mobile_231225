import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/venue_owner_profile.dart';

class VenueManagementPanelScreen extends StatelessWidget {
  final VenueOwnerProfile ownerProfile;
  final Future<bool?> Function(BuildContext context) openWeeklyCalendar;
  final Future<void> Function(BuildContext context) openConnectedArtists;

  const VenueManagementPanelScreen({
    super.key,
    required this.ownerProfile,
    required this.openWeeklyCalendar,
    required this.openConnectedArtists,
  });

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
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
      child: _GradientOutline(
        radius: 18,
        strokeWidth: 1,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.inputFill, AppColors.navBlueSoft],
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openApplicationsSheet(BuildContext context) {
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
                const Center(
                  child: Text(
                    'Basvurular',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _actionCard(
                  context: sheetContext,
                  icon: Icons.send_outlined,
                  title: 'Basvurularim',
                  message: 'Gonderdigin basvurular burada yonetilecek.',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.navBlueDeep,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (_) => _VenueApplicationsSheet(
                        venueId: ownerProfile.venueId,
                        mode: _ApplicationListMode.outgoing,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _actionCard(
                  context: sheetContext,
                  icon: Icons.inbox_outlined,
                  title: 'Gelen Basvurular',
                  message: 'Sana gelen basvurular burada yonetilecek.',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.navBlueDeep,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (_) => _VenueApplicationsSheet(
                        venueId: ownerProfile.venueId,
                        mode: _ApplicationListMode.incoming,
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mekan Yonetimi'),
        centerTitle: true,
      ),
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
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.inputFill, AppColors.navBlueSoft],
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownerProfile.venueName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Buradan mekan profilini destekleyen yonetim araclarina erisebilirsin.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _actionCard(
                context: context,
                icon: Icons.calendar_month_outlined,
                title: 'Haftalik Takvim',
                message: 'Etkinlik takvimini yonet',
                onTap: () async {
                  final changed = await openWeeklyCalendar(context);
                  if (changed == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.group_outlined,
                title: 'Baglantili Sanatcilar',
                message: 'Sanatci baglantilarini buradan yonetecegiz.',
                onTap: () => openConnectedArtists(context),
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.assignment_outlined,
                title: 'Basvurular',
                message: 'Basvuru yonetimi',
                onTap: () => _openApplicationsSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ApplicationListMode { outgoing, incoming }

class _ArtistVenueApplicationItem {
  final String id;
  final String musicianProfileId;
  final String venueId;
  final String musicianStageName;
  final String venueName;
  final String? message;
  final String status;
  final String requestByType;
  final String createdAt;

  const _ArtistVenueApplicationItem({
    required this.id,
    required this.musicianProfileId,
    required this.venueId,
    required this.musicianStageName,
    required this.venueName,
    required this.message,
    required this.status,
    required this.requestByType,
    required this.createdAt,
  });

  factory _ArtistVenueApplicationItem.fromJson(Map<String, dynamic> json) {
    return _ArtistVenueApplicationItem(
      id: json['id']?.toString() ?? '',
      musicianProfileId: json['musicianProfileId']?.toString() ?? '',
      venueId: json['venueId']?.toString() ?? '',
      musicianStageName: json['musicianStageName']?.toString() ?? '',
      venueName: json['venueName']?.toString() ?? 'Mekan',
      message: json['message']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      requestByType: json['requestByType']?.toString() ?? 'ARTIST',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

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

  const _VenueApplicationsSheet({
    required this.venueId,
    required this.mode,
  });

  @override
  State<_VenueApplicationsSheet> createState() => _VenueApplicationsSheetState();
}

class _VenueApplicationsSheetState extends State<_VenueApplicationsSheet> {
  final ApiClient _apiClient = serviceLocator<ApiClient>();
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<_ArtistVenueApplicationItem> _items = const [];
  Map<String, _MusicianApplicationProfile> _musicianProfiles = const {};

  bool get _showOutgoing => widget.mode == _ApplicationListMode.outgoing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get<List<_ArtistVenueApplicationItem>>(
        '/api/v1/artist-venue-connections/venue/${widget.venueId}',
        decoder: (json) {
          final list = json as List<dynamic>? ?? const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(_ArtistVenueApplicationItem.fromJson)
              .where((item) => item.id.isNotEmpty)
              .toList();
        },
      );
      final filtered = response.where((item) {
        if (_showOutgoing) return item.requestByType == 'VENUE';
        return item.requestByType == 'ARTIST';
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final profileEntries = await Future.wait(
        filtered
            .map((item) => item.musicianProfileId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .map(_fetchMusicianProfile),
      );
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _musicianProfiles = {
          for (final entry in profileEntries)
            if (entry != null) entry.key: entry.value,
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Basvurular getirilemedi: $e';
      });
    }
  }

  Future<MapEntry<String, _MusicianApplicationProfile>?> _fetchMusicianProfile(
    String profileId,
  ) async {
    try {
      final response = await _apiClient.get<_MusicianApplicationProfile>(
        '/api/v1/public/musician-profiles/$profileId',
        decoder: (json) {
          final map = json as Map<String, dynamic>? ?? const {};
          final username = map['username']?.toString().trim();
          final stageName = map['stageName']?.toString().trim();
          final displayName =
              stageName != null && stageName.isNotEmpty
              ? stageName
              : username != null && username.isNotEmpty
              ? username
              : 'Sanatci';
          return _MusicianApplicationProfile(
            displayName: displayName,
            profilePictureUrl:
                map['profilePictureUrl']?.toString() ??
                map['profilePicture']?.toString(),
          );
        },
      );
      return MapEntry(profileId, response);
    } catch (_) {
      return null;
    }
  }

  bool _isValidImageUrl(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.startsWith('http://') || normalized.startsWith('https://');
  }

  Future<void> _runAction({
    required String requestId,
    required String path,
    required String methodLabel,
    required bool useDelete,
  }) async {
    setState(() => _actionLoading = true);
    try {
      if (useDelete) {
        await _apiClient.delete<Object>(path);
      } else {
        await _apiClient.post<Object>(path);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(methodLabel)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Islem basarisiz: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACCEPTED':
        return const Color(0xFF4CD47A);
      case 'REJECTED':
        return AppColors.textMuted;
      default:
        return const Color(0xFFE7B65A);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACCEPTED':
        return 'Onaylandi';
      case 'REJECTED':
        return 'Reddedildi';
      default:
        return 'Beklemede';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _showOutgoing ? 'Basvurularim' : 'Gelen Basvurular';
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
                            final musicianProfile =
                                _musicianProfiles[item.musicianProfileId];
                            final musicianName =
                                musicianProfile?.displayName ??
                                (item.musicianStageName.trim().isNotEmpty
                                    ? item.musicianStageName.trim()
                                    : 'Sanatci');
                            final canCancel =
                                _showOutgoing && item.status == 'PENDING';
                            final canAccept =
                                !_showOutgoing && item.status == 'PENDING';
                            final canReject =
                                !_showOutgoing && item.status == 'PENDING';
                            final canDisconnect = item.status == 'ACCEPTED';
                            final canOpenProfile =
                                item.musicianProfileId.isNotEmpty;
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.inputFill,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: !canOpenProfile
                                              ? null
                                              : () {
                                                  Navigator.of(context).pushNamed(
                                                    AppRoutes
                                                        .musicianPublicProfile,
                                                    arguments: {
                                                      'profileId':
                                                          item.musicianProfileId,
                                                    },
                                                  );
                                                },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor:
                                                      AppColors.navBlueSoft,
                                                  backgroundImage:
                                                      _isValidImageUrl(
                                                            musicianProfile
                                                                ?.profilePictureUrl,
                                                          )
                                                          ? NetworkImage(
                                                              musicianProfile!
                                                                  .profilePictureUrl!,
                                                            )
                                                          : null,
                                                  child: !_isValidImageUrl(
                                                        musicianProfile
                                                            ?.profilePictureUrl,
                                                      )
                                                      ? const Icon(
                                                          Icons.person_outline,
                                                          color: AppColors
                                                              .textMuted,
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    musicianName,
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                          color: _statusColor(
                                            item.status,
                                          ).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: _statusColor(item.status),
                                          ),
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
                                  _showOutgoing
                                      ? Text(
                                          'Hedef mekan: ${item.venueName}',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 13,
                                          ),
                                        )
                                      : RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 13,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Sanatcinin notu: ',
                                              ),
                                              TextSpan(
                                                text:
                                                    item.message != null &&
                                                        item.message!.trim().isNotEmpty
                                                    ? item.message!.trim()
                                                    : 'Sanatcinin notu yok',
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
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
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: _actionLoading
                                              ? null
                                              : () => _runAction(
                                                  requestId: item.id,
                                                  path:
                                                      '/api/v1/artist-venue-connections/${item.id}/accept',
                                                  methodLabel:
                                                      'Basvuru onaylandi.',
                                                  useDelete: false,
                                                ),
                                          child: _GradientOutline(
                                            radius: 12,
                                            strokeWidth: 1,
                                            child: Ink(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.navBlueSoft,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ShaderMask(
                                                    shaderCallback: (bounds) =>
                                                        const LinearGradient(
                                                          colors: AppColors
                                                              .brandGradient,
                                                        ).createShader(bounds),
                                                    child: const Icon(
                                                      Icons.check_rounded,
                                                      size: 18,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Onayla',
                                                    style: TextStyle(
                                                      color: AppColors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (canReject)
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: _actionLoading
                                              ? null
                                              : () => _runAction(
                                                  requestId: item.id,
                                                  path:
                                                      '/api/v1/artist-venue-connections/${item.id}/reject',
                                                  methodLabel:
                                                      'Basvuru reddedildi.',
                                                  useDelete: false,
                                                ),
                                          child: _GradientOutline(
                                            radius: 12,
                                            strokeWidth: 1,
                                            child: Ink(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.navBlueSoft,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ShaderMask(
                                                    shaderCallback: (bounds) =>
                                                        const LinearGradient(
                                                          colors: AppColors
                                                              .brandGradient,
                                                        ).createShader(bounds),
                                                    child: const Icon(
                                                      Icons.close_rounded,
                                                      size: 18,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Reddet',
                                                    style: TextStyle(
                                                      color: AppColors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (canCancel)
                                        OutlinedButton(
                                          onPressed: _actionLoading
                                              ? null
                                              : () => _runAction(
                                                  requestId: item.id,
                                                  path:
                                                      '/api/v1/artist-venue-connections/${item.id}/cancel',
                                                  methodLabel:
                                                      'Basvuru iptal edildi.',
                                                  useDelete: false,
                                                ),
                                          child: const Text('Iptal Et'),
                                        ),
                                      if (canDisconnect)
                                        OutlinedButton(
                                          onPressed: _actionLoading
                                              ? null
                                              : () => _runAction(
                                                  requestId: item.id,
                                                  path:
                                                      '/api/v1/artist-venue-connections/${item.id}/disconnect',
                                                  methodLabel:
                                                      'Baglanti kaldirildi.',
                                                  useDelete: true,
                                                ),
                                          child: const Text(
                                            'Baglantiyi Kaldir',
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
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

class _GradientOutline extends StatelessWidget {
  final Widget child;
  final double radius;
  final double strokeWidth;

  const _GradientOutline({
    required this.child,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GradientOutlinePainter(
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

class _GradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;

  const _GradientOutlinePainter({
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
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
