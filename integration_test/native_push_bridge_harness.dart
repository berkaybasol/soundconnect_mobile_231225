// Test-only Dart peer for NativePushBridgeLifecycleTest. Never a product target.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('com.soundconnect/push_delivery');
  const test = MethodChannel('com.soundconnect/bridge_test');
  final opened = <Object?>[];
  native.setMethodCallHandler((call) async {
    if (call.method == 'opened') opened.add(call.arguments);
  });
  test.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'initial':
        return native.invokeMethod<Object?>('initialMessage');
      case 'events':
        return opened;
      default:
        throw MissingPluginException();
    }
  });
  runApp(const MaterialApp(home: Scaffold(body: Text('Native bridge test'))));
}
