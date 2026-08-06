import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../data/collab_mock_controller.dart';
import '../../domain/collab_application_models.dart';
import '../../domain/collab_discovery_models.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';
import 'collab_application_compose_screen.dart';
import 'collab_profile_selection_screen.dart';

class CollabListingDetailScreen extends StatefulWidget {
  const CollabListingDetailScreen({
    required this.listing,
    this.initiallySaved = false,
    this.onSavedChanged,
    this.showBottomNavigation = true,
    this.controller,
    this.initialActionSent = false,
    this.isOwnListing = false,
    this.isListingClosed = false,
    super.key,
  });

  final CollabDiscoveryListing listing;
  final bool initiallySaved;
  final ValueChanged<bool>? onSavedChanged;
  final bool showBottomNavigation;
  final CollabMockController? controller;
  final bool initialActionSent;
  final bool isOwnListing;
  final bool isListingClosed;

  @override
  State<CollabListingDetailScreen> createState() =>
      _CollabListingDetailScreenState();
}

class _CollabListingDetailScreenState extends State<CollabListingDetailScreen> {
  late bool _saved;
  late bool _actionSent;

  CollabDiscoveryListing get listing => widget.listing;
  CollabMockController get _controller =>
      widget.controller ?? collabMockController;
  bool get _isOwner =>
      widget.isOwnListing || _controller.ownsListing(listing.id);
  bool get _isFull =>
      listing.direction == CollabDirection.seeking &&
      listing.remainingPositions != null &&
      listing.remainingPositions! <= 0;

  @override
  void initState() {
    super.initState();
    _saved = widget.initiallySaved || _controller.isListingSaved(listing.id);
    _actionSent = widget.initialActionSent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        actions: [
          IconButton(
            onPressed: () => _showMessage('İlan bağlantısı paylaşmaya hazır.'),
            tooltip: 'İlanı paylaş',
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            onPressed: _toggleSaved,
            tooltip: _saved ? 'Kaydedilenlerden çıkar' : 'İlanı kaydet',
            icon: Icon(
              _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _saved ? AppColors.coralLight : null,
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 30),
          children: [
            _ListingHero(listing: listing),
            const SizedBox(height: 20),
            const _SectionTitle('Açıklama'),
            const SizedBox(height: 9),
            CollabGradientFrame(
              radius: 18,
              padding: const EdgeInsets.all(15),
              child: Text(
                listing.description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Rol & Detaylar'),
            const SizedBox(height: 9),
            CollabGradientFrame(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.person_search_outlined,
                    label: 'Rol',
                    value: listing.role,
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  _DetailRow(
                    icon: Icons.library_music_outlined,
                    label: 'Tarz',
                    value: listing.genres.isEmpty
                        ? 'Belirtilmemiş'
                        : listing.genres.join(', '),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('İlan Sahibi'),
            const SizedBox(height: 9),
            _OwnerCard(
              listing: listing,
              onTap: () => _showMessage(
                '${listing.ownerName} profili gerçek profil ekranına bağlanacak.',
              ),
            ),
            const SizedBox(height: 18),
            CollabPrimaryAction(
              key: const ValueKey('collab-detail-primary-action'),
              label: _primaryActionLabel,
              icon: _primaryActionIcon,
              onPressed: _primaryActionEnabled
                  ? (_isOwner ? _editListing : _openApplicationFlow)
                  : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _OutlineDetailAction(
                    label: 'Mesaj Gönder',
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: () => _showMessage(
                      'DM ekranı gerçek entegrasyon aşamasında açılacak.',
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _OutlineDetailAction(
                    label: _saved ? 'Kaydedildi' : 'Kaydet',
                    icon: _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    onPressed: _toggleSaved,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showReportSheet,
              child: Text(
                'Şikayet Et',
                style: TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? ProfilePublicBottomBar(currentIndex: 1)
          : null,
    );
  }

  void _toggleSaved() {
    setState(() => _saved = !_saved);
    _controller.setListingSaved(listing.id, saved: _saved);
    widget.onSavedChanged?.call(_saved);
  }

  bool get _primaryActionEnabled =>
      !widget.isListingClosed && !_actionSent && (_isOwner || !_isFull);

  String get _primaryActionLabel {
    if (widget.isListingClosed) return 'İlan Kapandı';
    if (_isOwner) return 'İlanı Düzenle';
    if (_isFull) return 'Kontenjan Doldu';
    if (_actionSent) {
      return listing.direction == CollabDirection.seeking
          ? 'Başvuru Gönderildi'
          : 'Teklif Gönderildi';
    }
    return listing.direction == CollabDirection.seeking
        ? 'Başvuru Yap'
        : 'İş Teklifi Gönder';
  }

  IconData get _primaryActionIcon {
    if (widget.isListingClosed || _isFull) return Icons.lock_outline_rounded;
    if (_isOwner) return Icons.edit_outlined;
    if (_actionSent) return Icons.check_rounded;
    return listing.direction == CollabDirection.seeking
        ? Icons.rocket_launch_outlined
        : Icons.send_outlined;
  }

  void _editListing() {
    _showMessage('İlan düzenleme ekranı backend entegrasyonunda bağlanacak.');
  }

  Future<void> _openApplicationFlow() async {
    final profile = await Navigator.of(context).push<CollabApplicantProfile>(
      collabPageRoute(
        builder: (_) => CollabProfileSelectionScreen(
          listing: listing,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (!mounted || profile == null) return;

    final submission = await Navigator.of(context).push<CollabApplicationDraft>(
      collabPageRoute(
        builder: (_) => CollabApplicationComposeScreen(
          listing: listing,
          initialProfile: profile,
          showBottomNavigation: widget.showBottomNavigation,
          onSubmitted: _controller.submit,
        ),
      ),
    );
    if (!mounted || submission == null) return;
    setState(() => _actionSent = true);
    _showMessage(
      submission.isOffer
          ? 'İş teklifin mock olarak gönderildi.'
          : 'Başvurun mock olarak gönderildi.',
    );
  }

  Future<void> _showReportSheet() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _ReportSheet(),
    );
    if (!mounted || reason == null) return;
    _showMessage('“$reason” bildirimi mock olarak alındı.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ListingHero extends StatelessWidget {
  const _ListingHero({required this.listing});

  final CollabDiscoveryListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabGradientFrame(
      highlighted: listing.isHighlighted,
      radius: 21,
      strokeWidth: listing.isHighlighted ? 1.5 : 1,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CollabProfileAvatar(listing: listing, size: 62),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.ownerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      listing.ownerSubtitle,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (listing.isHighlighted) const CollabFeaturedPill(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            listing.title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              CollabStatusPill(
                label: listing.cadence.label,
                color: AppColors.socialPink,
              ),
              CollabStatusPill(
                label: listing.direction.label,
                color: listing.direction == CollabDirection.seeking
                    ? AppColors.socialOrange
                    : AppColors.spotifyGreen,
              ),
            ],
          ),
          const SizedBox(height: 15),
          _HeroMetaGrid(listing: listing),
        ],
      ),
    );
  }
}

class _HeroMetaGrid extends StatelessWidget {
  const _HeroMetaGrid({required this.listing});

  final CollabDiscoveryListing listing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            _HeroMeta(
              width: width,
              icon: Icons.location_on_outlined,
              value: listing.location,
            ),
            _HeroMeta(
              width: width,
              icon: Icons.calendar_month_outlined,
              value: listing.timeLabel == null
                  ? listing.scheduleLabel
                  : '${listing.scheduleLabel} · ${listing.timeLabel}',
            ),
            _HeroMeta(
              width: width,
              icon: Icons.payments_outlined,
              value: _feeText(listing.feeAmount),
            ),
            _HeroMeta(
              width: width,
              icon: Icons.music_note_rounded,
              value: listing.role,
              trailing: _capacityText(listing),
            ),
          ],
        );
      },
    );
  }

  String? _capacityText(CollabDiscoveryListing listing) {
    final remaining = listing.remainingPositions;
    final total = listing.totalPositions;
    if (remaining == null || total == null) return null;
    return '$remaining/$total kalan';
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({
    required this.width,
    required this.icon,
    required this.value,
    this.trailing,
  });

  final double width;
  final IconData icon;
  final String value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Icon(icon, size: 17, color: muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 5),
            Text(
              trailing!,
              style: TextStyle(
                color: AppColors.coralLight,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.listing, required this.onTap});

  final CollabDiscoveryListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: CollabGradientFrame(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CollabProfileAvatar(listing: listing, size: 58),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.ownerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listing.profileKind.label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: AppColors.socialPurple,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${listing.rating.toStringAsFixed(1)} / 5',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${listing.reviewCount} yorum',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 43,
              color: theme.dividerColor,
              margin: const EdgeInsets.symmetric(horizontal: 11),
            ),
            Column(
              children: [
                Text(
                  '${listing.completedJobs}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tamamlanan\nİş',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                    height: 1.15,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineDetailAction extends StatelessWidget {
  const _OutlineDetailAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: CollabGradientFrame(
        highlighted: true,
        radius: 15,
        strokeWidth: 1.2,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  static const reasons = <String>[
    'Yanıltıcı veya hatalı ilan',
    'Uygunsuz içerik',
    'Spam veya tekrar eden ilan',
    'Şüpheli ödeme talebi',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'İlanı şikayet et',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Bildirim nedenini seç. Bu işlem şu an yalnızca mock olarak çalışır.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 9),
          ...reasons.map(
            (reason) => ListTile(
              title: Text(reason),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pop(reason),
            ),
          ),
        ],
      ),
    );
  }
}

String _feeText(int? amount) {
  if (amount == null) return 'Ücret belirtilmemiş';
  final value = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '₺$value';
}
