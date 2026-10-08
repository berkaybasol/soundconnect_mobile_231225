part of 'notification_target_read.dart';

/// Owns only one message, not the failed ACK. Retirement waits for controller
/// completion microtasks and only closes its own painted content. A queued
/// message is retired when it becomes visible, never by closing another bar.
class _TargetRetrySnack {
  _TargetRetrySnack(this.messenger);
  final ScaffoldMessengerState messenger;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;
  bool retired = false, closed = false, painted = false;
  void retire() {
    retired = true;
    scheduleMicrotask(() {
      if (!closed && painted && messenger.mounted) {
        controller.close();
      }
    });
  }
}
