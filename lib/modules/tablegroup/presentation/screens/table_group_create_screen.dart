import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/table_group_create_request.dart';
import '../../domain/entities/table_group_venue_option.dart';
import '../../domain/table_group_expiry_policy.dart';
import '../cubit/table_group_create_cubit.dart';
import '../cubit/table_group_create_state.dart';
import 'table_group_route_args.dart';

enum _SeatGender { me, female, male, other }

typedef _TableGroupCreateDraft = ({
  String? venueId,
  String? venueName,
  String description,
  int maxPersonCount,
  int femaleCount,
  int maleCount,
  int otherCount,
  int ageMin,
  int ageMax,
  int hour,
  int minute,
  String cityId,
  String? districtId,
  String? neighborhoodId,
});

class TableGroupCreateScreen extends StatefulWidget {
  final DateTime Function() now;

  TableGroupCreateScreen({super.key, DateTime Function()? now})
    : now = now ?? DateTime.now;

  @override
  State<TableGroupCreateScreen> createState() => _TableGroupCreateScreenState();
}

class _TableGroupCreateScreenState extends State<TableGroupCreateScreen>
    with WidgetsBindingObserver {
  late final TableGroupCreateCubit _cubit;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _venueFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _cityFocusNode = FocusNode();
  final FocusNode _districtFocusNode = FocusNode();
  final FocusNode _neighborhoodFocusNode = FocusNode();

  int _femaleCount = 0;
  int _maleCount = 0;
  int _otherCount = 0;
  RangeValues _ageRange = RangeValues(22, 35);
  TimeOfDay _selectedTime = TimeOfDay(hour: 23, minute: 0);
  String? _selectedCityId;
  String? _selectedDistrictId;
  String? _selectedNeighborhoodId;
  bool _settingVenueText = false;
  _TableGroupCreateDraft? _retryableCreateDraft;
  TableGroupCreateRequest? _retryableCreateRequest;
  late final TableGroupLocalDayRefreshScheduler _dayRefreshScheduler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = serviceLocator<TableGroupCreateCubit>();
    unawaited(_cubit.loadCities());
    _venueController.addListener(_onVenueChanged);
    _venueFocusNode.addListener(_onFocusChanged);
    _descriptionFocusNode.addListener(_onFocusChanged);
    _cityFocusNode.addListener(_onFocusChanged);
    _districtFocusNode.addListener(_onFocusChanged);
    _neighborhoodFocusNode.addListener(_onFocusChanged);
    _dayRefreshScheduler = TableGroupLocalDayRefreshScheduler(
      now: widget.now,
      onRefresh: () {
        if (mounted) setState(() {});
      },
    )..start();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onVenueChanged() {
    if (!context.mounted) return;
    if (_settingVenueText) return;
    if (!_cubit.state.hasSpecificVenue) return;
    if (_cubit.state.venueMode == TableGroupVenueMode.registered) {
      setState(() {
        _selectedCityId = null;
        _selectedDistrictId = null;
        _selectedNeighborhoodId = null;
      });
    }
    _cubit.venueTextChanged(_venueController.text);
  }

  void _selectRegisteredVenue(TableGroupVenueOption option) {
    if (_cubit.state.status == TableGroupCreateStatus.submitting) return;
    _cubit.selectRegisteredVenue(option);
    _settingVenueText = true;
    _venueController.value = TextEditingValue(
      text: option.name,
      selection: TextSelection.collapsed(offset: option.name.length),
    );
    _settingVenueText = false;
    setState(() {
      _selectedCityId = option.cityId;
      _selectedDistrictId = option.districtId;
      _selectedNeighborhoodId = option.neighborhoodId;
    });
  }

  void _useCustomVenue() {
    if (_cubit.state.status == TableGroupCreateStatus.submitting) return;
    _cubit.useCustomVenue(_venueController.text);
  }

  void _clearRegisteredVenue() {
    if (_cubit.state.status == TableGroupCreateStatus.submitting) return;

    _settingVenueText = true;
    _venueController.clear();
    _settingVenueText = false;
    setState(() {
      _selectedCityId = null;
      _selectedDistrictId = null;
      _selectedNeighborhoodId = null;
    });
    _cubit.detachRegisteredVenue('');
    _venueFocusNode.requestFocus();
  }

  void _setHasSpecificVenue(bool value) {
    if (_cubit.state.status == TableGroupCreateStatus.submitting ||
        value == _cubit.state.hasSpecificVenue) {
      return;
    }
    if (value) {
      _cubit.enableSpecificVenue();
      return;
    }

    final leavingRegisteredVenue =
        _cubit.state.venueMode == TableGroupVenueMode.registered;
    _venueFocusNode.unfocus();
    _settingVenueText = true;
    _venueController.clear();
    _settingVenueText = false;
    if (leavingRegisteredVenue) {
      setState(() {
        _selectedCityId = null;
        _selectedDistrictId = null;
        _selectedNeighborhoodId = null;
      });
    }
    _cubit.disableSpecificVenue();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayRefreshScheduler.dispose();
    _venueController.removeListener(_onVenueChanged);
    _venueController.dispose();
    _descriptionController.dispose();
    _venueFocusNode.removeListener(_onFocusChanged);
    _venueFocusNode.dispose();
    _descriptionFocusNode.removeListener(_onFocusChanged);
    _descriptionFocusNode.dispose();
    _cityFocusNode.removeListener(_onFocusChanged);
    _cityFocusNode.dispose();
    _districtFocusNode.removeListener(_onFocusChanged);
    _districtFocusNode.dispose();
    _neighborhoodFocusNode.removeListener(_onFocusChanged);
    _neighborhoodFocusNode.dispose();
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dayRefreshScheduler.reschedule(refresh: true);
    }
  }

  int get _guestCount => _femaleCount + _maleCount + _otherCount;

  int get _totalSeats => _guestCount + 1;

  String get _genderDistributionText {
    final parts = <String>[];
    if (_femaleCount > 0) parts.add('$_femaleCount kız');
    if (_maleCount > 0) parts.add('$_maleCount erkek');
    if (_otherCount > 0) parts.add('$_otherCount fark etmez');
    if (parts.isEmpty) return 'Seçim yok';
    return parts.join(', ');
  }

  void _changeGenderCount(_SeatGender type, int delta) {
    final total = _guestCount;
    if (delta > 0 && total >= 5) return;

    setState(() {
      switch (type) {
        case _SeatGender.female:
          _femaleCount = (_femaleCount + delta).clamp(0, 5);
        case _SeatGender.male:
          _maleCount = (_maleCount + delta).clamp(0, 5);
        case _SeatGender.other:
          _otherCount = (_otherCount + delta).clamp(0, 5);
        case _SeatGender.me:
          break;
      }
    });
  }

  List<_SeatGender> _seatGenders() {
    final list = <_SeatGender>[_SeatGender.me];
    list.addAll(List<_SeatGender>.filled(_femaleCount, _SeatGender.female));
    list.addAll(List<_SeatGender>.filled(_maleCount, _SeatGender.male));
    list.addAll(List<_SeatGender>.filled(_otherCount, _SeatGender.other));
    return list;
  }

  List<String> _buildGenderPrefs() {
    final prefs = <String>['OTHER'];
    prefs.addAll(List<String>.filled(_femaleCount, 'FEMALE'));
    prefs.addAll(List<String>.filled(_maleCount, 'MALE'));
    prefs.addAll(List<String>.filled(_otherCount, 'OTHER'));
    return prefs;
  }

  String _formatCardTime() {
    final now = widget.now();
    return formatTableGroupMeetingAt(
      resolveTableGroupMeetingAt(
        now: now,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      ),
      now: now,
    );
  }

  void _requestBackNavigation() {
    if (!mounted || _cubit.state.status == TableGroupCreateStatus.submitting) {
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _pickTime() async {
    if (_cubit.state.status == TableGroupCreateStatus.submitting) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.brandGradient.last,
              surface: Theme.of(context).colorScheme.surfaceContainer,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              dialBackgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              hourMinuteColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              hourMinuteTextColor: Theme.of(context).colorScheme.onSurface,
              dayPeriodColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              dayPeriodTextColor: Theme.of(context).colorScheme.onSurface,
              entryModeIconColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              dialHandColor: AppColors.brandGradient.last,
              dialTextColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedTime = picked);
  }

  Widget _venuePickerFeedback(
    BuildContext context,
    TableGroupCreateState state, {
    required bool submitting,
  }) {
    final selected = state.selectedVenue;
    if (state.venueMode == TableGroupVenueMode.registered && selected != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _compactVenueRow(
          context,
          selected,
          key: const Key('table_group_registered_venue_summary'),
          infoKey: const Key('table_group_selected_venue_info'),
          selected: true,
          infoEnabled: !submitting,
        ),
      );
    }

    final query = state.venueQuery;
    if (query.length < 2 || !state.venueSuggestionsVisible) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('table_group_venue_search_results'),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.venueSearchLoading)
            const LinearProgressIndicator(minHeight: 2),
          if (state.venueSearchError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Text(
                state.venueSearchError!.message,
                key: const Key('table_group_venue_search_error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          for (var index = 0; index < state.venueOptions.length; index++) ...[
            _compactVenueRow(
              context,
              state.venueOptions[index],
              key: ValueKey<String>(
                'table_group_venue_option-${state.venueOptions[index].id}',
              ),
              infoKey: ValueKey<String>(
                'table_group_venue_info-${state.venueOptions[index].id}',
              ),
              onTap: submitting
                  ? null
                  : () => _selectRegisteredVenue(state.venueOptions[index]),
              infoEnabled: !submitting,
            ),
            if (index < state.venueOptions.length - 1)
              const Divider(height: 1, indent: 64),
          ],
          TextButton(
            key: const Key('table_group_use_custom_venue'),
            onPressed: submitting ? null : _useCustomVenue,
            child: Text('“$query” adını serbest kullan'),
          ),
        ],
      ),
    );
  }

  Widget _compactVenueRow(
    BuildContext context,
    TableGroupVenueOption option, {
    required Key key,
    required Key infoKey,
    VoidCallback? onTap,
    bool selected = false,
    bool infoEnabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = colorScheme.onSurface;
    final secondary = colorScheme.onSurfaceVariant;

    return Semantics(
      key: ValueKey<String>('table_group_venue_semantics-${option.id}'),
      selected: selected ? true : null,
      child: Material(
        key: key,
        color: selected
            ? colorScheme.surfaceContainerHighest
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide(
                  color: AppColors.brandGradient.last.withValues(alpha: 0.72),
                  width: 1.2,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(
              children: [
                CircleAvatar(
                  key: ValueKey<String>(
                    'table_group_venue_avatar-${option.id}',
                  ),
                  radius: 21,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: ClipOval(
                    child: AppCachedNetworkImage(
                      key: ValueKey<String>(
                        'table_group_venue_image-${option.id}',
                      ),
                      imageUrl: option.profilePictureUrl,
                      width: 42,
                      height: 42,
                      cacheWidth: 126,
                      cacheHeight: 126,
                      errorBuilder: (context) => Icon(
                        Icons.storefront_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.locationSummary,
                        key: selected
                            ? const Key('table_group_locked_venue_location')
                            : null,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: secondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: infoKey,
                  tooltip: '${option.name} hakkında bilgi',
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  color: secondary,
                  onPressed: infoEnabled
                      ? () =>
                            unawaited(_showVenueSelectionInfo(context, option))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showVenueSelectionInfo(
    BuildContext context,
    TableGroupVenueOption option,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('table_group_venue_info_dialog'),
        scrollable: true,
        title: Text(option.name, key: const Key('table_group_venue_info_name')),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.locationSummary,
              key: const Key('table_group_venue_info_location'),
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              option.address,
              key: const Key('table_group_venue_info_address'),
            ),
            const Divider(height: 24),
            const Text(
              'Bu mekânı seçmen yalnızca masanın buluşma konumunu belirtir. '
              'Mekâna bildirim gönderilmez ve rezervasyon oluşturulmaz.',
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('table_group_venue_info_close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  Widget _descriptionField(BuildContext context, {required bool loading}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldCaption('Masa açıklaması'),
        const SizedBox(height: 8),
        _GradientFocusFrame(
          isFocused: _descriptionFocusNode.hasFocus,
          child: TextFormField(
            key: const Key('table_group_description_input'),
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            readOnly: loading,
            minLines: 3,
            maxLines: 5,
            inputFormatters: const [
              _DescriptionCodePointLengthFormatter(
                TableGroupCreateRequest.maxDescriptionLength,
              ),
            ],
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Masada nasıl bir buluşma planladığını kısaca anlat.',
              alignLabelWithHint: true,
              counterText: '',
              contentPadding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              filled: true,
              fillColor: const Color(0xFF071321),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              final description = TableGroupCreateRequest.normalizeDescription(
                value ?? '',
              );
              if (description.isEmpty) {
                return 'Masa açıklaması zorunlu';
              }
              if (TableGroupCreateRequest.descriptionCodePointLength(
                    description,
                  ) >
                  TableGroupCreateRequest.maxDescriptionLength) {
                return 'Masa açıklaması en fazla 280 karakter olabilir';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 6),
        _DescriptionCounter(controller: _descriptionController),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    if (_formKey.currentState?.validate() != true) return;
    if (_guestCount < 1) {
      messenger.showSnackBar(
        SnackBar(content: Text('En az 1 katılımcı seçmelisin')),
      );
      return;
    }
    final selectedVenue = _cubit.state.selectedVenue;
    final registered =
        _cubit.state.hasSpecificVenue &&
        _cubit.state.venueMode == TableGroupVenueMode.registered &&
        selectedVenue != null;
    final cityId = registered ? selectedVenue.cityId : _selectedCityId;
    if (cityId == null || cityId.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('Şehir seçimi zorunlu')));
      return;
    }

    final venueId = registered ? selectedVenue.id : null;
    final venueName = !_cubit.state.hasSpecificVenue || registered
        ? null
        : _venueController.text.trim();
    final districtId = registered
        ? selectedVenue.districtId
        : _selectedDistrictId;
    final neighborhoodId = registered
        ? selectedVenue.neighborhoodId
        : _selectedNeighborhoodId;
    final draft = (
      venueId: venueId,
      venueName: venueName,
      description: _descriptionController.text.trim(),
      maxPersonCount: _totalSeats,
      femaleCount: _femaleCount,
      maleCount: _maleCount,
      otherCount: _otherCount,
      ageMin: _ageRange.start.round(),
      ageMax: _ageRange.end.round(),
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      cityId: cityId,
      districtId: districtId,
      neighborhoodId: neighborhoodId,
    );

    var request = _retryableCreateDraft == draft
        ? _retryableCreateRequest
        : null;
    if (request == null) {
      final now = widget.now();
      final meetingAt = resolveTableGroupMeetingAt(
        now: now,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      );
      final meetingLead = meetingAt.difference(now);
      if (meetingLead <= Duration.zero ||
          meetingLead > tableGroupMaximumMeetingLead) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Buluşma saati en fazla 24 saat sonrası olabilir'),
          ),
        );
        return;
      }
      request = TableGroupCreateRequest(
        venueId: venueId,
        venueName: venueName,
        description: draft.description,
        maxPersonCount: draft.maxPersonCount,
        genderPrefs: _buildGenderPrefs(),
        ageMin: draft.ageMin,
        ageMax: draft.ageMax,
        meetingAt: meetingAt,
        cityId: draft.cityId,
        districtId: draft.districtId,
        neighborhoodId: draft.neighborhoodId,
      );
      // A committed response can be lost. Keep the exact request snapshot for
      // semantically identical retries so the backend's replay fingerprint is
      // preserved even if the selected minute has rolled into tomorrow.
      _retryableCreateDraft = draft;
      _retryableCreateRequest = request;
    }

    final ok = await _cubit.createTableGroup(request);
    if (!mounted) return;
    if (!ok) {
      if (identical(_retryableCreateRequest, request) &&
          _isDefinitiveCreateRejection(_cubit.state.error?.code)) {
        _retryableCreateDraft = null;
        _retryableCreateRequest = null;
      }
      return;
    }
    ScaffoldMessenger.of(
      this.context,
    ).showSnackBar(SnackBar(content: Text('Masa oluşturuldu')));
    Navigator.of(
      this.context,
    ).pop(TableGroupCreateResult(cityId: request.cityId));
  }

  bool _isDefinitiveCreateRejection(String? rawCode) {
    final code = rawCode?.trim().toUpperCase();
    if (code == null || code.isEmpty) return false;

    // These responses prove that this exact request did not commit. Keep the
    // snapshot for transport/decode ambiguity and every 5xx path so a replay
    // can still recover a response that was lost after commit.
    return const <String>{
      '9100', // VENUE_ID_AND_NAME_CONFLICT
      '9102', // INVALID_AGE_RANGE
      '9103', // GENDER_AND_COUNT_MISMATCH
      '9104', // TABLE_END_DATE_PASSED
      '9112', // TABLE_GROUP_DURATION_INVALID
      '9114', // TABLE_GROUP_VENUE_LOCATION_MISMATCH
      '9127', // TABLE_GROUP_OWNER_ACTIVE_EXISTS
    }.contains(code);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<TableGroupCreateCubit, TableGroupCreateState>(
        listenWhen: (previous, current) {
          if (current.status != TableGroupCreateStatus.failure ||
              current.error == null) {
            return false;
          }
          return previous.status != TableGroupCreateStatus.failure ||
              !identical(previous.error, current.error);
        },
        listener: (context, state) {
          if (state.status == TableGroupCreateStatus.failure &&
              state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!.message)));
          }
        },
        builder: (context, state) {
          final loading = state.status == TableGroupCreateStatus.submitting;
          final loadingLocations =
              state.status == TableGroupCreateStatus.loadingLocations;
          final busy = loading || loadingLocations;
          final locationInputsEnabled = !loading && !loadingLocations;

          return PopScope<Object?>(
            // Keep the route veto active continuously. The callback reads the
            // Cubit's live state, closing the tap-to-rebuild window in which a
            // second hardware-back event could otherwise escape during POST.
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _requestBackNavigation();
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text('Masa Oluştur'),
                leading: IconButton(
                  key: Key('table_group_create_back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: loading ? null : _requestBackNavigation,
                  icon: BackButtonIcon(),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionCard(
                        title: 'Masa Oluştur',
                        subtitle:
                            'Aynı frekanstaki insanlarla tanışmak için masanı tasarla.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TableSeatPreview(
                              seatGenders: _seatGenders(),
                              totalSeats: _totalSeats,
                            ),
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _GenderSeatMiniControl(
                                  keyPrefix: 'female',
                                  icon: Icons.female_rounded,
                                  count: _femaleCount,
                                  onAdd: loading
                                      ? null
                                      : () => _changeGenderCount(
                                          _SeatGender.female,
                                          1,
                                        ),
                                  onRemove: loading
                                      ? null
                                      : () => _changeGenderCount(
                                          _SeatGender.female,
                                          -1,
                                        ),
                                ),
                                SizedBox(width: 12),
                                _GenderSeatMiniControl(
                                  keyPrefix: 'male',
                                  icon: Icons.male_rounded,
                                  count: _maleCount,
                                  onAdd: loading
                                      ? null
                                      : () => _changeGenderCount(
                                          _SeatGender.male,
                                          1,
                                        ),
                                  onRemove: loading
                                      ? null
                                      : () => _changeGenderCount(
                                          _SeatGender.male,
                                          -1,
                                        ),
                                ),
                                SizedBox(width: 12),
                                _GenderSeatMiniControl(
                                  keyPrefix: 'other',
                                  icon: Icons.all_inclusive_rounded,
                                  count: _otherCount,
                                  onAdd: loading
                                      ? null
                                      : () => _changeGenderCount(
                                          _SeatGender.other,
                                          1,
                                        ),
                                  onRemove: loading
                                      ? null
                                      : () => _changeGenderCount(
                                          _SeatGender.other,
                                          -1,
                                        ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 15,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _formatCardTime(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).dividerColor,
                                          ),
                                        ),
                                        child: Text(
                                          _genderDistributionText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (state.hasSpecificVenue &&
                                    _venueController.text
                                        .trim()
                                        .isNotEmpty) ...[
                                  SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.storefront_outlined,
                                        size: 15,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _venueController.text.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 22),
                            _descriptionField(context, loading: loading),
                            const SizedBox(height: 22),
                            _PremiumVenueToggle(
                              controlKey: const Key(
                                'table_group_specific_venue_toggle',
                              ),
                              value: state.hasSpecificVenue,
                              onChanged: loading ? null : _setHasSpecificVenue,
                            ),
                            if (state.hasSpecificVenue) ...[
                              SizedBox(height: 12),
                              _FieldCaption('Mekânın adı'),
                              SizedBox(height: 6),
                              _GradientFocusFrame(
                                isFocused: _venueFocusNode.hasFocus,
                                child: TextFormField(
                                  key: const Key('table_group_venue_input'),
                                  controller: _venueController,
                                  focusNode: _venueFocusNode,
                                  readOnly:
                                      loading ||
                                      state.venueMode ==
                                          TableGroupVenueMode.registered,
                                  maxLength: 64,
                                  decoration: InputDecoration(
                                    hintText: 'Örnek: Jolly Joker',
                                    counterText: '',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    suffixIcon:
                                        state.venueMode ==
                                            TableGroupVenueMode.registered
                                        ? IconButton(
                                            key: const Key(
                                              'table_group_registered_venue_clear',
                                            ),
                                            tooltip: 'Mekân seçimini kaldır',
                                            onPressed: loading
                                                ? null
                                                : _clearRegisteredVenue,
                                            icon: const Icon(
                                              Icons.close_rounded,
                                            ),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: const Color(0xFF071321),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Mekân adı zorunlu';
                                    }
                                    if (value.trim().length > 64) {
                                      return 'Mekân adı en fazla 64 karakter olabilir';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              _venuePickerFeedback(
                                context,
                                state,
                                submitting: loading,
                              ),
                            ],
                            if (state.venueMode !=
                                TableGroupVenueMode.registered) ...[
                              SizedBox(height: 12),
                              if (state.locationError != null) ...[
                                Container(
                                  key: const Key(
                                    'table_group_location_load_error',
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.locationError!.message,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onErrorContainer,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      OutlinedButton.icon(
                                        key: const Key(
                                          'table_group_retry_locations',
                                        ),
                                        onPressed: loading
                                            ? null
                                            : () => unawaited(
                                                _cubit.retryLocations(),
                                              ),
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text(
                                          'Konumu tekrar yükle',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12),
                              ],
                              _FieldCaption('Şehir'),
                              SizedBox(height: 6),
                              _GradientFocusFrame(
                                isFocused: _cityFocusNode.hasFocus,
                                child: DropdownButtonFormField<String>(
                                  key: const Key('table_group_custom_city'),
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  focusNode: _cityFocusNode,
                                  value: _selectedCityId,
                                  decoration: InputDecoration(
                                    hintText: 'Şehir seç',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF071321),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  dropdownColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                                  items: state.cities
                                      .map(
                                        (city) => DropdownMenuItem<String>(
                                          value: city.id,
                                          child: Text(city.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: locationInputsEnabled
                                      ? (value) async {
                                          setState(() {
                                            _selectedCityId = value;
                                            _selectedDistrictId = null;
                                            _selectedNeighborhoodId = null;
                                          });
                                          final cubit = context
                                              .read<TableGroupCreateCubit>();
                                          await cubit.selectCity(value);
                                        }
                                      : null,
                                  validator: (value) =>
                                      (value == null || value.isEmpty)
                                      ? 'Şehir seçimi zorunlu'
                                      : null,
                                ),
                              ),
                              SizedBox(height: 12),
                              _FieldCaption('İlçe'),
                              SizedBox(height: 6),
                              _GradientFocusFrame(
                                isFocused: _districtFocusNode.hasFocus,
                                child: DropdownButtonFormField<String>(
                                  key: const Key('table_group_custom_district'),
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  focusNode: _districtFocusNode,
                                  value: _selectedDistrictId,
                                  decoration: InputDecoration(
                                    hintText: 'İlçe seç',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF071321),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  dropdownColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                                  items: state.districts
                                      .map(
                                        (district) => DropdownMenuItem<String>(
                                          value: district.id,
                                          child: Text(district.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged:
                                      locationInputsEnabled &&
                                          _selectedCityId != null
                                      ? (value) async {
                                          setState(() {
                                            _selectedDistrictId = value;
                                            _selectedNeighborhoodId = null;
                                          });
                                          final cubit = context
                                              .read<TableGroupCreateCubit>();
                                          await cubit.selectDistrict(value);
                                        }
                                      : null,
                                ),
                              ),
                              SizedBox(height: 12),
                              _FieldCaption('Mahalle (isteğe bağlı)'),
                              SizedBox(height: 6),
                              _GradientFocusFrame(
                                isFocused: _neighborhoodFocusNode.hasFocus,
                                child: DropdownButtonFormField<String>(
                                  key: const Key(
                                    'table_group_custom_neighborhood',
                                  ),
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  focusNode: _neighborhoodFocusNode,
                                  value: _selectedNeighborhoodId,
                                  decoration: InputDecoration(
                                    hintText: 'Mahalle seç',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF071321),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  dropdownColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                                  items: state.neighborhoods
                                      .map(
                                        (neighborhood) =>
                                            DropdownMenuItem<String>(
                                              value: neighborhood.id,
                                              child: Text(neighborhood.name),
                                            ),
                                      )
                                      .toList(),
                                  onChanged:
                                      locationInputsEnabled &&
                                          _selectedDistrictId != null
                                      ? (value) => setState(
                                          () => _selectedNeighborhoodId = value,
                                        )
                                      : null,
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            Text(
                              'Buluşma Tercihleri',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(child: _FieldCaption('Yaş aralığı')),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: Text(
                                    '${_ageRange.start.round()} – ${_ageRange.end.round()}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _PremiumAgeRangeSlider(
                              values: _ageRange,
                              min: 19,
                              max: 60,
                              divisions: 41,
                              onChanged: loading
                                  ? null
                                  : (value) =>
                                        setState(() => _ageRange = value),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '19',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '60',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            _FieldCaption('Buluşma saati'),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              key: const Key('table_group_create_time'),
                              onPressed: loading ? null : _pickTime,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                backgroundColor: const Color(0xFF071321),
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: SizedBox(
                                height: 50,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      '${_selectedTime.hour.toString().padLeft(2, '0')}:'
                                      '${_selectedTime.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Masan 24 saat boyunca açık kalır.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: InkWell(
                          key: const Key('table_group_create_submit'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: busy ? null : () => _submit(context),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: busy
                                    ? [
                                        Theme.of(
                                          context,
                                        ).dividerColor.withValues(alpha: 0.7),
                                        Theme.of(
                                          context,
                                        ).dividerColor.withValues(alpha: 0.7),
                                      ]
                                    : AppColors.brandGradient,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  loading
                                      ? 'Oluşturuluyor…'
                                      : loadingLocations
                                      ? 'Konumlar yükleniyor…'
                                      : 'Masa Oluştur',
                                  style: TextStyle(
                                    color: busy
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Enforces the API's normalized Unicode code-point limit without cutting a
/// user-perceived character (for example, a family emoji) in half.
class _DescriptionCodePointLengthFormatter extends TextInputFormatter {
  static const int _maxBoundaryWhitespaceCodePoints = 32;

  final int maxCodePoints;

  const _DescriptionCodePointLengthFormatter(this.maxCodePoints)
    : assert(maxCodePoints > 0);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = TableGroupCreateRequest.normalizeDescription(
      newValue.text,
    );
    final normalizedLength = normalized.runes.length;
    final rawLength = newValue.text.runes.length;
    final exceedsRawSafetyBound =
        rawLength > maxCodePoints + _maxBoundaryWhitespaceCodePoints;
    if (!exceedsRawSafetyBound && normalizedLength <= maxCodePoints) {
      return newValue;
    }

    // Let the IME finish composing before changing its range. The validator is
    // still authoritative if submission happens during composition. The raw
    // safety bound remains enforced so composition cannot retain an unbounded
    // whitespace paste in the controller.
    if (!exceedsRawSafetyBound &&
        newValue.composing.isValid &&
        !newValue.composing.isCollapsed) {
      return newValue;
    }

    final normalizedStart = newValue.text.indexOf(normalized);
    final normalizedEnd = normalizedStart + normalized.length;
    final retained = StringBuffer();
    var retainedCodePoints = 0;
    for (final grapheme in normalized.characters) {
      final graphemeCodePoints = grapheme.runes.length;
      if (retainedCodePoints + graphemeCodePoints > maxCodePoints) break;
      retained.write(grapheme);
      retainedCodePoints += graphemeCodePoints;
    }

    final retainedText = retained.toString();

    // Ordinary boundary whitespace is preserved while typing. If an excessive
    // paste crosses the finite raw-input bound, canonicalize it immediately;
    // the request would trim these same boundaries before transport anyway.
    if (exceedsRawSafetyBound) {
      return TextEditingValue(
        text: retainedText,
        selection: TextSelection.collapsed(offset: retainedText.length),
      );
    }

    final removalStart = normalizedStart + retainedText.length;
    final removedCodeUnits = normalizedEnd - removalStart;
    final truncatedText =
        '${newValue.text.substring(0, normalizedStart)}'
        '$retainedText${newValue.text.substring(normalizedEnd)}';

    int remapOffset(int offset) {
      if (offset <= removalStart) return offset;
      if (offset <= normalizedEnd) return removalStart;
      return offset - removedCodeUnits;
    }

    final selection = newValue.selection.isValid
        ? TextSelection(
            baseOffset: remapOffset(newValue.selection.baseOffset),
            extentOffset: remapOffset(newValue.selection.extentOffset),
            affinity: newValue.selection.affinity,
            isDirectional: newValue.selection.isDirectional,
          )
        : newValue.selection;

    return newValue.copyWith(
      text: truncatedText,
      selection: selection,
      composing: TextRange.empty,
    );
  }
}

class _TableSeatPreview extends StatelessWidget {
  final List<_SeatGender> seatGenders;
  final int totalSeats;

  _TableSeatPreview({required this.seatGenders, required this.totalSeats});

  List<Color> _seatGradient() {
    return AppColors.brandGradient;
  }

  IconData _seatIcon(_SeatGender gender) {
    return switch (gender) {
      _SeatGender.me => Icons.bookmark_rounded,
      _SeatGender.female => Icons.female_rounded,
      _SeatGender.male => Icons.male_rounded,
      _SeatGender.other => Icons.all_inclusive_rounded,
    };
  }

  double _seatIconSize(_SeatGender gender) {
    return switch (gender) {
      _SeatGender.me => 18,
      _SeatGender.female => 24,
      _SeatGender.male => 24,
      _SeatGender.other => 19,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 194,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(constraints.maxWidth / 2, 102);
          final rx = constraints.maxWidth * 0.39;
          final ry = 56.0;
          final seats = <Widget>[
            Positioned(
              left: center.dx - 113,
              top: center.dy - 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(42),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFCFBFF), Color(0xFFF2EEF9)],
                  ),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.45),
                    width: 1.0,
                  ),
                ),
                child: SizedBox(
                  width: 226,
                  height: 122,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 10,
                        child: Container(
                          width: 52,
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: AppColors.pureBlack.withValues(alpha: 0.10),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        child: Container(
                          width: 12,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Color(0xFFF0EDF7),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.8),
                              width: 0.8,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 170,
                        height: 86,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: AppColors.brandGradient
                                .map((color) => color.withValues(alpha: 0.32))
                                .toList(),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(1.4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32.6),
                            child: Container(
                              color: AppColors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: 0.72,
                        child: Image.asset(
                          'assets/logotransparent.png',
                          width: 132,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];

          for (int i = 0; i < seatGenders.length; i++) {
            final angle = -1.570796 + (6.283185 * i / seatGenders.length);
            final seatCenter = Offset(
              center.dx + rx * cos(angle),
              center.dy + ry * sin(angle),
            );
            final inwardShadowOffset = Offset(
              -cos(angle) * 1.6,
              -sin(angle) * 1.6,
            );
            final isMe = i == 0;
            final seatGradient = _seatGradient();
            seats.add(
              Positioned(
                left: seatCenter.dx - 18,
                top: seatCenter.dy - 18,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: seatGradient,
                      ),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.96),
                        width: 1.7,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pureBlack.withValues(alpha: 0.20),
                          blurRadius: 4.8,
                          offset: inwardShadowOffset,
                        ),
                      ],
                    ),
                    child: isMe
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.bookmark_rounded,
                                  size: 18,
                                  color: AppColors.white.withValues(
                                    alpha: 0.98,
                                  ),
                                ),
                                Positioned(
                                  top: 5.5,
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 8,
                                    color: AppColors.white.withValues(
                                      alpha: 0.98,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Icon(
                            _seatIcon(seatGenders[i]),
                            size: _seatIconSize(seatGenders[i]),
                            color: AppColors.white.withValues(alpha: 0.98),
                          ),
                  ),
                ),
              ),
            );
          }

          return Stack(children: seats);
        },
      ),
    );
  }
}

class _PremiumVenueToggle extends StatelessWidget {
  final Key controlKey;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _PremiumVenueToggle({
    required this.controlKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    final accent = AppColors.brandGradient.last;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      toggled: value,
      label: 'Belirli bir mekâna mı gidiyorsunuz?',
      value: value ? 'Açık' : 'Kapalı',
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.55,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: controlKey,
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? () => onChanged!(!value) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF071321),
                  border: Border.all(
                    color: value
                        ? accent.withValues(alpha: 0.82)
                        : const Color(0xFF263A52),
                    width: value ? 1.2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.brandGradient,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.surface,
                        ),
                        child: Icon(
                          value
                              ? Icons.location_on_rounded
                              : Icons.location_on_outlined,
                          color: colorScheme.onSurface,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Belirli bir mekâna mı gidiyorsunuz?',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            value
                                ? 'Mekânını aşağıdaki alandan seç'
                                : 'Dilersen buluşma mekânını ekle',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 56,
                      height: 34,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: value
                            ? LinearGradient(colors: AppColors.brandGradient)
                            : null,
                        color: value ? null : const Color(0xFF0B1829),
                        border: Border.all(
                          color: value
                              ? AppColors.white.withValues(alpha: 0.18)
                              : const Color(0xFF2A4059),
                        ),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: value
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.pureBlack.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
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
}

class _DescriptionCounter extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionCounter({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final length = TableGroupCreateRequest.descriptionCodePointLength(
          value.text,
        );
        final limit = TableGroupCreateRequest.maxDescriptionLength;
        return Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            label: '$length / $limit karakter',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '$length/$limit',
                  key: const Key('table_group_description_counter'),
                  style: TextStyle(
                    color: length > limit
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;

  _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _GradientFocusFrame extends StatelessWidget {
  final bool isFocused;
  final Widget child;

  _GradientFocusFrame({required this.isFocused, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: isFocused
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              )
            : const LinearGradient(
                colors: [Color(0xFF263A52), Color(0xFF263A52)],
              ),
      ),
      child: child,
    );
  }
}

class _PremiumAgeRangeSlider extends StatelessWidget {
  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<RangeValues>? onChanged;

  _PremiumAgeRangeSlider({
    required this.values,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final startPercent = ((values.start - min) / (max - min)).clamp(0.0, 1.0);
    final endPercent = ((values.end - min) / (max - min)).clamp(0.0, 1.0);

    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth - 24;
          final activeLeft = 12 + (trackWidth * startPercent);
          final activeRight = 12 + (trackWidth * endPercent);

          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                right: 12,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.95),
                  ),
                ),
              ),
              Positioned(
                left: activeLeft,
                width: (activeRight - activeLeft) < 8
                    ? 8
                    : (activeRight - activeLeft),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: AppColors.brandGradient,
                    ),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 0.01,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: AppColors.white,
                  overlayColor: Color(0xFFC15CE0).withValues(alpha: 0.16),
                  rangeThumbShape: RoundRangeSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                  rangeValueIndicatorShape:
                      PaddleRangeSliderValueIndicatorShape(),
                  valueIndicatorColor: AppColors.brandGradient.last,
                  valueIndicatorTextStyle: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: RangeSlider(
                  values: values,
                  min: min,
                  max: max,
                  divisions: divisions,
                  labels: RangeLabels(
                    values.start.round().toString(),
                    values.end.round().toString(),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GenderSeatMiniControl extends StatelessWidget {
  final String keyPrefix;
  final IconData icon;
  final int count;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  _GenderSeatMiniControl({
    required this.keyPrefix,
    required this.icon,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  List<Color> _seatGradient() {
    return AppColors.brandGradient;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _seatGradient(),
            ),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.95),
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: AppColors.white.withValues(alpha: 0.98),
          ),
        ),
        SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: Key('table_group_seat_$keyPrefix-remove'),
              borderRadius: BorderRadius.circular(999),
              onTap: onRemove,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.remove,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              width: 20,
              child: Text(
                count.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            InkWell(
              key: Key('table_group_seat_$keyPrefix-add'),
              borderRadius: BorderRadius.circular(999),
              onTap: onAdd,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
