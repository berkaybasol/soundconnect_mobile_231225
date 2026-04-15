import 'package:flutter/material.dart';

import '../shared/theme/app_colors.dart';
import 'router/app_routes.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Secimi')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Devam etmek istedigin profil gorunumunu sec.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _RouteButton(
                title: 'Muzisyen Owner Gorunumu',
                route: AppRoutes.musicianProfile,
              ),
              const SizedBox(height: 12),
              _RouteButton(
                title: 'Muzisyen Public Gorunumu',
                route: AppRoutes.musicianPublicProfile,
              ),
              const SizedBox(height: 12),
              _RouteButton(
                title: 'Mekan Owner Gorunumu',
                route: AppRoutes.venueProfile,
              ),
              const SizedBox(height: 12),
              _RouteButton(
                title: 'Mekan Public Gorunumu',
                route: AppRoutes.venuePublicProfile,
              ),
              const SizedBox(height: 12),
              _RouteButton(
                title: 'Listener Profili',
                route: AppRoutes.listenerProfile,
              ),
              const SizedBox(height: 12),
              _RouteButton(
                title: 'Muzik Birlestir',
                route: AppRoutes.tableGroupList,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteButton extends StatelessWidget {
  final String title;
  final String route;

  const _RouteButton({required this.title, required this.route});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pushNamed(route),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(title),
    );
  }
}
