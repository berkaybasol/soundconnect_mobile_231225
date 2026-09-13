import 'dart:async';

import 'musician_feed_models.dart';

class MusicianFeedAuthorUnmuted {
  const MusicianFeedAuthorUnmuted({
    required this.userId,
    required this.token,
    required this.author,
  });

  final String userId;
  final String token;
  final MusicianFeedAuthorProfileIdentity author;
}

/// Shares committed settings changes with already-open feed instances.
/// Events belong to a specific login and are never retained for another one.
class MusicianFeedMuteChanges {
  final _controller = StreamController<MusicianFeedAuthorUnmuted>.broadcast(
    sync: true,
  );

  Stream<MusicianFeedAuthorUnmuted> get unmuted => _controller.stream;

  void notifyUnmuted({
    required String userId,
    required String token,
    required MusicianFeedAuthorProfileIdentity author,
  }) {
    if (_controller.isClosed) return;
    _controller.add(
      MusicianFeedAuthorUnmuted(userId: userId, token: token, author: author),
    );
  }

  Future<void> close() => _controller.close();
}
