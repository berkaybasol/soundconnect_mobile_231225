import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/app_error.dart';
import '../../../overthinking/domain/entities/overthinking_post.dart';
import '../../../overthinking/domain/overthinking_profile_share_repository.dart';
import '../../../overthinking/domain/overthinking_repository.dart';
import '../../../overthinking/presentation/overthinking_profile_draft.dart';
import '../../domain/entities/listener_profile.dart';
import 'listener_overthinking_share_card.dart';
import 'listener_source_draft_composer.dart';

/// An in-memory profile card. Reading or editing this draft never publishes it.
class ListenerOverthinkingDraftComposer extends StatefulWidget {
  const ListenerOverthinkingDraftComposer({
    super.key,
    required this.draft,
    required this.profile,
    required this.onFinished,
    this.onStateChanged,
    this.repository,
    this.postsRepository,
    this.sessions,
  });

  final OverthinkingProfileDraftArgs draft;
  final ListenerProfile profile;
  final ValueChanged<bool> onFinished;
  final VoidCallback? onStateChanged;
  final OverthinkingProfileShareRepository? repository;
  final OverthinkingRepository? postsRepository;
  final AuthSessionManager? sessions;

  @override
  State<ListenerOverthinkingDraftComposer> createState() =>
      ListenerOverthinkingDraftComposerState();
}

class ListenerOverthinkingDraftComposerState
    extends State<ListenerOverthinkingDraftComposer> {
  final _composer =
      GlobalKey<ListenerSourceDraftComposerState<OverthinkingPost>>();

  bool get busy => _composer.currentState?.busy == true;
  bool get saving => _composer.currentState?.saving == true;
  bool get readyForReveal => _composer.currentState?.readyForReveal == true;
  bool get dirty => _composer.currentState?.dirty == true;
  bool get requiresLeaveGuard =>
      _composer.currentState?.requiresLeaveGuard == true;
  void invalidate() => _composer.currentState?.invalidate();
  Future<bool> canLeave() =>
      _composer.currentState?.canLeave() ?? Future.value(true);

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions ?? serviceLocator<AuthSessionManager>();
    final repository =
        widget.repository ??
        serviceLocator<OverthinkingProfileShareRepository>();
    final posts =
        widget.postsRepository ?? serviceLocator<OverthinkingRepository>();
    final draft = widget.draft;
    return ListenerSourceDraftComposer<OverthinkingPost>(
      key: _composer,
      sourceId: draft.postId,
      expectedSession: draft.expectedSession,
      profile: widget.profile,
      sessions: sessions,
      repositoryKey: (repository, posts),
      keyPrefix: 'listener-overthinking-draft',
      loadError:
          'Yazı ve profil paylaşımı yüklenemedi. Yeniden kontrol edebilirsin.',
      unavailableMessage:
          'Bu yazı şu anda profilinde paylaşılamıyor. Profil görünürlüğünü kontrol et.',
      removedMessage:
          'Profilinden kaldırdığında asıl yazı ve beğenileri korunur.',
      noteHint: 'Bu satırlar için birkaç söz ekle…',
      onFinished: widget.onFinished,
      onStateChanged: widget.onStateChanged,
      load: () async {
        final results = await Future.wait<Object?>([
          posts.getDetail(postId: draft.postId),
          repository.getState(
            postId: draft.postId,
            expectedSession: draft.expectedSession,
          ),
        ]);
        final source = results[0] as Result<OverthinkingPost>;
        final share = results[1] as Result<OverthinkingProfileShareState>;
        if (!source.isSuccess || source.data?.id != draft.postId) {
          return Result.failure(
            source.error ??
                const AppError(
                  code: 'overthinking_draft_source_unavailable',
                  message: 'Asıl yazı yüklenemedi.',
                ),
          );
        }
        if (!share.isSuccess || share.data?.postId != draft.postId) {
          return Result.failure(
            share.error ??
                const AppError(
                  code: 'overthinking_draft_share_unavailable',
                  message: 'Profil paylaşımı yüklenemedi.',
                ),
          );
        }
        return Result.success(
          ListenerSourceDraftData(source: source.data, state: share.data!),
        );
      },
      publish: (note) => repository.publish(
        postId: draft.postId,
        note: note,
        expectedSession: draft.expectedSession,
      ),
      remove: (shareId) => repository.deleteShare(
        shareId: shareId,
        expectedSession: draft.expectedSession,
      ),
      cardBuilder:
          (
            source, {
            required visibilityLabel,
            required noteEditor,
            required actions,
            required busy,
            required isCurrent,
          }) => ListenerOverthinkingShareCard.draft(
            post: source,
            username: widget.profile.username ?? '',
            avatarUrl: widget.profile.profilePictureUrl,
            visibilityLabel: visibilityLabel,
            busy: busy,
            maskAnonymousAuthor: true,
            isCurrent: isCurrent,
            noteEditor: noteEditor,
            actions: actions,
          ),
    );
  }
}
