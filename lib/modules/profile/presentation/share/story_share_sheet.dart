import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/theme/app_colors.dart';
import 'event_share_service.dart';

class StoryShareSheet extends StatefulWidget {
  const StoryShareSheet({
    super.key,
    required this.bytes,
    required this.accessibilityDescription,
    required this.title,
    required this.keyPrefix,
    this.validityChanges,
    this.isValid,
  });
  final Uint8List bytes;
  final String accessibilityDescription;
  final String title;
  final String keyPrefix;
  final Listenable? validityChanges;
  final bool Function()? isValid;

  @override
  State<StoryShareSheet> createState() => _StoryShareSheetState();
}

class _StoryShareSheetState extends State<StoryShareSheet> {
  bool _dismissed = false;
  bool _invalidated = false;
  bool _dismissScheduled = false;
  ModalRoute<dynamic>? _route;

  bool get _valid => !_invalidated && (widget.isValid?.call() ?? true);

  @override
  void initState() {
    super.initState();
    widget.validityChanges?.addListener(_validityChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    // The session may have changed after push but before this first build,
    // before the sheet could subscribe to the notifier.
    if (!_valid) _validityChanged();
  }

  @override
  void didUpdateWidget(covariant StoryShareSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.validityChanges != widget.validityChanges) {
      oldWidget.validityChanges?.removeListener(_validityChanged);
      widget.validityChanges?.addListener(_validityChanged);
    }
    if (!_valid) _validityChanged();
  }

  void _validityChanged() {
    if (!mounted || _valid) return;
    // A source tile can invalidate during its own update/disposal. Latch the
    // permission synchronously, but never mark this sibling dirty mid-build.
    _invalidated = true;
    if (_dismissScheduled) return;
    _dismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dismissScheduled = false;
      if (!mounted || _dismissed) return;
      final route = _route;
      final navigator = route?.navigator;
      if (route == null || navigator == null || !route.isActive) return;
      _dismissed = true;
      // Remove this exact private preview even when another route covers it;
      // popping here could dismiss an unrelated screen instead.
      navigator.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.validityChanges?.removeListener(_validityChanged);
    super.dispose();
  }

  void _finish([EventShareTarget? target]) {
    if (_dismissed || !mounted || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _dismissed = true;
    Navigator.of(context).pop(_valid ? target : null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) return const SizedBox.shrink();
    final android = defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        key: Key('${widget.keyPrefix}-sheet'),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A4253),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _finish,
                  tooltip: 'Kapat',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFA8A9BB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 166,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Image.memory(
                      widget.bytes,
                      key: Key('${widget.keyPrefix}-preview'),
                      fit: BoxFit.contain,
                      semanticLabel: widget.accessibilityDescription,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '1080 × 1920 · Hikâye formatı',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA8A9BB), fontSize: 12),
            ),
            const SizedBox(height: 22),
            if (android)
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(11) / 11;
                  final stacked =
                      (constraints.maxWidth - 18) / 3 < 84 * textScale;
                  final targets = [
                    _TargetButton(
                      label: 'Instagram\nHikâyesi',
                      icon: const FaIcon(FontAwesomeIcons.instagram),
                      target: EventShareTarget.instagramStory,
                      onTap: _finish,
                      keyPrefix: widget.keyPrefix,
                      horizontal: stacked,
                    ),
                    _TargetButton(
                      label: 'WhatsApp',
                      icon: const FaIcon(FontAwesomeIcons.whatsapp),
                      target: EventShareTarget.whatsapp,
                      onTap: _finish,
                      keyPrefix: widget.keyPrefix,
                      horizontal: stacked,
                    ),
                    _TargetButton(
                      label: 'Diğer',
                      icon: const Icon(Icons.ios_share_rounded),
                      target: EventShareTarget.other,
                      onTap: _finish,
                      keyPrefix: widget.keyPrefix,
                      horizontal: stacked,
                    ),
                  ];
                  if (stacked) {
                    return Column(
                      key: Key('${widget.keyPrefix}-targets-column'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < targets.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(height: 10),
                          targets[index],
                        ],
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < targets.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(width: 9),
                          Expanded(child: targets[index]),
                        ],
                      ],
                    ),
                  );
                },
              )
            else
              _TargetButton(
                label: 'Paylaş',
                icon: const Icon(Icons.ios_share_rounded),
                target: EventShareTarget.other,
                onTap: _finish,
                keyPrefix: widget.keyPrefix,
              ),
          ],
        ),
      ),
    );
  }
}

class _TargetButton extends StatelessWidget {
  const _TargetButton({
    required this.label,
    required this.icon,
    required this.target,
    required this.onTap,
    required this.keyPrefix,
    this.horizontal = false,
  });
  final String label;
  final String keyPrefix;
  final bool horizontal;
  final Widget icon;
  final EventShareTarget target;
  final ValueChanged<EventShareTarget> onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0.7),
        child: Material(
          color: const Color(0xFF151D2D),
          borderRadius: BorderRadius.circular(17.3),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('$keyPrefix-target-${target.name}'),
            onTap: () => onTap(target),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: horizontal ? 17 : 15,
                horizontal: horizontal ? 18 : 5,
              ),
              child: horizontal
                  ? Row(
                      children: [
                        IconTheme(
                          data: const IconThemeData(
                            size: 24,
                            color: Color(0xFFE58BB8),
                          ),
                          child: icon,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            label.replaceAll('\n', ' '),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconTheme(
                          data: const IconThemeData(
                            size: 24,
                            color: Color(0xFFE58BB8),
                          ),
                          child: icon,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
