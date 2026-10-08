part of 'collab_create_listing_screen.dart';

class _CreateStepIndicator extends StatelessWidget {
  const _CreateStepIndicator({
    required this.currentStep,
    required this.onStepTap,
  });

  final int currentStep;
  final ValueChanged<int> onStepTap;

  static const labels = <String>['İlan Türü', 'İlan Bilgileri', 'Önizleme'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: List.generate(labels.length * 2 - 1, (index) {
        if (index.isOdd) {
          final completed = currentStep > index ~/ 2;
          return Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: completed
                    ? LinearGradient(colors: AppColors.decorativeGradient)
                    : null,
                color: completed ? null : theme.dividerColor,
              ),
            ),
          );
        }
        final step = index ~/ 2;
        final active = step == currentStep;
        final completed = step < currentStep;
        final stepCircle = Container(
          width: 37,
          height: 37,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.isOriginalDark && (active || completed)
                ? LinearGradient(colors: AppColors.decorativeGradient)
                : null,
            border: active || completed
                ? null
                : Border.all(color: theme.dividerColor, width: 1.4),
          ),
          child: completed
              ? Icon(
                  Icons.check_rounded,
                  color: AppColors.decorativeForeground,
                  size: 19,
                )
              : Text(
                  '${step + 1}',
                  style: TextStyle(
                    color: active
                        ? AppColors.decorativeForeground
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        );
        return InkWell(
          onTap: completed ? () => onStepTap(step) : null,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 82,
            child: Column(
              children: [
                if (AppColors.isLight && (active || completed))
                  GradientOutline(radius: 18.5, child: stepCircle)
                else
                  stepCircle,
                const SizedBox(height: 5),
                Text(
                  labels[step],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? AppColors.coralLight
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _ListingTypeStep extends StatelessWidget {
  const _ListingTypeStep({
    required this.cadence,
    required this.editable,
    required this.onCadenceChanged,
    required this.onComingSoonTap,
    super.key,
  });

  final CollabCadence cadence;
  final bool editable;
  final ValueChanged<CollabCadence> onCadenceChanged;
  final VoidCallback onComingSoonTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'İlan Türü',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'İlanının çalışma biçimini seçerek başla.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 22),
          const CollabSectionTitle('İlan Türü'),
          const SizedBox(height: 9),
          _CreateChoiceCard(
            title: 'Düzenli',
            description: 'Sürekli veya tekrarlayan işler için.',
            icon: Icons.event_repeat_rounded,
            selected: cadence == CollabCadence.regular,
            onTap: editable
                ? () => onCadenceChanged(CollabCadence.regular)
                : null,
          ),
          const SizedBox(height: 9),
          _CreateChoiceCard(
            title: 'Ekstra',
            description: 'Tek seferlik veya kısa süreli işler için.',
            icon: Icons.work_outline_rounded,
            selected: cadence == CollabCadence.extra,
            onTap: editable
                ? () => onCadenceChanged(CollabCadence.extra)
                : null,
          ),
          const SizedBox(height: 17),
          _ComingSoonCard(
            title: 'Param Güvende',
            description:
                'Güvenli ödeme ve anlaşma sistemi yakında kullanıma açılacak.',
            icon: Icons.shield_outlined,
            onTap: onComingSoonTap,
          ),
        ],
      ),
    );
  }
}

class _CreateChoiceCard extends StatelessWidget {
  const _CreateChoiceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: CollabGradientFrame(
        highlighted: selected,
        radius: 18,
        strokeWidth: selected ? 1.4 : 1,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Icon(icon, color: AppColors.socialPink, size: 27),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _CreateRadio(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _CreateRadio extends StatelessWidget {
  const _CreateRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? AppColors.socialPink
              : Theme.of(context).colorScheme.onSurfaceVariant,
          width: 2,
        ),
      ),
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppColors.decorativeGradient),
              ),
            )
          : null,
    );
  }
}

class _ListingInformationStep extends StatelessWidget {
  const _ListingInformationStep({
    required this.input,
    required this.fieldsLocked,
    required this.instrumentCatalogError,
    required this.onCatalogRetry,
    required this.selectedActor,
    required this.cities,
    required this.instruments,
    required this.titleController,
    required this.descriptionController,
    required this.customSpecialtyController,
    required this.feeController,
    required this.feeMode,
    required this.occurrenceDate,
    required this.occurrenceTime,
    required this.dateError,
    required this.timeError,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    required this.onCityChanged,
    required this.onWantedTypeChanged,
    required this.onSpecialtyChanged,
    required this.onCustomSpecialtyChanged,
    required this.onGenreToggle,
    required this.onDateTap,
    required this.onTimeTap,
    required this.onFeeModeChanged,
    required this.onFeeChanged,
    required this.canSelectPublisher,
    required this.onPublisherTap,
    super.key,
  });

  final CollabListingInput input;
  final bool fieldsLocked;
  final String? instrumentCatalogError;
  final VoidCallback onCatalogRetry;
  final CollabActor selectedActor;
  final List<City> cities;
  final List<Instrument> instruments;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController customSpecialtyController;
  final TextEditingController feeController;
  final _CollabFeeMode feeMode;
  final DateTime? occurrenceDate;
  final TimeOfDay? occurrenceTime;
  final bool dateError;
  final bool timeError;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<CollabProfileKind?> onWantedTypeChanged;
  final ValueChanged<_CreateSpecialtyOption?> onSpecialtyChanged;
  final ValueChanged<String> onCustomSpecialtyChanged;
  final ValueChanged<String> onGenreToggle;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;
  final ValueChanged<_CollabFeeMode> onFeeModeChanged;
  final ValueChanged<String> onFeeChanged;
  final bool canSelectPublisher;
  final VoidCallback onPublisherTap;

  List<_CreateSpecialtyOption> _specialtyOptions() {
    final branches = CollabBranch.values
        .map(_CreateSpecialtyOption.branch)
        .toList(growable: false);
    final branchLabels = branches
        .map((option) => option.label.trim().toLowerCase())
        .toSet();
    final options = <_CreateSpecialtyOption>[
      ...instruments
          .where(
            (instrument) =>
                !branchLabels.contains(instrument.name.trim().toLowerCase()),
          )
          .map(_CreateSpecialtyOption.instrument),
      ...branches,
    ]..sort((a, b) => a.label.compareTo(b.label));
    return List<_CreateSpecialtyOption>.unmodifiable(options);
  }

  Future<_CreateSpecialtyOption?> _pickSpecialty(
    BuildContext context,
    List<_CreateSpecialtyOption> options,
    _CreateSpecialtyOption? selected,
  ) => showCollabModalBottomSheet<_CreateSpecialtyOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => CollabSearchableOptionSheet(
      title: 'Enstrüman / Branş',
      options: options,
      selected: selected,
      labelFor: (option) => option.label,
      onSelected: (option) => Navigator.of(sheetContext).pop(option),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cityValue = cities.any((city) => city.id == input.cityId)
        ? input.cityId
        : null;
    final specialtyOptions = _specialtyOptions();
    final specialtyValue = specialtyOptions
        .where(
          (option) =>
              (input.instrumentId != null &&
                  option.instrumentId == input.instrumentId) ||
              (input.branch != null && option.branch == input.branch),
        )
        .firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'İlan Bilgileri',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'İnsanların karar vermesi için gereken temel bilgileri ekle.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          if (fieldsLocked) ...[
            const SizedBox(height: 14),
            const _EditorNotice(
              key: ValueKey('collab-open-fields-locked'),
              message:
                  'Bu ilan başvuru aldığı için iş şartları artık değiştirilemez.',
              icon: Icons.lock_outline_rounded,
            ),
          ],
          if (instrumentCatalogError != null) ...[
            const SizedBox(height: 14),
            _EditorNotice(
              key: const ValueKey('collab-instrument-catalog-warning'),
              message:
                  '$instrumentCatalogError Branş seçenekleri kullanılabilir.',
              icon: Icons.cloud_off_outlined,
              actionLabel: 'Tekrar dene',
              onAction: onCatalogRetry,
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('collab-create-title'),
            controller: titleController,
            maxLength: 100,
            textInputAction: TextInputAction.next,
            readOnly: fieldsLocked,
            decoration: const InputDecoration(labelText: 'İlan Başlığı'),
            onChanged: onTitleChanged,
            validator: (value) {
              final length = value?.trim().length ?? 0;
              if (length < 5) return 'Başlık en az 5 karakter olmalı.';
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('collab-create-description'),
            controller: descriptionController,
            minLines: 4,
            maxLines: 7,
            maxLength: 500,
            readOnly: fieldsLocked,
            decoration: const InputDecoration(labelText: 'Açıklama'),
            onChanged: onDescriptionChanged,
            validator: (value) {
              final length = value?.trim().length ?? 0;
              if (length < 20) return 'Açıklama en az 20 karakter olmalı.';
              return null;
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const ValueKey('collab-create-location'),
            isExpanded: true,
            initialValue: cityValue,
            decoration: const InputDecoration(
              labelText: 'Şehir',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: cities
                .map(
                  (city) =>
                      DropdownMenuItem(value: city.id, child: Text(city.name)),
                )
                .toList(growable: false),
            onChanged: fieldsLocked ? null : onCityChanged,
            validator: (value) => value == null ? 'Şehir seç.' : null,
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<CollabProfileKind>(
            key: const ValueKey('collab-create-wanted-type'),
            isExpanded: true,
            initialValue: input.wantedType,
            decoration: const InputDecoration(
              labelText: 'Aranan',
              prefixIcon: Icon(Icons.manage_search_rounded),
            ),
            items: CollabProfileKind.values
                .map(
                  (kind) => DropdownMenuItem(
                    value: kind,
                    child: Text(kind.wantedLabel),
                  ),
                )
                .toList(growable: false),
            onChanged: fieldsLocked ? null : onWantedTypeChanged,
          ),
          if (input.wantedType == CollabProfileKind.musician) ...[
            const SizedBox(height: 13),
            FormField<_CreateSpecialtyOption>(
              initialValue: specialtyValue,
              validator: (value) =>
                  value == null ? 'Enstrüman veya branş seç.' : null,
              builder: (field) => InkWell(
                key: const ValueKey('collab-create-specialty'),
                borderRadius: BorderRadius.circular(12),
                onTap: fieldsLocked
                    ? null
                    : () async {
                        final selected = await _pickSpecialty(
                          context,
                          specialtyOptions,
                          field.value,
                        );
                        if (selected == null) return;
                        field.didChange(selected);
                        onSpecialtyChanged(selected);
                      },
                child: InputDecorator(
                  isEmpty: field.value == null,
                  decoration: InputDecoration(
                    labelText: 'Enstrüman / Branş',
                    hintText: 'Seçmek için dokun',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.music_note_outlined),
                    suffixIcon: const Icon(Icons.search_rounded),
                    errorText: field.errorText,
                    enabled: !fieldsLocked,
                  ),
                  child: Text(field.value?.label ?? ''),
                ),
              ),
            ),
            if (input.branch == CollabBranch.other) ...[
              const SizedBox(height: 13),
              TextFormField(
                key: const ValueKey('collab-create-custom-specialty'),
                controller: customSpecialtyController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Diğer branş',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                readOnly: fieldsLocked,
                onChanged: fieldsLocked ? null : onCustomSpecialtyChanged,
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Branşı yaz.' : null,
              ),
            ],
          ],
          const SizedBox(height: 20),
          const CollabSectionTitle('Tarz'),
          const SizedBox(height: 4),
          Text(
            'İsteğe bağlı · En fazla 3 seçim',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _collabGenreOptions
                .map(
                  (genre) => CollabChoiceChip(
                    label: genre,
                    selected: input.genres.contains(genre),
                    onTap: fieldsLocked ? null : () => onGenreToggle(genre),
                  ),
                )
                .toList(growable: false),
          ),
          if (input.cadence == CollabCadence.extra) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'Sahne Tarihi',
                    value: occurrenceDate == null
                        ? 'Tarih seç'
                        : _longDate(occurrenceDate!),
                    icon: Icons.calendar_month_outlined,
                    error: dateError ? 'Tarih seç.' : null,
                    onTap: fieldsLocked ? null : onDateTap,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _PickerField(
                    label: 'Saat',
                    value: occurrenceTime == null
                        ? 'Saat seç'
                        : _timeLabel(occurrenceTime!),
                    icon: Icons.schedule_rounded,
                    error: timeError ? 'Saat seç.' : null,
                    onTap: fieldsLocked ? null : onTimeTap,
                  ),
                ),
              ],
            ),
          ],
          if (input.cadence == CollabCadence.extra ||
              selectedActor.profileType == CollabProfileKind.venue) ...[
            const SizedBox(height: 20),
            const CollabSectionTitle('Ücret'),
            const SizedBox(height: 10),
            _FeeModeSelector(
              selected: feeMode,
              onSelected: fieldsLocked ? null : onFeeModeChanged,
            ),
            if (feeMode == _CollabFeeMode.paid) ...[
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('collab-create-fee'),
                controller: feeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                readOnly: fieldsLocked,
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) =>
                        _feeInputPattern.hasMatch(newValue.text)
                        ? newValue
                        : oldValue,
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Ücret',
                  prefixText: '₺ ',
                ),
                onChanged: onFeeChanged,
                validator: (value) {
                  final amountMinor = _parseFeeAmountMinor(value ?? '');
                  if (amountMinor == null ||
                      amountMinor <= 0 ||
                      amountMinor > collabMaxFeeAmountMinor) {
                    return '1-1.000.000 TRY arasında tek bir ücret gir.';
                  }
                  return null;
                },
              ),
            ],
          ],
          if (canSelectPublisher) ...[
            const SizedBox(height: 20),
            const CollabSectionTitle('İlan Veren Profil'),
            const SizedBox(height: 9),
            _PublisherCard(
              key: const ValueKey('collab-create-publisher-picker'),
              profile: selectedActor,
              onTap: fieldsLocked ? null : onPublisherTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.error,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: CollabGradientFrame(
            highlighted: error != null,
            radius: 14,
            child: SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 10),
          ),
        ],
      ],
    );
  }
}

class _FeeModeSelector extends StatelessWidget {
  const _FeeModeSelector({required this.selected, required this.onSelected});

  final _CollabFeeMode selected;
  final ValueChanged<_CollabFeeMode>? onSelected;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return CollabGradientFrame(
      radius: 15,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            _FeeModeOption(
              label: 'Ücretli',
              selected: selected == _CollabFeeMode.paid,
              onTap: onSelected == null
                  ? null
                  : () => onSelected!(_CollabFeeMode.paid),
            ),
            _FeeModeOption(
              label: 'Ücret belirtilmemiş',
              selected: selected == _CollabFeeMode.unspecified,
              onTap: onSelected == null
                  ? null
                  : () => onSelected!(_CollabFeeMode.unspecified),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeModeOption extends StatelessWidget {
  const _FeeModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: selected
            ? CollabGradientFrame(
                highlighted: true,
                radius: 14,
                strokeWidth: 1.2,
                child: Center(child: _FeeLabel(label: label, selected: true)),
              )
            : Center(child: _FeeLabel(label: label, selected: false)),
      ),
    );
  }
}

class _FeeLabel extends StatelessWidget {
  const _FeeLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11.5,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
      ),
    );
  }
}

class _PublisherCard extends StatelessWidget {
  const _PublisherCard({required this.profile, required this.onTap, super.key});

  final CollabActor profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: CollabGradientFrame(
        radius: 17,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            CollabIdentityAvatar(
              initials: profile.initials,
              profileKind: profile.profileType,
              avatarUrl: profile.avatarUrl,
              size: 52,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profile.profileType.label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _PublisherPicker extends StatelessWidget {
  const _PublisherPicker({required this.actors, required this.selected});

  final List<CollabActor> actors;
  final CollabActor? selected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
        children: [
          const CollabSectionTitle('İlan Veren Profili Seç'),
          const SizedBox(height: 6),
          Text(
            'Müzisyen, Grup, Mekan ve Stüdyo profillerinden birini seç.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          ...actors.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: CollabGradientFrame(
                highlighted: profile.actorId == selected?.actorId,
                radius: 16,
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: () => Navigator.of(context).pop(profile),
                    leading: CollabIdentityAvatar(
                      initials: profile.initials,
                      profileKind: profile.profileType,
                      avatarUrl: profile.avatarUrl,
                      size: 43,
                    ),
                    title: Text(profile.displayName),
                    subtitle: Text(profile.profileType.label),
                    trailing: _CreateRadio(
                      selected: profile.actorId == selected?.actorId,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
