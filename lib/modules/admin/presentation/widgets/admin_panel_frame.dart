import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/widgets/session_logout_action.dart';
import '../../../promotion/domain/announcement_access.dart';
import '../../domain/marketplace_report_admin.dart';
import '../../domain/musician_feed_report_admin.dart';
import '../../domain/notification_campaign.dart';
import '../../domain/pending_application.dart';
import '../../domain/system_health.dart';
import 'admin_visual_theme.dart';

typedef AdminSubpageFrame = Widget Function(Widget body);

class AdminApplicationEntry {
  const AdminApplicationEntry({required this.kind, required this.frame});
  final ApplicationKind kind;
  final AdminSubpageFrame frame;
}

enum AdminPanelSection {
  applications('Başvurular', Icons.inbox_outlined),
  reports('Şikâyetler', Icons.outlined_flag),
  publishing('Yayınlar', Icons.sensors),
  system('Sistem', Icons.monitor_heart_outlined);

  const AdminPanelSection(this.label, this.icon);
  final String label;
  final IconData icon;

  bool available(AuthSession session) => switch (this) {
    applications => ApplicationKind.values.any((kind) => kind.canRead(session)),
    reports =>
      canManageMarketplaceReports(session) ||
          canManageMusicianFeedReports(session),
    publishing =>
      announcementSessionIdentity(session, admin: true) != null ||
          canManageNotificationCampaigns(session),
    system => canViewSystemHealth(session),
  };
}

/// Shared chrome for the dashboard and application routes pushed from it.
class AdminPanelFrame extends StatelessWidget {
  const AdminPanelFrame({
    super.key,
    required this.sessions,
    required this.entry,
    required this.selected,
    required this.onSelect,
    required this.child,
  });

  final AuthSessionManager? sessions;
  final AuthSession? entry;
  final AdminPanelSection? selected;
  final ValueChanged<AdminPanelSection> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) => AdminThemeScope(
    child: Builder(
      builder: (context) {
        final manager = sessions;
        if (manager == null) return _layout(context, null);
        return ListenableBuilder(
          listenable: manager,
          builder: (context, _) => _layout(
            context,
            identical(entry, manager.session) ? entry : null,
          ),
        );
      },
    ),
  );

  Widget _layout(BuildContext context, AuthSession? session) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;
    final items = session == null
        ? <AdminPanelSection>[]
        : AdminPanelSection.values.where((s) => s.available(session)).toList();
    final bar = dark ? const Color(0xFF131524) : colors.surface;
    final shell = Scaffold(
      backgroundColor: dark ? const Color(0xFF0D1020) : colors.surface,
      body: SafeArea(
        bottom: items.isEmpty,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 9, 8, 9),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
                gradient: LinearGradient(
                  colors: [
                    dark ? const Color(0xFF0D1020) : colors.surface,
                    dark ? const Color(0xFF18192D) : colors.surfaceContainerLow,
                  ],
                ),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFA789),
                            Color(0xFFFC8DA8),
                            Color(0xFFBA98DC),
                          ],
                        ),
                      ),
                      child: const SizedBox.square(
                        dimension: 36,
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 23,
                          color: Color(0xFF231729),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SoundConnect',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.6,
                          ),
                        ),
                        Text(
                          'Admin paneli',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (session != null &&
                      canManageNotificationCampaigns(session))
                    IconButton(
                      key: const Key('admin-notification-home-entry'),
                      tooltip: 'Özel bildirimler',
                      icon: const Icon(Icons.notifications_none_rounded),
                      onPressed: () {
                        if (context.mounted &&
                            identical(session, sessions?.session) &&
                            canManageNotificationCampaigns(session) &&
                            ModalRoute.of(context)?.isCurrent == true) {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.adminNotificationCampaigns);
                        }
                      },
                    ),
                  const SessionLogoutIconButton(icon: Icons.logout_rounded),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: items.isEmpty
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: bar,
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final section in items)
                      Expanded(child: _destination(context, section, session!)),
                  ],
                ),
              ),
            ),
    );
    final overlay = dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: bar,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: shell,
    );
  }

  Widget _destination(
    BuildContext context,
    AdminPanelSection section,
    AuthSession session,
  ) {
    final theme = Theme.of(context);
    final active = section == selected;
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xFFFFAAA0)
        : const Color(0xFF993F48);
    final color = active ? accent : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        key: Key('admin-nav-${section.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (context.mounted &&
              identical(session, sessions?.session) &&
              section.available(session) &&
              ModalRoute.of(context)?.isCurrent == true) {
            onSelect(section);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? accent.withValues(alpha: .16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(section.icon, size: 20, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                section.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  letterSpacing: 0,
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
