class ListenerEventSharePreview {
  const ListenerEventSharePreview({
    required this.meta,
    required this.message,
    required this.eventTitle,
    required this.day,
    required this.month,
    required this.venue,
    required this.time,
    required this.location,
    required this.attendanceLabel,
    required this.commentCount,
  });

  final String meta;
  final String message;
  final String eventTitle;
  final String day;
  final String month;
  final String venue;
  final String time;
  final String location;
  final String attendanceLabel;
  final int commentCount;
}

class ListenerOverthinkingSharePreview {
  const ListenerOverthinkingSharePreview({
    required this.meta,
    required this.message,
    required this.likeCount,
    required this.commentCount,
  });

  final String meta;
  final String message;
  final int likeCount;
  final int commentCount;
}

class ListenerProfilePreviewData {
  const ListenerProfilePreviewData({
    required this.fallbackBio,
    required this.eventShare,
    required this.overthinkingShare,
  });

  final String fallbackBio;
  final ListenerEventSharePreview eventShare;
  final ListenerOverthinkingSharePreview overthinkingShare;
}

const listenerOwnerPreviewData = ListenerProfilePreviewData(
  fallbackBio:
      'Yeni gruplar, canlı performanslar ve gece eve dönerken iyi giden şarkılar.',
  eventShare: ListenerEventSharePreview(
    meta: 'Bir plan paylaştı · 2 saat önce',
    message:
        "Palmiyeler'i sonunda canlı dinleyeceğim. Bu gece güzel olacak gibi.",
    eventTitle: 'Ankara Indie Night',
    day: '06',
    month: 'EYL',
    venue: 'IF Performance Hall',
    time: 'Çankaya · 21.30',
    location: 'Nova Norda · Palmiyeler',
    attendanceLabel: 'Ben de gidiyorum',
    commentCount: 8,
  ),
  overthinkingShare: ListenerOverthinkingSharePreview(
    meta: 'Bir Overthinking paylaştı · dün',
    message:
        'Bazen bir şarkının ilk on saniyesi, bütün gün anlatmaya çalıştığın şeyi senden daha iyi anlatıyor.',
    likeCount: 24,
    commentCount: 11,
  ),
);
