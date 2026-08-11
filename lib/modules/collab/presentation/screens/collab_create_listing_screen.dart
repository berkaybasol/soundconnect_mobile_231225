import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../instrument/domain/entities/instrument.dart';
import '../../../instrument/domain/instrument_repository.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/location_repository.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_discovery_models.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_actor.dart';
import '../../domain/entities/collab_listing.dart';
import '../cubit/collab_async_state.dart';
import '../cubit/collab_listing_editor_cubit.dart';
import '../cubit/collab_listing_editor_state.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_specialty_picker.dart';

enum CollabCreateListingResult { published, draftSaved }

enum _CollabFeeMode { unspecified, paid }

class CollabCreateListingScreen extends StatefulWidget {
  const CollabCreateListingScreen({
    this.initialListing,
    this.showBottomNavigation = true,
    this.cubit,
    this.locationRepository,
    this.instrumentRepository,
    super.key,
  });

  final CollabListing? initialListing;
  final bool showBottomNavigation;
  final CollabListingEditorCubit? cubit;
  final LocationRepository? locationRepository;
  final InstrumentRepository? instrumentRepository;

  @override
  State<CollabCreateListingScreen> createState() =>
      _CollabCreateListingScreenState();
}

class _CollabCreateListingScreenState extends State<CollabCreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _feeController;
  late final TextEditingController _customSpecialtyController;
  late final CollabListingEditorCubit _cubit;
  late final bool _ownsCubit;
  late final LocationRepository _locationRepository;
  late final InstrumentRepository _instrumentRepository;
  List<City> _cities = const <City>[];
  List<Instrument> _instruments = const <Instrument>[];
  bool _catalogsLoading = true;
  String? _catalogError;
  int _step = 0;
  bool _dateError = false;
  bool _timeError = false;
  DateTime? _occurrenceDate;
  TimeOfDay? _occurrenceTime;
  _CollabFeeMode _feeMode = _CollabFeeMode.unspecified;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _feeController = TextEditingController();
    _customSpecialtyController = TextEditingController();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? serviceLocator<CollabListingEditorCubit>();
    _locationRepository =
        widget.locationRepository ?? serviceLocator<LocationRepository>();
    _instrumentRepository =
        widget.instrumentRepository ?? serviceLocator<InstrumentRepository>();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _customSpecialtyController.dispose();
    _feeController.dispose();
    _descriptionController.dispose();
    _titleController.dispose();
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _initialize() async {
    final editorFuture = _cubit.initialize(listing: widget.initialListing);
    final catalogsFuture = _loadCatalogs();
    await Future.wait<void>([editorFuture, catalogsFuture]);
    if (!mounted || _cubit.state.actorStatus != CollabLoadStatus.success) {
      return;
    }

    final input = _cubit.state.input;
    if (input == null) return;
    _syncFieldsFromInput(input);
    if (mounted) setState(() {});
  }

  Future<void> _loadCatalogs() async {
    if (mounted) {
      setState(() {
        _catalogsLoading = true;
        _catalogError = null;
      });
    }
    final cityFuture = _locationRepository.getCities();
    final instrumentFuture = _instrumentRepository.getAll();
    final cityResult = await cityFuture;
    final instrumentResult = await instrumentFuture;
    if (!mounted) return;
    setState(() {
      _catalogsLoading = false;
      if (cityResult.isSuccess && instrumentResult.isSuccess) {
        _cities = List<City>.unmodifiable(
          <City>[...cityResult.data!]..sort((a, b) => a.name.compareTo(b.name)),
        );
        _instruments = List<Instrument>.unmodifiable(
          <Instrument>[...instrumentResult.data!]
            ..sort((a, b) => a.name.compareTo(b.name)),
        );
      } else {
        _catalogError =
            cityResult.error?.message ??
            instrumentResult.error?.message ??
            'Şehir ve enstrüman seçenekleri yüklenemedi.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollabListingEditorCubit>.value(
      value: _cubit,
      child: BlocConsumer<CollabListingEditorCubit, CollabListingEditorState>(
        listenWhen: (previous, current) => previous.error != current.error,
        listener: (context, state) {
          if (state.error != null) _showMessage(state.error!.message);
        },
        builder: (context, state) => PopScope<CollabCreateListingResult>(
          canPop: _step == 0 && !state.isSubmitting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _step > 0 && !state.isSubmitting) {
              setState(() => _step--);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                widget.initialListing == null
                    ? 'İlan Oluştur'
                    : 'İlanı Düzenle',
              ),
              leading: BackButton(
                onPressed: state.isSubmitting ? null : _handleBack,
              ),
            ),
            body: SafeArea(top: false, bottom: false, child: _buildBody(state)),
            bottomNavigationBar: widget.showBottomNavigation
                ? ProfilePublicBottomBar(currentIndex: 1)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CollabListingEditorState state) {
    if (state.actorStatus == CollabLoadStatus.loading ||
        state.actorStatus == CollabLoadStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.actorStatus == CollabLoadStatus.failure) {
      return _EditorInitializationState(
        message: state.error?.message ?? 'Collab profillerin yüklenemedi.',
        onRetry: () => unawaited(_initialize()),
      );
    }
    if (state.actors.isEmpty || state.input == null) {
      return const _EditorInitializationState(
        message:
            'İlan vermek için Müzisyen, Grup, Mekan veya Stüdyo profiline ihtiyacın var.',
      );
    }

    final input = state.input!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: _CreateStepIndicator(
            currentStep: _step,
            onStepTap: (step) {
              if (step < _step && !state.isSubmitting) {
                setState(() => _step = step);
              }
            },
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_step) {
              0 => _ListingTypeStep(
                key: const ValueKey('create-step-type'),
                cadence: input.cadence,
                editable: state.listing?.isOpen != true,
                onCadenceChanged: _changeCadence,
                onComingSoonTap: () =>
                    _showMessage('Param Güvende yakında kullanıma açılacak.'),
              ),
              1 => _buildInformationStep(state, input),
              _ => _PreviewStep(
                key: const ValueKey('create-step-preview'),
                listing: _previewListing(state),
                description: input.description,
                genres: input.genres,
                publisherName: state.selectedActor!.displayName,
                submitting: state.isSubmitting,
                editingOpenListing: state.listing?.isOpen == true,
                onPublish: _publishOrUpdate,
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
              onPressed: state.isSubmitting ? null : _continue,
            ),
          ),
      ],
    );
  }

  Widget _buildInformationStep(
    CollabListingEditorState state,
    CollabListingInput input,
  ) {
    if (_catalogsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_catalogError != null) {
      return _EditorInitializationState(
        message: _catalogError!,
        onRetry: () => unawaited(_loadCatalogs()),
      );
    }
    return Form(
      key: _formKey,
      child: _ListingInformationStep(
        key: const ValueKey('create-step-information'),
        input: input,
        editingOpenListing: state.listing?.isOpen == true,
        selectedActor: state.selectedActor!,
        cities: _cities,
        instruments: _instruments,
        titleController: _titleController,
        descriptionController: _descriptionController,
        customSpecialtyController: _customSpecialtyController,
        feeController: _feeController,
        feeMode: _feeMode,
        occurrenceDate: _occurrenceDate,
        occurrenceTime: _occurrenceTime,
        dateError: _dateError,
        timeError: _timeError,
        onTitleChanged: (value) => _updateInput(input.copyWith(title: value)),
        onDescriptionChanged: (value) =>
            _updateInput(input.copyWith(description: value)),
        onCityChanged: (value) {
          if (value != null) _updateInput(input.copyWith(cityId: value));
        },
        onWantedTypeChanged: (value) {
          if (value != null) _changeWantedType(value);
        },
        onSpecialtyChanged: _changeSpecialty,
        onCustomSpecialtyChanged: (value) =>
            _updateInput(input.copyWith(customSpecialty: value)),
        onGenreToggle: _toggleGenre,
        onDateTap: _pickDate,
        onTimeTap: _pickTime,
        onFeeModeChanged: _changeFeeMode,
        onFeeChanged: _changeFee,
        onPublisherTap: _pickPublisher,
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
    final state = _cubit.state;
    final input = state.input;
    final actor = state.selectedActor;
    if (input == null || actor == null) return;
    _updateInput(
      input.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
      ),
    );
    final normalized = _cubit.state.input!;
    final formValid = _formKey.currentState?.validate() ?? false;
    final needsDate = normalized.cadence == CollabCadence.extra;
    setState(() {
      _dateError = needsDate && _occurrenceDate == null;
      _timeError = needsDate && _occurrenceTime == null;
    });
    final errors = normalized.validate(publisherType: actor.profileType);
    if (!formValid || _dateError || _timeError || errors.isNotEmpty) {
      _showMessage('Devam etmek için zorunlu alanları kontrol et.');
      return;
    }
    setState(() => _step = 2);
  }

  void _changeCadence(CollabCadence cadence) {
    final input = _cubit.state.input;
    if (input == null) return;
    var next = input.copyWith(cadence: cadence);
    if (cadence == CollabCadence.regular) {
      next = next.copyWith(clearScheduledAt: true);
      _occurrenceDate = null;
      _occurrenceTime = null;
    }
    _updateInput(next);
    _syncFeeUiFromCubit();
  }

  void _changeWantedType(CollabProfileKind wantedType) {
    final input = _cubit.state.input;
    if (input == null) return;
    _customSpecialtyController.clear();
    _updateInput(
      input.copyWith(
        wantedType: wantedType,
        clearInstrumentId: true,
        clearBranch: true,
        clearCustomSpecialty: true,
      ),
    );
  }

  void _changeSpecialty(_CreateSpecialtyOption? specialty) {
    final input = _cubit.state.input;
    if (input == null || specialty == null) return;
    _customSpecialtyController.clear();
    if (specialty.instrumentId != null) {
      _updateInput(
        input.copyWith(
          instrumentId: specialty.instrumentId,
          clearBranch: true,
          clearCustomSpecialty: true,
        ),
      );
    } else {
      _updateInput(
        input.copyWith(
          clearInstrumentId: true,
          branch: specialty.branch,
          clearCustomSpecialty: true,
        ),
      );
    }
  }

  void _toggleGenre(String genre) {
    final input = _cubit.state.input;
    if (input == null) return;
    final genres = <String>{...input.genres};
    if (!genres.remove(genre)) {
      if (genres.length >= 3) {
        _showMessage('En fazla 3 tarz seçebilirsin.');
        return;
      }
      genres.add(genre);
    }
    _updateInput(input.copyWith(genres: genres.toList(growable: false)));
  }

  void _changeFeeMode(_CollabFeeMode mode) {
    if (mode == _CollabFeeMode.unspecified) {
      _feeController.clear();
      final input = _cubit.state.input;
      if (input != null) {
        _updateInput(input.copyWith(clearFeeAmount: true, clearCurrency: true));
      }
    }
    setState(() => _feeMode = mode);
  }

  void _changeFee(String value) {
    final input = _cubit.state.input;
    if (input == null) return;
    final amount = int.tryParse(value.replaceAll(RegExp(r'\D'), ''));
    _updateInput(
      amount == null
          ? input.copyWith(clearFeeAmount: true, clearCurrency: true)
          : input.copyWith(feeAmountMinor: amount * 100, currency: 'TRY'),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _occurrenceDate ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 7)),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _occurrenceDate = picked;
      _dateError = false;
    });
    _updateSchedule();
  }

  Future<void> _pickTime() async {
    final current = _occurrenceTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current?.hour ?? 21,
        minute: current?.minute ?? 0,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _occurrenceTime = picked;
      _timeError = false;
    });
    _updateSchedule();
  }

  Future<void> _pickPublisher() async {
    final state = _cubit.state;
    final profile = await showModalBottomSheet<CollabActor>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _PublisherPicker(actors: state.actors, selected: state.selectedActor),
    );
    if (!mounted || profile == null) return;
    final input = _cubit.state.input;
    if (input == null) return;
    _updateInput(input.copyWith(publisherActorId: profile.actorId));
    _syncFeeUiFromCubit();
  }

  Future<void> _publishOrUpdate() async {
    if (_cubit.state.isSubmitting) return;
    if (_cubit.state.listing?.isOpen == true) {
      await _cubit.updateOpenListing();
    } else {
      await _cubit.publish();
    }
    if (!mounted) return;
    final state = _cubit.state;
    if (state.error == null &&
        state.validationErrors.isEmpty &&
        !state.isDirty &&
        state.listing?.isOpen == true) {
      Navigator.of(context).pop(CollabCreateListingResult.published);
    }
  }

  Future<void> _saveDraft() async {
    if (_cubit.state.isSubmitting) return;
    await _cubit.saveDraft();
    if (!mounted) return;
    final state = _cubit.state;
    if (state.error == null &&
        state.validationErrors.isEmpty &&
        !state.isDirty &&
        state.listing?.isDraft == true) {
      Navigator.of(context).pop(CollabCreateListingResult.draftSaved);
    }
  }

  void _updateInput(CollabListingInput input) {
    _cubit.updateInput(input);
  }

  void _updateSchedule() {
    final input = _cubit.state.input;
    if (input == null) return;
    final date = _occurrenceDate;
    final time = _occurrenceTime;
    if (date == null || time == null) {
      _updateInput(input.copyWith(clearScheduledAt: true));
      return;
    }
    _updateInput(
      input.copyWith(
        scheduledAt: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      ),
    );
  }

  void _syncFieldsFromInput(CollabListingInput input) {
    _titleController.text = input.title;
    _descriptionController.text = input.description;
    _customSpecialtyController.text = input.customSpecialty ?? '';
    final scheduled = input.scheduledAt?.toLocal();
    _occurrenceDate = scheduled == null
        ? null
        : DateTime(scheduled.year, scheduled.month, scheduled.day);
    _occurrenceTime = scheduled == null
        ? null
        : TimeOfDay(hour: scheduled.hour, minute: scheduled.minute);
    _feeMode = input.feeAmountMinor == null
        ? _CollabFeeMode.unspecified
        : _CollabFeeMode.paid;
    _feeController.text = input.feeAmountMinor == null
        ? ''
        : (input.feeAmountMinor! ~/ 100).toString();
  }

  void _syncFeeUiFromCubit() {
    final input = _cubit.state.input;
    if (input?.feeAmountMinor == null) {
      _feeController.clear();
      if (mounted) setState(() => _feeMode = _CollabFeeMode.unspecified);
    }
  }

  CollabDiscoveryListing _previewListing(CollabListingEditorState state) {
    final input = state.input!;
    final actor = state.selectedActor!;
    final cityName =
        _cities.where((value) => value.id == input.cityId).firstOrNull?.name ??
        state.listing?.city.name ??
        'Sehir';
    final instrument = input.instrumentId == null
        ? null
        : _instruments
              .where((value) => value.id == input.instrumentId)
              .firstOrNull;
    final specialty =
        instrument?.name ??
        (input.branch == CollabBranch.other
            ? input.customSpecialty
            : input.branch?.label) ??
        '';
    return CollabDiscoveryListing(
      id: state.listing?.id ?? 'preview',
      ownerName: actor.displayName,
      ownerInitials: actor.initials,
      profileKind: actor.profileType,
      wantedKind: input.wantedType,
      avatarUrl: actor.avatarUrl,
      title: input.title.trim(),
      cadence: input.cadence,
      location: cityName,
      scheduledAt: input.scheduledAt,
      feeAmountMinor: input.feeAmountMinor,
      feeCurrency: input.currency,
      role: specialty,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

const _collabGenreOptions = <String>[
  'Rock',
  'Pop',
  'Alternatif',
  'Jazz',
  'Blues',
  'Funk',
  'Soul',
  'Akustik',
  'Elektronik',
  'Diğer',
];

class _CreateSpecialtyOption {
  const _CreateSpecialtyOption._({
    required this.label,
    this.instrumentId,
    this.branch,
  });

  factory _CreateSpecialtyOption.instrument(Instrument instrument) =>
      _CreateSpecialtyOption._(
        label: instrument.name,
        instrumentId: instrument.id,
      );

  factory _CreateSpecialtyOption.branch(CollabBranch branch) =>
      _CreateSpecialtyOption._(label: branch.label, branch: branch);

  final String label;
  final String? instrumentId;
  final CollabBranch? branch;

  @override
  bool operator ==(Object other) =>
      other is _CreateSpecialtyOption &&
      other.instrumentId == instrumentId &&
      other.branch == branch;

  @override
  int get hashCode => Object.hash(instrumentId, branch);
}

class _EditorInitializationState extends StatelessWidget {
  const _EditorInitializationState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              onRetry == null
                  ? Icons.person_off_outlined
                  : Icons.cloud_off_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              FilledButton.tonal(
                key: const ValueKey('collab-create-initialize-retry'),
                onPressed: onRetry,
                child: const Text('Tekrar dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
                gradient: LinearGradient(colors: AppColors.brandGradient),
              ),
            )
          : null,
    );
  }
}

class _ListingInformationStep extends StatelessWidget {
  const _ListingInformationStep({
    required this.input,
    required this.editingOpenListing,
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
    required this.onPublisherTap,
    super.key,
  });

  final CollabListingInput input;
  final bool editingOpenListing;
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
  ) => showModalBottomSheet<_CreateSpecialtyOption>(
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
            onChanged: editingOpenListing ? null : onCityChanged,
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
            onChanged: editingOpenListing ? null : onWantedTypeChanged,
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
                onTap: editingOpenListing
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
                    prefixIcon: const Icon(Icons.music_note_outlined),
                    suffixIcon: const Icon(Icons.search_rounded),
                    errorText: field.errorText,
                    enabled: !editingOpenListing,
                  ),
                  child: Text(field.value?.label ?? 'Seçmek için dokun'),
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
                onChanged: editingOpenListing ? null : onCustomSpecialtyChanged,
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
                    onTap: () => onGenreToggle(genre),
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
                    onTap: editingOpenListing ? null : onDateTap,
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
                    onTap: editingOpenListing ? null : onTimeTap,
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
            _FeeModeSelector(selected: feeMode, onSelected: onFeeModeChanged),
            if (feeMode == _CollabFeeMode.paid) ...[
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
                  if (amount == null ||
                      amount <= 0 ||
                      amount > collabMaxFeeAmountMinor ~/ 100) {
                    return '1-1.000.000 TRY arasında tek bir ücret gir.';
                  }
                  return null;
                },
              ),
            ],
          ],
          const SizedBox(height: 20),
          const CollabSectionTitle('İlan Veren Profil'),
          const SizedBox(height: 9),
          _PublisherCard(
            profile: selectedActor,
            onTap: editingOpenListing ? null : onPublisherTap,
          ),
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
  final ValueChanged<_CollabFeeMode> onSelected;

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
              selected: selected == _CollabFeeMode.paid,
              onTap: () => onSelected(_CollabFeeMode.paid),
            ),
            _FeeModeOption(
              label: 'Ücret belirtilmemiş',
              selected: selected == _CollabFeeMode.unspecified,
              onTap: () => onSelected(_CollabFeeMode.unspecified),
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

class _PublisherCard extends StatelessWidget {
  const _PublisherCard({required this.profile, required this.onTap});

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

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.listing,
    required this.publisherName,
    required this.genres,
    required this.description,
    required this.submitting,
    required this.editingOpenListing,
    required this.onPublish,
    required this.onSaveDraft,
    super.key,
  });

  final CollabDiscoveryListing listing;
  final String publisherName;
  final List<String> genres;
  final String description;
  final bool submitting;
  final bool editingOpenListing;
  final VoidCallback onPublish;
  final VoidCallback onSaveDraft;

  @override
  Widget build(BuildContext context) {
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
                  value: publisherName,
                ),
                _PreviewRow(
                  icon: Icons.library_music_outlined,
                  label: 'Tarz',
                  value: genres.isEmpty ? 'Belirtilmemiş' : genres.join(', '),
                ),
                _PreviewRow(
                  icon: Icons.notes_rounded,
                  label: 'Açıklama',
                  value: description,
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
            label: editingOpenListing ? 'Değişiklikleri Kaydet' : 'Yayınla',
            icon: editingOpenListing
                ? Icons.save_outlined
                : Icons.send_outlined,
            busy: submitting,
            onPressed: submitting ? null : onPublish,
          ),
          if (!editingOpenListing) ...[
            const SizedBox(height: 9),
            CollabOutlineAction(
              key: const ValueKey('collab-create-save-draft'),
              label: 'Taslak Kaydet',
              icon: Icons.description_outlined,
              onPressed: submitting ? null : onSaveDraft,
            ),
          ],
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

String _timeLabel(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
