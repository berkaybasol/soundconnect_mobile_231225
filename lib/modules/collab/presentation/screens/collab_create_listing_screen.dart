import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../data/collab_creation_mock_data.dart';
import '../../data/collab_mock_controller.dart';
import '../../domain/collab_discovery_models.dart';
import '../../domain/collab_listing_draft.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';

enum CollabCreateListingResult { published, draftSaved }

class CollabCreateListingScreen extends StatefulWidget {
  const CollabCreateListingScreen({
    this.controller,
    this.initialDraft,
    this.showBottomNavigation = true,
    super.key,
  });

  final CollabMockController? controller;
  final CollabListingDraft? initialDraft;
  final bool showBottomNavigation;

  @override
  State<CollabCreateListingScreen> createState() =>
      _CollabCreateListingScreenState();
}

class _CollabCreateListingScreenState extends State<CollabCreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _feeController;
  late CollabListingDraft _draft;
  int _step = 0;
  bool _submitting = false;
  bool _dateError = false;
  bool _timeError = false;

  CollabMockController get _controller =>
      widget.controller ?? collabMockController;

  @override
  void initState() {
    super.initState();
    final initialDraft = widget.initialDraft;
    if (initialDraft != null) {
      _titleController = TextEditingController(text: initialDraft.title);
      _descriptionController = TextEditingController(
        text: initialDraft.description,
      );
      _feeController = TextEditingController(
        text: initialDraft.feeAmount?.toString() ?? '',
      );
      _draft = initialDraft;
      return;
    }
    final now = DateTime.now();
    final mockDate = DateTime(now.year, now.month, now.day + 7);
    _titleController = TextEditingController(
      text: 'Çarşamba gecesi bas gitarist arıyoruz',
    );
    _descriptionController = TextEditingController(
      text:
          'Çarşamba gecesi sahne alacağımız mekan için deneyimli bir bas '
          'gitarist arıyoruz. Enerjisi yüksek biriyle çalışmak istiyoruz.',
    );
    _feeController = TextEditingController(text: '1500');
    _draft = CollabListingDraft(
      cadence: CollabCadence.extra,
      direction: CollabDirection.seeking,
      title: _titleController.text,
      description: _descriptionController.text,
      location: collabCreationLocations.keys.first,
      city: collabCreationLocations.values.first,
      role: 'Bas Gitar',
      genres: const {'Rock', 'Funk'},
      occurrenceDate: mockDate,
      occurrenceTime: const CollabClockTime(hour: 21, minute: 0),
      feeMode: CollabFeeMode.paid,
      feeAmount: 1500,
      capacity: 1,
      publisher: collabPublisherMockProfiles.first,
    );
  }

  @override
  void dispose() {
    _feeController.dispose();
    _descriptionController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<CollabCreateListingResult>(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('İlan Oluştur'),
          leading: BackButton(onPressed: _handleBack),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _CreateStepIndicator(
                  currentStep: _step,
                  onStepTap: (step) {
                    if (step < _step) setState(() => _step = step);
                  },
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: switch (_step) {
                    0 => _TypeAndDirectionStep(
                      key: const ValueKey('create-step-type'),
                      draft: _draft,
                      onCadenceChanged: _changeCadence,
                      onDirectionChanged: _changeDirection,
                      onComingSoonTap: () => _showMessage(
                        'Param Güvende yakında kullanıma açılacak.',
                      ),
                    ),
                    1 => Form(
                      key: _formKey,
                      child: _ListingInformationStep(
                        key: const ValueKey('create-step-information'),
                        draft: _draft,
                        titleController: _titleController,
                        descriptionController: _descriptionController,
                        feeController: _feeController,
                        dateError: _dateError,
                        timeError: _timeError,
                        onTitleChanged: (value) =>
                            _updateDraft(_draft.copyWith(title: value)),
                        onDescriptionChanged: (value) =>
                            _updateDraft(_draft.copyWith(description: value)),
                        onLocationChanged: _changeLocation,
                        onRoleChanged: (value) =>
                            _updateDraft(_draft.copyWith(role: value)),
                        onGenreToggle: _toggleGenre,
                        onDateTap: _pickDate,
                        onTimeTap: _pickTime,
                        onFeeModeChanged: _changeFeeMode,
                        onFeeChanged: _changeFee,
                        onCapacityChanged: (value) =>
                            _updateDraft(_draft.copyWith(capacity: value)),
                        onPublisherTap: _pickPublisher,
                      ),
                    ),
                    _ => _PreviewStep(
                      key: const ValueKey('create-step-preview'),
                      draft: _draft,
                      submitting: _submitting,
                      onPublish: _publish,
                      onSaveDraft: _saveDraft,
                    ),
                  },
                ),
              ),
              if (_step < 2)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(14, 9, 14, 13),
                  child: CollabPrimaryAction(
                    key: const ValueKey('collab-create-continue'),
                    label: 'Devam Et',
                    onPressed: _continue,
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: widget.showBottomNavigation
            ? ProfilePublicBottomBar(currentIndex: 1)
            : null,
      ),
    );
  }

  void _handleBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _continue() {
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    _draft = _draft.copyWith(
      title: _titleController.text,
      description: _descriptionController.text,
    );
    final formValid = _formKey.currentState?.validate() ?? false;
    final needsDate =
        _draft.cadence == CollabCadence.extra &&
        _draft.direction == CollabDirection.seeking;
    setState(() {
      _dateError = needsDate && _draft.occurrenceDate == null;
      _timeError = needsDate && _draft.occurrenceTime == null;
    });
    if (!formValid || _dateError || _timeError || _draft.publisher == null) {
      _showMessage('Devam etmek için zorunlu alanları kontrol et.');
      return;
    }
    if (_isOccurrenceInPast()) {
      _showMessage('Sahne tarihi ve saati geçmişte olamaz.');
      return;
    }
    setState(() => _step = 2);
  }

  bool _isOccurrenceInPast() {
    if (_draft.cadence != CollabCadence.extra ||
        _draft.direction != CollabDirection.seeking ||
        _draft.occurrenceDate == null ||
        _draft.occurrenceTime == null) {
      return false;
    }
    final date = _draft.occurrenceDate!;
    final time = _draft.occurrenceTime!;
    final occurrence = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return occurrence.isBefore(DateTime.now());
  }

  void _changeCadence(CollabCadence cadence) {
    var next = _draft.copyWith(cadence: cadence);
    if (cadence == CollabCadence.regular) {
      next = next.copyWith(
        clearOccurrenceDate: true,
        clearOccurrenceTime: true,
      );
    }
    _updateDraft(next);
  }

  void _changeDirection(CollabDirection direction) {
    var next = _draft.copyWith(direction: direction);
    if (direction == CollabDirection.available) {
      next = next.copyWith(
        clearCapacity: true,
        clearOccurrenceDate: _draft.cadence == CollabCadence.extra,
        clearOccurrenceTime: _draft.cadence == CollabCadence.extra,
      );
    } else if (next.capacity == null) {
      next = next.copyWith(capacity: 1);
    }
    _updateDraft(next);
  }

  void _changeLocation(String? location) {
    if (location == null) return;
    _updateDraft(
      _draft.copyWith(
        location: location,
        city: collabCreationLocations[location],
      ),
    );
  }

  void _toggleGenre(String genre) {
    final genres = Set<String>.of(_draft.genres);
    if (!genres.remove(genre)) {
      if (genres.length >= 3) {
        _showMessage('En fazla 3 tarz seçebilirsin.');
        return;
      }
      genres.add(genre);
    }
    _updateDraft(_draft.copyWith(genres: genres));
  }

  void _changeFeeMode(CollabFeeMode mode) {
    if (mode == CollabFeeMode.unspecified) {
      _feeController.clear();
      _updateDraft(_draft.copyWith(feeMode: mode, clearFeeAmount: true));
    } else {
      _updateDraft(_draft.copyWith(feeMode: mode));
    }
  }

  void _changeFee(String value) {
    final amount = int.tryParse(value.replaceAll(RegExp(r'\D'), ''));
    _updateDraft(
      amount == null
          ? _draft.copyWith(clearFeeAmount: true)
          : _draft.copyWith(feeAmount: amount),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _draft.occurrenceDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _draft = _draft.copyWith(occurrenceDate: picked);
      _dateError = false;
    });
  }

  Future<void> _pickTime() async {
    final current = _draft.occurrenceTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current?.hour ?? 21,
        minute: current?.minute ?? 0,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _draft = _draft.copyWith(
        occurrenceTime: CollabClockTime(
          hour: picked.hour,
          minute: picked.minute,
        ),
      );
      _timeError = false;
    });
  }

  Future<void> _pickPublisher() async {
    final profile = await showModalBottomSheet<CollabPublisherProfile>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PublisherPicker(selected: _draft.publisher),
    );
    if (!mounted || profile == null) return;
    _updateDraft(_draft.copyWith(publisher: profile));
  }

  Future<void> _publish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final initialDraft = widget.initialDraft;
    if (initialDraft != null) _controller.removeDraft(initialDraft);
    _controller.publish(_draft);
    Navigator.of(context).pop(CollabCreateListingResult.published);
  }

  void _saveDraft() {
    if (_submitting) return;
    final initialDraft = widget.initialDraft;
    if (initialDraft != null) _controller.removeDraft(initialDraft);
    _controller.saveDraft(_draft);
    Navigator.of(context).pop(CollabCreateListingResult.draftSaved);
  }

  void _updateDraft(CollabListingDraft draft) {
    setState(() => _draft = draft);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CreateStepIndicator extends StatelessWidget {
  const _CreateStepIndicator({
    required this.currentStep,
    required this.onStepTap,
  });

  final int currentStep;
  final ValueChanged<int> onStepTap;

  static const labels = <String>['Tür ve Yön', 'İlan Bilgileri', 'Önizleme'];

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
                    ? LinearGradient(colors: AppColors.brandGradient)
                    : null,
                color: completed ? null : theme.dividerColor,
              ),
            ),
          );
        }
        final step = index ~/ 2;
        final active = step == currentStep;
        final completed = step < currentStep;
        return InkWell(
          onTap: completed ? () => onStepTap(step) : null,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 82,
            child: Column(
              children: [
                Container(
                  width: 37,
                  height: 37,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: active || completed
                        ? LinearGradient(colors: AppColors.brandGradient)
                        : null,
                    border: active || completed
                        ? null
                        : Border.all(color: theme.dividerColor, width: 1.4),
                  ),
                  child: completed
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.white,
                          size: 19,
                        )
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            color: active
                                ? AppColors.white
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
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

class _TypeAndDirectionStep extends StatelessWidget {
  const _TypeAndDirectionStep({
    required this.draft,
    required this.onCadenceChanged,
    required this.onDirectionChanged,
    required this.onComingSoonTap,
    super.key,
  });

  final CollabListingDraft draft;
  final ValueChanged<CollabCadence> onCadenceChanged;
  final ValueChanged<CollabDirection> onDirectionChanged;
  final VoidCallback onComingSoonTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'İlan Türü ve Yönü',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'İlanının süresini ve ne aradığını seçerek başla.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 22),
          const CollabSectionTitle('İlan Türü'),
          const SizedBox(height: 9),
          _CreateChoiceCard(
            title: 'Ekstra',
            description: 'Tek seferlik veya kısa süreli işler için.',
            icon: Icons.work_outline_rounded,
            selected: draft.cadence == CollabCadence.extra,
            onTap: () => onCadenceChanged(CollabCadence.extra),
          ),
          const SizedBox(height: 9),
          _CreateChoiceCard(
            title: 'Düzenli',
            description: 'Sürekli veya tekrarlayan işler için.',
            icon: Icons.event_repeat_rounded,
            selected: draft.cadence == CollabCadence.regular,
            onTap: () => onCadenceChanged(CollabCadence.regular),
          ),
          const SizedBox(height: 20),
          const CollabSectionTitle('İlan Yönü'),
          const SizedBox(height: 9),
          _CreateChoiceCard(
            title: 'Arıyorum',
            description: 'Müzisyen, ekip, mekan veya stüdyo ihtiyacın için.',
            icon: Icons.search_rounded,
            selected: draft.direction == CollabDirection.seeking,
            onTap: () => onDirectionChanged(CollabDirection.seeking),
          ),
          const SizedBox(height: 9),
          _CreateChoiceCard(
            title: 'Müsaitim / İş Arıyorum',
            description: 'Yeteneğini, mekanını veya stüdyonu duyur.',
            icon: Icons.person_outline_rounded,
            selected: draft.direction == CollabDirection.available,
            onTap: () => onDirectionChanged(CollabDirection.available),
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
  final VoidCallback onTap;

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
                gradient: LinearGradient(colors: AppColors.brandGradient),
              ),
            )
          : null,
    );
  }
}

class _ListingInformationStep extends StatelessWidget {
  const _ListingInformationStep({
    required this.draft,
    required this.titleController,
    required this.descriptionController,
    required this.feeController,
    required this.dateError,
    required this.timeError,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    required this.onLocationChanged,
    required this.onRoleChanged,
    required this.onGenreToggle,
    required this.onDateTap,
    required this.onTimeTap,
    required this.onFeeModeChanged,
    required this.onFeeChanged,
    required this.onCapacityChanged,
    required this.onPublisherTap,
    super.key,
  });

  final CollabListingDraft draft;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController feeController;
  final bool dateError;
  final bool timeError;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String> onGenreToggle;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;
  final ValueChanged<CollabFeeMode> onFeeModeChanged;
  final ValueChanged<String> onFeeChanged;
  final ValueChanged<int> onCapacityChanged;
  final VoidCallback onPublisherTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('collab-create-title'),
            controller: titleController,
            maxLength: 100,
            textInputAction: TextInputAction.next,
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
            initialValue: draft.location,
            decoration: const InputDecoration(
              labelText: 'Şehir / Konum',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: collabCreationLocations.keys
                .map(
                  (location) =>
                      DropdownMenuItem(value: location, child: Text(location)),
                )
                .toList(growable: false),
            onChanged: onLocationChanged,
            validator: (value) => value == null ? 'Konum seç.' : null,
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            key: const ValueKey('collab-create-role'),
            isExpanded: true,
            initialValue: draft.role,
            decoration: InputDecoration(
              labelText: draft.direction == CollabDirection.seeking
                  ? 'Aranan kişi, ekip veya yer'
                  : 'Sunduğun rol veya imkan',
              prefixIcon: const Icon(Icons.music_note_outlined),
            ),
            items: collabCreationRoles
                .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                .toList(growable: false),
            onChanged: onRoleChanged,
            validator: (value) =>
                value == null ? 'Rol veya ihtiyaç seç.' : null,
          ),
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
            children: collabCreationGenres
                .map(
                  (genre) => CollabChoiceChip(
                    label: genre,
                    selected: draft.genres.contains(genre),
                    onTap: () => onGenreToggle(genre),
                  ),
                )
                .toList(growable: false),
          ),
          if (draft.cadence == CollabCadence.extra &&
              draft.direction == CollabDirection.seeking) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'Sahne Tarihi',
                    value: draft.occurrenceDate == null
                        ? 'Tarih seç'
                        : _longDate(draft.occurrenceDate!),
                    icon: Icons.calendar_month_outlined,
                    error: dateError ? 'Tarih seç.' : null,
                    onTap: onDateTap,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _PickerField(
                    label: 'Saat',
                    value: draft.occurrenceTime?.label ?? 'Saat seç',
                    icon: Icons.schedule_rounded,
                    error: timeError ? 'Saat seç.' : null,
                    onTap: onTimeTap,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          const CollabSectionTitle('Ücret'),
          const SizedBox(height: 9),
          _FeeModeSelector(
            selected: draft.feeMode,
            onSelected: onFeeModeChanged,
          ),
          if (draft.feeMode == CollabFeeMode.paid) ...[
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey('collab-create-fee'),
              controller: feeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Ücret',
                prefixText: '₺ ',
              ),
              onChanged: onFeeChanged,
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Sıfırdan büyük tek bir ücret gir.';
                }
                return null;
              },
            ),
          ],
          if (draft.direction == CollabDirection.seeking) ...[
            const SizedBox(height: 20),
            const CollabSectionTitle('Kontenjan'),
            const SizedBox(height: 9),
            _CapacityStepper(
              value: draft.capacity ?? 1,
              onChanged: onCapacityChanged,
            ),
          ],
          const SizedBox(height: 20),
          const CollabSectionTitle('İlan Veren Profil'),
          const SizedBox(height: 9),
          _PublisherCard(profile: draft.publisher!, onTap: onPublisherTap),
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
  final VoidCallback onTap;

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

  final CollabFeeMode selected;
  final ValueChanged<CollabFeeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return CollabGradientFrame(
      radius: 15,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            _FeeModeOption(
              label: 'Ücretli',
              selected: selected == CollabFeeMode.paid,
              onTap: () => onSelected(CollabFeeMode.paid),
            ),
            _FeeModeOption(
              label: 'Ücret belirtilmemiş',
              selected: selected == CollabFeeMode.unspecified,
              onTap: () => onSelected(CollabFeeMode.unspecified),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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

class _CapacityStepper extends StatelessWidget {
  const _CapacityStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return CollabGradientFrame(
      highlighted: true,
      radius: 15,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            tooltip: 'Kontenjanı azalt',
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: value < 10 ? () => onChanged(value + 1) : null,
            tooltip: 'Kontenjanı artır',
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _PublisherCard extends StatelessWidget {
  const _PublisherCard({required this.profile, required this.onTap});

  final CollabPublisherProfile profile;
  final VoidCallback onTap;

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
              profileKind: profile.profileKind,
              avatarAsset: profile.avatarAsset,
              size: 52,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
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
                    profile.subtitle,
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
  const _PublisherPicker({required this.selected});

  final CollabPublisherProfile? selected;

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
            'Yalnızca Müzisyen, Mekan ve Stüdyo profilleri ilan verebilir.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          ...collabPublisherMockProfiles.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: CollabGradientFrame(
                highlighted: profile.id == selected?.id,
                radius: 16,
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: () => Navigator.of(context).pop(profile),
                    leading: CollabIdentityAvatar(
                      initials: profile.initials,
                      profileKind: profile.profileKind,
                      avatarAsset: profile.avatarAsset,
                      size: 43,
                    ),
                    title: Text(profile.name),
                    subtitle: Text(profile.subtitle),
                    trailing: _CreateRadio(
                      selected: profile.id == selected?.id,
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

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.draft,
    required this.submitting,
    required this.onPublish,
    required this.onSaveDraft,
    super.key,
  });

  final CollabListingDraft draft;
  final bool submitting;
  final VoidCallback onPublish;
  final VoidCallback onSaveDraft;

  @override
  Widget build(BuildContext context) {
    final listing = draft.toListing('preview');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Önizleme',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'İlanının nasıl görüneceğini son kez kontrol et.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          CollabListingCard(
            listing: listing,
            saved: false,
            onTap: () {},
            onSave: () {},
            interactive: false,
            showSave: false,
          ),
          const SizedBox(height: 13),
          CollabGradientFrame(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            child: Column(
              children: [
                _PreviewRow(
                  icon: Icons.person_outline_rounded,
                  label: 'İlan Veren',
                  value: draft.publisher!.name,
                ),
                _PreviewRow(
                  icon: Icons.library_music_outlined,
                  label: 'Tarz',
                  value: draft.genres.isEmpty
                      ? 'Belirtilmemiş'
                      : draft.genres.join(', '),
                ),
                _PreviewRow(
                  icon: Icons.notes_rounded,
                  label: 'Açıklama',
                  value: draft.description,
                  multiLine: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _ComingSoonCard(
            title: 'Öne Çıkar',
            description: 'İlanını daha fazla Backstage profiline ulaştır.',
            icon: Icons.rocket_launch_outlined,
          ),
          const SizedBox(height: 14),
          CollabPrimaryAction(
            key: const ValueKey('collab-create-publish'),
            label: 'Yayınla',
            icon: Icons.send_outlined,
            busy: submitting,
            onPressed: submitting ? null : onPublish,
          ),
          const SizedBox(height: 9),
          CollabOutlineAction(
            key: const ValueKey('collab-create-save-draft'),
            label: 'Taslak Kaydet',
            icon: Icons.description_outlined,
            onPressed: submitting ? null : onSaveDraft,
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool multiLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: multiLine
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: multiLine ? 4 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.socialPurple.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: AppColors.socialPurple.withValues(alpha: 0.48),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.socialPurple, size: 29),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CollabStatusPill(label: 'Yakında', color: AppColors.socialPurple),
          ],
        ),
      ),
    );
  }
}

String _longDate(DateTime date) {
  const months = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
