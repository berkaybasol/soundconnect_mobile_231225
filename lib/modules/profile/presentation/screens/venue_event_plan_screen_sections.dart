part of 'venue_event_plan_screen.dart';

extension _OwnerPlanSections on _OwnerPlanState {
  Widget _panel(BuildContext context, {required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appCardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: child,
    );
  }

  Widget _metadata(BuildContext context, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
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

  Widget _buildPlanSummary(BuildContext context, EventPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    final definition = plan.definition;
    final days = definition.weekdays.toList()..sort();
    final end = definition.template.endTime;
    final time =
        '${definition.template.startTime.substring(0, 5)}${end == null ? '' : ' – ${end.substring(0, 5)}'}';
    return _panel(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: scheme.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    plan.active ? Icons.autorenew_rounded : Icons.pause_rounded,
                    size: 14,
                    color: plan.active
                        ? AppColors.brandGradient.last
                        : scheme.onSurfaceVariant,
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
          const SizedBox(height: 14),
          Text(
            definition.template.title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          _metadata(
            context,
            Icons.repeat_rounded,
            'Her ${days.map((day) => eventPlanWeekdayNames[day - 1]).join(', ')}',
          ),
          _metadata(context, Icons.schedule_rounded, time),
          _metadata(
            context,
            Icons.date_range_outlined,
            '${eventPlanDateLabel(definition.startDate, includeWeekday: false)} – ${definition.untilDate == null ? 'Ben durdurana kadar' : eventPlanDateLabel(definition.untilDate!, includeWeekday: false)}',
          ),
          if (plan.status == 'STOPPED')
            _metadata(
              context,
              Icons.info_outline_rounded,
              'Yeni etkinlik tarihleri hazırlanmaz.',
            ),
          const SizedBox(height: 18),
          if (plan.status != 'STOPPED')
            GradientOutline(
              radius: 10,
              strokeWidth: .9,
              child: OutlinedButton.icon(
                onPressed: _busy || _loading ? null : _edit,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  foregroundColor: scheme.onSurface,
                  backgroundColor: scheme.surfaceContainerHighest,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: Icon(
                  Icons.edit_calendar_outlined,
                  size: 18,
                  color: AppColors.brandGradient[2],
                ),
                label: const Text(
                  'Gelecek etkinlikleri düzenle / uzat',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (plan.active)
            TextButton.icon(
              onPressed: _busy || _loading ? null : () => _act('stop'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.pause_circle_outline_rounded, size: 17),
              label: const Text('Planı durdur'),
            ),
          if (plan.status == 'STOPPED')
            TextButton.icon(
              onPressed: _busy || _loading ? null : () => _act('cancel'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.event_busy_outlined, size: 17),
              label: const Text('Hazırlanmış gelecek etkinlikleri iptal et'),
            ),
        ],
      ),
    );
  }

  Widget _buildPerformerStatus(BuildContext context, EventPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    final manual = plan.consentStatus == 'NOT_REQUIRED';
    final explanation = switch (plan.consentStatus) {
      'PENDING' =>
        plan.active
            ? 'Etkinliklerin mekan takviminde hazırlanması bu onayı beklemez.'
            : 'Bu programa henüz katılım onayı verilmedi.',
      'ACCEPTED' =>
        plan.showOnProfile
            ? 'Sanatçı bu programı kendi profilinde de paylaşıyor.'
            : 'Sanatçı bu programı kendi profilinde paylaşmıyor.',
      'REJECTED' ||
      'WITHDRAWN' => 'Katılım onayı, planın çalışma durumundan ayrıdır.',
      _ => null,
    };
    return _panel(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            manual ? 'SANATÇI' : 'SANATÇI KATILIMI',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            plan.performerName,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!manual) ...[
            const SizedBox(height: 4),
            Text(
              switch (plan.consentStatus) {
                'PENDING' => 'Katılım onayı bekleniyor',
                'ACCEPTED' => 'Programa katılım onaylandı',
                'REJECTED' => 'Sanatçı katılım davetini reddetti',
                'WITHDRAWN' => 'Sanatçı katılım onayını geri çekti',
                _ => plan.consentLabel,
              },
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (explanation != null) ...[
            const SizedBox(height: 10),
            Text(
              explanation,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOccurrence(
    BuildContext context,
    EventPlanOccurrence occurrence,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final template = occurrence.template ?? _plan!.definition.template;
    final start = template.startTime.substring(0, 5);
    final end = template.endTime?.substring(0, 5);
    final actionStyle = TextButton.styleFrom(
      foregroundColor: scheme.onSurface,
      backgroundColor: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outline),
      ),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _panel(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              eventPlanDateLabel(occurrence.eventDate),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$start${end == null ? '' : ' – $end'}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(switch (occurrence.status) {
              'OVERRIDDEN' => 'Bu tarih ayrı düzenlendi',
              'SKIPPED' => 'Atlandı',
              'CANCELLED' => 'İptal edildi',
              _ => 'Etkinlik hazır',
            }, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
            if (_upcoming(occurrence)) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _busy || _loading
                        ? null
                        : () => _edit(occurrence: occurrence),
                    style: actionStyle,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Bu tarihi düzenle'),
                  ),
                  TextButton.icon(
                    onPressed: _busy || _loading
                        ? null
                        : () => _act('skip', occurrence: occurrence),
                    style: actionStyle.copyWith(
                      foregroundColor: WidgetStatePropertyAll(
                        scheme.onSurfaceVariant,
                      ),
                    ),
                    icon: const Icon(Icons.event_busy_outlined, size: 15),
                    label: const Text('Bu tarihi atla'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
