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

  VenueWeeklyCalendarEditorScreen({super.key, required this.ownerProfile});

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
  List<VenueOwnerEventItem> _events = [];

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
      final items = result.data ?? <VenueOwnerEventItem>[];
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) =>
          _VenueEventDraftSheet(ownerProfile: widget.ownerProfile),
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
      ).showSnackBar(SnackBar(content: Text('Etkinlik eklendi.')));
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
      ).showSnackBar(SnackBar(content: Text('Etkinlik silindi.')));
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
        title: Text('Haftalik Takvim'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _loadEvents,
            icon: Icon(Icons.refresh_rounded),
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
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                        Theme.of(context).colorScheme.surfaceContainer,
                      ],
                    ),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GradientText(
                        text: widget.ownerProfile.venueName,
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: AppColors.brandGradient,
                        ),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Bu ekrandan haftalik takvime yeni etkinlik ekleyebilir ve mevcut etkinlikleri silebilirsin.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                if (_loading)
                  Expanded(child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
