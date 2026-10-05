import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../data/models/table_group_create_request.dart';
import '../../domain/entities/table_group_venue_option.dart';
import '../../domain/table_group_expiry_policy.dart';
import '../cubit/table_group_create_cubit.dart';
import '../cubit/table_group_create_state.dart';
import 'table_group_route_args.dart';

part 'table_group_create_screen_on_focus_changed.dart';
part 'table_group_create_screen_table_seat_preview.dart';

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

class TableGroupCreateScreen extends StatelessWidget {
  final DateTime Function() now;

  TableGroupCreateScreen({super.key, DateTime Function()? now})
    : now = now ?? DateTime.now;

  @override
  Widget build(BuildContext context) =>
      AppSurfaceThemeScope(child: _TableGroupCreateContent(now: now));
}

class _TableGroupCreateContent extends StatefulWidget {
  const _TableGroupCreateContent({required this.now});

  final DateTime Function() now;

  @override
  State<_TableGroupCreateContent> createState() =>
      _TableGroupCreateScreenState();
}

class _TableGroupCreateScreenState extends State<_TableGroupCreateContent>
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
  bool _attemptedSubmit = false;
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

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
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
            ScaffoldMessenger.of(context).showSnackBar(
              appSnackBar(
                context,
                tone: AppSnackBarTone.error,
                content: Text(state.error!.message),
              ),
            );
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
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).scaffoldBackgroundColor
                    : null,
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
                  autovalidateMode: _attemptedSubmit
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
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
                                    fillColor: (AppColors.isOriginalDark
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest
                                        : AppColors.inputFill),
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
                                    fillColor: (AppColors.isOriginalDark
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest
                                        : AppColors.inputFill),
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
                                    fillColor: (AppColors.isOriginalDark
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest
                                        : AppColors.inputFill),
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
                                    fillColor: (AppColors.isOriginalDark
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest
                                        : AppColors.inputFill),
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
                                backgroundColor: (AppColors.isOriginalDark
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest
                                    : AppColors.inputFill),
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
                                    : AppColors.decorativeGradient,
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

  void _updateView(VoidCallback change) => setState(change);
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
