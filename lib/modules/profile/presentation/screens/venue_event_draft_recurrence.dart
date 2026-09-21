part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftRecurrence on _VenueEventDraftSheetState {
  Widget _buildRecurrenceOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.initialPlan == null)
        _EventRecurrenceToggle(
          key: const Key('event-repeat-toggle'),
          label: 'Belirli günlerde tekrarla',
          value: _repeating,
          onChanged: _formLocked
              ? null
              : (value) => _updateState(() => _repeating = value),
        ),
      if (_repeating) ...[
        const SizedBox(height: 18),
        _sectionLabel('Her hafta', icon: Icons.repeat_rounded),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var day = 1; day <= 7; day++)
              FilterChip(
                key: ValueKey('plan-weekday-$day'),
                label: Text(
                  const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][day -
                      1],
                ),
                selected: _weekdays.contains(day),
                showCheckmark: false,
                selectedColor: AppColors.brandGradient[2].withValues(
                  alpha: AppColors.isLight ? .18 : .24,
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                surfaceTintColor: Colors.transparent,
                labelStyle: TextStyle(
                  color: _weekdays.contains(day)
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: _weekdays.contains(day)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                side: BorderSide(
                  color: _weekdays.contains(day)
                      ? AppColors.brandGradient[2]
                      : Theme.of(context).colorScheme.outline,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: _formLocked
                    ? null
                    : (selected) => _updateState(() {
                        if (selected) {
                          _weekdays.add(day);
                        } else {
                          _weekdays.remove(day);
                        }
                      }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _EventRecurrenceToggle(
          key: const Key('plan-until-toggle'),
          label: 'Ben durdurana kadar',
          value: _unlimited,
          onChanged: _formLocked
              ? null
              : (value) => _updateState(() {
                  _unlimited = value;
                  _untilDate ??= DateUtils.dateOnly(
                    _selectedDate ?? DateTime.now(),
                  ).add(const Duration(days: 28));
                }),
        ),
        if (!_unlimited) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('plan-until-date'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              'Bitiş: ${eventPlanDateLabel(_untilDate ?? _selectedDate!, includeWeekday: false)}',
            ),
            onPressed: _formLocked
                ? null
                : () async {
                    final first = DateUtils.dateOnly(
                      _selectedDate ?? DateTime.now(),
                    );
                    final initial =
                        _untilDate != null && !_untilDate!.isBefore(first)
                        ? _untilDate!
                        : first;
                    final date = await showSoundConnectDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: first,
                      lastDate: initial.isAfter(DateTime(first.year + 5))
                          ? initial
                          : DateTime(first.year + 5),
                      helpText: 'Planın son günü',
                    );
                    if (mounted && date != null) {
                      _updateState(() => _untilDate = date);
                    }
                  },
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Tarihleri önizlemede kontrol edip istemediklerini çıkarabilirsin.'
          '${_selectedPerformer == null ? '' : ' Seçtiğin sanatçı veya gruptan bu program için ayrıca katılım onayı istenir.'}',
        ),
        if (widget.initialPlan != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Değişiklik henüz başlamamış bağlı tarihlere uygulanır. Ayrı düzenlediğin tarihler korunur.'
              '${_selectedPerformer == null ? '' : ' Program değişirse yeniden sanatçı katılım onayı istenir.'}',
            ),
          ),
      ],
    ],
  );
}

class _EventRecurrenceToggle extends StatelessWidget {
  const _EventRecurrenceToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.brandGradient[2],
                inactiveTrackColor: Theme.of(context).colorScheme.outline,
                thumbColor: AppColors.white,
                inactiveThumbColor: AppColors.white,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
