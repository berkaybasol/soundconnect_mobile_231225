import 'package:flutter/material.dart';

import '../shared/theme/app_colors.dart';
import 'router/app_routes.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Seçimi')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Devam etmek istediğin profil görünümünü seç.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _RouteButton(
                title: 'Müzisyen Owner Görünümü',
                route: AppRoutes.musicianProfile,
              ),
              const SizedBox(height: 12),
              _RouteButton(
                title: 'Müzisyen Public Görünümü',
                route: AppRoutes.musicianPublicProfile,
              ),
              const SizedBox(height: 12),
              _RouteButton(
                title: 'Mekan Owner Görünümü',
                route: AppRoutes.venueProfile,
              ),
              const SizedBox(height: 12),
              _RouteButton(
                title: 'Mekan Public Görünümü',
                route: AppRoutes.venuePublicProfile,
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
