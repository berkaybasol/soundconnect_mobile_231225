import 'package:flutter/material.dart';

import 'venue_event_item.dart';

String eventPlanDate(DateTime value) => formatVenueApiDate(value);

/// Private owner/performer management data. Never used as a public EVENT id.
class EventPlanTemplate {
  const EventPlanTemplate({
    required this.title,
    this.description = '',
    required this.startTime,
    this.endTime,
    this.posterImage,
    this.musicianProfileId,
    this.bandId,
    this.manualPerformerName,
  });
  final String title, description, startTime;
  final String? endTime,
      posterImage,
      musicianProfileId,
      bandId,
      manualPerformerName;

  factory EventPlanTemplate.fromDraft(VenueEventDraft draft) =>
      EventPlanTemplate(
        title: draft.title,
        description: draft.description,
        startTime: formatVenueApiTime(draft.startTime),
        endTime: draft.endTime == null
            ? null
            : formatVenueApiTime(draft.endTime!),
        posterImage: draft.posterImage,
        musicianProfileId: draft.musicianProfileId,
        bandId: draft.bandId,
        manualPerformerName: draft.manualPerformerName,
      );

  VenueEventDraft toDraft(DateTime date) => VenueEventDraft(
    title: title,
    description: description,
    eventDate: date,
    startTime: _time(startTime)!,
    endTime: _time(endTime),
    posterImage: posterImage,
    musicianProfileId: musicianProfileId,
    bandId: bandId,
    manualPerformerName: manualPerformerName,
  );

  static TimeOfDay? _time(String? raw) {
    if (raw == null) return null;
    final fields = raw.split(':');
    return TimeOfDay(hour: int.parse(fields[0]), minute: int.parse(fields[1]));
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'description': description,
    'startTime': startTime,
    'endTime': endTime,
    'posterImage': posterImage,
    'musicianProfileId': musicianProfileId,
    'bandId': bandId,
    'manualPerformerName': manualPerformerName,
  };
}

class EventPlanDefinition {
  // These are API calendar dates, not instants. Keep the chosen calendar day
  // even when a draft was initialized from DateTime.now or a UTC DateTime.
  EventPlanDefinition({
    required this.venueId,
    required DateTime startDate,
    required DateTime? untilDate,
    required Iterable<int> weekdays,
    required Iterable<DateTime> excludedDates,
    required this.template,
  }) : startDate = DateUtils.dateOnly(startDate),
       untilDate = untilDate == null ? null : DateUtils.dateOnly(untilDate),
       weekdays = List.unmodifiable(weekdays),
       excludedDates = List.unmodifiable(excludedDates.map(DateUtils.dateOnly));
  final String venueId;
  final DateTime startDate;
  final DateTime? untilDate;
  final List<int> weekdays;
  final List<DateTime> excludedDates;
  final EventPlanTemplate template;

  EventPlanDefinition withExclusions(Iterable<DateTime> dates) =>
      EventPlanDefinition(
        venueId: venueId,
        startDate: startDate,
        untilDate: untilDate,
        weekdays: weekdays,
        excludedDates: dates,
        template: template,
      );
  Map<String, Object?> toJson() => {
    'venueId': venueId,
    'startDate': eventPlanDate(startDate),
    'untilDate': untilDate == null ? null : eventPlanDate(untilDate!),
    'weekdays': weekdays,
    'excludedDates': excludedDates.map(eventPlanDate).toList(),
    'template': template.toJson(),
  };
  String get scheduleLabel {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final ordered = weekdays.toList()..sort();
    return '${ordered.map((day) => days[day - 1]).join(', ')} · '
        '${formatVenueEventDate(startDate)} – '
        '${untilDate == null ? 'Ben durdurana kadar' : formatVenueEventDate(untilDate!)}';
  }
}

class EventPlan {
  const EventPlan({
    required this.id,
    required this.version,
    required this.definition,
    required this.venueName,
    required this.performerName,
    this.posterUrl,
    required this.status,
    required this.consentStatus,
    required this.showOnProfile,
    this.generatedThrough,
    required this.serverNow,
    required this.decisionAllowed,
    required this.withdrawAllowed,
  });
  final String id, venueName, performerName, status, consentStatus;
  final int version;
  final EventPlanDefinition definition;
  final String? posterUrl;
  final DateTime? generatedThrough;
  final DateTime serverNow;
  final bool showOnProfile, decisionAllowed, withdrawAllowed;
  bool get active => status == 'ACTIVE';
  String get statusLabel => switch (status) {
    'STOPPED' => 'Durduruldu',
    'COMPLETED' => 'Tamamlandı',
    _ => 'Aktif',
  };
  String get consentLabel => switch (consentStatus) {
    'PENDING' => 'Sanatçı onayı bekleniyor',
    'ACCEPTED' => 'Katılım onaylandı',
    'REJECTED' => 'Davet reddedildi',
    'WITHDRAWN' => 'Katılım onayı geri çekildi',
    _ => 'Manuel sanatçı bilgisi',
  };
}

class EventPlanPreview {
  const EventPlanPreview({
    required this.dates,
    required this.throughDate,
    required this.hasMore,
    required this.serverNow,
    this.preservedDates = const [],
  });
  final List<DateTime> dates;
  final DateTime throughDate, serverNow;
  final bool hasMore;
  final List<EventPlanPreservedDate> preservedDates;
}

/// Read-only exceptions retained when the remaining program is edited.
class EventPlanPreservedDate {
  const EventPlanPreservedDate({
    required this.scheduledDate,
    required this.eventDate,
    required this.status,
  });
  final DateTime scheduledDate, eventDate;
  final String status;
}

class EventPlanOccurrence {
  const EventPlanOccurrence({
    required this.scheduledDate,
    required this.eventDate,
    required this.status,
    this.eventId,
    this.event,
    this.template,
  });
  final DateTime scheduledDate, eventDate;
  final String status;
  final String? eventId;
  final VenueOwnerEventItem? event;

  /// Raw mutation references; event.posterImage is a resolved display URL.
  final EventPlanTemplate? template;
  bool get prepared =>
      eventId != null && (status == 'GENERATED' || status == 'OVERRIDDEN');
}

class EventPlanPage<T> {
  const EventPlanPage({
    required this.items,
    required this.page,
    required this.hasNext,
  });
  final List<T> items;
  final int page;
  final bool hasNext;
}
