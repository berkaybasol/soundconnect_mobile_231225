import 'listener_visibility_context.dart';
import 'listener_visibility_mode.dart';

enum ProfileSearchResultType {
  musician,
  listener,
  band,
  studio,
  venue,
  unknown,
}

class ProfileSearchResult {
  final ProfileSearchResultType type;
  final String targetId;
  final String? userId;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final ListenerVisibilityMode visibilityMode;

  const ProfileSearchResult({
    required this.type,
    required this.targetId,
    required this.userId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.visibilityMode = ListenerVisibilityMode.standard,
  });

  bool get isGhostListener =>
      type == ProfileSearchResultType.listener && visibilityMode.isGhost;

  factory ProfileSearchResult.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().trim().toUpperCase();
    final type = switch (rawType) {
      'MUSICIAN' => ProfileSearchResultType.musician,
      'LISTENER' => ProfileSearchResultType.listener,
      'BAND' => ProfileSearchResultType.band,
      'STUDIO' => ProfileSearchResultType.studio,
      'VENUE' => ProfileSearchResultType.venue,
      _ => ProfileSearchResultType.unknown,
    };
    return ProfileSearchResult(
      type: type,
      targetId: json['targetId']?.toString().trim() ?? '',
      userId: _nonBlank(json['userId']),
      title: json['title']?.toString().trim() ?? '',
      subtitle: json['subtitle']?.toString().trim(),
      imageUrl: _nonBlank(json['imageUrl']),
      visibilityMode: parseContextualListenerVisibilityMode(
        json['visibilityMode'],
      ),
    );
  }

  static String? _nonBlank(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  String get typeLabel {
    return switch (type) {
      ProfileSearchResultType.musician => 'Müzisyen',
      ProfileSearchResultType.listener => 'Dinleyici',
      ProfileSearchResultType.band => 'Grup',
      ProfileSearchResultType.studio => 'Stüdyo',
      ProfileSearchResultType.venue => 'Mekan',
      ProfileSearchResultType.unknown => 'Profil',
    };
  }
}
