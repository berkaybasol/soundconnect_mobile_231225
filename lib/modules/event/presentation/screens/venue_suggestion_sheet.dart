import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/turkish_alphabetical.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/entities/district.dart';
import '../../../location/domain/location_repository.dart';
import '../../domain/venue_suggestion_repository.dart';

Future<bool?> showVenueSuggestionSheet(
  BuildContext context, {
  required LocationRepository locationRepository,
  required VenueSuggestionRepository repository,
  City? initialCity,
  District? initialDistrict,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: AppColors.navBlueDeep,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
  ),
  builder: (_) => _VenueSuggestionForm(
    locations: locationRepository,
    repository: repository,
    initialCity: initialCity,
    initialDistrict: initialDistrict,
  ),
);

class _VenueSuggestionForm extends StatefulWidget {
  const _VenueSuggestionForm({
    required this.locations,
    required this.repository,
    this.initialCity,
    this.initialDistrict,
  });
  final LocationRepository locations;
  final VenueSuggestionRepository repository;
  final City? initialCity;
  final District? initialDistrict;
  @override
  State<_VenueSuggestionForm> createState() => _VenueSuggestionFormState();
}

class _VenueSuggestionFormState extends State<_VenueSuggestionForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  List<City> _cities = [];
  List<District> _districts = [];
  City? _city;
  District? _district;
  VenueSuggestionLiveMusic? _liveMusic;
  bool _loadingCities = true;
  bool _loadingDistricts = false;
  bool _submitting = false;
  bool _attempted = false;
  bool _prefillApplied = false;
  String? _cityError;
  String? _districtError;
  String? _submitError;
  String? _attemptPayload;
  String? _requestId;
  int _cityGeneration = 0;
  int _districtGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCities());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    final generation = ++_cityGeneration;
    setState(() {
      _loadingCities = true;
      _cityError = null;
    });
    Result<List<City>> result;
    try {
      result = await widget.locations.getCities();
    } catch (_) {
      result = const Result.failure(AppError(code: 'location', message: ''));
    }
    if (!mounted || generation != _cityGeneration) return;
    City? prefill;
    setState(() {
      _loadingCities = false;
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        _cities = sortByTurkishName(result.data!, (item) => item.name);
        if (!_prefillApplied) {
          _prefillApplied = true;
          final matches = _cities.where(
            (item) => item.id == widget.initialCity?.id,
          );
          if (matches.isNotEmpty) prefill = matches.first;
        }
      } else {
        _cityError = 'İller yüklenemedi. Tekrar deneyebilirsin.';
      }
    });
    if (prefill != null) await _selectCity(prefill!, prefill: true);
  }

  Future<void> _selectCity(City city, {bool prefill = false}) async {
    if (_submitting || _city?.id == city.id) return;
    setState(() {
      _city = city;
      _district = null;
      _districts = [];
      _districtError = null;
      _submitError = null;
    });
    await _loadDistricts(prefill: prefill);
  }

  Future<void> _loadDistricts({bool prefill = false}) async {
    final cityId = _city?.id;
    if (cityId == null || _submitting) return;
    final generation = ++_districtGeneration;
    setState(() {
      _loadingDistricts = true;
      _districtError = null;
    });
    Result<List<District>> result;
    try {
      result = await widget.locations.getDistricts(cityId);
    } catch (_) {
      result = const Result.failure(AppError(code: 'location', message: ''));
    }
    if (!mounted || generation != _districtGeneration || cityId != _city?.id) {
      return;
    }
    setState(() {
      _loadingDistricts = false;
      if (result.isSuccess && result.data != null) {
        // A stale or invalid parent from a location response must not be selected.
        _districts = sortByTurkishName(
          result.data!.where((item) => item.cityId == cityId).toList(),
          (item) => item.name,
        );
        if (_districts.isEmpty) _districtError = 'İlçeler yüklenemedi.';
        if (prefill && widget.initialDistrict?.cityId == cityId) {
          final matches = _districts.where(
            (item) => item.id == widget.initialDistrict?.id,
          );
          if (matches.isNotEmpty) _district = matches.first;
        }
      } else {
        _districtError = 'İlçeler yüklenemedi. Tekrar deneyebilirsin.';
      }
    });
  }

  Future<void> _pickCity() async {
    if (_submitting || _loadingCities || _cities.isEmpty) return;
    final id = await _pickOption(
      context,
      title: 'İl seç',
      options: {for (final city in _cities) city.id: city.name},
      selected: _city?.id,
    );
    if (!mounted || id == null || _submitting) return;
    final matches = _cities.where((city) => city.id == id);
    if (matches.isNotEmpty) await _selectCity(matches.first);
  }

  Future<void> _pickDistrict() async {
    if (_submitting || _loadingDistricts || _districts.isEmpty) return;
    final cityId = _city?.id;
    final id = await _pickOption(
      context,
      title: 'İlçe seç',
      options: {for (final district in _districts) district.id: district.name},
      selected: _district?.id,
    );
    if (!mounted || id == null || _submitting || cityId != _city?.id) return;
    final matches = _districts.where(
      (item) => item.id == id && item.cityId == cityId,
    );
    if (matches.isNotEmpty) {
      setState(() {
        _district = matches.first;
        _submitError = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _attempted = true;
      _submitError = null;
    });
    final validName = _form.currentState?.validate() ?? false;
    if (!validName ||
        _city == null ||
        _district == null ||
        _liveMusic == null ||
        _loadingCities ||
        _loadingDistricts ||
        !_cities.any((item) => item.id == _city!.id) ||
        !_districts.any(
          (item) => item.id == _district!.id && item.cityId == _city!.id,
        )) {
      return;
    }
    final name = _name.text.trim();
    final payload = jsonEncode([
      name,
      _city!.id,
      _district!.id,
      _liveMusic!.name,
    ]);
    if (_attemptPayload != payload) {
      _attemptPayload = payload;
      _requestId = const Uuid().v4();
    }
    setState(() => _submitting = true);
    Result<void> result;
    try {
      result = await widget.repository.submit(
        requestId: _requestId!,
        venueName: name,
        cityId: _city!.id,
        districtId: _district!.id,
        liveMusic: _liveMusic!,
      );
    } catch (_) {
      result = const Result.failure(
        AppError(
          code: 'unconfirmed',
          message:
              'Gönderim doğrulanamadı. Aynı bilgilerle yeniden deneyebilirsin.',
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitError = result.error?.message;
    });
    if (result.isSuccess) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          child: Form(
            key: _form,
            autovalidateMode: _attempted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const BrandGradientIcon.social(
                      Icons.add_location_alt_outlined,
                      size: 25,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Mekan öner',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'SoundConnect’te bulamadığın mekanı bize öner.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('proposal-venue-name'),
                  controller: _name,
                  enabled: !_submitting,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('Mekan adı'),
                  validator: (raw) {
                    final length = (raw ?? '').trim().runes.length;
                    return length < 2 || length > 100
                        ? 'Mekan adı 2–100 karakter olmalı.'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                _SuggestionField(
                  key: const ValueKey('proposal-city'),
                  label: 'İl',
                  value: _city?.name ?? 'İl seç',
                  loading: _loadingCities,
                  onTap: _submitting || _loadingCities || _cities.isEmpty
                      ? null
                      : _pickCity,
                ),
                if (_cityError != null) _retry(_cityError!, _loadCities),
                if (_attempted && _city == null) _validation('İl seçmelisin.'),
                const SizedBox(height: 14),
                _SuggestionField(
                  key: const ValueKey('proposal-district'),
                  label: 'İlçe',
                  value: _district?.name ?? 'İlçe seç',
                  loading: _loadingDistricts,
                  onTap: _submitting || _loadingDistricts || _districts.isEmpty
                      ? null
                      : _pickDistrict,
                ),
                if (_districtError != null)
                  _retry(_districtError!, _loadDistricts),
                if (_attempted && _district == null)
                  _validation('İlçe seçmelisin.'),
                const SizedBox(height: 25),
                const Text(
                  'Bu mekanda canlı müzik yapılıyor mu?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in VenueSuggestionLiveMusic.values)
                      _SuggestionChoice(
                        value: choice,
                        selected: _liveMusic == choice,
                        onTap: _submitting
                            ? null
                            : () => setState(() {
                                _liveMusic = choice;
                                _submitError = null;
                              }),
                      ),
                  ],
                ),
                if (_attempted && _liveMusic == null)
                  _validation('Bir seçenek işaretlemelisin.'),
                if (_submitError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _submitError!,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 26),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: GradientOutlineButton(
                    key: const ValueKey('proposal-submit'),
                    label: 'Öneriyi gönder',
                    onPressed: _submitting ? null : _submit,
                    loading: _submitting,
                    strokeWidth: .9,
                    horizontalPadding: 16,
                    backgroundColor: AppColors.inputFill,
                    leading: const BrandGradientIcon.social(
                      Icons.send_outlined,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Vazgeç'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _retry(String message, VoidCallback retry) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        TextButton.icon(
          onPressed: _submitting ? null : retry,
          icon: const BrandGradientIcon.social(Icons.refresh_rounded, size: 17),
          label: const Text('Tekrar dene'),
        ),
      ],
    ),
  );

  Widget _validation(String message) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Text(
      message,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: 12,
      ),
    ),
  );
}

InputDecoration _decoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: AppColors.inputFill,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: AppColors.textMuted),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: AppColors.border),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: AppColors.coral),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: AppColors.coral),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
);

class _SuggestionField extends StatelessWidget {
  const _SuggestionField({
    super.key,
    required this.label,
    required this.value,
    required this.loading,
    this.onTap,
  });
  final String label;
  final String value;
  final bool loading;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: '$label, $value',
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: onTap == null
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (loading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (onTap != null)
                  const BrandGradientIcon.social(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SuggestionChoice extends StatelessWidget {
  const _SuggestionChoice({
    required this.value,
    required this.selected,
    this.onTap,
  });
  final VenueSuggestionLiveMusic value;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final label = switch (value) {
      VenueSuggestionLiveMusic.yes => 'Evet',
      VenueSuggestionLiveMusic.no => 'Hayır',
      VenueSuggestionLiveMusic.unknown => 'Bilmiyorum',
    };
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(.8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: selected ? BrandGradientIcon.gradient : null,
            color: selected ? null : AppColors.border,
          ),
          child: Material(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(12.2),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 14,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: onTap == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _pickOption(
  BuildContext context, {
  required String title,
  required Map<String, String> options,
  String? selected,
}) => showModalBottomSheet<String>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppColors.navBlueDeep,
  builder: (_) => _SuggestionLocationPicker(
    title: title,
    options: options,
    selected: selected,
  ),
);

class _SuggestionLocationPicker extends StatefulWidget {
  const _SuggestionLocationPicker({
    required this.title,
    required this.options,
    this.selected,
  });
  final String title;
  final Map<String, String> options;
  final String? selected;
  @override
  State<_SuggestionLocationPicker> createState() =>
      _SuggestionLocationPickerState();
}

class _SuggestionLocationPickerState extends State<_SuggestionLocationPicker> {
  String _query = '';
  String _fold(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
  @override
  Widget build(BuildContext context) {
    final options = widget.options.entries
        .where((item) => _fold(item.value).contains(_fold(_query)))
        .toList();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: _decoration('Ara').copyWith(
                      prefixIcon: const BrandGradientIcon.social(
                        Icons.search_rounded,
                      ),
                    ),
                  ),
                ),
              ),
              if (options.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text('Sonuç bulunamadı.'),
                  ),
                ),
              SliverList.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final item = options[index];
                  return ListTile(
                    title: Text(item.value),
                    selected: item.key == widget.selected,
                    trailing: item.key == widget.selected
                        ? const BrandGradientIcon.social(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.of(context).pop(item.key),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
