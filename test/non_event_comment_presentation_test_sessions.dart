part of 'non_event_comment_presentation_test.dart';

class _Sessions extends ChangeNotifier implements AuthSessionManager {
  AuthSession _value = _session('viewer');
  @override
  AuthSession get session => _value;
  void replaceSilently(AuthSession value) {
    _value = value;
  }

  void replace(AuthSession value) {
    _value = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CommentItem _comment(
  String id, {
  String userId = 'other',
  String username = 'aedrum',
  String text = 'Birlikte dinleyelim.',
  String? avatar,
  bool anonymous = false,
  bool deleted = false,
  bool ghost = false,
  int replies = 0,
  String? parent,
  int likeCount = 0,
  bool likedByMe = false,
}) => CommentItem(
  id: id,
  user: CommentUserSummary(
    id: userId,
    username: username,
    avatarUrl: avatar,
    visibilityMode: ghost
        ? ListenerVisibilityMode.ghost
        : ListenerVisibilityMode.standard,
  ),
  text: text,
  anonymousAuthor: anonymous,
  deleted: deleted,
  parentCommentId: parent,
  replyCount: replies,
  likeCount: likeCount,
  likedByMe: likedByMe,
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

class _Repository extends Fake implements EngagementRepository {
  List<CommentItem> roots = [_comment('root', replies: 21)];
  int total = 1;
  bool failRead = false,
      failCreate = false,
      failAfterCreate = false,
      failReplies = false;
  Completer<Result<CommentItem>>? pendingCreate;
  Completer<Result<CommentPage>>? pendingReplies;
  final pages = <int>[];
  final replyPages = <int>[];
  final creates = <(String, String?)>[];
  final deletes = <String>[];
  final likeReads = <String>[];
  final likeWrites = <(String, bool)>[];
  List<CommentItem>? previewReplies;
  @override
  Future<Result<CommentLikeState>> setCommentLike({
    required String commentId,
    required bool liked,
  }) async {
    likeWrites.add((commentId, liked));
    return Result.success(
      CommentLikeState(likeCount: liked ? 1 : 0, likedByMe: liked),
    );
  }

  @override
  Future<Result<CommentLikeState>> readCommentLike({
    required String commentId,
  }) async {
    likeReads.add(commentId);
    return const Result.success(
      CommentLikeState(likeCount: 0, likedByMe: false),
    );
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    if (failRead) return const Result.failure(_error);
    return Result.success(
      CommentPage(
        items: page == 0 ? roots : [_comment('last', text: 'Son yorum')],
        totalElements: total,
        page: page,
        size: size,
      ),
    );
  }

  @override
  Future<Result<CommentPage>> listReplyPage(
    String commentId, {
    String? eventId,
    int page = 0,
    int size = 20,
  }) async {
    replyPages.add(page);
    if (pendingReplies != null) return pendingReplies!.future;
    if (failReplies) return const Result.failure(_error);
    if (previewReplies != null) {
      return Result.success(
        CommentPage(
          items: previewReplies!,
          totalElements: previewReplies!.length,
          page: page,
          size: size,
        ),
      );
    }
    return Result.success(
      CommentPage(
        items: [
          _comment(
            page == 0 ? 'reply-first' : 'reply-last',
            parent: commentId,
            text: page == 0 ? 'İlk yanıt' : 'Son yanıt',
          ),
        ],
        totalElements: 21,
        page: page,
        size: size,
      ),
    );
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    creates.add((text, parentCommentId));
    if (pendingCreate != null) return pendingCreate!.future;
    if (failCreate) return const Result.failure(_error);
    if (failAfterCreate) failRead = true;
    return Result.success(
      _comment(
        'created',
        text: text,
        userId: 'viewer',
        parent: parentCommentId,
      ),
    );
  }

  @override
  Future<Result<void>> deleteComment({required String commentId}) async {
    deletes.add(commentId);
    return const Result.success(null);
  }

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async => const Result.success(0);
  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async => const Result.success(false);
}

const _target = DmProfileTarget(
  type: DmProfileTargetType.musician,
  id: 'profile-id',
  displayName: 'aedrum',
  imageUrl: null,
);

class _Resolver extends Fake implements DmUserProfileResolver {
  final calls = <String>[];
  final pending = Completer<List<DmProfileTarget>>();
  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) {
    calls.add(userId);
    return pending.future;
  }
}

const _post = OverthinkingPost(
  id: 'post',
  authorId: 'author',
  authorUsername: 'yazar',
  authorAvatarUrl: null,
  anonymous: false,
  canViewAuthor: true,
  visibilityType: 'PUBLIC',
  title: 'Düşünce başlığı',
  content: 'Düşünce metni',
  spotifyTrackUrl: null,
  spotifyArtistId: null,
  spotifyTrackName: null,
  spotifyArtistName: null,
  spotifyAlbumImageUrl: null,
  musicianTrackId: null,
  bandTrackId: null,
  artistId: null,
  artistType: null,
  likeCount: 0,
  commentCount: 1,
  likedByMe: false,
);

class _FeedCubit extends Cubit<OverthinkingFeedState>
    implements OverthinkingFeedCubit {
  _FeedCubit() : super(const OverthinkingFeedState.initial());
  @override
  bool get isSessionCurrent => true;
  @override
  bool get canWrite => true;
  @override
  bool isPostUnavailable(String postId) => false;
  @override
  void incrementCommentCount(String postId) {}
  @override
  Future<void> refreshPost(String postId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
