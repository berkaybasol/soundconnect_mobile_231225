import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Register once in the root navigator. Modal routes also suspend exposure.
final RouteObserver<ModalRoute<dynamic>> analyticsRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// Reports one real exposure per keyed widget lifetime.
///
/// Cards require >=50% visibility for one continuous foreground second. Pages
/// may supply Duration.zero after their authoritative public data has loaded.
/// A different entity should use a different widget key.
class AnalyticsExposure extends StatefulWidget {
  const AnalyticsExposure({
    super.key,
    required this.child,
    required this.onExposed,
    this.enabled = true,
    this.minimumVisibleDuration = const Duration(seconds: 1),
  });

  final Widget child;
  final VoidCallback onExposed;
  final bool enabled;
  final Duration minimumVisibleDuration;

  @override
  State<AnalyticsExposure> createState() => _AnalyticsExposureState();
}

class _AnalyticsExposureState extends State<AnalyticsExposure>
    with WidgetsBindingObserver, RouteAware {
  final Key _detectorKey = UniqueKey();
  ModalRoute<dynamic>? _route;
  Timer? _dwell;
  double _visibleFraction = 0;
  bool _exposed = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    // Per-frame coalescing prevents a quick below-threshold scroll from being
    // lost inside the package's default 500 ms notification batch.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _observeNextPaintedFrame();
  }

  void _observeNextPaintedFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _exposed) return;
      // Opacity can change without geometry changing, in which case the
      // detector intentionally emits no new visibility value. Observe existing
      // frames only; this callback never requests or drives additional frames.
      _reconcile();
      _observeNextPaintedFrame();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      analyticsRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) analyticsRouteObserver.subscribe(this, route);
      _cancelDwell();
    }
    _reconcile();
  }

  @override
  void didUpdateWidget(covariant AnalyticsExposure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.minimumVisibleDuration != widget.minimumVisibleDuration) {
      _cancelDwell();
      _reconcile();
    }
  }

  bool get _qualifies {
    if (!mounted ||
        !widget.enabled ||
        _exposed ||
        !_foreground ||
        _route?.isCurrent != true ||
        _visibleFraction < 0.5 ||
        !TickerMode.of(context)) {
      return false;
    }
    // The detector handles nested clipping and offstage paint exclusion. Fully
    // transparent ancestors need this additional check (opacity is not geometry).
    RenderObject? render = context.findRenderObject();
    while (render != null) {
      if ((render is RenderOpacity && render.opacity == 0) ||
          (render is RenderAnimatedOpacity && render.opacity.value == 0) ||
          (render is RenderOffstage && render.offstage)) {
        return false;
      }
      render = render.parent;
    }
    return true;
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    _visibleFraction = info.visibleFraction;
    _reconcile();
  }

  void _reconcile() {
    if (!_qualifies) {
      _cancelDwell();
      return;
    }
    _dwell ??= Timer(widget.minimumVisibleDuration, () {
      _dwell = null;
      if (!_qualifies) return;
      _exposed = true;
      try {
        widget.onExposed();
      } catch (_) {
        // Analytics is optional and must never break page interactions.
      }
    });
  }

  void _cancelDwell() {
    _dwell?.cancel();
    _dwell = null;
  }

  @override
  void didPushNext() => _cancelDwell();

  @override
  void didPop() => _cancelDwell();

  @override
  void didPopNext() => _reconcile();

  @override
  void didPush() => _reconcile();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _cancelDwell();
    if (_foreground) _reconcile();
  }

  @override
  void dispose() {
    _cancelDwell();
    WidgetsBinding.instance.removeObserver(this);
    analyticsRouteObserver.unsubscribe(this);
    VisibilityDetectorController.instance.forget(_detectorKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: _detectorKey,
    onVisibilityChanged: _onVisibilityChanged,
    child: widget.child,
  );
}
