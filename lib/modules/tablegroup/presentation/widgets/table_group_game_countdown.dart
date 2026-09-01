import 'dart:async';

import 'package:flutter/material.dart';

class TableGroupGameCountdown extends StatefulWidget {
  const TableGroupGameCountdown({
    super.key,
    required this.deadline,
    required this.serverTime,
    required this.expiryToken,
    required this.onExpired,
    this.now,
  });

  final DateTime deadline;
  final DateTime? serverTime;
  final String expiryToken;
  final VoidCallback onExpired;
  final DateTime Function()? now;

  @override
  State<TableGroupGameCountdown> createState() =>
      _TableGroupGameCountdownState();
}

class _TableGroupGameCountdownState extends State<TableGroupGameCountdown> {
  Timer? _timer;
  late Duration _clockOffset;
  late int _secondsLeft;
  bool _expiryReported = false;

  DateTime get _localNow => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _resetClock();
  }

  @override
  void didUpdateWidget(covariant TableGroupGameCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiryToken != widget.expiryToken ||
        oldWidget.deadline != widget.deadline ||
        oldWidget.serverTime != widget.serverTime) {
      _resetClock();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resetClock() {
    _timer?.cancel();
    final localNow = _localNow;
    _clockOffset = widget.serverTime == null
        ? Duration.zero
        : widget.serverTime!.difference(localNow);
    _expiryReported = false;
    _secondsLeft = _calculateSecondsLeft(localNow);
    if (_secondsLeft <= 0) {
      _reportExpiry();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final next = _calculateSecondsLeft(_localNow);
    if (next != _secondsLeft) setState(() => _secondsLeft = next);
    if (next <= 0) {
      _timer?.cancel();
      _reportExpiry();
    }
  }

  int _calculateSecondsLeft(DateTime localNow) {
    final adjustedNow = localNow.add(_clockOffset);
    final milliseconds = widget.deadline.difference(adjustedNow).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds + 999) ~/ 1000;
  }

  void _reportExpiry() {
    if (_expiryReported) return;
    _expiryReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExpired();
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return Semantics(
      label: 'Kalan süre $minutes dakika $seconds saniye',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            '$minutes:$seconds',
            key: const ValueKey<String>('table-group-game-countdown'),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
