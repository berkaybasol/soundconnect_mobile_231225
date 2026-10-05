import 'dart:async';

import 'package:flutter/material.dart';

import '../collab_access_gate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/utils/turkish_alphabetical.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
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
import '../cubit/collab_conflict_support.dart';
import '../cubit/collab_listing_editor_cubit.dart';
import '../cubit/collab_listing_editor_state.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../widgets/collab_specialty_picker.dart';

part 'collab_create_listing_screen_create_step_indicator.dart';
part 'collab_create_listing_screen_preview_step.dart';

enum CollabCreateListingResult { published, draftSaved }

enum _CollabFeeMode { unspecified, paid }

final RegExp _feeInputPattern = RegExp(r'^\d{0,7}([,.]\d{0,2})?$');

int? _parseFeeAmountMinor(String rawValue) {
  final normalized = rawValue.trim().replaceAll(',', '.');
  if (normalized.isEmpty ||
      !RegExp(r'^\d+([.]\d{0,2})?$').hasMatch(normalized)) {
    return null;
  }
  final segments = normalized.split('.');
  final major = int.tryParse(segments.first);
  if (major == null) return null;
  final fraction = segments.length == 1 ? '' : segments.last;
  final minor = fraction.isEmpty ? 0 : int.tryParse(fraction.padRight(2, '0'));
  if (minor == null) return null;
  return major * 100 + minor;
}

String _formatFeeAmountMinor(int amountMinor) {
  final major = amountMinor ~/ 100;
  final minor = (amountMinor % 100).abs();
  if (minor == 0) return major.toString();
  return '$major,${minor.toString().padLeft(2, '0')}';
}

class CollabCreateListingScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return CollabAccessGate(
      builder: (_) => _CollabCreateListingScreenContent(
        initialListing: initialListing,
        showBottomNavigation: showBottomNavigation,
        cubit: cubit,
        locationRepository: locationRepository,
        instrumentRepository: instrumentRepository,
      ),
    );
  }
}

class _CollabCreateListingScreenContent extends StatefulWidget {
  const _CollabCreateListingScreenContent({
    this.initialListing,
    this.showBottomNavigation = true,
    this.cubit,
    this.locationRepository,
    this.instrumentRepository,
  });

  final CollabListing? initialListing;
  final bool showBottomNavigation;
  final CollabListingEditorCubit? cubit;
  final LocationRepository? locationRepository;
  final InstrumentRepository? instrumentRepository;

  @override
  State<_CollabCreateListingScreenContent> createState() =>
      _CollabCreateListingScreenState();
}

class _CollabCreateListingScreenState
    extends State<_CollabCreateListingScreenContent> {
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
  String? _cityCatalogError;
  String? _instrumentCatalogError;
  int _step = 0;
  bool _dateError = false;
  bool _timeError = false;
  bool _discardConfirmed = false;
  bool _conflictDialogOpen = false;
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
        _cityCatalogError = null;
        _instrumentCatalogError = null;
      });
    }
    final cityFuture = _locationRepository.getCities();
    final instrumentFuture = _instrumentRepository.getAll();
    final cityResult = await cityFuture;
    final instrumentResult = await instrumentFuture;
    if (!mounted) return;
    setState(() {
      _catalogsLoading = false;
      if (cityResult.isSuccess) {
        _cities = List<City>.unmodifiable(
          sortByTurkishName(cityResult.data!, (city) => city.name),
        );
      } else {
        _cityCatalogError =
            cityResult.error?.message ?? 'Şehir seçenekleri yüklenemedi.';
      }
      if (instrumentResult.isSuccess) {
        _instruments = List<Instrument>.unmodifiable(
          <Instrument>[...instrumentResult.data!]
            ..sort((a, b) => a.name.compareTo(b.name)),
        );
      } else {
        _instrumentCatalogError =
            instrumentResult.error?.message ??
            'Enstrüman seçenekleri yüklenemedi.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return BlocProvider<CollabListingEditorCubit>.value(
      value: _cubit,
      child: BlocConsumer<CollabListingEditorCubit, CollabListingEditorState>(
        listenWhen: (previous, current) =>
            previous.error != current.error ||
            (previous.validationErrors != current.validationErrors &&
                current.validationErrors.isNotEmpty),
        listener: (context, state) {
          if (isCollabStaleUpdate(state.error) && state.input != null) {
            _syncFieldsFromInput(state.input!);
            _syncFeeUiFromCubit();
          }
          if (isCollabStaleUpdate(state.error) &&
              state.hasUnresolvedConflict &&
              state.conflictListing != null) {
            unawaited(_showConflictChoice());
          } else if (state.error != null) {
            _showMessage(state.error!.message, tone: AppSnackBarTone.error);
          } else if (state.validationErrors.isNotEmpty) {
            _showMessage(state.validationErrors.first);
          }
        },
        builder: (context, state) => PopScope<CollabCreateListingResult>(
          canPop:
              _discardConfirmed ||
              (_step == 0 && !state.isSubmitting && !state.isDirty),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_handleBlockedPop());
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                widget.initialListing == null
                    ? 'İlan Oluştur'
                    : 'İlanı Düzenle',
              ),
              leading: BackButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => unawaited(_handleBack()),
              ),
            ),
            body: SafeArea(top: false, bottom: false, child: _buildBody(state)),
            bottomNavigationBar: widget.showBottomNavigation
                ? ProfilePublicBottomBar(
                    currentIndex: 1,
                    onBeforeNavigate: _confirmDiscardIfNeeded,
                  )
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
    final editingOpenListing = state.listing?.isOpen == true;
    final fieldsLocked =
        state.hasUnresolvedConflict ||
        (editingOpenListing && (state.listing?.applicationCount ?? 0) > 0);
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
        if (state.validationErrors.isNotEmpty)
          _ValidationSummary(errors: state.validationErrors),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_step) {
              0 => _ListingTypeStep(
                key: const ValueKey('create-step-type'),
                cadence: input.cadence,
                editable: !fieldsLocked,
                onCadenceChanged: _changeCadence,
                onComingSoonTap: () => _showMessage(
                  'Param Güvende yakında kullanıma açılacak.',
                  tone: AppSnackBarTone.info,
                ),
              ),
              1 => _buildInformationStep(state, input),
              _ => _PreviewStep(
                key: const ValueKey('create-step-preview'),
                listing: _previewListing(state),
                description: input.description,
                genres: input.genres,
                publisherName: state.selectedActor!.displayName,
                submitting: state.isSubmitting || state.hasUnresolvedConflict,
                editingOpenListing: editingOpenListing,
                fieldsLocked: fieldsLocked,
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
              onPressed: state.isSubmitting || state.hasUnresolvedConflict
                  ? null
                  : _continue,
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
    if (_cityCatalogError != null) {
      return _EditorInitializationState(
        message: _cityCatalogError!,
        onRetry: () => unawaited(_loadCatalogs()),
      );
    }
    return Form(
      key: _formKey,
      child: _ListingInformationStep(
        key: const ValueKey('create-step-information'),
        input: input,
        fieldsLocked:
            state.hasUnresolvedConflict ||
            (state.listing?.isOpen == true &&
                (state.listing?.applicationCount ?? 0) > 0),
        instrumentCatalogError: _instrumentCatalogError,
        onCatalogRetry: () => unawaited(_loadCatalogs()),
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
        canSelectPublisher: _publisherChoices(state).length > 1,
        onPublisherTap: _pickPublisher,
      ),
    );
  }

  Future<void> _handleBlockedPop() async {
    if (_cubit.state.isSubmitting) return;
    if (_step > 0) {
      setState(() => _step--);
      return;
    }
    if (await _confirmDiscardIfNeeded() && mounted) {
      setState(() => _discardConfirmed = true);
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleBack() => _handleBlockedPop();

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_cubit.state.isDirty) return true;
    final discard = await showCollabDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Değişiklikler silinsin mi?'),
        content: const Text(
          'Kaydetmeden çıkarsan bu ilanda yaptığın değişiklikler kaybolacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Düzenlemeye Devam Et'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Değişiklikleri Sil'),
          ),
        ],
      ),
    );
    if (discard != true) return false;
    return _cubit.abandonPendingCreate();
  }

  Future<void> _showConflictChoice() async {
    if (_conflictDialogOpen || !mounted) return;
    _conflictDialogOpen = true;
    try {
      final loadLatest = await showCollabDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope<void>(
          canPop: false,
          child: AlertDialog(
            title: const Text('İlan başka bir cihazda değişti'),
            content: const Text(
              'Bu cihazdaki form değişikliklerin korunuyor. Sunucudaki güncel '
              'sürüm de alındı. Formda kalırsan alanlar salt okunur kalır ve '
              'içeriği kopyalayabilirsin. Güncel hali yüklersen bu formdaki '
              'değişiklikler silinir.',
            ),
            actions: [
              TextButton(
                key: const ValueKey('collab-conflict-keep-local'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Formda Kal'),
              ),
              FilledButton(
                key: const ValueKey('collab-conflict-load-server'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Sunucudaki Güncel Hali Yükle'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (loadLatest == true) {
        _cubit.loadLatestConflictVersion();
        final input = _cubit.state.input;
        if (input != null) {
          _syncFieldsFromInput(input);
          _syncFeeUiFromCubit();
          setState(() {});
        }
      } else {
        _cubit.keepLocalConflictForm();
      }
    } finally {
      _conflictDialogOpen = false;
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
    final errors = normalized.validate(
      publisherType: actor.profileType,
      latestScheduledAt: _latestScheduleForEditor,
    );
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
    final amountMinor = _parseFeeAmountMinor(value);
    _updateInput(
      amountMinor == null
          ? input.copyWith(clearFeeAmount: true, clearCurrency: true)
          : input.copyWith(feeAmountMinor: amountMinor, currency: 'TRY'),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _occurrenceDate ?? today;
    final latest =
        _latestScheduleForEditor?.toLocal() ?? now.add(const Duration(days: 7));
    final lastDate = DateTime(latest.year, latest.month, latest.day);
    if (lastDate.isBefore(today)) {
      _showMessage('Bu ekstra ilanın düzenleme süresi doldu.');
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today)
          ? today
          : initial.isAfter(lastDate)
          ? lastDate
          : initial,
      firstDate: today,
      lastDate: lastDate,
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
    final choices = _publisherChoices(state);
    if (choices.length < 2) return;
    final profile = await showCollabModalBottomSheet<CollabActor>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _PublisherPicker(actors: choices, selected: state.selectedActor),
    );
    if (!mounted || profile == null) return;
    final input = _cubit.state.input;
    if (input == null) return;
    _updateInput(input.copyWith(publisherActorId: profile.actorId));
    _syncFeeUiFromCubit();
  }

  List<CollabActor> _publisherChoices(CollabListingEditorState state) {
    final selectedType = state.selectedActor?.profileType;
    if (selectedType != CollabProfileKind.musician &&
        selectedType != CollabProfileKind.band) {
      return const <CollabActor>[];
    }
    return state.actors
        .where(
          (actor) =>
              actor.profileType == CollabProfileKind.musician ||
              actor.profileType == CollabProfileKind.band,
        )
        .toList(growable: false);
  }

  Future<void> _publishOrUpdate() async {
    if (_cubit.state.isSubmitting || _cubit.state.hasUnresolvedConflict) {
      return;
    }
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
    if (_cubit.state.isSubmitting || _cubit.state.hasUnresolvedConflict) {
      return;
    }
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
    if (_cubit.state.hasUnresolvedConflict) return;
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
        : _formatFeeAmountMinor(input.feeAmountMinor!);
  }

  void _syncFeeUiFromCubit() {
    final input = _cubit.state.input;
    if (input?.feeAmountMinor == null) {
      _feeController.clear();
      if (mounted) setState(() => _feeMode = _CollabFeeMode.unspecified);
    }
  }

  DateTime? get _latestScheduleForEditor {
    final listing = _cubit.state.listing;
    final publishedAt = listing?.publishedAt;
    if (listing?.isOpen != true || publishedAt == null) return null;
    return publishedAt.add(const Duration(days: 7));
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

  void _showMessage(
    String message, {
    AppSnackBarTone tone = AppSnackBarTone.warning,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(context, tone: tone, content: Text(message)));
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
  'Türkü',
  'Türk Sanat Müziği',
  'Piyasa',
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

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('collab-validation-summary'),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lütfen şu alanları düzelt:',
              style: TextStyle(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            ...errors.map(
              (error) => Text(
                '• $error',
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorNotice extends StatelessWidget {
  const _EditorNotice({
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
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
