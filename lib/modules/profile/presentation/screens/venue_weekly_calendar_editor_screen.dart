import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/soundconnect_date_picker.dart';
import '../../domain/entities/profile_search_result.dart';
import '../../domain/profile_search_repository.dart';
import '../../domain/venue_event_repository.dart';
import '../../domain/entities/venue_owner_profile.dart';
import 'band_profile_screen.dart';
import 'profile_screen_support.dart';
import 'venue_event_management_widgets.dart';
import 'venue_event_support.dart';
import 'venue_event_action_feedback.dart';
import 'venue_future_event_notice.dart';
import 'weekly_event_detail_screen.dart';

part 'venue_weekly_calendar_editor_screen_draft_sheet.dart';
part 'venue_weekly_calendar_editor_screen_draft_sheet_constants.dart';
part 'venue_weekly_calendar_editor_screen_draft_sheet_methods.dart';
part 'venue_weekly_calendar_editor_screen_draft_sheet_methods_time_media.dart';
part 'venue_weekly_calendar_editor_screen_draft_sheet_ui_helpers.dart';
part 'venue_weekly_calendar_editor_screen_draft_sheet_sections.dart';
part 'venue_weekly_calendar_editor_screen_draft_sheet_sections_performer.dart';
part 'venue_weekly_calendar_editor_screen_painter.dart';

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
  bool _draftOpen = false;
  bool _changed = false;
  int _loadGeneration = 0;
  String? _error;
  List<VenueOwnerEventItem> _events = [];

  bool get _ownsSession {
    if (!serviceLocator.isRegistered<AuthSessionManager>()) return true;
    final userId = serviceLocator<AuthSessionManager>().session.userId;
    return userId != null &&
        userId.isNotEmpty &&
        userId == widget.ownerProfile.ownerUserId;
  }

  String get _profileName => widget.ownerProfile.venueName;
  String? get _profileImage => widget.ownerProfile.profilePictureUrl;

  List<VenueOwnerEventItem> get _upcomingEvents {
    final items = _events.where((item) => !isVenueEventPast(item)).toList();
    items.sort(_compareEventsChronologically);
    return items;
  }

  List<VenueOwnerEventItem> get _pastEvents {
    final items = _events.where(isVenueEventPast).toList();
    items.sort((a, b) => _compareEventsChronologically(b, a));
    return items;
  }

  int _compareEventsChronologically(
    VenueOwnerEventItem a,
    VenueOwnerEventItem b,
  ) {
    final dateCompare = a.eventDate.compareTo(b.eventDate);
    if (dateCompare != 0) return dateCompare;
    return a.startTime.compareTo(b.startTime);
  }

  String get _locationLabel {
    return [widget.ownerProfile.districtName, widget.ownerProfile.cityName]
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) {
          return item.isNotEmpty;
        })
        .join(' • ');
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_ownsSession) {
        throw 'Oturum değişti. Etkinlik yönetimini yeniden aç.';
      }
      final result = await _venueEventRepository.listByVenue(
        widget.ownerProfile.venueId,
      );
      if (!result.isSuccess) {
        throw result.error?.message ?? 'Etkinlikler alınamadı';
      }
      final items = result.data ?? <VenueOwnerEventItem>[];
      if (!mounted || generation != _loadGeneration) return;
      if (!_ownsSession) {
        throw 'Oturum değişti. Etkinlik yönetimini yeniden aç.';
      }
      setState(() {
        _events = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = 'Etkinlikler alınamadı: $e';
        if (!_ownsSession) _events = [];
      });
    }
  }

  Future<void> _createEvent() async {
    if (_saving || _loading || _draftOpen || !_ownsSession) return;
    _draftOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (sheetContext) => _VenueEventDraftSheet(
          ownerProfile: widget.ownerProfile,
          onSave: _saveDraft,
        ),
      );
    } finally {
      _draftOpen = false;
    }
    if (mounted) await _loadEvents();
  }

  Future<Result<void>> _saveDraft(VenueEventDraft draft) async {
    if (_saving || !mounted) {
      return const Result.failure(
        AppError(
          code: 'event_save_busy',
          message: 'İşlem tamamlanırken bekle.',
        ),
      );
    }
    setState(() => _saving = true);
    try {
      if (!_ownsSession) {
        return const Result.failure(
          AppError(
            code: 'event_session_changed',
            message: 'Oturum değişti. Etkinlik yönetimini yeniden aç.',
          ),
        );
      }
      final result = await _venueEventRepository.create(
        venueId: widget.ownerProfile.venueId,
        draft: draft,
      );
      if (!result.isSuccess) return result;
      _changed = true;
      if (!mounted) return const Result.success(null);
      showVenueEventFeedback(context, 'Etkinlik eklendi.');
      return const Result.success(null);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'event_create_unknown',
          message: 'Etkinliğin kayıt sonucu doğrulanamadı.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteEvent(VenueOwnerEventItem item) async {
    if (_saving || !_canDelete(item)) return;
    setState(() => _saving = true);
    try {
      if (!_ownsSession) {
        throw 'Oturum değişti. Etkinlik yönetimini yeniden aç.';
      }
      final result = await _venueEventRepository.delete(item.id);
      if (!result.isSuccess) throw result.error?.message ?? 'Delete failed';
      _changed = true;
      if (!mounted) return;
      showVenueEventFeedback(context, 'Etkinlik silindi.');
      await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      showVenueEventFeedback(context, 'Etkinlik silinemedi: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _canDelete(VenueOwnerEventItem item) => item.eventOrigin == 'VENUE';

  Future<void> _confirmDeleteEvent(VenueOwnerEventItem item) async {
    final confirmed = await confirmVenueEventDeletion(context, item.title);
    if (confirmed == true && mounted) await _deleteEvent(item);
  }

  void _openEvent(VenueOwnerEventItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WeeklyEventDetailScreen(event: _toWeeklyCalendarEvent(item)),
      ),
    );
  }

  String _eventTimeLabel(VenueOwnerEventItem item) {
    final start = formatVenueDisplayTime(item.startTime);
    final end = formatVenueDisplayTime(item.endTime ?? '');
    if (start.isEmpty) return 'Saat belirtilmedi';
    return end.isEmpty ? start : '$start – $end';
  }

  WeeklyCalendarEvent _toWeeklyCalendarEvent(VenueOwnerEventItem item) {
    return WeeklyCalendarEvent(
      id: item.id,
      title: item.title,
      artistName: item.performerName.trim().isEmpty
          ? 'Sanatçı'
          : item.performerName,
      artistProfileId: item.musicianProfileId,
      bandProfileId: item.bandId,
      performerType: item.performerType,
      venueName: _profileName,
      venueId: widget.ownerProfile.venueId,
      city: item.venueCity ?? widget.ownerProfile.cityName ?? '-',
      district: item.venueDistrict ?? widget.ownerProfile.districtName ?? '-',
      neighborhood:
          item.venueNeighborhood ?? widget.ownerProfile.neighborhoodName ?? '-',
      eventDate: formatVenueEventDate(item.eventDate),
      startTime: formatVenueDisplayTime(item.startTime),
      endTime: item.endTime == null || item.endTime!.trim().isEmpty
          ? '-'
          : formatVenueDisplayTime(item.endTime!),
      imageAssetPath: item.posterImage?.trim().isEmpty == true
          ? null
          : item.posterImage?.trim(),
      description: item.description?.trim() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navBlueDeep,
      appBar: AppBar(
        title: const Text('Haftalık Takvim'),
        backgroundColor: AppColors.navBlueDeep,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Etkinlikleri yenile',
            onPressed: _loading || _saving ? null : _loadEvents,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop || _saving) return;
          Navigator.of(context).pop(_changed);
        },
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: AppColors.coralAlt,
                    onRefresh: _saving ? () async {} : _loadEvents,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate(
                              _buildCalendarContent(
                                upcomingEvents: _upcomingEvents,
                                pastEvents: _pastEvents,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCalendarContent({
    required List<VenueOwnerEventItem> upcomingEvents,
    required List<VenueOwnerEventItem> pastEvents,
  }) {
    final isInitialLoad = _loading && _events.isEmpty;
    final now = DateTime.now();
    final thisWeek = upcomingEvents
        .where((event) => !isVenueEventBeyondWeek(event.eventDate, now: now))
        .toList();
    final future = upcomingEvents
        .where((event) => isVenueEventBeyondWeek(event.eventDate, now: now))
        .toList();
    return [
      VenueCalendarProfileHeader(
        imageUrl: _profileImage,
        venueName: _profileName,
        locationLabel: _locationLabel,
      ),
      const SizedBox(height: 22),
      VenueCalendarCreateButton(
        onTap: _loading || !_ownsSession ? null : _createEvent,
        saving: _saving,
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        VenueCalendarErrorCard(message: _error!, onRetry: _loadEvents),
      ],
      const SizedBox(height: 20),
      if (isInitialLoad)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 52),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        for (final section in [
          ('Bu Haftaki Etkinlikler', 'Bu hafta etkinlik yok.', thisWeek),
          ('Gelecek Etkinlikler', 'İleri tarihli etkinlik yok.', future),
        ]) ...[
          VenueCalendarHistoryHeader(
            title: section.$1,
            count: section.$3.length,
          ),
          const SizedBox(height: 10),
          if (section.$3.isEmpty)
            VenueCalendarEmptyState(history: false, message: section.$2)
          else
            for (final item in section.$3) ...[
              VenueCalendarEventCard(
                posterImage: item.posterImage,
                title: item.title,
                dateLabel: formatVenueEventDate(item.eventDate),
                timeLabel: _eventTimeLabel(item),
                performerName: item.performerName,
                onTap: () => _openEvent(item),
                saving: _saving || _loading,
                onDelete: _canDelete(item)
                    ? () => _confirmDeleteEvent(item)
                    : null,
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 26),
        ],
        VenueCalendarHistoryHeader(count: pastEvents.length),
        const SizedBox(height: 10),
        if (pastEvents.isEmpty)
          const VenueCalendarEmptyState(history: true)
        else
          for (final item in pastEvents) ...[
            VenueCalendarPastEventCard(
              posterImage: item.posterImage,
              title: item.title,
              dateLabel: formatVenueEventDate(item.eventDate),
              timeLabel: _eventTimeLabel(item),
              performerName: item.performerName,
              onTap: () => _openEvent(item),
              saving: _saving || _loading,
              onDelete: _canDelete(item)
                  ? () => _confirmDeleteEvent(item)
                  : null,
            ),
            const SizedBox(height: 10),
          ],
      ],
    ];
  }
}
