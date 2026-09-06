import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/theme/app_colors.dart';
import 'event_share_service.dart';

Future<EventShareTarget?> showEventShareSheet(
  BuildContext context,
  PreparedEventShare prepared,
) => showModalBottomSheet<EventShareTarget>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.navBlueDeep,
  barrierColor: Colors.black.withValues(alpha: 0.65),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    side: BorderSide(color: Color(0xFF2A3244)),
  ),
  builder: (_) => EventShareSheet(prepared: prepared),
);

class EventShareSheet extends StatefulWidget {
  const EventShareSheet({super.key, required this.prepared});
  final PreparedEventShare prepared;

  @override
  State<EventShareSheet> createState() => _EventShareSheetState();
}

class _EventShareSheetState extends State<EventShareSheet> {
  bool _dismissed = false;

  void _finish([EventShareTarget? target]) {
    if (_dismissed || !mounted || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _dismissed = true;
    Navigator.of(context).pop(target);
  }

  @override
  Widget build(BuildContext context) {
    final android = defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        key: const Key('event-share-sheet'),
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
                const Expanded(
                  child: Text(
                    'Etkinliği paylaş',
                    style: TextStyle(
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
                      widget.prepared.bytes,
                      key: const Key('event-share-preview'),
                      fit: BoxFit.contain,
                      semanticLabel:
                          widget.prepared.data.accessibilityDescription,
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
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _TargetButton(
                        label: 'Instagram\nHikâyesi',
                        icon: const FaIcon(FontAwesomeIcons.instagram),
                        target: EventShareTarget.instagramStory,
                        onTap: _finish,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _TargetButton(
                        label: 'WhatsApp',
                        icon: const FaIcon(FontAwesomeIcons.whatsapp),
                        target: EventShareTarget.whatsapp,
                        onTap: _finish,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _TargetButton(
                        label: 'Diğer',
                        icon: const Icon(Icons.ios_share_rounded),
                        target: EventShareTarget.other,
                        onTap: _finish,
                      ),
                    ),
                  ],
                ),
              )
            else
              _TargetButton(
                label: 'Paylaş',
                icon: const Icon(Icons.ios_share_rounded),
                target: EventShareTarget.other,
                onTap: _finish,
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
  });
  final String label;
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
            key: Key('event-share-target-${target.name}'),
            onTap: () => onTap(target),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
              child: Column(
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
