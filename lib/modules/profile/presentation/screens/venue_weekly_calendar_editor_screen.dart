import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../domain/musician_search_repository.dart';
import '../../domain/venue_event_repository.dart';
import '../../domain/entities/venue_owner_profile.dart';
import 'profile_screen_support.dart';
import 'venue_event_management_widgets.dart';
import 'venue_event_support.dart';
import 'weekly_event_detail_screen.dart';

class VenueWeeklyCalendarEditorScreen extends StatefulWidget {
  final VenueOwnerProfile ownerProfile;

  const VenueWeeklyCalendarEditorScreen({
    super.key,
    required this.ownerProfile,
  });

  @override
  State<VenueWeeklyCalendarEditorScreen> createState() =>
      _VenueWeeklyCalendarEditorScreenState();
}

class _VenueWeeklyCalendarEditorScreenState
    extends State<VenueWeeklyCalendarEditorScreen> {
  final _venueEventRepository = serviceLocator<VenueEventRepository>();
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;
  String? _error;
  List<VenueOwnerEventItem> _events = const [];

  List<VenueOwnerEventItem> get _sortedEvents {
    final items = [..._events];
    items.sort((a, b) {
      final dateCompare = a.eventDate.compareTo(b.eventDate);
      if (dateCompare != 0) return dateCompare;
      return a.startTime.compareTo(b.startTime);
    });
    return items;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _venueEventRepository.listByVenue(
        widget.ownerProfile.venueId,
      );
      final items = result.data ?? const <VenueOwnerEventItem>[];
      if (!mounted) return;
      setState(() {
        _events = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Etkinlikler alinamadi: $e';
      });
    }
  }

  Future<void> _createEvent() async {
    final draft = await showModalBottomSheet<VenueEventDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _VenueEventDraftSheet(
        ownerProfile: widget.ownerProfile,
      ),
    );

    if (draft == null) return;

    setState(() => _saving = true);
    try {
      final result = await _venueEventRepository.create(
        venueId: widget.ownerProfile.venueId,
        draft: draft,
      );
      if (!result.isSuccess) throw result.error?.message ?? 'Create failed';
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Etkinlik eklendi.')));
      await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Etkinlik eklenemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteEvent(VenueOwnerEventItem item) async {
    setState(() => _saving = true);
    try {
      final result = await _venueEventRepository.delete(item.id);
      if (!result.isSuccess) throw result.error?.message ?? 'Delete failed';
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Etkinlik silindi.')));
      await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Etkinlik silinemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  WeeklyCalendarEvent _toWeeklyCalendarEvent(VenueOwnerEventItem item) {
    return WeeklyCalendarEvent(
      id: item.id,
      title: item.title,
      artistName: item.performerName.trim().isEmpty
          ? 'Sanatci'
          : item.performerName,
      artistProfileId: item.musicianProfileId,
      venueName: widget.ownerProfile.venueName,
      venueId: widget.ownerProfile.venueId,
      city: widget.ownerProfile.cityName ?? '-',
      district: widget.ownerProfile.districtName ?? '-',
      neighborhood: widget.ownerProfile.neighborhoodName ?? '-',
      eventDate: formatVenueEventDate(item.eventDate),
      startTime: formatVenueDisplayTime(item.startTime),
      endTime: item.endTime == null || item.endTime!.trim().isEmpty
          ? '-'
          : formatVenueDisplayTime(item.endTime!),
      imageAssetPath: item.posterImage?.trim().isEmpty == true
          ? null
          : item.posterImage?.trim(),
      description: item.description?.trim().isNotEmpty == true
          ? item.description!.trim()
          : '${item.performerName.trim().isEmpty ? 'Sanatci' : item.performerName} performansi',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalik Takvim'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _loadEvents,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).pop(_changed);
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.inputFill, AppColors.navBlueSoft],
                    ),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GradientText(
                        text: widget.ownerProfile.venueName,
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: AppColors.brandGradient,
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bu ekrandan haftalik takvime yeni etkinlik ekleyebilir ve mevcut etkinlikleri silebilirsin.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.68,
                          ),
                      itemCount: _sortedEvents.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return EmptyCalendarEventCard(
                            onTap: _saving ? null : _createEvent,
                          );
                        }
                        final item = _sortedEvents[index - 1];
                        return VenueCalendarEventCard(
                          posterImage: item.posterImage,
                          title: item.title,
                          dateLabel: formatVenueEventDate(item.eventDate),
                          performerName: item.performerName,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WeeklyEventDetailScreen(
                                  event: _toWeeklyCalendarEvent(item),
                                ),
                              ),
                            );
                          },
                          saving: _saving,
                          onDelete: () => _deleteEvent(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VenueEventDraftSheet extends StatefulWidget {
  final VenueOwnerProfile ownerProfile;

  const _VenueEventDraftSheet({required this.ownerProfile});

  @override
  State<_VenueEventDraftSheet> createState() => _VenueEventDraftSheetState();
}

class _VenueEventDraftSheetState extends State<_VenueEventDraftSheet> {
  final _musicianSearchRepository = serviceLocator<MusicianSearchRepository>();
  static const List<int> _timePickerHours = <int>[
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
  ];
  static const List<int> _timePickerMinutes = <int>[
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
  ];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _performerController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _performerFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  DateTime? _selectedDate = DateTime.now();
  TimeOfDay? _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay? _endTime = const TimeOfDay(hour: 22, minute: 0);
  String? _selectedMusicianId;
  String? _selectedMusicianLabel;
  String? _selectedMusicianSecondaryLabel;
  String? _selectedMusicianImageUrl;
  String? _posterAssetId;
  String? _posterPreviewPath;
  bool _posterUploading = false;
  bool _searchLoading = false;
  String? _searchError;
  List<MusicianSearchOption> _searchResults = const [];
  Timer? _searchDebounce;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _titleFocusNode.addListener(_handleFocusChanged);
    _performerFocusNode.addListener(_handleFocusChanged);
    _descriptionFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _titleFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _performerFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _descriptionFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _performerController.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    final token = ++_searchToken;
    if (query.length < 2) {
      setState(() {
        _searchLoading = false;
        _searchError = null;
        _searchResults = const [];
      });
      return;
    }
    setState(() {
      _searchLoading = true;
      _searchError = null;
    });
    try {
      final result = await _musicianSearchRepository.search(query);
      final results = result.data ?? const <MusicianSearchOption>[];
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searchLoading = false;
        _searchResults = results;
        _searchError = results.isEmpty ? 'Sonuc bulunamadi.' : null;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searchLoading = false;
        _searchResults = const [];
        _searchError = 'Arama su anda yapilamiyor.';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) {
        final baseTheme = Theme.of(context);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: AppColors.brandGradient[1],
              secondary: AppColors.brandGradient[2],
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart
        ? (_startTime ?? const TimeOfDay(hour: 20, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 22, minute: 0));
    final initialHour = current.hour == 0 ? 24 : current.hour;
    int selectedHour = initialHour;
    int selectedMinute = current.minute.clamp(0, 59);
    if (initialHour == 24 && selectedMinute != 0) {
      selectedMinute = 0;
    }
    final hourController = FixedExtentScrollController(
      initialItem: _timePickerHours.indexOf(initialHour),
    );
    final minuteController = FixedExtentScrollController(
      initialItem: _timePickerMinutes.indexOf(selectedMinute),
    );
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText(
                  text: isStart ? 'Başlangıç Saati' : 'Bitiş Saati',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.brandGradient,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Saati ve dakikayı kaydırarak seç.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 216,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: hourController,
                          itemExtent: 48,
                          useMagnifier: true,
                          magnification: 1.08,
                          selectionOverlay: _pickerSelectionOverlay(),
                          onSelectedItemChanged: (index) {
                            setSheetState(() {
                              selectedHour = _timePickerHours[index];
                              if (selectedHour == 24 && selectedMinute == 30) {
                                selectedMinute = 0;
                                minuteController.jumpToItem(0);
                              }
                            });
                          },
                          children: _timePickerHours
                              .map(
                                (hour) => Center(
                                  child: Text(
                                    hour.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          ':',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: minuteController,
                          itemExtent: 48,
                          useMagnifier: true,
                          magnification: 1.08,
                          selectionOverlay: _pickerSelectionOverlay(),
                          onSelectedItemChanged: (index) {
                            setSheetState(() {
                              final nextMinute = _timePickerMinutes[index];
                              selectedMinute = selectedHour == 24 ? 0 : nextMinute;
                              if (selectedHour == 24 && nextMinute != 0) {
                                minuteController.jumpToItem(0);
                              }
                            });
                          },
                          children: _timePickerMinutes
                              .map(
                                (minute) => Center(
                                  child: Text(
                                    minute.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      color:
                                          selectedHour == 24 && minute == 30
                                          ? AppColors.textMuted.withValues(alpha: 0.45)
                                          : AppColors.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  selectedHour == 24 && selectedMinute == 0
                      ? 'Seçilen saat: 24.00'
                      : 'Seçilen saat: ${selectedHour.toString().padLeft(2, '0')}.${selectedMinute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    TimeOfDay(
                      hour: selectedHour == 24 ? 0 : selectedHour,
                      minute: selectedMinute,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.inputFill,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Saati Seç',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickPoster() async {
    if (_posterUploading) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2048,
    );
    if (picked == null) return;

    setState(() {
      _posterUploading = true;
      _posterPreviewPath = picked.path;
    });

    try {
      final bytes = await File(picked.path).readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Secilen afis okunamadi');
      }
      final fileName = fileNameFromPath(picked.path, fallback: picked.name);
      final uploaded = await uploadProfileMediaAsset(
        bytes: bytes,
        ownerType: 'VENUE_PROFILE',
        ownerId: widget.ownerProfile.venueProfileId,
        mediaKind: 'IMAGE',
        mimeType: inferImageMimeType(fileName),
        originalFileName: fileName,
      );
      if (!mounted) return;
      setState(() {
        _posterAssetId = uploaded.uuid.trim().isEmpty
            ? null
            : uploaded.uuid.trim();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posterAssetId = null;
        _posterPreviewPath = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Afiş yüklenemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _posterUploading = false);
      }
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    final performerText = _performerController.text.trim();
    if (title.isEmpty || _selectedDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Başlık, tarih ve başlangıç saati zorunlu.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      VenueEventDraft(
        title: title,
        description: _descriptionController.text.trim(),
        eventDate: _selectedDate!,
        startTime: _startTime!,
        endTime: _endTime,
        posterImage: _posterAssetId,
        musicianProfileId: _selectedMusicianId,
        manualPerformerName:
            _selectedMusicianId == null && performerText.isNotEmpty
            ? performerText
            : null,
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _fieldFrame({
    required Widget child,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: active
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              )
            : null,
        border: active ? null : Border.all(color: AppColors.border),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16.8),
        ),
        child: child,
      ),
    );
  }

  Widget _gradientIcon(IconData icon, {double size = 20}) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }

  Widget _pickerSelectionOverlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GradientOutlinePainter(
            borderRadius: 14,
            strokeWidth: 1.4,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  String _formatTimeValue(TimeOfDay time) {
    final hourLabel = time.hour == 0
        ? '24'
        : time.hour.toString().padLeft(2, '0');
    final minuteLabel = time.minute.toString().padLeft(2, '0');
    return '$hourLabel.$minuteLabel';
  }

  Widget _timeField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(label),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.navBlueDeep.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _gradientIcon(icon, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final sheetTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: AppColors.brandGradient[1],
        secondary: AppColors.brandGradient[2],
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.white,
        selectionColor: Color(0x40F06C86),
        selectionHandleColor: AppColors.brandGradient[1],
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.brandGradient[1],
        linearTrackColor: AppColors.border,
      ),
    );

    return Theme(
      data: sheetTheme,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.inputFill,
                    AppColors.navBlueSoft,
                    AppColors.navBlueDeep.withValues(alpha: 0.96),
                  ],
                ),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GradientText(
                    text: 'Etkinlik Ekle',
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Afişi ekle, sanatçıyı bağla ve sahne akışını tek formdan oluştur.',
                    style: TextStyle(color: AppColors.textMuted, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Temel bilgiler'),
                  _fieldFrame(
                    active: _titleFocusNode.hasFocus,
                    child: TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Etkinlik başlığı',
                        hintText: 'Örn: Cuma Gecesi Akustik Set',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _pickPoster,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.navBlueDeep.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 74,
                              height: 74,
                              color: AppColors.navBlueSoft,
                              child: _posterPreviewPath == null
                                  ? const Icon(
                                      Icons.image_outlined,
                                      size: 28,
                                      color: AppColors.textMuted,
                                    )
                                  : Image.file(
                                      File(_posterPreviewPath!),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Afiş görseli',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _posterUploading
                                      ? 'Görsel yükleniyor...'
                                      : _posterAssetId != null
                                      ? 'Afiş hazır, değiştirmek için dokun'
                                      : 'Galeriden etkinlik afişi seç',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_posterUploading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.cloud_upload_outlined,
                              size: 22,
                              color: AppColors.textMuted,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Performer'),
                  _fieldFrame(
                    active: _performerFocusNode.hasFocus,
                    child: TextField(
                      controller: _performerController,
                      focusNode: _performerFocusNode,
                      onChanged: (value) {
                        final trimmed = value.trim();
                        if (_selectedMusicianId != null &&
                            trimmed != (_selectedMusicianLabel ?? '').trim()) {
                          _selectedMusicianId = null;
                          _selectedMusicianLabel = null;
                        }
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 320),
                          () => _runSearch(trimmed),
                        );
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Çalacak sanatçı / grup',
                        hintText: 'İsim yaz, eşleşirse profile bağlanır',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 14, right: 10),
                          child: Icon(
                            Icons.search,
                            size: 19,
                            color: AppColors.textMuted,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        suffixIcon: _selectedMusicianId != null
                            ? _gradientIcon(Icons.verified_rounded)
                            : null,
                      ),
                    ),
                  ),
                  if (_selectedMusicianId != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (_selectedMusicianId == null ||
                            _selectedMusicianId!.isEmpty) {
                          return;
                        }
                        Navigator.of(context).pushNamed(
                          AppRoutes.musicianPublicProfile,
                          arguments: {
                            'profileId': _selectedMusicianId,
                            'viewerUserId': widget.ownerProfile.ownerUserId,
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navBlueDeep.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.navBlueSoft,
                              backgroundImage: _selectedMusicianImageUrl != null &&
                                      _selectedMusicianImageUrl!.startsWith(
                                        'http',
                                      )
                                  ? NetworkImage(_selectedMusicianImageUrl!)
                                  : null,
                              child: _selectedMusicianImageUrl == null ||
                                      !_selectedMusicianImageUrl!.startsWith(
                                        'http',
                                      )
                                  ? const Icon(
                                      Icons.person_outline,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedMusicianLabel ??
                                        'SoundConnect Profili',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (_selectedMusicianSecondaryLabel != null)
                                    Text(
                                      _selectedMusicianSecondaryLabel!,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _gradientIcon(Icons.open_in_new_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_searchLoading) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 2),
                  ] else if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 190),
                      decoration: BoxDecoration(
                        color: AppColors.navBlueDeep.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            onTap: () {
                              _performerController.text = item.displayName;
                              _performerController.selection =
                                  TextSelection.collapsed(
                                    offset: _performerController.text.length,
                                  );
                              setState(() {
                                _selectedMusicianId = item.profileId;
                                _selectedMusicianLabel = item.displayName;
                                _selectedMusicianSecondaryLabel =
                                    item.secondaryLabel;
                                _selectedMusicianImageUrl =
                                    item.profilePictureUrl;
                                _searchResults = const [];
                                _searchError = null;
                              });
                            },
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.navBlueSoft,
                              backgroundImage: item.profilePictureUrl != null &&
                                      item.profilePictureUrl!.startsWith('http')
                                  ? NetworkImage(item.profilePictureUrl!)
                                  : null,
                              child: item.profilePictureUrl == null ||
                                      !item.profilePictureUrl!.startsWith(
                                        'http',
                                      )
                                  ? const Icon(
                                      Icons.person_outline,
                                      color: AppColors.textMuted,
                                    )
                                  : null,
                            ),
                            title: Text(
                              item.displayName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: item.secondaryLabel == null
                                ? null
                                : Text(
                                    item.secondaryLabel!,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  ] else if (_searchError != null &&
                      _performerController.text.trim().length >= 2) ...[
                    const SizedBox(height: 8),
                    Text(
                      _searchError!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Tarih ve saat'),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _pickDate,
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navBlueDeep.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          _gradientIcon(Icons.event_outlined, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                    ? 'Tarih seç'
                                    : formatVenueEventDate(_selectedDate!),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _timeField(
                        label: 'Başlangıç saati',
                        icon: Icons.schedule_outlined,
                        value: _startTime == null
                            ? 'Saat seç'
                            : _formatTimeValue(_startTime!),
                        onTap: () => _pickTime(isStart: true),
                      ),
                      const SizedBox(width: 10),
                      _timeField(
                        label: 'Bitiş saati',
                        icon: Icons.timer_outlined,
                        value: _endTime == null
                            ? 'Opsiyonel'
                            : _formatTimeValue(_endTime!),
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Bitiş saati girmezsen etkinlik tek saat üzerinden oluşturulur.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Açıklama'),
                  _fieldFrame(
                    active: _descriptionFocusNode.hasFocus,
                    child: TextField(
                      controller: _descriptionController,
                      focusNode: _descriptionFocusNode,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Kısa açıklama, sahne akışı veya özel notlar',
                        contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: FilledButton.icon(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.textPrimary,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _gradientIcon(Icons.save_outlined),
                label: const Text(
                  'Etkinliği Kaydet',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientOutlinePainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;

  const _GradientOutlinePainter({
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientOutlinePainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}



