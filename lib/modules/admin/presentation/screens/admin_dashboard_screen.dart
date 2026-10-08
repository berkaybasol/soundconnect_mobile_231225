import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/app_route_guard.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/backstage_palette.dart';
import '../../../../shared/widgets/session_logout_action.dart';
import '../../domain/musician_feed_report_admin.dart';
import '../../domain/marketplace_report_admin.dart';
import '../../domain/notification_campaign.dart';
import '../../domain/system_health.dart';
import '../../../promotion/domain/announcement_access.dart';
import '../../../notification/presentation/notification_target_read.dart';
import '../widgets/admin_visual_theme.dart';

/// The authenticated admin entry point. Campaign management will be added to
/// the sponsorship tab separately; this shell intentionally loads no data.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AdminThemeScope(child: _AdminDashboardBody());
}

class _AdminDashboardBody extends StatelessWidget {
  const _AdminDashboardBody();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final sessions = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Admin Paneli'),
          backgroundColor: Colors.transparent,
          foregroundColor: (AppColors.isOriginalDark
              ? BackstagePalette.textPrimary
              : AppColors.textPrimary),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: const [SessionLogoutIconButton()],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: (AppColors.isOriginalDark
                ? BackstagePalette.textPrimary
                : AppColors.textPrimary),
            unselectedLabelColor: (AppColors.isOriginalDark
                ? BackstagePalette.textMuted
                : AppColors.textMuted),
            indicatorColor: AppColors.coral,
            dividerColor: (AppColors.isOriginalDark
                ? BackstagePalette.border
                : AppColors.border),
            tabs: const [
              Tab(text: 'Ana Sayfa'),
              Tab(text: 'Sponsorluklar'),
              Tab(text: 'Akış Yönetimi'),
              Tab(text: 'Bildirim Yönetimi'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              if (sessions == null)
                const SizedBox.expand(key: Key('admin-home-empty'))
              else
                AnimatedBuilder(
                  animation: sessions,
                  builder: (context, _) {
                    final identity = musicianFeedReportAdminIdentity(
                      sessions.session,
                    );
                    final marketAccess = canManageMarketplaceReports(
                      sessions.session,
                    );
                    final notificationAccess = canManageNotificationCampaigns(
                      sessions.session,
                    );
                    final marketSession = sessions.session;
                    final healthAccess = canViewSystemHealth(marketSession);
                    if (identity == null &&
                        !marketAccess &&
                        !notificationAccess &&
                        !healthAccess) {
                      return NotificationTargetReady(
                        ready:
                            AppRouteGuard.redirectFor(
                              AppRoutes.adminDashboard,
                              sessions.session,
                            ) ==
                            null,
                        customModuleKinds: const {'HOME'},
                        child: const SizedBox.expand(
                          key: Key('admin-home-empty'),
                        ),
                      );
                    }
                    return NotificationTargetReady(
                      ready:
                          AppRouteGuard.redirectFor(
                            AppRoutes.adminDashboard,
                            sessions.session,
                          ) ==
                          null,
                      customModuleKinds: const {'HOME'},
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (healthAccess)
                            AdminSectionCard(
                              title: 'Sistem sağlığı',
                              icon: Icons.monitor_heart_outlined,
                              description:
                                  'Hizmetleri, geciken işleri ve hata ölçümlerini izle.',
                              children: [
                                AdminBrandButton(
                                  key: const Key('admin-system-health-entry'),
                                  label: 'Durumu görüntüle',
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: () {
                                    if (identical(
                                          marketSession,
                                          sessions.session,
                                        ) &&
                                        canViewSystemHealth(sessions.session)) {
                                      Navigator.of(
                                        context,
                                      ).pushNamed(AppRoutes.adminSystemHealth);
                                    }
                                  },
                                ),
                              ],
                            ),
                          if (notificationAccess)
                            AdminSectionCard(
                              title: 'Özel bildirimler',
                              icon: Icons.notifications_active_outlined,
                              description:
                                  'Mesajlarını hazırla, alıcılarını seç ve gönderimlerini planla.',
                              children: [
                                AdminBrandButton(
                                  key: const Key(
                                    'admin-notification-home-entry',
                                  ),
                                  label: 'Bildirimleri yönet',
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: () {
                                    if (identical(
                                          marketSession,
                                          sessions.session,
                                        ) &&
                                        canManageNotificationCampaigns(
                                          sessions.session,
                                        )) {
                                      Navigator.of(context).pushNamed(
                                        AppRoutes.adminNotificationCampaigns,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          if (marketAccess)
                            Card(
                              child: ListTile(
                                key: const Key(
                                  'admin-marketplace-reports-entry',
                                ),
                                contentPadding: const EdgeInsets.all(20),
                                leading: const Icon(Icons.storefront_outlined),
                                title: const Text('Pazar şikâyetleri'),
                                subtitle: const Text(
                                  'İlan bildirimlerini incele ve sonuçlandır',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  if (identical(
                                        marketSession,
                                        sessions.session,
                                      ) &&
                                      canManageMarketplaceReports(
                                        sessions.session,
                                      )) {
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.adminMarketplaceReports,
                                    );
                                  }
                                },
                              ),
                            ),
                          if (identity != null)
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: const Key('admin-feed-reports-entry'),
                                onTap: () {
                                  if (identity !=
                                      musicianFeedReportAdminIdentity(
                                        sessions.session,
                                      )) {
                                    return;
                                  }
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.adminMusicianFeedReports,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.flag_outlined),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Akış şikâyetleri',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Müzisyen akışındaki içerik bildirimleri',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox.expand(key: Key('admin-sponsorships-empty')),
              if (sessions == null)
                const SizedBox.shrink()
              else
                AnimatedBuilder(
                  animation: sessions,
                  builder: (context, _) {
                    final identity = announcementSessionIdentity(
                      sessions.session,
                      admin: true,
                    );
                    if (identity == null) {
                      return const Center(
                        child: Text('Duyuru yönetim yetkisi gerekli.'),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Card(
                          child: ListTile(
                            key: const Key('admin-announcements-entry'),
                            contentPadding: const EdgeInsets.all(20),
                            leading: const Icon(Icons.campaign_outlined),
                            title: const Text('SoundConnect duyuruları'),
                            subtitle: const Text(
                              'Taslaklar, yayın takvimi, hedef profiller ve istatistikler',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              if (identity ==
                                  announcementSessionIdentity(
                                    sessions.session,
                                    admin: true,
                                  )) {
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.adminAnnouncements);
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              if (sessions == null)
                const SizedBox.shrink()
              else
                AnimatedBuilder(
                  animation: sessions,
                  builder: (context, _) {
                    final captured = sessions.session;
                    if (!canManageNotificationCampaigns(captured)) {
                      return const Center(
                        child: Text('Bildirim yönetim yetkisi gerekli.'),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        AdminSectionCard(
                          title: 'Mesajlarını planla',
                          icon: Icons.notifications_active_outlined,
                          description:
                              'Doğru kişilere, doğru zamanda ulaş. Özel bildirimlerini burada hazırla ve takip et.',
                          children: [
                            AdminBrandButton(
                              key: const Key(
                                'admin-notification-campaigns-entry',
                              ),
                              label: 'Özel bildirimler',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () {
                                if (identical(captured, sessions.session) &&
                                    canManageNotificationCampaigns(
                                      sessions.session,
                                    )) {
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.adminNotificationCampaigns,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Alıcılar, mesaj, açılacak sayfa ve gönderim takvimi. Kaydettiğin taslaklar sen planlayana kadar gönderilmez.',
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
