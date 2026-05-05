class OverthinkingEndpoints {
  static const String _base = '/api/v1/overthinking';

  static const String feed = '$_base/feed';
  static const String create = '$_base/create';
  static const String myPosts = '$_base/me';
  static const String incomingRevealRequests =
      '$_base/reveal-requests/incoming';
  static const String sentRevealRequests = '$_base/reveal-requests/sent';

  static String detail(String postId) => '$_base/$postId';

  static String update(String postId) => '$_base/$postId';

  static String delete(String postId) => '$_base/$postId';

  static String postsByArtist(String artistId) => '$_base/artist/$artistId';

  static String createRevealRequest(String postId) =>
      '$_base/$postId/reveal-requests';

  static String approveRevealRequest(String requestId) =>
      '$_base/reveal-requests/$requestId/approve';

  static String rejectRevealRequest(String requestId) =>
      '$_base/reveal-requests/$requestId/reject';
}
