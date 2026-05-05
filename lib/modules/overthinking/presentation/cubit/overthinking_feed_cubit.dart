import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../engagement/domain/engagement_repository.dart';
import '../../domain/entities/overthinking_post.dart';
import '../../domain/overthinking_repository.dart';
import 'overthinking_feed_state.dart';

class OverthinkingFeedCubit extends Cubit<OverthinkingFeedState> {
  static const String targetType = 'OVERTHINKING';

  final OverthinkingRepository _overthinkingRepository;
  final EngagementRepository _engagementRepository;

  OverthinkingFeedCubit({
    required OverthinkingRepository overthinkingRepository,
    required EngagementRepository engagementRepository,
  }) : _overthinkingRepository = overthinkingRepository,
       _engagementRepository = engagementRepository,
       super(const OverthinkingFeedState.initial());

  Future<void> load() async {
    emit(state.copyWith(status: OverthinkingFeedStatus.loading, error: null));
    final result = await _overthinkingRepository.getFeed(page: 0, size: 20);
    if (!result.isSuccess || result.data == null) {
      emit(
        state.copyWith(
          status: OverthinkingFeedStatus.failure,
          error: result.error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: OverthinkingFeedStatus.idle,
        posts: result.data!.items,
        hasNext: result.data!.hasNext,
        page: 0,
        error: null,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.status == OverthinkingFeedStatus.loading ||
        state.status == OverthinkingFeedStatus.loadingMore ||
        !state.hasNext) {
      return;
    }

    final nextPage = state.page + 1;
    emit(
      state.copyWith(status: OverthinkingFeedStatus.loadingMore, error: null),
    );
    final result = await _overthinkingRepository.getFeed(
      page: nextPage,
      size: 20,
    );
    if (!result.isSuccess || result.data == null) {
      emit(
        state.copyWith(
          status: OverthinkingFeedStatus.failure,
          error: result.error,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: OverthinkingFeedStatus.idle,
        posts: [...state.posts, ...result.data!.items],
        hasNext: result.data!.hasNext,
        page: nextPage,
        error: null,
      ),
    );
  }

  Future<bool> createPost({
    required String title,
    required String content,
    required bool anonymous,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
  }) async {
    emit(state.copyWith(submitting: true, error: null));
    final result = await _overthinkingRepository.createPost(
      title: title,
      content: content,
      visibilityType: anonymous ? 'ANONYMOUS' : 'VISIBLE',
      spotifyTrackUrl: spotifyTrackUrl,
      spotifyArtistId: spotifyArtistId,
      spotifyTrackName: spotifyTrackName,
      spotifyArtistName: spotifyArtistName,
      spotifyAlbumImageUrl: spotifyAlbumImageUrl,
    );
    if (!result.isSuccess || result.data == null) {
      emit(state.copyWith(submitting: false, error: result.error));
      return false;
    }
    emit(
      state.copyWith(
        submitting: false,
        posts: [result.data!, ...state.posts],
        error: null,
      ),
    );
    return true;
  }

  Future<void> refreshPost(String postId) async {
    final result = await _overthinkingRepository.getDetail(postId: postId);
    if (!result.isSuccess || result.data == null) {
      emit(state.copyWith(error: result.error));
      return;
    }
    _replacePost(result.data!);
  }

  Future<bool> updatePost({
    required OverthinkingPost post,
    required String title,
    required String content,
    required bool anonymous,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
  }) async {
    emit(state.copyWith(submitting: true, error: null));
    final result = await _overthinkingRepository.updatePost(
      postId: post.id,
      title: title,
      content: content,
      visibilityType: anonymous ? 'ANONYMOUS' : 'VISIBLE',
      spotifyTrackUrl: spotifyTrackUrl,
      spotifyArtistId: spotifyArtistId,
      spotifyTrackName: spotifyTrackName,
      spotifyArtistName: spotifyArtistName,
      spotifyAlbumImageUrl: spotifyAlbumImageUrl,
      musicianTrackId: post.musicianTrackId,
      bandTrackId: post.bandTrackId,
    );
    if (!result.isSuccess || result.data == null) {
      emit(state.copyWith(submitting: false, error: result.error));
      return false;
    }
    emit(state.copyWith(submitting: false, error: null));
    _replacePost(result.data!);
    return true;
  }

  Future<bool> deletePost(String postId) async {
    emit(state.copyWith(deleting: true, error: null));
    final result = await _overthinkingRepository.deletePost(postId: postId);
    if (!result.isSuccess) {
      emit(state.copyWith(deleting: false, error: result.error));
      return false;
    }
    final posts = state.posts.where((item) => item.id != postId).toList();
    emit(state.copyWith(deleting: false, posts: posts, error: null));
    return true;
  }

  Future<void> toggleLike(OverthinkingPost post) async {
    final before = post;
    final optimistic = post.copyWith(
      likedByMe: !post.likedByMe,
      likeCount: (post.likeCount + (post.likedByMe ? -1 : 1))
          .clamp(0, 1 << 30)
          .toInt(),
    );
    _replacePost(optimistic);

    final result = before.likedByMe
        ? await _engagementRepository.unlike(
            targetType: targetType,
            targetId: before.id,
          )
        : await _engagementRepository.like(
            targetType: targetType,
            targetId: before.id,
          );

    if (!result.isSuccess) {
      _replacePost(before);
      emit(state.copyWith(error: result.error));
    }
  }

  Future<bool> requestReveal(OverthinkingPost post) async {
    final requesting = Set<String>.from(state.revealRequestingIds)
      ..add(post.id);
    emit(state.copyWith(revealRequestingIds: requesting, error: null));

    final result = await _overthinkingRepository.requestReveal(postId: post.id);

    final next = Set<String>.from(state.revealRequestingIds)..remove(post.id);
    emit(state.copyWith(revealRequestingIds: next));

    if (!result.isSuccess) {
      emit(state.copyWith(error: result.error));
      return false;
    }
    return true;
  }

  void incrementCommentCount(String postId) {
    OverthinkingPost? post;
    for (final item in state.posts) {
      if (item.id == postId) {
        post = item;
        break;
      }
    }
    if (post == null) return;
    _replacePost(post.copyWith(commentCount: post.commentCount + 1));
  }

  void _replacePost(OverthinkingPost post) {
    final exists = state.posts.any((item) => item.id == post.id);
    final posts = exists
        ? state.posts.map((item) => item.id == post.id ? post : item).toList()
        : [post, ...state.posts];
    emit(state.copyWith(posts: posts, error: null));
  }
}
