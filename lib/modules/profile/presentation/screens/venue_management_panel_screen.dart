import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../artist_venue/domain/artist_venue_connection_repository.dart';
import '../../../promotion/domain/entities/promotion_item.dart';
import '../../../promotion/domain/promotion_repository.dart';
import '../../domain/entities/artist_venue_application.dart';
import '../../domain/musician_profile_repository.dart';
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
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
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

  Future<void> _openPromotionLink(String? rawUrl) async {
    final url = rawUrl?.trim();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _shiftedBannerImage(Widget child) {
    return ClipRect(
      child: Transform.translate(
        offset: const Offset(0, 4),
        child: child,
      ),
    );
  }

  Widget _adPlaceholderCard() {
    return _GradientOutline(
      radius: 22,
      strokeWidth: 1,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.inputFill, AppColors.navBlueSoft],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                    ),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Reklam Alanı',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 1240 / 400,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.navBlueDeep,
                      AppColors.navBlueSoft.withValues(alpha: 0.94),
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _shiftedBannerImage(
                    Image.asset(
                      'assets/buraya bakarlar v3.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promotionFallback() {
    return _shiftedBannerImage(
      Image.asset(
        'assets/buraya bakarlar v3.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.navBlueDeep,
                AppColors.navBlueSoft.withValues(alpha: 0.94),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.campaign_outlined,
              color: AppColors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }

  Widget _promotionCard(BuildContext context) {
    final repository = serviceLocator<PromotionRepository>();
    return FutureBuilder<Result<List<PromotionItem>>>(
      future: repository.getDisplayableByPlacement('VENUE_MANAGEMENT_PANEL'),
      builder: (context, snapshot) {
        final items = snapshot.data?.data ?? const <PromotionItem>[];
        final item = items.isNotEmpty ? items.first : null;
        final imageUrl = item?.mediaUrl?.trim();
        final hasImage =
            imageUrl != null &&
            imageUrl.isNotEmpty &&
            (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

        if (item == null) return _adPlaceholderCard();

        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openPromotionLink(item.redirectUrl),
          child: _GradientOutline(
            radius: 22,
            strokeWidth: 1,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.inputFill, AppColors.navBlueSoft],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1240 / 400,
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        color: AppColors.navBlueDeep,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        child: hasImage
                            ? _shiftedBannerImage(
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) =>
                                      _promotionFallback(),
                                ),
                              )
                            : _promotionFallback(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navBlueDeep,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'Sponsorlu İçerik',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (item.description?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.description!.trim(),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openArtistAndApplicationSheet(BuildContext context) {
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
                    'Sanatçı Bağlantılarını Yönet',
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
                  icon: Icons.group_outlined,
                  title: 'Sanatçı Bağlantısı Oluştur',
                  message: 'Sanatçı bağlantılarını buradan yöneteceğiz.',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await openConnectedArtists(context);
                  },
                ),
                const SizedBox(height: 12),
                _actionCard(
                  context: sheetContext,
                  icon: Icons.send_outlined,
                  title: 'Bağlantı İsteklerim',
                  message: 'Gönderdiğin başvurular burada yönetilecek.',
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
                  title: 'Gelen Bağlantı İstekleri',
                  message: 'Sana gelen başvurular burada yönetilecek.',
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
                    GradientText(
                      text: ownerProfile.venueName,
                      gradient: const LinearGradient(
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
                    const Text(
                      'Buradan mekan profilini destekleyen yönetim araçlarına erişebilirsin.',
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
                title: 'Etkinlik Yönetimi',
                message: 'Etkinlik takvimini yönet',
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
                icon: Icons.hub_outlined,
                title: 'Sanatçı Bağlantılarını Yönet',
                message: 'Bağlantılı sanatçılar ve başvuru akışları burada.',
                onTap: () => _openArtistAndApplicationSheet(context),
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.mode_comment_outlined,
                title: 'İşletmene Gelen Yorumları Görüntüle',
                message: 'İşletmene gelen yorumlar burada listelenecek.',
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.dashboard_customize_outlined,
                title: 'İstatistikler',
                message: 'İstatistikler modülü yakında burada açılacak.',
                trailingLabel: 'Yakında!',
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.extension_outlined,
                title: 'Kampanyalar / Tanıtım',
                message: 'Kampanya ve tanıtım alanı yakında burada açılacak.',
                trailingLabel: 'Yakında!',
              ),
              const SizedBox(height: 18),
              _promotionCard(context),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ApplicationListMode { outgoing, incoming }

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
  final _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  final _musicianProfileRepository =
      serviceLocator<MusicianProfileRepository>();
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<ArtistVenueApplication> _items = const [];
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
      final result = await _artistVenueRepository.listVenueApplications(
        widget.venueId,
      );
      final response = result.data ?? const <ArtistVenueApplication>[];
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
        _error = 'Başvurular getirilemedi: $e';
      });
    }
  }

  Future<MapEntry<String, _MusicianApplicationProfile>?> _fetchMusicianProfile(
    String profileId,
  ) async {
    try {
      final result = await _musicianProfileRepository.getPublicProfileByProfileId(
        profileId,
      );
      final data = result.data;
      if (data == null) return null;
      final stageName = data.stageName?.trim() ?? '';
      final username = data.username?.trim() ?? '';
      final displayName = stageName.isNotEmpty
          ? stageName
          : username.isNotEmpty
          ? username
          : 'Sanatci';
      final response = _MusicianApplicationProfile(
        displayName: displayName,
        profilePictureUrl: data.profilePicture,
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
    required String methodLabel,
    required Future<dynamic> Function() action,
  }) async {
    setState(() => _actionLoading = true);
    try {
      await action();
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
    final title = _showOutgoing ? 'Başvurular' : 'Gelen Başvurular';
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
                                                  methodLabel:
                                                      'Başvuru onaylandı.',
                                                  action: () =>
                                                      _artistVenueRepository
                                                          .acceptRequest(
                                                            item.id,
                                                          ),
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
                                                  methodLabel:
                                                      'Başvuru reddedildi.',
                                                  action: () =>
                                                      _artistVenueRepository
                                                          .rejectRequest(
                                                            item.id,
                                                          ),
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
                                                  methodLabel:
                                                      'Başvuru iptal edildi.',
                                                  action: () =>
                                                      _artistVenueRepository
                                                          .cancelRequest(
                                                            item.id,
                                                          ),
                                                ),
                                          child: const Text('Iptal Et'),
                                        ),
                                      if (canDisconnect)
                                        OutlinedButton(
                                          onPressed: _actionLoading
                                              ? null
                                              : () => _runAction(
                                                  requestId: item.id,
                                                  methodLabel:
                                                      'Bağlantı kaldırıldı.',
                                                  action: () =>
                                                      _artistVenueRepository
                                                          .disconnect(item.id),
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

