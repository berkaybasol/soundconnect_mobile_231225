import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/backstage_palette.dart';
import '../../../../shared/widgets/session_logout_action.dart';

/// The authenticated admin entry point. Campaign management will be added to
/// the sponsorship tab separately; this shell intentionally loads no data.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
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
          ],
        ),
      ),
      body: const SafeArea(
        child: TabBarView(
          children: [
            SizedBox.expand(key: Key('admin-home-empty')),
            SizedBox.expand(key: Key('admin-sponsorships-empty')),
          ],
        ),
      ),
    ),
  );
}
