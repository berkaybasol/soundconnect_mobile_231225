import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_actor.dart';
import '../../domain/entities/collab_listing.dart';
import '../collab_navigation.dart';
import '../cubit/collab_async_state.dart';
import '../cubit/collab_listing_detail_cubit.dart';
import '../cubit/collab_listing_detail_state.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';
import 'collab_actor_reviews_screen.dart';
import 'collab_application_compose_screen.dart';
import 'collab_profile_selection_screen.dart';

class CollabListingDetailScreen extends StatefulWidget {
  const CollabListingDetailScreen({
    required this.listingId,
    this.showBottomNavigation = true,
    this.onListingChanged,
    this.detailCubit,
    super.key,
  });

  final String listingId;
  final bool showBottomNavigation;
  final ValueChanged<CollabListing>? onListingChanged;

  /// Test/embedding seam. Production callers use the route-scoped GetIt
  /// factory and should leave this null.
  final CollabListingDetailCubit? detailCubit;

  @override
  State<CollabListingDetailScreen> createState() =>
      _CollabListingDetailScreenState();
}

class _CollabListingDetailScreenState extends State<CollabListingDetailScreen> {
  late final CollabListingDetailCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.detailCubit == null;
    _cubit = widget.detailCubit ?? serviceLocator<CollabListingDetailCubit>();
    _cubit.load(widget.listingId);
  }

  @override
  void didUpdateWidget(covariant CollabListingDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listingId != widget.listingId) {
      _cubit.load(widget.listingId);
    }
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollabListingDetailCubit>.value(
      value: _cubit,
      child: _DetailView(
        listingId: widget.listingId,
        showBottomNavigation: widget.showBottomNavigation,
        onListingChanged: widget.onListingChanged,
      ),
    );
  }
}

class _DetailView extends StatefulWidget {
  const _DetailView({
    required this.listingId,
    required this.showBottomNavigation,
    this.onListingChanged,
  });

  final String listingId;
  final bool showBottomNavigation;
  final ValueChanged<CollabListing>? onListingChanged;

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CollabListingDetailCubit, CollabListingDetailState>(
          listenWhen: (previous, current) {
            final applicationFinished =
                previous.isApplying && !current.isApplying;
            return previous.listing != current.listing ||
                (!applicationFinished &&
                    previous.actionError != current.actionError &&
                    current.actionError != null);
          },
          listener: (context, state) {
            final listing = state.listing;
            if (listing != null) widget.onListingChanged?.call(listing);
            final error = state.actionError;
            if (error != null) _showMessage(error.message);
          },
        ),
        BlocListener<CollabListingDetailCubit, CollabListingDetailState>(
          listenWhen: (previous, current) =>
              !previous.reportSubmitted && current.reportSubmitted,
          listener: (_, _) =>
              _showMessage('Bildirimin alındı. Teşekkür ederiz.'),
        ),
      ],
      child: BlocBuilder<CollabListingDetailCubit, CollabListingDetailState>(
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            actions: [
              if (state.listing case final listing?)
                IconButton(
                  onPressed: _sharing ? null : () => _share(listing),
                  tooltip: 'İlanı paylaş',
                  icon: _sharing
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                ),
              if (state.listing case final listing?)
                IconButton(
                  onPressed: listing.ownedByMe || state.isSaving
                      ? null
                      : context.read<CollabListingDetailCubit>().toggleSaved,
                  tooltip: listing.savedByMe
                      ? 'Kaydedilenlerden çıkar'
                      : 'İlanı kaydet',
                  icon: Icon(
                    listing.savedByMe
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: listing.savedByMe ? AppColors.coralLight : null,
                  ),
                ),
              const SizedBox(width: 5),
            ],
          ),
          body: _buildBody(context, state),
          bottomNavigationBar: widget.showBottomNavigation
              ? ProfilePublicBottomBar(currentIndex: 1)
              : null,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CollabListingDetailState state) {
    if (state.status == CollabLoadStatus.loading ||
        state.status == CollabLoadStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == CollabLoadStatus.failure || state.listing == null) {
      return _DetailError(
        message: state.error?.message ?? 'İlan detayı getirilemedi.',
        onRetry: () =>
            context.read<CollabListingDetailCubit>().load(widget.listingId),
      );
    }
    final listing = state.listing!;
    return RefreshIndicator(
      onRefresh: context.read<CollabListingDetailCubit>().refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 30),
        children: [
          _ListingHero(listing: listing),
          const SizedBox(height: 20),
          const CollabSectionTitle('Açıklama'),
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
          const CollabSectionTitle('Rol & Detaylar'),
          const SizedBox(height: 9),
          CollabGradientFrame(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.person_search_outlined,
                  label: 'Aranan',
                  value: _wantedSummary(listing),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                _DetailRow(
                  icon: Icons.library_music_outlined,
                  label: 'Tarz',
                  value: listing.genres.isEmpty
                      ? 'Belirtilmemiş'
                      : listing.genres.join(', '),
                ),
                if (_supportsFee(listing)) ...[
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  _DetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Ücret',
                    value: _feeText(listing),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const CollabSectionTitle('İlan Sahibi'),
          const SizedBox(height: 9),
          _OwnerCard(
            actor: listing.publisher,
            onTap: () => openCollabActorProfile(context, listing.publisher),
            onReviews: () => Navigator.of(context).push<void>(
              collabPageRoute(
                builder: (_) => CollabActorReviewsScreen(
                  actor: listing.publisher,
                  showBottomNavigation: widget.showBottomNavigation,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          CollabPrimaryAction(
            key: const ValueKey<String>('collab-detail-primary-action'),
            label: _primaryLabel(listing),
            icon: _primaryIcon(listing),
            busy:
                state.isApplying ||
                state.isClosing ||
                state.actorStatus == CollabLoadStatus.loading,
            onPressed: _primaryEnabled(listing, state)
                ? () => listing.ownedByMe
                      ? _confirmClose(listing)
                      : _openApplicationFlow(listing)
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OutlineDetailAction(
                  label: 'Mesaj Gönder',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed:
                      listing.ownedByMe ||
                          listing.publisher.contactUserId.trim().isEmpty
                      ? null
                      : () => openCollabActorConversation(
                          context,
                          listing.publisher,
                        ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _OutlineDetailAction(
                  label: listing.savedByMe ? 'Kaydedildi' : 'Kaydet',
                  icon: listing.savedByMe
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onPressed: listing.ownedByMe || state.isSaving
                      ? null
                      : context.read<CollabListingDetailCubit>().toggleSaved,
                ),
              ),
            ],
          ),
          if (!listing.ownedByMe) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: state.isReporting || state.reportSubmitted
                  ? null
                  : _showReportSheet,
              child: Text(
                'Şikayet Et',
                style: TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _primaryEnabled(CollabListing listing, CollabListingDetailState state) {
    if (!listing.isOpen || state.isApplying || state.isClosing) return false;
    if (listing.ownedByMe) return true;
    return listing.canApply;
  }

  String _primaryLabel(CollabListing listing) {
    if (!listing.isOpen) return _statusLabel(listing.status);
    if (listing.ownedByMe) return 'İlanı Kapat';
    if (listing.appliedByMe) return 'Başvuru Gönderildi';
    return 'Başvuru Yap';
  }

  IconData _primaryIcon(CollabListing listing) {
    if (!listing.isOpen) return Icons.lock_outline_rounded;
    if (listing.ownedByMe) return Icons.close_rounded;
    if (listing.appliedByMe) return Icons.check_rounded;
    return Icons.rocket_launch_outlined;
  }

  Future<void> _openApplicationFlow(CollabListing listing) async {
    final cubit = context.read<CollabListingDetailCubit>();
    await cubit.loadMyActors(
      force: cubit.state.actorStatus == CollabLoadStatus.failure,
    );
    if (!mounted) return;
    final actors = cubit.state.eligibleActors;
    if (actors.isEmpty) {
      _showMessage(
        'Bu ilana başvurabilecek bir ${listing.wantedType.label.toLowerCase()} profilin bulunmuyor.',
      );
      return;
    }
    final actor = await Navigator.of(context).push<CollabActor>(
      collabPageRoute(
        builder: (_) => CollabProfileSelectionScreen(
          actors: actors,
          wantedType: listing.wantedType,
          showBottomNavigation: false,
        ),
      ),
    );
    if (!mounted || actor == null) return;
    final submitted = await Navigator.of(context).push<bool>(
      collabPageRoute(
        builder: (_) => BlocProvider<CollabListingDetailCubit>.value(
          value: cubit,
          child: CollabApplicationComposeScreen(
            listing: listing,
            initialActor: actor,
            eligibleActors: actors,
            showBottomNavigation: false,
          ),
        ),
      ),
    );
    if (mounted && submitted == true) {
      _showMessage('Başvurun gönderildi.');
    }
  }

  Future<void> _confirmClose(CollabListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı kapat'),
        content: const Text(
          'İlan kapatıldığında bekleyen başvurular geçersizleşir ve ilan yeniden açılamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İlanı Kapat'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<CollabListingDetailCubit>().closeListing();
    }
  }

  Future<void> _showReportSheet() async {
    final input = await showModalBottomSheet<CollabReportInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ReportSheet(),
    );
    if (mounted && input != null) {
      await context.read<CollabListingDetailCubit>().report(input);
    }
  }

  Future<void> _share(CollabListing listing) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final lines = <String>[
      listing.title,
      _wantedSummary(listing),
      listing.city.name,
      if (listing.cadence == CollabCadence.extra)
        _dateTimeText(listing.scheduledAt),
      if (_supportsFee(listing)) _feeText(listing),
      'SoundConnect Collab',
    ];
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: lines.join('\n'),
          subject: listing.title,
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
    } catch (_) {
      if (mounted) _showMessage('Paylaşım açılamadı.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ListingHero extends StatelessWidget {
  const _ListingHero({required this.listing});

  final CollabListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabGradientFrame(
      radius: 21,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CollabIdentityAvatar(
                initials: listing.publisher.initials,
                profileKind: listing.publisher.profileType,
                avatarUrl: listing.publisher.avatarUrl,
                size: 62,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.publisher.displayName,
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
                      listing.publisher.profileType.label,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
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
                label: _wantedSummary(listing),
                color: AppColors.socialOrange,
              ),
              if (!listing.isOpen)
                CollabStatusPill(
                  label: _statusLabel(listing.status),
                  color: AppColors.coral,
                ),
            ],
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [
                  _HeroMeta(
                    width: width,
                    icon: Icons.location_on_outlined,
                    value: listing.city.name,
                  ),
                  if (listing.cadence == CollabCadence.extra)
                    _HeroMeta(
                      width: width,
                      icon: Icons.calendar_month_outlined,
                      value: _dateTimeText(listing.scheduledAt),
                    ),
                  _HeroMeta(
                    width: width,
                    icon: Icons.music_note_rounded,
                    value: listing.specialtyLabel ?? listing.wantedType.label,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({
    required this.width,
    required this.icon,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String value;

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
        ],
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
  const _OwnerCard({
    required this.actor,
    required this.onTap,
    required this.onReviews,
  });

  final CollabActor actor;
  final VoidCallback onTap;
  final VoidCallback onReviews;

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
            CollabIdentityAvatar(
              initials: actor.initials,
              profileKind: actor.profileType,
              avatarUrl: actor.avatarUrl,
              size: 58,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actor.displayName,
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
                    actor.profileType.label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    button: true,
                    label: 'Collab değerlendirmelerini aç',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReviews,
                      child: Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: AppColors.socialPurple,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              actor.reviewCount == 0
                                  ? 'Henüz yorum yok'
                                  : '${actor.rating.toStringAsFixed(1)} / 5 · ${actor.reviewCount} yorum',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
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
                  '${actor.completedJobCount}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: Opacity(
        opacity: onPressed == null ? 0.48 : 1,
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
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _detailsController = TextEditingController();
  CollabReportReason _reason = CollabReportReason.misleading;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
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
              'Bildirim nedenini seç ve gerekliyse kısa bir açıklama ekle.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            ...CollabReportReason.values.map(
              (reason) => RadioListTile<CollabReportReason>(
                value: reason,
                groupValue: _reason,
                title: Text(_reportReasonLabel(reason)),
                onChanged: (value) {
                  if (value != null) setState(() => _reason = value);
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: _reason == CollabReportReason.other
                    ? 'Açıklama zorunlu'
                    : 'Açıklama (isteğe bağlı)',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                final input = CollabReportInput(
                  reason: _reason,
                  details: _detailsController.text.trim(),
                );
                if (!input.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Diğer nedeni için açıklama yazmalısın.'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(input);
              },
              child: const Text('Bildirimi Gönder'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _supportsFee(CollabListing listing) =>
    listing.cadence == CollabCadence.extra ||
    (listing.cadence == CollabCadence.regular &&
        listing.publisher.profileType == CollabProfileKind.venue);

String _wantedSummary(CollabListing listing) {
  final base = listing.wantedType.wantedLabel;
  final specialty = listing.specialtyLabel;
  return listing.wantedType == CollabProfileKind.musician && specialty != null
      ? '$base: $specialty'
      : base;
}

String _dateTimeText(DateTime? value) {
  if (value == null) return 'Tarih belirtilmemiş';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} · '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _feeText(CollabListing listing) {
  final minor = listing.feeAmountMinor;
  if (minor == null) return 'Ücret belirtilmemiş';
  final major = minor ~/ 100;
  final fraction = minor.remainder(100).abs();
  final grouped = major.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final amount = fraction == 0
      ? grouped
      : '$grouped,${fraction.toString().padLeft(2, '0')}';
  return listing.currency == 'TRY'
      ? '₺$amount'
      : '$amount ${listing.currency ?? ''}'.trim();
}

String _statusLabel(CollabListingStatus status) => switch (status) {
  CollabListingStatus.draft => 'Taslak',
  CollabListingStatus.open => 'Açık',
  CollabListingStatus.closed => 'İlan Kapandı',
  CollabListingStatus.expired => 'İlanın Süresi Doldu',
};

String _reportReasonLabel(CollabReportReason reason) => switch (reason) {
  CollabReportReason.spam => 'Spam veya tekrar eden ilan',
  CollabReportReason.inappropriate => 'Uygunsuz içerik',
  CollabReportReason.misleading => 'Yanıltıcı veya hatalı ilan',
  CollabReportReason.other => 'Diğer',
};
