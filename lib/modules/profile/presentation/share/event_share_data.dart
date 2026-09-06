import '../../domain/entities/venue_event_detail.dart';

/// An immutable snapshot of the public event, never of private invitations.
class EventShareData {
  const EventShareData({
    required this.eventId,
    required this.title,
    required this.performerName,
    required this.performerLinked,
    required this.venueName,
    required this.location,
    this.description = '',
    this.eventDate,
    this.startTime = '',
    this.endTime = '',
    this.posterUrl,
    this.venueAvatarUrl,
    this.shareUrl,
  });

  factory EventShareData.fromDetail(
    VenueEventDetail detail, {
    String? venueAvatarUrl,
  }) => EventShareData(
    eventId: detail.id.trim(),
    title: _clean(detail.title).isEmpty ? 'Etkinlik' : _clean(detail.title),
    description: detail.description?.trim() ?? '',
    performerName: _clean(detail.performerName),
    performerLinked:
        detail.id.trim().isNotEmpty &&
        detail.performerIdentity.hasLinkedProfile,
    venueName: _clean(detail.venueName),
    location: [
      detail.venueDistrict,
      detail.venueCity,
    ].map(_clean).where((part) => part.isNotEmpty).toSet().join(' · '),
    eventDate: detail.eventDate,
    startTime: _time(detail.startTime),
    endTime: _time(detail.endTime),
    posterUrl: detail.posterImage,
    venueAvatarUrl: venueAvatarUrl,
    shareUrl: detail.shareUrl,
  );

  final String eventId;
  final String title;
  final String description;
  final String performerName;
  final bool performerLinked;
  final String venueName;
  final String location;
  final DateTime? eventDate;
  final String startTime;
  final String endTime;
  final String? posterUrl;
  final String? venueAvatarUrl;
  final String? shareUrl;

  String get plainPerformerName => _withoutAt(performerName);
  bool get hasPerformer => !{
    '',
    '-',
    'performer',
    'yakinda aciklanacak',
    'yakında açıklanacak',
    'belirtilmemiş',
    'belirtilmemis',
  }.contains(plainPerformerName.toLowerCase());
  String get performerLabel => hasPerformer
      ? '${performerLinked ? '@' : ''}$plainPerformerName'
      : 'Belirtilmemiş';
  String get venueLabel => _withoutAt(venueName).isEmpty
      ? 'Mekan bilgisi paylaşılmadı'
      : '@${_withoutAt(venueName)}';

  String get dateLabel {
    final date = eventDate;
    if (date == null) return 'Tarih paylaşılmadı';
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String get weekdayLabel => eventDate == null
      ? ''
      : const [
          'Pazartesi',
          'Salı',
          'Çarşamba',
          'Perşembe',
          'Cuma',
          'Cumartesi',
          'Pazar',
        ][eventDate!.weekday - 1];

  String get timeLabel {
    final start = _time(startTime);
    final end = _time(endTime);
    if (start.isEmpty) return '';
    return end.isEmpty ? start : '$start – $end';
  }

  /// Preserve the server's real link; do not invent an unsupported event link.
  String? get safeShareUrl {
    final uri = Uri.tryParse(shareUrl?.trim() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }

  /// Full text for reviewing the image with a screen reader, not for sending.
  String get accessibilityDescription => [
    title,
    if (description.trim().isNotEmpty) description.trim(),
    [dateLabel, timeLabel].where((part) => part.isNotEmpty).join(' · '),
    if (hasPerformer) performerLabel,
    venueLabel,
    if (location.isNotEmpty) location,
    if (safeShareUrl != null) safeShareUrl!,
  ].join('\n');

  static String _clean(String? value) {
    final text = value?.trim() ?? '';
    return text == '-' ? '' : text;
  }

  static String _withoutAt(String value) =>
      _clean(value).replaceFirst(RegExp(r'^(?:@\s*)+'), '').trim();

  static String _time(String? value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$',
    ).firstMatch(_clean(value));
    if (match == null) return '';
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return '';
    return '${hour.toString().padLeft(2, '0')}:${match[2]}';
  }
}
