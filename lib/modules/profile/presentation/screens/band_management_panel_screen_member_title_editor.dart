part of 'band_management_panel_screen.dart';

extension _BandMemberTitleActions on _BandMembersWorkspaceScreenState {
  bool _canEditTitle(BandMemberSummary member) {
    return _canManageMembers &&
        member.userId.trim().isNotEmpty &&
        member.status.trim().toUpperCase() == 'ACTIVE' &&
        member.titleVersion >= 0;
  }

  bool _sameTitleMember(BandMemberSummary member) => _profile.members.any(
    (current) =>
        current.userId == member.userId &&
        current.profileId == member.profileId &&
        current.roleCode == member.roleCode &&
        current.status.trim().toUpperCase() == 'ACTIVE' &&
        current.titleVersion == member.titleVersion &&
        current.memberTitle == member.memberTitle,
  );

  Future<void> _editMemberTitle(BandMemberSummary member) async {
    if (!mounted ||
        _busy ||
        !_canEditTitle(member) ||
        !_sameTitleMember(member) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final bandId = _profile.id;
    final session = _titleSessionManager!.session;
    final expectedSessionKey = session.userId!.trim();
    var reconciled = false;
    bool sameOwner() =>
        _owner.mounted &&
        identical(_titleSessionManager?.session, session) &&
        _owner._profile.id == bandId;
    Future<void> reconcileOwner() async {
      if (!sameOwner() || reconciled) return;
      reconciled = true;
      await _owner._refreshProfile();
    }

    bool sameContext() => mounted && sameOwner();
    bool canWrite() =>
        sameContext() &&
        _canEditTitle(member) &&
        _sameTitleMember(member) &&
        ModalRoute.of(context)?.isCurrent == true;

    _updateTitleState(() => _titleEditorOpen = true);
    var ownsSubmission = false;
    try {
      final draft = await showDialog<_BandMemberTitleDraft>(
        context: context,
        builder: (_) => _BandMemberTitleDialog(member: member),
      );
      if (!sameContext() || draft == null) return;
      if (!canWrite()) {
        await reconcileOwner();
        if (sameContext()) {
          _showTitleMessage('Üye bilgileri değişti. Rolü yeniden düzenle.');
        }
        return;
      }
      if (BandMemberTitlePolicy.validationMessage(draft.title) != null) return;
      final title = BandMemberTitlePolicy.normalize(draft.title);
      if (title == member.displayTitle) return;

      _updateTitleState(() {
        _titleEditorOpen = false;
        _savingTitleUserId = member.userId;
      });
      _owner._updateState(() => _owner._submitting = true);
      ownsSubmission = true;
      final result = await _owner._bandRepository.updateMemberTitle(
        bandId: bandId,
        userId: member.userId,
        memberTitle: title,
        expectedTitleVersion: member.titleVersion,
        expectedSessionKey: expectedSessionKey,
      );
      if (!sameContext()) {
        await reconcileOwner();
        return;
      }
      final updated = result.data;
      final confirmed =
          canWrite() &&
          result.isSuccess &&
          updated != null &&
          updated.userId.trim() == member.userId.trim() &&
          updated.roleCode == member.roleCode &&
          updated.status.trim().toUpperCase() == 'ACTIVE' &&
          BandMemberTitlePolicy.validationMessage(updated.memberTitle) ==
              null &&
          (updated.titleVersion == member.titleVersion + 1 ||
              (updated.titleVersion == member.titleVersion &&
                  updated.memberTitle == member.memberTitle));
      if (confirmed) {
        // Only the verified title fields change. Roster identity, avatar and
        // authority remain from the currently loaded canonical band profile.
        _owner._updateState(() {
          final profile = _profile;
          _owner._profile = BandProfile(
            id: profile.id,
            name: profile.name,
            description: profile.description,
            profilePictureUrl: profile.profilePictureUrl,
            instagramUrl: profile.instagramUrl,
            youtubeUrl: profile.youtubeUrl,
            soundCloudUrl: profile.soundCloudUrl,
            spotifyEmbedUrl: profile.spotifyEmbedUrl,
            spotifyArtistId: profile.spotifyArtistId,
            spotifyTrackIds: profile.spotifyTrackIds,
            members: List.unmodifiable(
              profile.members.map(
                (current) => current.userId == member.userId
                    ? current.copyWithTitle(
                        memberTitle: updated.memberTitle,
                        titleVersion: updated.titleVersion,
                      )
                    : current,
              ),
            ),
          );
        });
        _showTitleMessage(
          updated.displayTitle == null
              ? 'Gruptaki rolü kaldırıldı.'
              : 'Gruptaki rolü kaydedildi.',
          tone: AppSnackBarTone.success,
        );
      } else {
        // Conflicts or uncertain responses reconcile once, never replay writes.
        await reconcileOwner();
        if (sameContext()) {
          _showTitleMessage(
            result.error?.message ??
                'Değişiklik doğrulanamadı. Üye bilgileri yenilendi.',
          );
        }
      }
    } catch (_) {
      if (!mounted) {
        if (ownsSubmission) await reconcileOwner();
        return;
      }
      if (sameContext()) {
        await reconcileOwner();
        if (sameContext()) {
          _showTitleMessage(
            'Rol kaydedilemedi. Üye bilgilerini kontrol edip tekrar dene.',
          );
        }
      }
    } finally {
      if (ownsSubmission && _owner.mounted) {
        _owner._updateState(() => _owner._submitting = false);
      }
      if (mounted) {
        _updateTitleState(() {
          _titleEditorOpen = false;
          _savingTitleUserId = null;
        });
        _drainResumeRefresh();
      }
    }
  }

  void _showTitleMessage(
    String message, {
    AppSnackBarTone tone = AppSnackBarTone.error,
  }) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(appSnackBar(context, tone: tone, content: Text(message)));
  }
}

class _BandMemberTitleDraft {
  const _BandMemberTitleDraft(this.title);
  final String? title;
}

class _BandMemberTitleDialog extends StatefulWidget {
  const _BandMemberTitleDialog({required this.member});
  final BandMemberSummary member;

  @override
  State<_BandMemberTitleDialog> createState() => _BandMemberTitleDialogState();
}

class _BandMemberTitleDialogState extends State<_BandMemberTitleDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.member.displayTitle ?? '',
  );
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!mounted || _submitted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (BandMemberTitlePolicy.validationMessage(_controller.text) != null) {
      return;
    }
    final title = BandMemberTitlePolicy.normalize(_controller.text);
    if (title == widget.member.displayTitle) return;
    setState(() => _submitted = true);
    Navigator.of(context).pop(_BandMemberTitleDraft(title));
  }

  void _clear() {
    if (!mounted || _submitted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _controller.clear();
  }

  void _cancel() {
    if (!mounted || _submitted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      key: const Key('band-member-title-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _GradientOutline(
          radius: 24,
          strokeWidth: 1,
          paintOverChild: true,
          child: Container(
            color: colors.surfaceContainerHighest,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _GradientIcon(icon: Icons.badge_outlined, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Gruptaki rolü',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.member.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final error = BandMemberTitlePolicy.validationMessage(
                        value.text,
                      );
                      final changed =
                          BandMemberTitlePolicy.normalize(value.text) !=
                          widget.member.displayTitle;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: const Key('band-member-title-input'),
                            controller: _controller,
                            autofocus: true,
                            maxLines: 1,
                            maxLength: BandMemberTitlePolicy.maxCharacters,
                            maxLengthEnforcement: MaxLengthEnforcement
                                .truncateAfterCompositionEnds,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                            decoration: InputDecoration(
                              labelText: 'Rol',
                              hintText: 'Örn. Vokal / Gitar',
                              errorText: error,
                              errorMaxLines: 3,
                              suffixIcon: value.text.isEmpty
                                  ? null
                                  : IconButton(
                                      key: const Key('band-member-title-clear'),
                                      tooltip: 'Rolü temizle',
                                      onPressed: _submitted ? null : _clear,
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 19,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: _submitted ? null : _cancel,
                                  child: const Text('Vazgeç'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GradientOutlineButton(
                                  key: const Key('band-member-title-save'),
                                  label: 'Kaydet',
                                  horizontalPadding: 12,
                                  strokeWidth: 1,
                                  onPressed:
                                      !_submitted && error == null && changed
                                      ? _save
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
