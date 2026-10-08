import 'package:flutter/material.dart';

import 'preview/runtime/preview_bootstrap.dart';

Future<void> main() async {
  try {
    await launchPreview();
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Önizleme açılamadı.\n\n$error'),
            ),
          ),
        ),
      ),
    );
  }
}
