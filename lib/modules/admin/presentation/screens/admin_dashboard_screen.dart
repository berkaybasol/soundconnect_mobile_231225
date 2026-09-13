import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/backstage_palette.dart';
import '../../../../shared/widgets/session_logout_action.dart';
import '../../domain/musician_feed_report_admin.dart';
import '../../../promotion/domain/announcement_access.dart';

/// The authenticated admin entry point. Campaign management will be added to
/// the sponsorship tab separately; this shell intentionally loads no data.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: BackstagePalette.canvas,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Admin Paneli'),
          backgroundColor: BackstagePalette.surface,
          foregroundColor: BackstagePalette.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: const [SessionLogoutIconButton()],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: BackstagePalette.textPrimary,
            unselectedLabelColor: BackstagePalette.textMuted,
            indicatorColor: AppColors.coral,
            dividerColor: BackstagePalette.border,
            tabs: const [
              Tab(text: 'Ana Sayfa'),
              Tab(text: 'Sponsorluklar'),
              Tab(text: 'Akış Yönetimi'),
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
                    if (identity == null) {
                      return const SizedBox.expand(
                        key: Key('admin-home-empty'),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
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
                              Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.adminMusicianFeedReports);
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
                      padding: const EdgeInsets.all(16),
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
            ],
          ),
        ),
      ),
    );
  }
}
