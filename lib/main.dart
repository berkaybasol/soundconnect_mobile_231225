import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/di/service_locator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies();
  runApp(const SoundConnectApp());
}
