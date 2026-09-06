import '../../domain/entities/event_performer_request.dart';

extension EventPerformerRequestCopy on EventPerformerRequest {
  bool get _isVisibility =>
      requestPurpose == EventPerformerRequestPurpose.profileVisibility;

  bool get _isBand => targetType == EventPerformerTargetType.band;

  String get incompatibleApprovalExplanation =>
      'Güvenli onay için uygulama ve sunucu sürümleri uyumlu olmalı. '
      'Güncelleme sonrası tekrar dene.';

  String get purposeLabel =>
      _isVisibility ? 'Profilde gösterim izni' : 'Etkinlik katılım onayı';

  String get purposeExplanation {
    if (_isVisibility) {
      return _isBand
          ? 'Mekan, bu etkinliği “$performerName” adlı grubunun profil '
                'takviminde göstermek istiyor. Mevcut profil bağlantısı '
                'bu karardan etkilenmez.'
          : 'Mekan, bu etkinliği profil takviminde göstermek istiyor. '
                'Mevcut profil bağlantın bu karardan etkilenmez.';
    }
    return _isBand
        ? 'Onaylarsan mekan etkinliğinde grubunun profil bağlantısı açılır. '
              'Bu özellik grubunu SoundConnect’te daha görünür kılar.'
        : 'Onaylarsan mekan etkinliğinde profil bağlantın açılır. '
              'Bu özellik seni SoundConnect’te daha görünür kılar.';
  }

  String get calendarVisibilityExplanation => _isBand
      ? 'Seçtiğin etkinlik grup profilinde görünür. Sonradan gizleyebilirsin.'
      : 'Seçtiğin etkinlik profilinde görünür. Sonradan gizleyebilirsin.';

  String get calendarVisibilityHelpTitle => 'Profilde nasıl görünür?';

  List<String> get calendarVisibilityHelpParagraphs {
    final String permissionExplanation;
    if (_isVisibility) {
      permissionExplanation = _isBand
          ? 'Bu daveti onaylamak etkinliğin grubunun profilinde gösterimine '
                'izin verir. Reddetsen de mekandaki etkinlik ve grubunun '
                'mevcut profil bağlantısı korunur.'
          : 'Bu daveti onaylamak etkinliğin profilinde gösterimine izin '
                'verir. Reddetsen de mekandaki etkinlik ve mevcut profil '
                'bağlantın korunur.';
    } else {
      permissionExplanation = _isBand
          ? '“Bu etkinliği grubun profilinde de göster” seçeneğini işaretleyerek '
                'grubunun profilinde gösterime izin verebilirsin. İşaretlemeden '
                'onaylarsan yalnızca mekandaki etkinlikte grubunun profil '
                'bağlantısı açılır. Etkinlik grup profilinde görünmez.'
          : '“Bu etkinliği profilimde de göster” seçeneğini işaretleyerek '
                'profilinde gösterime izin verebilirsin. İşaretlemeden '
                'onaylarsan yalnızca mekandaki etkinlikte profil bağlantın '
                'açılır. Etkinlik kendi profilinde görünmez.';
    }

    return [
      permissionExplanation,
      _isBand
          ? 'Onaylanan etkinliklerin grup profilinde görünüp görünmeyeceğini '
                '“Etkinliklerim” bölümünden '
                'değiştirebilirsin. Bu seçim katılım onayını ve mekandaki '
                'profil bağlantısını değiştirmez.'
          : 'Onaylanan etkinliklerin profilinde görünüp görünmeyeceğini '
                '“Etkinliklerim” bölümünden '
                'değiştirebilirsin. Bu seçim katılım onayını ve mekandaki '
                'profil bağlantını değiştirmez.',
      if (_isBand)
        'Grup profilindeki seçim üyelerin kişisel profillerini değiştirmez. '
            'Aktif üyeler katılımı onaylanmış grup etkinliklerini kendi '
            'profillerinde gösterip göstermemeye ayrı ayrı karar verir.',
    ];
  }

  String get rejectionTitle =>
      _isVisibility ? 'Profilde gösterimi reddet' : 'Etkinlik davetini reddet';

  String get rejectionExplanation {
    if (_isVisibility) {
      final target = _isBand
          ? '“$performerName” adlı grubunun profil takvimine'
          : 'profil takvimine';
      return 'Bu etkinlik $target eklenmez. Mekan profilindeki etkinlik ve '
          'mevcut profil bağlantısı korunur.';
    }
    return '$venueName, “$eventTitle” etkinliğinde $performerName adını '
        'gösterebilir ancak profil bağlantısı kurulmaz. Etkinlik profil '
        'takvimine de eklenmez.';
  }

  String decisionSuccessMessage({
    required bool accept,
    bool showOnProfile = false,
  }) {
    if (_isVisibility) {
      return accept
          ? 'Etkinlik profil takvimine eklendi.'
          : 'Profilde gösterim reddedildi. Mekandaki etkinlik ve profil '
                'bağlantısı korundu.';
    }
    if (!accept) return 'Etkinlik daveti reddedildi.';
    return showOnProfile
        ? 'Profil bağlantısı açıldı. Etkinlik profil takvimine eklendi.'
        : 'Profil bağlantısı açıldı. Etkinlik profil takvimine eklenmedi.';
  }
}
