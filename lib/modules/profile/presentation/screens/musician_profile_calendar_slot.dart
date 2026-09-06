import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/musician_calendar.dart';
import '../../domain/entities/venue_event_detail.dart';
import '../../domain/musician_calendar_repository.dart';
import 'profile_section_support.dart';
import 'weekly_event_carousel.dart';
import 'weekly_event_detail_screen.dart';

/// Only server-authorized events produce a calendar section. Venue connections
/// remain in the caller's layout, including when no events are published.
class MusicianProfileCalendarSlot extends StatefulWidget {
  const MusicianProfileCalendarSlot({
    super.key,
    required this.profileId,
    this.refreshToken,
    this.compactTitle = false,
    this.repository,
  });

  final String profileId;
  final Object? refreshToken;
  final bool compactTitle;
  final MusicianCalendarRepository? repository;

  @override
  State<MusicianProfileCalendarSlot> createState() =>
      _MusicianProfileCalendarSlotState();
}

class _MusicianProfileCalendarSlotState
    extends State<MusicianProfileCalendarSlot>
    with WidgetsBindingObserver {
  MusicianCalendarRepository? _repository;
  StreamSubscription<void>? _subscription;
  MusicianCalendarPage? _page;
  List<VenueEventDetail> _events = const [];
  bool _loading = true;
  int _request = 0;
  DateTime? _lastLoad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindRepository();
  }

  void _bindRepository() {
    _subscription?.cancel();
    _repository =
        widget.repository ??
        (serviceLocator.isRegistered<MusicianCalendarRepository>()
            ? serviceLocator<MusicianCalendarRepository>()
            : null);
    _subscription = _repository?.changes.listen((_) => _load());
    _load();
  }

  @override
  void didUpdateWidget(covariant MusicianProfileCalendarSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _bindRepository();
    } else if (oldWidget.profileId != widget.profileId ||
        oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_lastLoad == null ||
            DateTime.now().difference(_lastLoad!) >=
                const Duration(seconds: 15))) {
      _load();
    }
  }

  Future<void> _load({int? targetPage}) async {
    final repository = _repository;
    if (repository == null) return;
    final navigating = targetPage != null;
    if (navigating &&
        (_loading ||
            _page == null ||
            targetPage < 0 ||
            targetPage > 100 ||
            (targetPage - _page!.page).abs() != 1 ||
            (targetPage > _page!.page && !_page!.hasNext))) {
      return;
    }
    final request = ++_request;
    final profileId = widget.profileId;
    final nextPage = targetPage ?? 0;
    final today = DateTime.now();
    final start = navigating
        ? _page!.startDate
        : DateTime.utc(today.year, today.month, today.day);
    final end = navigating
        ? _page!.endDate
        : start.add(const Duration(days: 6));
    _lastLoad = today;
    setState(() {
      _loading = true;
      // Per-event publication permissions may have changed since the previous
      // read. Never carry older pages into a fresh eligibility snapshot.
      _page = null;
      _events = const [];
    });
    try {
      final result = await repository.getCalendar(
        profileId: profileId,
        startDate: start,
        endDate: end,
        page: nextPage,
      );
      if (!mounted || request != _request || profileId != widget.profileId) {
        return;
      }
      final page = result.data;
      if (!result.isSuccess || page == null || page.profileId != profileId) {
        setState(() {
          _loading = false;
          // Even on a failed pagination read the latest visibility is unknown.
          _events = const [];
          _page = null;
        });
        return;
      }
      if (page.visible &&
          page.events.isEmpty &&
          !page.hasNext &&
          nextPage > 0) {
        // Concurrent deletion/revocation can exhaust a page. Return to a fresh
        // first page once instead of stranding the user beyond the current end.
        await _load();
        return;
      }
      setState(() {
        _loading = false;
        _page = page;
        _events = page.visible ? page.events : const [];
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _page = null;
        _events = const [];
      });
    }
  }

  @override
  void dispose() {
    ++_request;
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (_repository == null ||
        page == null ||
        !page.visible ||
        _events.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const Key('musician-weekly-calendar'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        ProfileSectionHeader(title: 'Haftalık Takvim'),
        WeeklyEventCarousel(
          key: ValueKey('calendar-page:${widget.profileId}:${page.page}'),
          items: _events.map(_toWeeklyEvent).toList(growable: false),
          compactTitle: widget.compactTitle,
        ),
        if (page.page > 0 || (page.hasNext && page.page < 100))
          Center(
            child: Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (page.page > 0)
                  TextButton(
                    key: const Key('musician-calendar-previous'),
                    onPressed: _loading
                        ? null
                        : () => _load(targetPage: page.page - 1),
                    child: const Text('Önceki etkinlikler'),
                  ),
                if (page.hasNext && page.page < 100)
                  TextButton(
                    key: const Key('musician-calendar-more'),
                    onPressed: _loading
                        ? null
                        : () => _load(targetPage: page.page + 1),
                    child: const Text('Sonraki etkinlikler'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  WeeklyCalendarEvent _toWeeklyEvent(VenueEventDetail event) {
    final date = event.eventDate!;
    return WeeklyCalendarEvent(
      id: event.id,
      title: event.title!,
      artistName: event.performerName!,
      artistProfileId: event.musicianProfileId,
      bandProfileId: event.bandId,
      performerType: event.performerType,
      venueName: event.venueName!,
      venueId: event.venueId,
      city: event.venueCity ?? '',
      district: event.venueDistrict ?? '',
      neighborhood: event.venueNeighborhood ?? '',
      eventDate:
          '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.${date.year}',
      startTime: event.startTime!.substring(0, 5),
      endTime: event.endTime?.substring(0, 5) ?? '-',
      imageAssetPath: event.posterImage,
      description: event.description ?? '',
    );
  }
}
