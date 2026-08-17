import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/session_logout_action.dart';
import '../../domain/entities/admin_dashboard_summary.dart';
import '../../domain/entities/admin_venue_application.dart';
import '../../domain/entities/admin_studio_application.dart';
import '../cubit/admin_panel_cubit.dart';
import '../cubit/admin_panel_state.dart';
import 'admin_application_filters.dart';
import 'admin_backline_category_requests.dart';
import 'admin_collab_reports.dart';

enum _AdminModule {
  venueApplications,
  studioApplications,
  backlineCategoryRequests,
  collabReports,
  users,
  profiles,
  promotions,
  venues,
  locations,
  instruments,
  dmModeration,
  roles,
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<AdminPanelCubit>()..initialize(),
      child: const _AdminDashboardView(),
    );
  }
}

class _AdminDashboardView extends StatefulWidget {
  const _AdminDashboardView();

  @override
  State<_AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<_AdminDashboardView> {
  _AdminModule _selectedModule = _AdminModule.venueApplications;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminPanelCubit, AdminPanelState>(
      listenWhen: (previous, current) =>
          current.status == AdminPanelStatus.failure &&
          !identical(previous.error, current.error),
      listener: (context, state) {
        final message = state.error?.message;
        if (state.status == AdminPanelStatus.failure &&
            message != null &&
            message.trim().isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.pureBlack,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => context.read<AdminPanelCubit>().refresh(
                loadStudio: _selectedModule == _AdminModule.studioApplications,
                loadBacklineCategoryRequests:
                    _selectedModule == _AdminModule.backlineCategoryRequests,
                loadCollabReports:
                    _selectedModule == _AdminModule.collabReports,
              ),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _BackstageHero(
                      summary: state.summary,
                      onRefresh: () => context.read<AdminPanelCubit>().refresh(
                        loadStudio:
                            _selectedModule == _AdminModule.studioApplications,
                        loadBacklineCategoryRequests:
                            _selectedModule ==
                            _AdminModule.backlineCategoryRequests,
                        loadCollabReports:
                            _selectedModule == _AdminModule.collabReports,
                      ),
                    ),
                  ),
                  if (state.summaryError != null)
                    SliverToBoxAdapter(
                      child: _AdminLoadError(
                        message: state.summaryError!.message,
                        onRetry: () => context.read<AdminPanelCubit>().refresh(
                          loadStudio:
                              _selectedModule ==
                              _AdminModule.studioApplications,
                          loadBacklineCategoryRequests:
                              _selectedModule ==
                              _AdminModule.backlineCategoryRequests,
                          loadCollabReports:
                              _selectedModule == _AdminModule.collabReports,
                        ),
                        compact: true,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: _ModuleBoard(
                      selectedModule: _selectedModule,
                      onSelected: (module) {
                        setState(() => _selectedModule = module);
                        if (module == _AdminModule.studioApplications) {
                          context
                              .read<AdminPanelCubit>()
                              .loadStudioApplications(state.selectedStatus);
                        } else if (module ==
                            _AdminModule.backlineCategoryRequests) {
                          context
                              .read<AdminPanelCubit>()
                              .loadBacklineCategoryRequestsList(
                                state.selectedBacklineCategoryRequestStatus,
                              );
                        } else if (module == _AdminModule.collabReports) {
                          context.read<AdminPanelCubit>().loadCollabReportsList(
                            state.selectedCollabReportStatus,
                            state.selectedCollabReportReason,
                          );
                        } else if (module == _AdminModule.venueApplications) {
                          context.read<AdminPanelCubit>().loadVenueApplications(
                            state.selectedStatus,
                          );
                        }
                      },
                      summary: state.summary,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: _ModuleHeader(module: _selectedModule),
                    ),
                  ),
                  ..._moduleSlivers(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _moduleSlivers(BuildContext context, AdminPanelState state) {
    if (_selectedModule == _AdminModule.studioApplications) {
      return _studioApplicationSlivers(context, state);
    }
    if (_selectedModule == _AdminModule.backlineCategoryRequests) {
      return AdminBacklineCategoryRequestsSection.buildSlivers(context, state);
    }
    if (_selectedModule == _AdminModule.collabReports) {
      return AdminCollabReportsSection.buildSlivers(context, state);
    }
    if (_selectedModule != _AdminModule.venueApplications) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ComingSoonModule(module: _selectedModule),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AdminVenueApplicationFilters(state: state),
        ),
      ),
      if (state.status == AdminPanelStatus.loading &&
          state.venueApplications.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (state.applicationsError != null &&
          state.venueApplications.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _AdminLoadError(
            message: state.applicationsError!.message,
            onRetry: () => context
                .read<AdminPanelCubit>()
                .loadVenueApplications(state.selectedStatus),
          ),
        )
      else if (state.venueApplications.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyApplications(status: state.selectedStatus),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index.isOdd) return const SizedBox(height: 10);
              final application = state.venueApplications[index ~/ 2];
              return _VenueApplicationTile(
                application: application,
                loading: state.actionIds.contains(application.id),
              );
            }, childCount: state.venueApplications.length * 2 - 1),
          ),
        ),
    ];
  }

  List<Widget> _studioApplicationSlivers(
    BuildContext context,
    AdminPanelState state,
  ) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AdminStudioApplicationFilters(state: state),
        ),
      ),
      if (state.status == AdminPanelStatus.loading &&
          state.studioApplications.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (state.applicationsError != null &&
          state.studioApplications.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _AdminLoadError(
            message: state.applicationsError!.message,
            onRetry: () => context
                .read<AdminPanelCubit>()
                .loadStudioApplications(state.selectedStatus),
          ),
        )
      else if (state.studioApplications.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyApplications(status: state.selectedStatus),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index.isOdd) return const SizedBox(height: 10);
              final application = state.studioApplications[index ~/ 2];
              return _StudioApplicationTile(
                application: application,
                loading: state.actionIds.contains(application.id),
              );
            }, childCount: state.studioApplications.length * 2 - 1),
          ),
        ),
      if (state.studioApplicationsHasNext ||
          state.studioApplicationsLoadingMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: OutlinedButton.icon(
              onPressed: state.studioApplicationsLoadingMore
                  ? null
                  : context.read<AdminPanelCubit>().loadMoreStudioApplications,
              icon: state.studioApplicationsLoadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Daha fazla yükle'),
            ),
          ),
        ),
    ];
  }
}

class _BackstageHero extends StatelessWidget {
  final AdminDashboardSummary summary;
  final VoidCallback onRefresh;

  const _BackstageHero({required this.summary, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.navBlueDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.socialPurple.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      text: 'SoundConnect Backstage',
                      gradient: LinearGradient(colors: AppColors.brandGradient),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Modül bazlı operasyon paneli',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                key: const Key('admin-account-settings'),
                tooltip: 'Ayarlar',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Yenile',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Oturumu Kapat',
                onPressed: () => confirmAndLogoutSession(context),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PulseSummary(summary: summary),
        ],
      ),
    );
  }
}

class _PulseSummary extends StatelessWidget {
  final AdminDashboardSummary summary;

  const _PulseSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricItem(
        'Kullanıcılar',
        summary.totalUsers,
        Icons.people_alt_outlined,
      ),
      _MetricItem(
        'Bekleyen başvuru',
        summary.pendingVenueApplications + summary.pendingStudioApplications,
        Icons.pending_actions_outlined,
      ),
      _MetricItem(
        'Onaylanan',
        summary.approvedVenueApplications + summary.approvedStudioApplications,
        Icons.verified_outlined,
      ),
      _MetricItem(
        'Aktif promosyon',
        summary.activePromotions,
        Icons.campaign_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 86,
          ),
          itemBuilder: (context, index) => _MetricTile(item: items[index]),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _MetricItem item;

  const _MetricTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navBlueSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: AppColors.coralLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value.toString(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleBoard extends StatelessWidget {
  final _AdminModule selectedModule;
  final ValueChanged<_AdminModule> onSelected;
  final AdminDashboardSummary summary;

  const _ModuleBoard({
    required this.selectedModule,
    required this.onSelected,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleItem(
        module: _AdminModule.venueApplications,
        title: 'Mekân Başvuruları',
        subtitle: '${summary.pendingVenueApplications} bekleyen',
        icon: Icons.storefront_outlined,
      ),
      _ModuleItem(
        module: _AdminModule.studioApplications,
        title: 'Stüdyo Başvuruları',
        subtitle: '${summary.pendingStudioApplications} bekleyen',
        icon: Icons.mic_external_on_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.backlineCategoryRequests,
        title: 'Backline Kategori Talepleri',
        subtitle: 'Onay ve red kuyruğu',
        icon: Icons.account_tree_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.collabReports,
        title: 'Collab Moderasyonu',
        subtitle: 'İlan raporları ve kararlar',
        icon: Icons.shield_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.users,
        title: 'Kullanıcılar',
        subtitle: 'Hesaplar ve roller',
        icon: Icons.groups_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.profiles,
        title: 'Profiller',
        subtitle: 'Sanatçı, mekân, stüdyo',
        icon: Icons.badge_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.promotions,
        title: 'Promosyonlar',
        subtitle: 'Banner ve vitrin',
        icon: Icons.campaign_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.venues,
        title: 'Mekânlar',
        subtitle: 'Kayıtlı mekânlar',
        icon: Icons.location_city_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.locations,
        title: 'Lokasyon',
        subtitle: 'Şehir, ilçe, semt',
        icon: Icons.map_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.instruments,
        title: 'Enstrümanlar',
        subtitle: 'Katalog yönetimi',
        icon: Icons.music_note_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.dmModeration,
        title: 'DM Moderasyon',
        subtitle: 'Mesaj denetimi',
        icon: Icons.forum_outlined,
      ),
      const _ModuleItem(
        module: _AdminModule.roles,
        title: 'Roller & Yetkiler',
        subtitle: 'Platform sahibi alanı',
        icon: Icons.admin_panel_settings_outlined,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 980
              ? 3
              : constraints.maxWidth >= 640
              ? 2
              : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 84,
            ),
            itemBuilder: (context, index) {
              final item = modules[index];
              return _ModuleButton(
                item: item,
                selected: item.module == selectedModule,
                onTap: () => onSelected(item.module),
              );
            },
          );
        },
      ),
    );
  }
}

class _ModuleButton extends StatelessWidget {
  final _ModuleItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ModuleButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: selected
              ? LinearGradient(colors: AppColors.brandGradient)
              : null,
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.navBlueDeep.withValues(alpha: 0.94)
                : AppColors.navBlueSoft.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: selected ? AppColors.coralLight : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.chevron_right,
                color: selected ? AppColors.coralLight : AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  final _AdminModule module;

  const _ModuleHeader({required this.module});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _moduleTitle(module),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.10)),
          ),
          child: Text(
            const <_AdminModule>{
                  _AdminModule.venueApplications,
                  _AdminModule.studioApplications,
                  _AdminModule.backlineCategoryRequests,
                  _AdminModule.collabReports,
                }.contains(module)
                ? 'Canlı'
                : 'Sıradaki',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ComingSoonModule extends StatelessWidget {
  final _AdminModule module;

  const _ComingSoonModule({required this.module});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.navBlueSoft.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_outlined,
              color: AppColors.coralLight,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              _moduleTitle(module),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bu modülün operasyon ekranı sonraki adımda bağlanacak.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueApplicationTile extends StatelessWidget {
  final AdminVenueApplication application;
  final bool loading;

  const _VenueApplicationTile({
    required this.application,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final canAct = application.status == AdminVenueApplicationStatus.pending;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navBlueSoft.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  application.venueName.isEmpty
                      ? 'İsimsiz mekân'
                      : application.venueName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _StatusPill(status: application.status),
            ],
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.person_outline,
            text: application.applicantUsername,
          ),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: application.venueAddress,
          ),
          _InfoLine(icon: Icons.phone_outlined, text: application.phone),
          if (canAct) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _rejectDialog(context, application),
                    icon: const Icon(Icons.close),
                    label: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: loading
                        ? null
                        : () => context
                              .read<AdminPanelCubit>()
                              .approveVenueApplication(application.id),
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Onayla'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rejectDialog(
    BuildContext context,
    AdminVenueApplication application,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Başvuruyu reddet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Red nedeni'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
    controller.dispose();
    final cleanReason = reason?.trim() ?? '';
    if (!context.mounted || cleanReason.isEmpty) return;
    await context.read<AdminPanelCubit>().rejectVenueApplication(
      id: application.id,
      reason: cleanReason,
    );
  }
}

class _StudioApplicationTile extends StatelessWidget {
  final AdminStudioApplication application;
  final bool loading;

  const _StudioApplicationTile({
    required this.application,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final canAct = application.status == AdminVenueApplicationStatus.pending;
    final location = [
      application.neighborhoodName,
      application.districtName,
      application.cityName,
    ].where((value) => value.trim().isNotEmpty).join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navBlueSoft.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  application.studioName.isEmpty
                      ? 'İsimsiz stüdyo'
                      : application.studioName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _StatusPill(status: application.status),
            ],
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.person_outline,
            text: application.applicantUsername,
          ),
          if (location.isNotEmpty)
            _InfoLine(icon: Icons.place_outlined, text: location),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: application.studioAddress,
          ),
          _InfoLine(icon: Icons.phone_outlined, text: application.phone),
          if ((application.rejectionReason ?? '').isNotEmpty)
            _InfoLine(
              icon: Icons.info_outline,
              text: application.rejectionReason!,
            ),
          if (canAct) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _rejectStudioDialog(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: loading
                        ? null
                        : () => context
                              .read<AdminPanelCubit>()
                              .approveStudioApplication(application.id),
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Onayla'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rejectStudioDialog(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stüdyo başvurusunu reddet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Red nedeni'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
    controller.dispose();
    final cleanReason = reason?.trim() ?? '';
    if (!context.mounted || cleanReason.isEmpty) return;
    await context.read<AdminPanelCubit>().rejectStudioApplication(
      id: application.id,
      reason: cleanReason,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final AdminVenueApplicationStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AdminVenueApplicationStatus.pending => AppColors.coralAlt,
      AdminVenueApplicationStatus.approved => AppColors.spotifyGreen,
      AdminVenueApplicationStatus.rejected => Colors.redAccent,
      AdminVenueApplicationStatus.unknown => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cleanText,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyApplications extends StatelessWidget {
  final AdminVenueApplicationStatus status;

  const _EmptyApplications({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 42, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              '${status.label} başvuru yok',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminLoadError extends StatelessWidget {
  const _AdminLoadError({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.coralLight),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final int value;
  final IconData icon;

  const _MetricItem(this.label, this.value, this.icon);
}

class _ModuleItem {
  final _AdminModule module;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ModuleItem({
    required this.module,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

String _moduleTitle(_AdminModule module) {
  return switch (module) {
    _AdminModule.venueApplications => 'Mekân Başvuruları',
    _AdminModule.studioApplications => 'Stüdyo Başvuruları',
    _AdminModule.backlineCategoryRequests => 'Backline Kategori Talepleri',
    _AdminModule.collabReports => 'Collab Moderasyonu',
    _AdminModule.users => 'Kullanıcılar',
    _AdminModule.profiles => 'Profiller',
    _AdminModule.promotions => 'Promosyonlar',
    _AdminModule.venues => 'Mekânlar',
    _AdminModule.locations => 'Lokasyon',
    _AdminModule.instruments => 'Enstrümanlar',
    _AdminModule.dmModeration => 'DM Moderasyon',
    _AdminModule.roles => 'Roller & Yetkiler',
  };
}
