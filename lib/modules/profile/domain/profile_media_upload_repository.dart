import 'dart:async';

import '../../../core/error/result.dart';
import 'entities/profile_upload_result.dart';

typedef ProfileUploadStreamFactory = Stream<List<int>> Function();
typedef ProfileUploadProgress = void Function(int sentBytes, int totalBytes);
typedef ProfileUploadStageChanged = void Function(ProfileUploadStage stage);

enum ProfileUploadStage {
  initializing,
  uploading,
  verifying,
  attaching,
  backgroundProcessing,
  completed,
}

enum ProfileUploadAttachmentType { none, draft, gallery, profilePicture, track }

/// Durable operation that follows object upload verification.
class ProfileUploadAttachmentIntent {
  final ProfileUploadAttachmentType type;
  final String? profileType;
  final String? targetId;
  final String? title;
  final int? expectedVersion;

  const ProfileUploadAttachmentIntent._({
    required this.type,
    this.profileType,
    this.targetId,
    this.title,
    this.expectedVersion,
  });

  const ProfileUploadAttachmentIntent.none()
    : this._(type: ProfileUploadAttachmentType.none);

  /// Marks a verified upload as belonging to a transient form draft.
  ///
  /// The upload pipeline durably hands this asset to the guarded cleanup queue
  /// before reporting completion to the caller.
  const ProfileUploadAttachmentIntent.draft()
    : this._(type: ProfileUploadAttachmentType.draft);

  const ProfileUploadAttachmentIntent.gallery({required String profileType})
    : this._(
        type: ProfileUploadAttachmentType.gallery,
        profileType: profileType,
      );

  const ProfileUploadAttachmentIntent.profilePicture({
    required String profileType,
    String? targetId,
    int? expectedVersion,
  }) : this._(
         type: ProfileUploadAttachmentType.profilePicture,
         profileType: profileType,
         targetId: targetId,
         expectedVersion: expectedVersion,
       );

  const ProfileUploadAttachmentIntent.track({
    required String ownerType,
    required String title,
  }) : this._(
         type: ProfileUploadAttachmentType.track,
         profileType: ownerType,
         title: title,
       );
}

class ProfileUploadRecoveryEvent {
  final String assetId;
  final String ownerType;
  final String ownerId;
  final ProfileUploadStage stage;
  final ProfileUploadedMedia? media;
  final Object? error;

  const ProfileUploadRecoveryEvent({
    required this.assetId,
    required this.ownerType,
    required this.ownerId,
    required this.stage,
    this.media,
    this.error,
  });

  bool get isSuccess => stage == ProfileUploadStage.completed && error == null;
}

class ProfileUploadSource {
  final int sizeBytes;
  final ProfileUploadStreamFactory _openRead;

  const ProfileUploadSource({
    required this.sizeBytes,
    required ProfileUploadStreamFactory openRead,
  }) : _openRead = openRead;

  factory ProfileUploadSource.bytes(List<int> bytes) {
    return ProfileUploadSource(
      sizeBytes: bytes.length,
      openRead: () => Stream<List<int>>.value(bytes),
    );
  }

  Stream<List<int>> openRead() => _openRead();
}

class ProfileUploadCancellation {
  bool _isCancelled = false;
  Object? _reason;
  void Function(Object? reason)? _listener;
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _isCancelled;
  Object? get reason => _reason;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel([Object? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    _reason = reason;
    _cancelled.complete();
    _listener?.call(reason);
  }

  void attach(void Function(Object? reason) listener) {
    _listener = listener;
    if (_isCancelled) listener(_reason);
  }

  void detach() {
    _listener = null;
  }
}

abstract class ProfileMediaUploadRepository {
  Stream<ProfileUploadRecoveryEvent> get recoveryEvents;

  Future<Result<ProfileUploadedMedia>> uploadAsset({
    required ProfileUploadSource source,
    required String ownerType,
    required String ownerId,
    required String mediaKind,
    required String mimeType,
    required String originalFileName,
    ProfileUploadAttachmentIntent attachmentIntent =
        const ProfileUploadAttachmentIntent.none(),
    ProfileUploadProgress? onProgress,
    ProfileUploadStageChanged? onStageChanged,
    ProfileUploadCancellation? cancellation,
  });

  Future<void> resumePendingUploads();

  /// Requests deletion through the server-side ownership and reference guard.
  ///
  /// Callers must still limit this to assets they own. The backend rejects an
  /// asset that is referenced by first-party content, which makes this safe for
  /// compensating an upload after an ambiguous create/update response.
  Future<Result<void>> deleteOwnedAsset({
    required String assetId,
    required String ownerType,
    required String ownerId,
  });

  Future<Result<void>> persistDraftCleanupIntent({
    required String assetId,
    required String ownerType,
    required String ownerId,
  });

  Future<Result<void>> clearDraftCleanupIntents(Iterable<String> assetIds);

  /// Releases only the in-memory form lease; the durable cleanup intent stays.
  void releaseDraftCleanupLeases(Iterable<String> assetIds);
}
