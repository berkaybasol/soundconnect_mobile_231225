import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';

/// Test entry starts the same route-free coordinator as native/inbox callers.
class NotificationDirectTestHost extends StatefulWidget {
  const NotificationDirectTestHost({super.key, required this.opener});
  final Widget opener;
  @override
  State<NotificationDirectTestHost> createState() => _HostState();
}

class _HostState extends State<NotificationDirectTestHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          NotificationDirectOpen.start(
            context,
            identity: 'test-notification',
            builder: (_) => widget.opener,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Original product page'));
}
