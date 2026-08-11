import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_application.dart';
import '../collab_navigation.dart';
import '../cubit/collab_async_state.dart';
import '../cubit/collab_incoming_applications_cubit.dart';
import '../cubit/collab_paged_cubit.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_management_widgets.dart';
import 'collab_listing_detail_screen.dart';

class CollabIncomingApplicationsScreen extends StatefulWidget {
  const CollabIncomingApplicationsScreen({
    required this.listingId,
    this.listingTitle,
    this.showBottomNavigation = true,
    this.cubit,
    super.key,
  });

  final String listingId;
  final String? listingTitle;
  final bool showBottomNavigation;
  final CollabIncomingApplicationsCubit? cubit;

  @override
  State<CollabIncomingApplicationsScreen> createState() =>
      _CollabIncomingApplicationsScreenState();
}

class _CollabIncomingApplicationsScreenState
    extends State<CollabIncomingApplicationsScreen> {
  late final CollabIncomingApplicationsCubit _cubit;
  late final bool _ownsCubit;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? serviceLocator<CollabIncomingApplicationsCubit>();
    _scrollController = ScrollController()..addListener(_onScroll);
    unawaited(_cubit.loadForListing(widget.listingId));
  }

  @override
  void didUpdateWidget(covariant CollabIncomingApplicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listingId != widget.listingId) {
      unawaited(_cubit.loadForListing(widget.listingId));
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 320) {
      unawaited(_cubit.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollabIncomingApplicationsCubit>.value(
      value: _cubit,
      child:
          BlocConsumer<
            CollabIncomingApplicationsCubit,
            CollabPagedState<CollabApplication>
          >(
            listenWhen: (previous, current) =>
                (previous.actionError != current.actionError &&
                    current.actionError != null) ||
                (previous.error != current.error &&
                    current.error != null &&
                    current.items.isNotEmpty),
            listener: (context, state) =>
                _showMessage((state.actionError ?? state.error)!.message),
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Başvurular')),
              body: SafeArea(
                top: false,
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: _cubit.refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_listingTitle(state).isNotEmpty)
                                Text(
                                  _listingTitle(state),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              const SizedBox(height: 5),
                              Text(
                                '${state.totalElements} başvuru',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 12),
                          child: _StatusRail(
                            selected: _cubit.statusFilter,
                            onSelected: (status) =>
                                unawaited(_cubit.setStatusFilter(status)),
                          ),
                        ),
                      ),
                      ..._contentSlivers(state),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: widget.showBottomNavigation
                  ? ProfilePublicBottomBar(currentIndex: 1)
                  : null,
            ),
          ),
    );
  }

  String _listingTitle(CollabPagedState<CollabApplication> state) {
    final supplied = widget.listingTitle?.trim();
    if (supplied != null && supplied.isNotEmpty) return supplied;
    return state.items.isEmpty ? '' : state.items.first.listing.title;
  }

  List<Widget> _contentSlivers(CollabPagedState<CollabApplication> state) {
    if (state.status == CollabLoadStatus.loading && state.items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.status == CollabLoadStatus.failure && state.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _LoadError(
            message: state.error?.message,
            onRetry: _cubit.loadInitial,
          ),
        ),
      ];
    }
    if (state.items.isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: _EmptyState()),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 11),
          itemBuilder: (context, index) {
            final application = state.items[index];
            final busy = state.actionIds.contains(application.id);
            return _ApplicationCard(
              application: application,
              busy: busy,
              onDetail: () => _openDetail(application.listing.id),
              onProfile: () =>
                  openCollabActorProfile(context, application.applicant),
              onMessage: application.applicant.contactUserId.trim().isEmpty
                  ? null
                  : () => openCollabActorConversation(
                      context,
                      application.applicant,
                    ),
              onPhone: application.phone?.trim().isNotEmpty == true
                  ? () => _openPhone(application.phone!)
                  : null,
              onAccept: application.isPending && application.listing.isOpen
                  ? () => _confirmDecision(application, accept: true)
                  : null,
              onReject: application.isPending
                  ? () => _confirmDecision(application, accept: false)
                  : null,
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: CollabPagedFooter(
          loading: state.isLoadingMore,
          hasError: state.loadMoreError != null,
          onRetry: _cubit.loadMore,
        ),
      ),
    ];
  }

  Future<void> _confirmDecision(
    CollabApplication application, {
    required bool accept,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Başvuruyu kabul et' : 'Başvuruyu reddet'),
        content: Text(
          accept
              ? '${application.applicant.displayName} kabul edildiğinde ilan kapanır ve diğer bekleyen başvurular geçersizleşir.'
              : '${application.applicant.displayName} tarafından yapılan başvuru reddedilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              accept ? 'Kabul et' : 'Reddet',
              style: TextStyle(
                color: accept ? AppColors.spotifyGreen : AppColors.coral,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (accept) {
      await _cubit.accept(application);
    } else {
      await _cubit.reject(application);
    }
  }

  Future<void> _openDetail(String listingId) async {
    await Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabListingDetailScreen(
          listingId: listingId,
          showBottomNavigation: widget.showBottomNavigation,
        ),
      ),
    );
    if (mounted) await _cubit.refresh();
  }

  Future<void> _openPhone(String phone) async {
    final compact = phone.replaceAll(RegExp(r'[^+\d]'), '');
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: compact));
      if (launched) return;
    } catch (_) {
      // Some desktop/emulator environments have no telephone handler. The
      // recoverable fallback below still lets the owner use the private phone.
    }
    try {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) _showMessage('Telefon numarası panoya kopyalandı.');
    } catch (_) {
      if (mounted) _showMessage('Telefon uygulaması açılamadı.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatusRail extends StatelessWidget {
  const _StatusRail({required this.selected, required this.onSelected});

  final CollabApplicationStatus? selected;
  final ValueChanged<CollabApplicationStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = <(CollabApplicationStatus?, String)>[
      (null, 'Tümü'),
      (CollabApplicationStatus.pending, 'Bekliyor'),
      (CollabApplicationStatus.accepted, 'Kabul edildi'),
      (CollabApplicationStatus.rejected, 'Reddedildi'),
      (CollabApplicationStatus.withdrawnByApplicant, 'Geri çekildi'),
      (CollabApplicationStatus.invalidatedByListingClosure, 'Geçersizleşti'),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final option = options[index];
          return CollabChoiceChip(
            label: option.$2,
            selected: selected == option.$1,
            onTap: () => onSelected(option.$1),
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.busy,
    required this.onDetail,
    required this.onProfile,
    required this.onMessage,
    required this.onPhone,
    required this.onAccept,
    required this.onReject,
  });

  final CollabApplication application;
  final bool busy;
  final VoidCallback onDetail;
  final VoidCallback onProfile;
  final VoidCallback? onMessage;
  final VoidCallback? onPhone;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabGradientFrame(
      highlighted: application.isPending,
      radius: 19,
      strokeWidth: application.isPending ? 1.25 : 1,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollabActorHeader(
            actor: application.applicant,
            onTap: onProfile,
            trailing: CollabApplicationStatusPill(status: application.status),
          ),
          const SizedBox(height: 13),
          Text(
            application.message.trim().isEmpty
                ? 'Başvuran bir mesaj bırakmadı.'
                : application.message,
            style: TextStyle(
              color: application.message.trim().isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
              fontSize: 13,
              height: 1.45,
              fontStyle: application.message.trim().isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 9,
            children: [
              CollabTinyMeta(
                icon: Icons.schedule_rounded,
                label: collabShortDate(application.submittedAt),
              ),
              if (application.phone case final phone?)
                InkWell(
                  onTap: onPhone,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: CollabTinyMeta(
                      icon: Icons.phone_outlined,
                      label: phone,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          CollabActionsWrap(
            actions: [
              CollabCardAction(
                label: 'Profil',
                icon: Icons.person_outline_rounded,
                onPressed: busy ? null : onProfile,
              ),
              CollabCardAction(
                label: 'Mesaj',
                icon: Icons.chat_bubble_outline_rounded,
                tone: CollabCardActionTone.brand,
                onPressed: busy ? null : onMessage,
              ),
              if (onReject != null)
                CollabCardAction(
                  label: 'Reddet',
                  icon: Icons.close_rounded,
                  tone: CollabCardActionTone.danger,
                  busy: busy,
                  onPressed: busy ? null : onReject,
                ),
              if (onAccept != null)
                CollabCardAction(
                  label: 'Kabul et',
                  icon: Icons.check_rounded,
                  tone: CollabCardActionTone.success,
                  busy: busy,
                  onPressed: busy ? null : onAccept,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: busy ? null : onDetail,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('İlan detayı'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Bu filtreye uygun başvuru bulunmuyor.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message ?? 'Başvurular yüklenemedi.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Yeniden dene'),
          ),
        ],
      ),
    ),
  );
}
