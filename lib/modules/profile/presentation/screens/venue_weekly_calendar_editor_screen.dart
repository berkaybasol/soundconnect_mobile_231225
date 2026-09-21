import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/soundconnect_date_picker.dart';
import '../../domain/entities/profile_search_result.dart';
import '../../domain/profile_search_repository.dart';
import '../../domain/venue_event_repository.dart';
import '../../domain/entities/venue_owner_profile.dart';
import '../../domain/entities/event_plan.dart';
import '../../domain/event_plan_repository.dart';
import 'event_plan_date_label.dart';
import 'event_plan_preview_sheet.dart';
import 'venue_event_plan_screen.dart';
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
part 'venue_event_draft_recurrence.dart';
part 'venue_event_management_sections.dart';

Future<bool?> showVenueEventDraft(
  BuildContext context, {
  required VenueOwnerProfile ownerProfile,
  required Future<Result<void>> Function(VenueEventDraft) onSave,
  Future<Result<void>> Function(EventPlanDefinition, String)? onPlanSave,
  VenueEventDraft? initialDraft,
  EventPlanDefinition? initialPlan,
  bool initiallyRepeating = false,
  String? editingPlanId,
  int? editingPlanVersion,
  String? performerName,
  String? posterUrl,
  String title = 'Yeni etkinlik',
  String submitLabel = 'Etkinliği Oluştur',
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .72),
  builder: (_) => AppSurfaceThemeScope(
    child: _VenueEventDraftSheet(
      ownerProfile: ownerProfile,
      onSave: onSave,
      onPlanSave: onPlanSave,
      initialDraft: initialDraft,
      initialPlan: initialPlan,
      initiallyRepeating: initiallyRepeating,
      editingPlanId: editingPlanId,
      editingPlanVersion: editingPlanVersion,
      performerName: performerName,
      posterUrl: posterUrl,
      title: title,
      submitLabel: submitLabel,
    ),
  ),
);

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
    extends State<VenueWeeklyCalendarEditorScreen>
    with WidgetsBindingObserver {
  final _venueEventRepository = serviceLocator<VenueEventRepository>();
  AuthSessionManager? _managementSessions;
  Object? _managementSession;
  ModalRoute<dynamic>? _deleteDialog;
  bool _confirmingDelete = false;
  bool _loading = true;
  bool _saving = false;
  bool _draftOpen = false;
  bool _changed = false;
  int _loadGeneration = 0;
  String? _error;
  List<VenueOwnerEventItem> _events = [];
  List<VenueOwnerEventItem> _historyEvents = [];
  DateTime? _historyAsOf;
  int _pastEventCount = 0;
  String? _historyNextCursor;
  String? _historyError;
  bool _historyLoaded = false;
  bool _historyLoading = false;
  bool _historyHasNext = false;
  int _historyGeneration = 0;
  EventPlanPage<EventPlan>? _plans;
  String? _plansError;
  bool _plansLoading = false;
  int _plansGeneration = 0;
  int _requestedPlansPage = 0;
  int _managementTab = 0;
  Set<_EventGroup>? _expandedEventGroups;
  bool _planHistoryExpanded = false;

  void _selectManagementTab(int index) =>
      setState(() => _managementTab = index);

  void _toggleEventGroup(_EventGroup group) {
    setState(() {
      final expanded = _expandedEventGroups ??= <_EventGroup>{};
      if (!expanded.remove(group)) expanded.add(group);
    });
    if (group == _EventGroup.past &&
        _expandedEventGroups!.contains(group) &&
        !_historyLoaded) {
      unawaited(_loadHistory(reset: true));
    }
  }

  void _togglePlanHistory() =>
      setState(() => _planHistoryExpanded = !_planHistoryExpanded);

  Future<void> _refreshManagement() => _loadEvents();
  EventPlanRepository? get _planRepository =>
      serviceLocator.isRegistered<EventPlanRepository>()
      ? serviceLocator<EventPlanRepository>()
      : null;

  bool get _ownsSession {
    final sessions = _managementSessions;
    if (sessions == null) return true;
    final session = sessions.session;
    return identical(session, _managementSession) &&
        session.isAuthenticated &&
        session.isActive &&
        session.userId == widget.ownerProfile.ownerUserId;
  }

  String get _profileName => widget.ownerProfile.venueName;
  String? get _profileImage => widget.ownerProfile.profilePictureUrl;

  List<VenueOwnerEventItem> get _upcomingEvents {
    // The server classifies ongoing/upcoming and past at the same instant.
    final items = List<VenueOwnerEventItem>.of(_events);
    items.sort(_compareEventsChronologically);
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
    _managementSessions = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    _managementSession = _managementSessions?.session;
    _managementSessions?.addListener(_managementSessionChanged);
    WidgetsBinding.instance.addObserver(this);
    if (_ownsSession) {
      _loadEvents();
    } else {
      _managementSessionChanged();
    }
  }

  void _managementSessionChanged() {
    if (!mounted || _ownsSession) return;
    ++_loadGeneration;
    ++_plansGeneration;
    final dialog = _deleteDialog;
    if (dialog?.isActive == true) dialog!.navigator?.removeRoute(dialog);
    _deleteDialog = null;
    setState(() {
      _events = [];
      _clearHistory();
      _plans = null;
      _loading = false;
      _plansLoading = false;
      _saving = false;
      _confirmingDelete = false;
      _error = 'Oturum değişti. Etkinlik yönetimini yeniden aç.';
      _plansError = _error;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _ownsSession &&
        !_saving &&
        !_draftOpen &&
        !_confirmingDelete &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(_loadEvents());
    }
  }

  Future<void> _loadEvents({int? planPage}) async {
    if (!_ownsSession) return;
    final plansLoad = _loadPlans(page: planPage ?? _requestedPlansPage);
    final generation = ++_loadGeneration;
    // Invalidate a pending history page before requesting a new cutoff.
    ++_historyGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _historyLoading = false;
    });
    try {
      if (!_ownsSession) {
        throw 'Oturum değişti. Etkinlik yönetimini yeniden aç.';
      }
      final result = await _venueEventRepository.loadManagement(
        widget.ownerProfile.venueId,
      );
      if (!result.isSuccess || result.data == null) {
        throw result.error?.message ?? 'Etkinlikler alınamadı';
      }
      final snapshot = result.data!;
      final items = snapshot.upcomingEvents;
      if (!mounted || generation != _loadGeneration) return;
      if (!_ownsSession) {
        throw 'Oturum değişti. Etkinlik yönetimini yeniden aç.';
      }
      setState(() {
        _events = items;
        _loading = false;
        _historyAsOf = snapshot.historyAsOf;
        _pastEventCount = snapshot.pastCount;
        _historyNextCursor = null;
        _historyHasNext = false;
        _historyError = null;
        _historyLoaded = snapshot.pastCount == 0;
        if (_historyLoaded ||
            _expandedEventGroups?.contains(_EventGroup.past) != true) {
          _historyEvents = [];
        }
        final now = DateTime.now();
        _expandedEventGroups ??= {
          items.any((item) => !isVenueEventBeyondWeek(item.eventDate, now: now))
              ? _EventGroup.thisWeek
              : _EventGroup.future,
        };
      });
      if (_expandedEventGroups!.contains(_EventGroup.past) && !_historyLoaded) {
        await _loadHistory(reset: true);
      }
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = 'Etkinlikler alınamadı: $e';
        if (!_ownsSession) {
          _events = [];
          _clearHistory();
        } else if (_historyAsOf != null && !_historyLoaded) {
          _historyError = 'Geçmiş etkinlikler yüklenemedi. Yeniden dene.';
        }
      });
    }
    await plansLoad;
  }

  void _clearHistory() {
    ++_historyGeneration;
    _historyEvents = [];
    _historyAsOf = null;
    _pastEventCount = 0;
    _historyNextCursor = null;
    _historyError = null;
    _historyLoaded = false;
    _historyLoading = false;
    _historyHasNext = false;
  }

  Future<void> _loadHistory({bool reset = false}) async {
    final asOf = _historyAsOf;
    if (_loading || _historyLoading || !_ownsSession || asOf == null) {
      return;
    }
    if (!reset && !_historyHasNext) return;
    final cursor = reset ? null : _historyNextCursor;
    final generation = ++_historyGeneration;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final result = await _venueEventRepository.loadHistory(
        widget.ownerProfile.venueId,
        asOf: asOf,
        cursor: cursor,
      );
      if (!mounted || generation != _historyGeneration) return;
      if (!_ownsSession) {
        setState(() {
          _events = [];
          _clearHistory();
        });
        return;
      }
      final page = result.data;
      if (!result.isSuccess || page == null) {
        throw result.error?.message ?? 'Geçmiş etkinlikler alınamadı.';
      }
      if (page.hasNext &&
          (page.nextCursor == null || page.nextCursor == cursor)) {
        throw 'Geçmiş etkinlikler alınamadı. Yeniden dene.';
      }
      setState(() {
        final items = reset
            ? <VenueOwnerEventItem>[]
            : List<VenueOwnerEventItem>.of(_historyEvents);
        final knownIds = items.map((item) => item.id).toSet();
        for (final item in page.items) {
          if (knownIds.add(item.id)) items.add(item);
        }
        _historyEvents = items;
        _historyNextCursor = page.nextCursor;
        _historyHasNext = page.hasNext;
        _historyLoaded = true;
        _historyLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _historyGeneration) return;
      setState(() {
        if (!_ownsSession) {
          _events = [];
          _clearHistory();
        } else {
          _historyLoading = false;
          _historyError = error.toString();
        }
      });
    }
  }

  Future<void> _createEvent({bool asPlan = false}) async {
    if (_saving || _loading || _draftOpen || !_ownsSession) return;
    _draftOpen = true;
    try {
      await showVenueEventDraft(
        context,
        ownerProfile: widget.ownerProfile,
        onSave: _saveDraft,
        onPlanSave: _planRepository == null ? null : _savePlan,
        initiallyRepeating: asPlan,
        title: asPlan ? 'Yeni plan' : 'Yeni etkinlik',
      );
    } finally {
      _draftOpen = false;
    }
    if (mounted) await _loadEvents();
  }

  Future<Result<void>> _savePlan(
    EventPlanDefinition definition,
    String requestId,
  ) async {
    if (_saving || !_ownsSession) {
      return const Result.failure(
        AppError(
          code: 'event_plan_session_changed',
          message: 'Oturum değişti. Planı yeniden aç.',
        ),
      );
    }
    setState(() => _saving = true);
    try {
      final result = await _planRepository!.create(requestId, definition);
      if (!_ownsSession) {
        return const Result.failure(
          AppError(
            code: 'event_plan_session_changed',
            message: 'Oturum değişti.',
          ),
        );
      }
      if (!result.isSuccess) return Result.failure(result.error);
      _changed = true;
      _requestedPlansPage = 0;
      if (mounted) setState(() => _managementTab = 1);
      return const Result.success(null);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyEvent(VenueOwnerEventItem item) async {
    final repository = _planRepository;
    if (repository == null || _saving || _draftOpen || !_ownsSession) return;
    setState(() => _saving = true);
    Result<VenueEventDraft> result;
    try {
      result = await repository.copySource(
        item.id,
        widget.ownerProfile.venueId,
      );
    } catch (_) {
      result = const Result.failure(
        AppError(
          code: 'event_copy_unknown',
          message: 'Etkinlik bilgileri alınamadı. Tekrar dene.',
        ),
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!_ownsSession) return;
    final source = result.data;
    if (!result.isSuccess || source == null) {
      showVenueEventFeedback(
        context,
        result.error?.message ?? 'Etkinlik bilgileri alınamadı.',
        isError: true,
      );
      return;
    }
    final initial = VenueEventDraft(
      title: source.title,
      description: source.description,
      eventDate: DateTime.now(),
      startTime: source.startTime,
      endTime: source.endTime,
      posterImage: source.posterImage,
      musicianProfileId: source.musicianProfileId,
      bandId: source.bandId,
      manualPerformerName: source.manualPerformerName,
    );
    _draftOpen = true;
    try {
      await showVenueEventDraft(
        context,
        ownerProfile: widget.ownerProfile,
        onSave: _saveDraft,
        onPlanSave: _savePlan,
        initialDraft: initial,
        performerName: item.performerName,
        posterUrl: item.posterImage,
        title: 'Etkinliği tekrarla',
      );
    } finally {
      _draftOpen = false;
    }
    if (mounted) await _loadEvents();
  }

  Future<void> _loadPlans({int page = 0}) async {
    final repository = _planRepository;
    if (repository == null || !_ownsSession) return;
    final generation = ++_plansGeneration;
    setState(() {
      _plansLoading = true;
      _plansError = null;
      _requestedPlansPage = page;
    });
    try {
      final result = await repository.listOwner(
        widget.ownerProfile.venueId,
        page: page,
      );
      if (!mounted || generation != _plansGeneration || !_ownsSession) return;
      setState(() {
        _plansLoading = false;
        _plans = result.data;
        _plansError = result.isSuccess
            ? null
            : result.error?.message ?? 'Planlar alınamadı.';
      });
    } catch (_) {
      if (mounted && generation == _plansGeneration) {
        setState(() {
          _plansLoading = false;
          _plans = null;
          _plansError = 'Planlar alınamadı.';
        });
      }
    }
  }

  Future<void> _openPlan(EventPlan plan) async {
    if (_saving || !_ownsSession) return;
    final page = _requestedPlansPage;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VenueEventPlanScreen(
          planId: plan.id,
          ownerProfile: widget.ownerProfile,
        ),
      ),
    );
    _changed = true;
    if (mounted) await _loadEvents(planPage: page);
  }

  Widget _ownerPlanCard(EventPlan plan) {
    final theme = appSurfaceTheme(Theme.of(context));
    final scheme = theme.colorScheme;
    final definition = plan.definition;
    final days = definition.weekdays.toList()..sort();
    final status = switch (plan.status) {
      'STOPPED' => 'Plan durduruldu',
      'COMPLETED' => 'Plan tamamlandı',
      _ => 'Plan aktif',
    };
    final participation = switch (plan.consentStatus) {
      'PENDING' => 'Sanatçı katılımı: Onay bekleniyor',
      'ACCEPTED' => 'Sanatçı katılımı: Onaylandı',
      'REJECTED' => 'Sanatçı katılımı: Davet reddedildi',
      'WITHDRAWN' => 'Sanatçı katılımı: Onay geri çekildi',
      _ => 'Sanatçı bilgisi: Profil daveti yok',
    };
    final accent = plan.active
        ? AppColors.brandGradient[2]
        : scheme.onSurfaceVariant;
    final enabled = !_saving && !_plansLoading && _ownsSession;
    return Theme(
      data: theme,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('owner-event-plan-${plan.id}'),
          onTap: enabled ? () => _openPlan(plan) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.definition.template.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${days.map((day) => eventPlanWeekdayNames[day - 1]).join(', ')}\n'
                  '${formatVenueDisplayTime(definition.template.startTime)}'
                  '${definition.template.endTime == null ? '' : ' – ${formatVenueDisplayTime(definition.template.endTime!)}'}\n'
                  '${eventPlanDateLabel(definition.startDate, includeWeekday: false)} – '
                  '${definition.untilDate == null ? 'Ben durdurana kadar' : eventPlanDateLabel(definition.untilDate!, includeWeekday: false)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: .32)),
                  ),
                  child: Text(
                    status,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 12),
                Text(
                  participation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (plan.consentStatus == 'PENDING') ...[
                  const SizedBox(height: 5),
                  Text(
                    'Sanatçı onayı beklenmesi etkinliklerin yayınını durdurmaz.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
      if (!_ownsSession) {
        return const Result.failure(
          AppError(code: 'event_session_changed', message: 'Oturum değişti.'),
        );
      }
      if (!result.isSuccess) return result;
      _changed = true;
      if (!mounted) return const Result.success(null);
      setState(() => _managementTab = 0);
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
      if (!mounted || !_ownsSession) return;
      if (!result.isSuccess) throw result.error?.message ?? 'Delete failed';
      _changed = true;
      if (!mounted) return;
      showVenueEventFeedback(context, 'Etkinlik silindi.');
      await _loadEvents();
    } catch (e) {
      if (!mounted || !_ownsSession) return;
      showVenueEventFeedback(context, 'Etkinlik silinemedi: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _canDelete(VenueOwnerEventItem item) =>
      _ownsSession && item.eventOrigin == 'VENUE';

  Future<void> _confirmDeleteEvent(VenueOwnerEventItem item) async {
    if (_saving || _confirmingDelete || !_canDelete(item)) return;
    _confirmingDelete = true;
    final confirmed = await confirmVenueEventDeletion(
      context,
      item.title,
      onRoute: (route) => _deleteDialog = route,
    );
    _deleteDialog = null;
    _confirmingDelete = false;
    if (confirmed == true && mounted) await _deleteEvent(item);
  }

  void _openEvent(VenueOwnerEventItem item) {
    if (!_ownsSession) return;
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
  void dispose() {
    ++_loadGeneration;
    ++_historyGeneration;
    ++_plansGeneration;
    _managementSessions?.removeListener(_managementSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppSurfaceThemeScope(child: Builder(builder: _buildEditor));
}
