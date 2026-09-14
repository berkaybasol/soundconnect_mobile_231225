import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';
import '../../../profile/presentation/screens/backstage_profile_search_sheet.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../../profile/presentation/screens/stage_home_top_bar.dart';
import '../../domain/backstage_feed_session.dart';
import '../cubit/musician_feed_cubit.dart';
import 'musician_feed_view.dart';

/// Mainstage entry to the same feed engine and card design.
class ListenerFeedScreen extends StatelessWidget {
  const ListenerFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = serviceLocator<AuthSessionManager>();
    return ListenableBuilder(
      listenable: sessions,
      builder: (context, _) {
        final identity = backstageFeedSessionIdentity(sessions.session);
        if (identity?.audience != BackstageFeedAudience.listener) {
          return const Scaffold(body: SizedBox.expand());
        }
        bool current() =>
            context.mounted &&
            identity == backstageFeedSessionIdentity(sessions.session);
        Future<void> open(String route) async {
          if (current()) await Navigator.of(context).pushNamed(route);
        }

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                StageHomeTopBar(
                  searchHint: 'Müzisyen, dinleyici, grup veya mekân ara',
                  onSearchTap: () => showBackstageProfileSearch(context),
                  onMenuTap: () => showProfileQuickMenu(
                    context,
                    onSettings: () => open(AppRoutes.settings),
                    onAnnouncements: () => open(AppRoutes.announcements),
                  ),
                ),
                Expanded(
                  child: BlocProvider(
                    key: PageStorageKey(identity),
                    create: (_) =>
                        serviceLocator<MusicianFeedCubit>()..initialize(),
                    child: const MusicianFeedView(),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: ProfilePublicBottomBar(
            currentIndex: 0,
            mainstageCurrentIndex: 0,
            stageMode: StageMode.mainstage,
            allowCurrentDestinationNavigation: true,
          ),
        );
      },
    );
  }
}
