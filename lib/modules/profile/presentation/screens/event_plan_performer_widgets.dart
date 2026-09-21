part of 'event_plan_performer_screen.dart';

String _performerPlanRange(EventPlanDefinition definition) =>
    '${eventPlanDateLabel(definition.startDate, includeWeekday: false)} – '
    '${definition.untilDate == null ? 'Mekan programı durdurana kadar' : eventPlanDateLabel(definition.untilDate!, includeWeekday: false)}';

String _performerPlanDays(EventPlanDefinition definition) {
  final days = definition.weekdays.toList()..sort();
  return 'Her ${days.map((day) => eventPlanWeekdayNames[day - 1]).join(', ')}';
}

String _performerPlanTime(EventPlanDefinition definition) {
  final end = definition.template.endTime;
  return '${definition.template.startTime.substring(0, 5)}'
      '${end == null ? '' : ' – ${end.substring(0, 5)}'}';
}

class EventPlanConsentCard extends StatelessWidget {
  const EventPlanConsentCard({
    super.key,
    required this.plan,
    required this.busy,
    required this.showOnProfile,
    required this.onPublicationChanged,
    required this.onDecision,
  });

  final EventPlan plan;
  final bool busy, showOnProfile;
  final ValueChanged<bool> onPublicationChanged;
  final ValueChanged<String> onDecision;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.brandGradient.last;
    final definition = plan.definition;
    final consent = switch (plan.consentStatus) {
      'PENDING' => 'Katılım onayın bekleniyor',
      'ACCEPTED' => 'Programa katılımın onaylandı',
      'REJECTED' => 'Bu daveti reddettin',
      'WITHDRAWN' => 'Katılım onayını geri çektin',
      _ => plan.consentLabel,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appCardSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  plan.venueName,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            definition.template.title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: scheme.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    plan.active
                        ? Icons.autorenew_rounded
                        : plan.status == 'COMPLETED'
                        ? Icons.task_alt_rounded
                        : Icons.pause_rounded,
                    size: 14,
                    color: plan.active ? accent : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      switch (plan.status) {
                        'STOPPED' => 'Plan durduruldu',
                        'COMPLETED' => 'Plan tamamlandı',
                        _ => 'Plan aktif',
                      },
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          _PerformerPlanMetadata(
            icon: Icons.repeat_rounded,
            label: _performerPlanDays(definition),
          ),
          _PerformerPlanMetadata(
            icon: Icons.schedule_rounded,
            label: _performerPlanTime(definition),
          ),
          _PerformerPlanMetadata(
            icon: Icons.date_range_outlined,
            label: _performerPlanRange(definition),
          ),
          if (definition.excludedDates.isNotEmpty)
            _PerformerPlanMetadata(
              icon: Icons.event_busy_outlined,
              label:
                  'Hariç tutulan tarihler: ${definition.excludedDates.map(eventPlanDateLabel).join(', ')}',
            ),
          const SizedBox(height: 10),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'KATILIM DURUMUN',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            consent,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (plan.consentStatus == 'ACCEPTED') ...[
            const SizedBox(height: 5),
            Text(
              plan.showOnProfile
                  ? 'Bu programdaki etkinlikler profilinde de gösteriliyor.'
                  : 'Bu programdaki etkinlikler profilinde paylaşılmıyor.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (plan.decisionAllowed) ...[
            const SizedBox(height: 7),
            Text(
              'Bu programdaki gelecek tarihlere katılımını onaylayabilirsin. Katılımını daha sonra sonlandırabilirsin.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                key: ValueKey('plan-publication-${plan.id}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: accent,
                checkColor: AppColors.onAccent,
                checkboxShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                tileColor: Color.alphaBlend(
                  accent.withValues(alpha: .07),
                  scheme.surfaceContainerHighest,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: showOnProfile
                        ? accent.withValues(alpha: .65)
                        : scheme.outline,
                  ),
                ),
                title: Text(
                  'Bu programdaki etkinlikleri profilimde de göster',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                value: showOnProfile,
                onChanged: busy
                    ? null
                    : (value) => onPublicationChanged(value == true),
              ),
            ),
            const SizedBox(height: 16),
            _PerformerPlanPrimaryAction(
              buttonKey: ValueKey('plan-accept-${plan.id}'),
              onPressed: busy ? null : () => onDecision('ACCEPT'),
              label: 'Programı onayla',
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: busy ? null : () => onDecision('REJECT'),
              style: _performerPlanSecondaryStyle(context),
              child: const Text('Reddet'),
            ),
          ],
          if (plan.withdrawAllowed) ...[
            const SizedBox(height: 16),
            TextButton(
              key: ValueKey('plan-withdraw-${plan.id}'),
              onPressed: busy ? null : () => onDecision('WITHDRAW'),
              style: _performerPlanSecondaryStyle(context).copyWith(
                side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
              ),
              child: const Text(
                'Gelecek tarihler için onayımı geri çek',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PerformerPlanMetadata extends StatelessWidget {
  const _PerformerPlanMetadata({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _performerPlanSecondaryStyle(BuildContext context) =>
    TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

class _PerformerPlanPrimaryAction extends StatelessWidget {
  const _PerformerPlanPrimaryAction({
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });
  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GradientOutline(
      radius: 10,
      strokeWidth: 1,
      colors: onPressed == null
          ? [scheme.outline, scheme.outline]
          : AppColors.brandGradient,
      child: FilledButton(
        key: buttonKey,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(
            alpha: .6,
          ),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _PerformerPlanDecisionDialog extends StatelessWidget {
  const _PerformerPlanDecisionDialog({
    required this.plan,
    required this.decision,
    required this.publish,
    required this.onCancel,
    required this.onConfirm,
  });
  final EventPlan plan;
  final String decision;
  final bool publish;
  final VoidCallback onCancel, onConfirm;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      scrollable: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outline),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 20, 20),
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
      ),
      contentTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 13,
        height: 1.5,
      ),
      title: Text(switch (decision) {
        'ACCEPT' => 'Bu programı onayla',
        'REJECT' => 'Plan davetini reddet',
        _ => 'Katılım onayını geri çek',
      }),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.venueName,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  plan.definition.template.title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                _PerformerPlanMetadata(
                  icon: Icons.repeat_rounded,
                  label: _performerPlanDays(plan.definition),
                ),
                _PerformerPlanMetadata(
                  icon: Icons.schedule_rounded,
                  label: _performerPlanTime(plan.definition),
                ),
                _PerformerPlanMetadata(
                  icon: Icons.date_range_outlined,
                  label: _performerPlanRange(plan.definition),
                ),
                if (plan.definition.excludedDates.isNotEmpty)
                  _PerformerPlanMetadata(
                    icon: Icons.event_busy_outlined,
                    label:
                        'Hariç tutulan tarihler: ${plan.definition.excludedDates.map(eventPlanDateLabel).join(', ')}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(switch (decision) {
            'ACCEPT' =>
              'Bu programdaki gelecek tarihlere katılımını onaylıyorsun. Katılımını daha sonra sonlandırabilirsin.',
            'REJECT' => 'Bu program için katılımın onaylanmayacak.',
            _ =>
              'Yeni ve henüz başlamamış plan etkinliklerindeki katılım bağlantın ve profil yayınların kaldırılır. Geçmiş etkinlikler değişmez.',
          }),
          if (decision == 'ACCEPT') ...[
            const SizedBox(height: 12),
            Text(
              publish
                  ? 'Etkinlikler profilinde de gösterilecek.'
                  : 'Profilinde paylaşılmayacak.',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          style: _performerPlanSecondaryStyle(context),
          child: const Text('Vazgeç'),
        ),
        _PerformerPlanPrimaryAction(
          onPressed: onConfirm,
          label: decision == 'ACCEPT'
              ? 'Programı onayla'
              : decision == 'REJECT'
              ? 'Reddet'
              : 'Onayımı geri çek',
        ),
      ],
    );
  }
}
