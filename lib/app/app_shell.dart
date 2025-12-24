import 'package:flutter/material.dart';
import '../shared/widgets/placeholder_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'SoundConnect',
      message: 'Mainstage and Backstage navigation will live here.',
    );
  }
}
