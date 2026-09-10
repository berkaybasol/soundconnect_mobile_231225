import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/app_error.dart';
import '../../../tablegroup/domain/table_group_profile_share_repository.dart';
import '../../../tablegroup/presentation/table_group_profile_draft.dart';
import '../../domain/entities/listener_profile.dart';
import 'listener_source_draft_composer.dart';
import 'listener_table_group_share_card.dart';

class ListenerTableGroupDraftComposer extends StatefulWidget {
  const ListenerTableGroupDraftComposer({
    super.key,
    required this.draft,
    required this.profile,
    required this.onFinished,
    this.onStateChanged,
    this.repository,
    this.sessions,
  });

  final TableGroupProfileDraftArgs draft;
  final ListenerProfile profile;
  final ValueChanged<bool> onFinished;
  final VoidCallback? onStateChanged;
  final TableGroupProfileShareRepository? repository;
  final AuthSessionManager? sessions;

  @override
  State<ListenerTableGroupDraftComposer> createState() =>
      ListenerTableGroupDraftComposerState();
}

class ListenerTableGroupDraftComposerState
    extends State<ListenerTableGroupDraftComposer> {
  final _composer =
      GlobalKey<
        ListenerSourceDraftComposerState<TableGroupProfileShareSource>
      >();

  bool get saving => _composer.currentState?.saving == true;
  bool get readyForReveal => _composer.currentState?.readyForReveal == true;
  void invalidate() => _composer.currentState?.invalidate();
  Future<bool> canLeave() =>
      _composer.currentState?.canLeave() ?? Future.value(true);

  @override
  Widget build(BuildContext context) {
    final repository =
        widget.repository ?? serviceLocator<TableGroupProfileShareRepository>();
    final draft = widget.draft;
    return ListenerSourceDraftComposer<TableGroupProfileShareSource>(
      key: _composer,
      sourceId: draft.tableGroupId,
      expectedSession: draft.expectedSession,
      profile: widget.profile,
      sessions: widget.sessions ?? serviceLocator<AuthSessionManager>(),
      repositoryKey: repository,
      keyPrefix: 'listener-table-group-draft',
      loadError:
          'Masa ve profil paylaşımı yüklenemedi. Yeniden kontrol edebilirsin.',
      unavailableMessage:
          'Yalnızca sahibi olduğun veya katıldığın açık masaları paylaşabilirsin.',
      removedMessage:
          'Profilinden kaldırdığında masan ve masaya katılımın korunur.',
      noteHint: 'Bu masa için birkaç söz ekle…',
      onFinished: widget.onFinished,
      onStateChanged: widget.onStateChanged,
      load: () async {
        final result = await repository.getState(
          tableGroupId: draft.tableGroupId,
          expectedSession: draft.expectedSession,
        );
        final state = result.data;
        if (!result.isSuccess || state?.tableGroupId != draft.tableGroupId) {
          return Result.failure(
            result.error ??
                const AppError(
                  code: 'table_group_draft_unavailable',
                  message: 'Profil paylaşımı yüklenemedi.',
                ),
          );
        }
        return Result.success(
          ListenerSourceDraftData(source: state!.tableGroup, state: state),
        );
      },
      publish: (note) => repository.publish(
        tableGroupId: draft.tableGroupId,
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
          }) => ListenerTableGroupShareCard.draft(
            tableGroup: source,
            username: widget.profile.username ?? '',
            avatarUrl: widget.profile.profilePictureUrl,
            visibilityLabel: visibilityLabel,
            busy: busy,
            isCurrent: isCurrent,
            noteEditor: noteEditor,
            actions: actions,
          ),
    );
  }
}
