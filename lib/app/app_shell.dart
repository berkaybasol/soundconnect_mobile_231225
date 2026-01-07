import 'package:flutter/material.dart';
import 'router/app_routes.dart';
import '../shared/widgets/app_scaffold.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'SoundConnect',
      centerContent: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Mainstage and Backstage navigation will live here.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.musicianProfile,
            ),
            child: const Text('Musician profiline git'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.musicianPublicProfile,
            ),
            child: const Text('Public musician profiline git'),
          ),
        ],
      ),
    );
  }
}
