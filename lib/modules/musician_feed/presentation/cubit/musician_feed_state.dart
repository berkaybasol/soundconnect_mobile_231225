import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/musician_feed_models.dart';

enum MusicianFeedStatus {
  initial,
  loading,
  ready,
  loadingMore,
  featureUnavailable,
  failure,
}

class MusicianFeedState {
  const MusicianFeedState({
    this.status = MusicianFeedStatus.initial,
    this.items = const <MusicianFeedItem>[],
    this.feedSessionId,
    this.algorithmVersion,
    this.generatedAt,
    this.nextCursor,
    this.hasMore = false,
    this.refreshing = false,
    this.pendingItemIds = const <String>{},
    this.error,
    this.loadMoreError,
    this.actionError,
    this.noticeSerial = 0,
  });

  final MusicianFeedStatus status;
  final List<MusicianFeedItem> items;
  final String? feedSessionId;
  final String? algorithmVersion;
  final DateTime? generatedAt;
  final String? nextCursor;
  final bool hasMore;
  final bool refreshing;
  final Set<String> pendingItemIds;
  final AppError? error;
  final AppError? loadMoreError;
  final AppError? actionError;
  final int noticeSerial;

  bool get hasContent => items.isNotEmpty;
  bool get isInitialLoading =>
      !hasContent &&
      (status == MusicianFeedStatus.initial ||
          status == MusicianFeedStatus.loading);

  MusicianFeedState copyWith({
    MusicianFeedStatus? status,
    List<MusicianFeedItem>? items,
    Object? feedSessionId = copyWithUnset,
    Object? algorithmVersion = copyWithUnset,
    Object? generatedAt = copyWithUnset,
    Object? nextCursor = copyWithUnset,
    bool? hasMore,
    bool? refreshing,
    Set<String>? pendingItemIds,
    Object? error = copyWithUnset,
    Object? loadMoreError = copyWithUnset,
    Object? actionError = copyWithUnset,
    int? noticeSerial,
  }) {
    return MusicianFeedState(
      status: status ?? this.status,
      items: items ?? this.items,
      feedSessionId: identical(feedSessionId, copyWithUnset)
          ? this.feedSessionId
          : feedSessionId as String?,
      algorithmVersion: identical(algorithmVersion, copyWithUnset)
          ? this.algorithmVersion
          : algorithmVersion as String?,
      generatedAt: identical(generatedAt, copyWithUnset)
          ? this.generatedAt
          : generatedAt as DateTime?,
      nextCursor: identical(nextCursor, copyWithUnset)
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      refreshing: refreshing ?? this.refreshing,
      pendingItemIds: pendingItemIds ?? this.pendingItemIds,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
      loadMoreError: identical(loadMoreError, copyWithUnset)
          ? this.loadMoreError
          : loadMoreError as AppError?,
      actionError: identical(actionError, copyWithUnset)
          ? this.actionError
          : actionError as AppError?,
      noticeSerial: noticeSerial ?? this.noticeSerial,
    );
  }
}
