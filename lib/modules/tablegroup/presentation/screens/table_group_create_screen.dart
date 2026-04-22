import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/table_group_create_request.dart';
import '../cubit/table_group_create_cubit.dart';
import '../cubit/table_group_create_state.dart';

enum _SeatGender { me, female, male, other }

class TableGroupCreateScreen extends StatefulWidget {
  TableGroupCreateScreen({super.key});

  @override
  State<TableGroupCreateScreen> createState() => _TableGroupCreateScreenState();
}

class _TableGroupCreateScreenState extends State<TableGroupCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _venueController = TextEditingController();
  final FocusNode _venueFocusNode = FocusNode();
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

  @override
  void initState() {
    super.initState();
    _venueController.addListener(_onVenueChanged);
    _venueFocusNode.addListener(_onVenueChanged);
    _cityFocusNode.addListener(_onVenueChanged);
    _districtFocusNode.addListener(_onVenueChanged);
    _neighborhoodFocusNode.addListener(_onVenueChanged);
  }

  void _onVenueChanged() {
    if (!context.mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _venueController.removeListener(_onVenueChanged);
    _venueController.dispose();
    _venueFocusNode.removeListener(_onVenueChanged);
    _venueFocusNode.dispose();
    _cityFocusNode.removeListener(_onVenueChanged);
    _cityFocusNode.dispose();
    _districtFocusNode.removeListener(_onVenueChanged);
    _districtFocusNode.dispose();
    _neighborhoodFocusNode.removeListener(_onVenueChanged);
    _neighborhoodFocusNode.dispose();
    super.dispose();
  }

  int get _guestCount => _femaleCount + _maleCount + _otherCount;

  int get _totalSeats => _guestCount + 1;

  String get _genderDistributionText {
    final parts = <String>[];
    if (_femaleCount > 0) parts.add('$_femaleCount kiz');
    if (_maleCount > 0) parts.add('$_maleCount erkek');
    if (_otherCount > 0) parts.add('$_otherCount farketmez');
    if (parts.isEmpty) return 'Secim yok';
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

  DateTime _mergeDateAndTime() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  String _formatCardTime() {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime() async {
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
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  Future<void> _submit(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!_formKey.currentState!.validate()) return;
    if (_guestCount < 1) {
      messenger.showSnackBar(
        SnackBar(content: Text('En az 1 katilimci secmelisin')),
      );
      return;
    }
    if (_selectedCityId == null || _selectedCityId!.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('Sehir secimi zorunlu')));
      return;
    }

    final expiresAt = _mergeDateAndTime();
    if (!expiresAt.isAfter(DateTime.now())) {
      messenger.showSnackBar(
        SnackBar(content: Text('Masanin bitis zamani simdiden ileri olmali')),
      );
      return;
    }

    final request = TableGroupCreateRequest(
      venueId: null,
      venueName: _venueController.text.trim(),
      maxPersonCount: _totalSeats,
      genderPrefs: _buildGenderPrefs(),
      ageMin: _ageRange.start.round(),
      ageMax: _ageRange.end.round(),
      expiresAt: expiresAt,
      cityId: _selectedCityId!,
      districtId: _selectedDistrictId,
      neighborhoodId: _selectedNeighborhoodId,
    );

    final ok = await context.read<TableGroupCreateCubit>().createTableGroup(
      request,
    );
    if (!mounted) return;
    if (!ok) return;
    messenger.showSnackBar(SnackBar(content: Text('Masa olusturuldu')));
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<TableGroupCreateCubit>()..loadCities(),
      child: BlocConsumer<TableGroupCreateCubit, TableGroupCreateState>(
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

          return Scaffold(
            appBar: AppBar(title: Text('Masa Olustur')),
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionCard(
                      title: 'Masa Olustur',
                      subtitle:
                          'Ayni frekanstaki insanlarla tanismak icin masani tasarla.',
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
                                icon: Icons.female_rounded,
                                count: _femaleCount,
                                onAdd: () =>
                                    _changeGenderCount(_SeatGender.female, 1),
                                onRemove: () =>
                                    _changeGenderCount(_SeatGender.female, -1),
                              ),
                              SizedBox(width: 12),
                              _GenderSeatMiniControl(
                                icon: Icons.male_rounded,
                                count: _maleCount,
                                onAdd: () =>
                                    _changeGenderCount(_SeatGender.male, 1),
                                onRemove: () =>
                                    _changeGenderCount(_SeatGender.male, -1),
                              ),
                              SizedBox(width: 12),
                              _GenderSeatMiniControl(
                                icon: Icons.all_inclusive_rounded,
                                count: _otherCount,
                                onAdd: () =>
                                    _changeGenderCount(_SeatGender.other, 1),
                                onRemove: () =>
                                    _changeGenderCount(_SeatGender.other, -1),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
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
                              Text(
                                _formatCardTime(),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 14),
                              Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _venueController.text.trim().isEmpty
                                      ? 'Mekan secilmedi'
                                      : _venueController.text.trim(),
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
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                child: Text(
                                  _genderDistributionText,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _FieldCaption('Mekanin adi'),
                          SizedBox(height: 6),
                          _GradientFocusFrame(
                            isFocused: _venueFocusNode.hasFocus,
                            child: TextFormField(
                              controller: _venueController,
                              focusNode: _venueFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Ornek: Jolly Joker',
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Mekan adi zorunlu';
                                }
                                if (value.trim().length > 64) {
                                  return 'Mekan adi en fazla 64 karakter olabilir';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _FieldCaption('Sehir'),
                          SizedBox(height: 6),
                          _GradientFocusFrame(
                            isFocused: _cityFocusNode.hasFocus,
                            child: DropdownButtonFormField<String>(
                              focusNode: _cityFocusNode,
                              value: _selectedCityId,
                              decoration: InputDecoration(
                                hintText: 'Sehir sec',
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
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
                              onChanged: (value) async {
                                setState(() {
                                  _selectedCityId = value;
                                  _selectedDistrictId = null;
                                  _selectedNeighborhoodId = null;
                                });
                                if (value != null) {
                                  await context
                                      .read<TableGroupCreateCubit>()
                                      .loadDistricts(value);
                                }
                              },
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                  ? 'Sehir secimi zorunlu'
                                  : null,
                            ),
                          ),
                          SizedBox(height: 12),
                          _FieldCaption('Ilce'),
                          SizedBox(height: 6),
                          _GradientFocusFrame(
                            isFocused: _districtFocusNode.hasFocus,
                            child: DropdownButtonFormField<String>(
                              focusNode: _districtFocusNode,
                              value: _selectedDistrictId,
                              decoration: InputDecoration(
                                hintText: 'Ilce sec',
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
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
                              onChanged: (value) async {
                                setState(() {
                                  _selectedDistrictId = value;
                                  _selectedNeighborhoodId = null;
                                });
                                if (value != null) {
                                  await context
                                      .read<TableGroupCreateCubit>()
                                      .loadNeighborhoods(value);
                                }
                              },
                            ),
                          ),
                          SizedBox(height: 12),
                          _FieldCaption('Mahalle (opsiyonel)'),
                          SizedBox(height: 6),
                          _GradientFocusFrame(
                            isFocused: _neighborhoodFocusNode.hasFocus,
                            child: DropdownButtonFormField<String>(
                              focusNode: _neighborhoodFocusNode,
                              value: _selectedNeighborhoodId,
                              decoration: InputDecoration(
                                hintText: 'Mahalle sec',
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              dropdownColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              items: state.neighborhoods
                                  .map(
                                    (neighborhood) => DropdownMenuItem<String>(
                                      value: neighborhood.id,
                                      child: Text(neighborhood.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(
                                () => _selectedNeighborhoodId = value,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Yas araligi: ${_ageRange.start.round()} - ${_ageRange.end.round()}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          _PremiumAgeRangeSlider(
                            values: _ageRange,
                            min: 19,
                            max: 60,
                            divisions: 41,
                            onChanged: (value) =>
                                setState(() => _ageRange = value),
                          ),
                          SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: Icon(Icons.schedule),
                            label: Text(
                              'Aktif kalacagi saat: '
                              '${_selectedTime.hour.toString().padLeft(2, '0')}:'
                              '${_selectedTime.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: loading ? null : () => _submit(context),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: loading
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
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(1),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              loading ? 'Olusturuluyor...' : 'Masa Olustur',
                              style: TextStyle(
                                color: loading
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
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
          );
        },
      ),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.pureBlack.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
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
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            SizedBox(height: 12),
            child,
          ],
        ),
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
        fontSize: 12,
        fontWeight: FontWeight.w600,
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
      duration: Duration(milliseconds: 160),
      padding: EdgeInsets.all(1.3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isFocused
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              )
            : LinearGradient(
                colors: [
                  Theme.of(context).dividerColor,
                  Theme.of(context).dividerColor.withValues(alpha: 0.92),
                ],
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
  final ValueChanged<RangeValues> onChanged;

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
  final IconData icon;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  _GenderSeatMiniControl({
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
