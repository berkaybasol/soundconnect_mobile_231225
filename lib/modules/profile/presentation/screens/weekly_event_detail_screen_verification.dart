part of 'weekly_event_detail_screen.dart';

String _eventPerformerDisplayName(String value) =>
    value.trim().replaceFirst(RegExp(r'^(?:@\s*)+'), '').trim();

bool _hasNamedEventPerformer(String name) =>
    name.isNotEmpty &&
    !const {
      '-',
      'performer',
      'yakinda aciklanacak',
      'yakında açıklanacak',
      'belirtilmemiş',
      'belirtilmemis',
    }.contains(name.toLowerCase());

extension _WeeklyEventPerformerVerification on _WeeklyEventDetailScreenState {
  Future<void> _showPerformerVerificationInfo() async {
    if (!mounted ||
        _isShowingPerformerInfo ||
        widget.event.hasLinkedPerformerProfile ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final name = _eventPerformerDisplayName(widget.event.artistName);
    if (!_hasNamedEventPerformer(name)) return;

    // This is informational only. Profile navigation continues to depend on
    // the existing public identity, never on profile-calendar publication.
    _isShowingPerformerInfo = true;
    var dismissed = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final scheme = Theme.of(dialogContext).colorScheme;
          void dismiss() {
            if (dismissed ||
                !dialogContext.mounted ||
                ModalRoute.of(dialogContext)?.isCurrent != true) {
              return;
            }
            dismissed = true;
            Navigator.of(dialogContext).pop();
          }

          return Dialog(
            key: const Key('event-performer-verification-dialog'),
            backgroundColor: scheme.surfaceContainerHighest,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: scheme.onSurface.withValues(alpha: .12)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GradientIcon(icon: Icons.info_outline_rounded, size: 28),
                    const SizedBox(height: 16),
                    Text(
                      'Katılım bilgisi',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Unlinked public payloads intentionally hide whether the
                    // name belongs to a musician or band. Do not infer a kind
                    // or claim a pending invitation (it may also be rejected).
                    Text(
                      'Sanatçı/grup bu etkinliğe katılımını henüz doğrulamadı.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: GradientOutlineButton(
                        key: const Key('event-performer-verification-dismiss'),
                        label: 'Anladım',
                        strokeWidth: .8,
                        onPressed: dismiss,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _isShowingPerformerInfo = false;
    }
  }
}
