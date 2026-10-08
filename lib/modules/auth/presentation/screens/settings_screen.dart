import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_coordinator.dart';
import '../../../../core/push/push_settings_screen.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Ayarlar',
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('settings-account-settings-button'),
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Hesap Ayarları'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.accountSettings),
                ),
                if (serviceLocator.isRegistered<PushCoordinator>())
                  ListTile(
                    key: const Key('settings-notifications-button'),
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Bildirim ayarları'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PushSettingsScreen(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
