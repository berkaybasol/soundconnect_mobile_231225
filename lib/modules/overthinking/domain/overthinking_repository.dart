import '../../../core/error/result.dart';
import '../../../core/pagination/page.dart';
import 'entities/overthinking_post.dart';
import 'entities/overthinking_reveal_request.dart';

abstract class OverthinkingRepository {
  Future<Result<Page<OverthinkingPost>>> getFeed({int page = 0, int size = 20});

  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  });

  Future<Result<Page<OverthinkingPost>>> getPostsByArtist({
    required String artistId,
    int page = 0,
    int size = 20,
  });

  Future<Result<OverthinkingPost>> getDetail({required String postId});

  Future<Result<OverthinkingPost>> createPost({
    required String title,
    required String content,
    required String visibilityType,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
  });

  Future<Result<OverthinkingPost>> updatePost({
    required String postId,
    required String title,
    required String content,
    required String visibilityType,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
    String? musicianTrackId,
    String? bandTrackId,
  });

  Future<Result<void>> deletePost({required String postId});

  Future<Result<void>> requestReveal({required String postId});

  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  });

  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  });

  Future<Result<OverthinkingRevealRequest>> approveRevealRequest({
    required String requestId,
  });

  Future<Result<OverthinkingRevealRequest>> rejectRevealRequest({
    required String requestId,
  });
}
