import 'package:flutter/material.dart';

import '../../../../app/router/app_route_guard.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../notification/presentation/notification_target_read.dart';
import '../../../promotion/domain/announcement_access.dart';
import '../../data/system_health_repository.dart';
import '../../domain/marketplace_report_admin.dart';
import '../../domain/musician_feed_report_admin.dart';
import '../../domain/notification_campaign.dart';
import '../../domain/pending_application.dart';
import '../widgets/admin_dashboard_tiles.dart';
import '../widgets/admin_panel_frame.dart';
import 'system_health_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    if (sessions == null) {
      return AdminPanelFrame(
        sessions: null,
        entry: null,
        selected: null,
        onSelect: (_) {},
        child: const SizedBox.expand(key: Key('admin-home-empty')),
      );
    }
    return ListenableBuilder(
      listenable: sessions,
      builder: (context, _) => _SessionDashboard(
        key: ObjectKey(sessions.session),
        sessions: sessions,
        entry: sessions.session,
      ),
    );
  }
}

class _SessionDashboard extends StatefulWidget {
  const _SessionDashboard({
    super.key,
    required this.sessions,
    required this.entry,
  });
  final AuthSessionManager sessions;
  final AuthSession entry;
  @override
  State<_SessionDashboard> createState() => _SessionDashboardState();
}

class _SessionDashboardState extends State<_SessionDashboard> {
  AdminPanelSection? _selected;
  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final sessions = widget.sessions;
    final sections = AdminPanelSection.values.where(
      (section) => section.available(entry),
    );
    // Entering the panel must never start the health poller in the background.
    final landing = sections
        .where((section) => section != AdminPanelSection.system)
        .firstOrNull;
    final selected = sections.contains(_selected) ? _selected : landing;
    void select(AdminPanelSection section) {
      if (!mounted ||
          !identical(entry, sessions.session) ||
          !section.available(entry)) {
        return;
      }
      setState(() => _selected = section);
    }

    return AdminPanelFrame(
      sessions: sessions,
      entry: entry,
      selected: selected,
      onSelect: select,
      child: NotificationTargetReady(
        ready:
            selected == landing &&
            AppRouteGuard.redirectFor(AppRoutes.adminDashboard, entry) == null,
        customModuleKinds: const {'HOME'},
        child: switch (selected) {
          null when sections.contains(AdminPanelSection.system) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: AdminModuleTile(
                  entryKey: const Key('admin-open-system-health'),
                  title: 'Sistem sağlığını aç',
                  description:
                      'Servislerin durumunu ve son mobil olayları incele.',
                  icon: Icons.monitor_heart_outlined,
                  accent: Theme.of(context).colorScheme.primary,
                  onTap: () {
                    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                      select(AdminPanelSection.system);
                    }
                  },
                ),
              ),
            ],
          ),
          null => const SizedBox.expand(key: Key('admin-home-empty')),
          AdminPanelSection.system => SystemHealthScreen(
            key: ObjectKey(entry),
            embedded: true,
            repository: SystemHealthRepository(
              serviceLocator<ApiClient>(),
              sessions,
            ),
            sessions: sessions,
          ),
          _ => _AdminDirectory(
            section: selected,
            entry: entry,
            sessions: sessions,
            onApplication: (kind) => _openApplication(kind, sessions, entry),
          ),
        },
      ),
    );
  }

  void _openApplication(
    ApplicationKind kind,
    AuthSessionManager sessions,
    AuthSession entry,
  ) {
    if (!mounted ||
        !identical(entry, sessions.session) ||
        !kind.canRead(entry)) {
      return;
    }
    final home = ModalRoute.of(context);
    if (home == null || !home.isCurrent) {
      return;
    }
    final navigator = Navigator.of(context);
    navigator.pushNamed(
      AppRoutes.adminApplications,
      arguments: AdminApplicationEntry(
        kind: kind,
        frame: (body) => AdminPanelFrame(
          entry: entry,
          sessions: sessions,
          selected: AdminPanelSection.applications,
          child: body,
          onSelect: (section) {
            if (!mounted ||
                !home.isActive ||
                !identical(entry, sessions.session) ||
                !section.available(entry)) {
              return;
            }
            setState(() => _selected = section);
            navigator.popUntil((route) => identical(route, home));
          },
        ),
      ),
    );
  }
}

class _AdminDirectory extends StatelessWidget {
  const _AdminDirectory({
    required this.section,
    required this.entry,
    required this.sessions,
    required this.onApplication,
  });
  final AdminPanelSection section;
  final AuthSession entry;
  final AuthSessionManager sessions;
  final ValueChanged<ApplicationKind> onApplication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final applications = section == AdminPanelSection.applications;
    final reports = section == AdminPanelSection.reports;
    final rows = <Widget>[];
    void addModule(
      String label,
      String description,
      String key,
      IconData icon,
      Color accent,
      String route,
      bool Function(AuthSession) allowed,
    ) {
      if (!allowed(entry)) return;
      if (rows.isNotEmpty) {
        rows.add(Divider(height: 1, color: colors.outlineVariant));
      }
      rows.add(
        AdminModuleTile(
          entryKey: Key(key),
          title: label,
          description: description,
          icon: icon,
          accent: accent,
          onTap: () {
            if (context.mounted &&
                identical(entry, sessions.session) &&
                allowed(entry) &&
                ModalRoute.of(context)?.isCurrent == true) {
              Navigator.of(context).pushNamed(route);
            }
          },
        ),
      );
    }

    if (reports) {
      addModule(
        'Pazar şikâyetleri',
        'İlanlar hakkındaki bildirimler',
        'admin-marketplace-reports-entry',
        Icons.storefront_outlined,
        const Color(0xFFE7BC84),
        AppRoutes.adminMarketplaceReports,
        canManageMarketplaceReports,
      );
      addModule(
        'Akış şikâyetleri',
        'Müzisyen akışındaki içerikler',
        'admin-feed-reports-entry',
        Icons.chat_bubble_outline_rounded,
        const Color(0xFFBEADFF),
        AppRoutes.adminMusicianFeedReports,
        canManageMusicianFeedReports,
      );
    } else if (section == AdminPanelSection.publishing) {
      addModule(
        'SoundConnect duyuruları',
        'Taslaklar, yayın takvimi ve istatistikler',
        'admin-announcements-entry',
        Icons.campaign_outlined,
        const Color(0xFFFF9A91),
        AppRoutes.adminAnnouncements,
        (s) => announcementSessionIdentity(s, admin: true) != null,
      );
      addModule(
        'Özel bildirimler',
        'Mesajlar, alıcılar ve gönderim planı',
        'admin-notification-campaigns-entry',
        Icons.notifications_none_rounded,
        const Color(0xFFBEADFF),
        AppRoutes.adminNotificationCampaigns,
        canManageNotificationCampaigns,
      );
    }
    return ListView(
      key: PageStorageKey(section),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            section.label,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          applications
              ? 'İncelemek istediğin işletme türünü seç.'
              : reports
              ? 'İnceleyeceğin şikâyetin kaynağını seç.'
              : 'Duyuruları ve özel bildirimleri yönet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        if (applications)
          for (final kind in ApplicationKind.values.where(
            (kind) => kind.canRead(entry),
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: AdminApplicationTile(
                kind: kind,
                onTap: () => onApplication(kind),
              ),
            )
        else ...[
          Text(
            reports ? 'Şikâyet listeleri' : 'Yayın araçları',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Material(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF181B2B)
                : colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: rows),
          ),
        ],
      ],
    );
  }
}
