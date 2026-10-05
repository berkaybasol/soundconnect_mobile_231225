part of 'table_group_detail_screen.dart';

extension _TableGroupDetailScreenStateJoinMethods
    on _TableGroupDetailScreenState {
  Future<void> _join() async {
    if (_joinInFlight || !_isSessionActive) return;
    if (!_canCreateOrJoin) {
      _showSnack(
        'Masa oluşturma ve katılma işlemleri kişisel hesaplarla kullanılabilir.',
        tone: AppSnackBarTone.warning,
      );
      return;
    }
    final submission = await showDialog<_JoinDialogSubmission>(
      context: context,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.76),
      builder: (context) => const _PremiumJoinDialog(),
    );
    if (submission == null) return;
    final note = submission.note.trim();
    if (!mounted) return;
    _updateView(() => _joinInFlight = true);
    try {
      final result = await _repository.joinTableGroup(
        tableGroupId: widget.args.tableGroupId,
        note: note,
      );
      if (!mounted) return;
      _showSnack(
        result.isSuccess
            ? 'Katılma isteği gönderildi'
            : (result.error?.message ?? 'Islem basarisiz'),
        tone: result.isSuccess
            ? AppSnackBarTone.success
            : AppSnackBarTone.error,
      );
      if (result.isSuccess) {
        await _loadDetail(replaceScreenOnFailure: false);
      }
    } finally {
      if (mounted) _updateView(() => _joinInFlight = false);
    }
  }

  Future<void> _runOwnerAction({
    required String participantId,
    required Future<bool> Function() fn,
  }) async {
    if (!_hasActiveChatAccess ||
        _ownerActionInFlightIds.contains(participantId)) {
      return;
    }
    _updateView(() {
      _ownerActionInFlightIds.add(participantId);
    });
    try {
      final succeeded = await fn();
      if (succeeded) {
        await _loadDetail(replaceScreenOnFailure: false);
      }
    } finally {
      if (mounted) {
        _updateView(() {
          _ownerActionInFlightIds.remove(participantId);
        });
      }
    }
  }

  bool _notificationMatches(TableGroup group) {
    final target = widget.args.notificationTarget;
    if (target == null) {
      final result = widget.args.notificationResult;
      return result == null ||
          (group.id == result.tableGroupId && _notificationSessionCurrent);
    }
    if (group.id != target.tableGroupId ||
        !_notificationSessionCurrent ||
        !isTableGroupSessionActiveAt(group, _now())) {
      return false;
    }
    final expected = target.pending
        ? TableGroupParticipantStatus.pending
        : TableGroupParticipantStatus.accepted;
    return (target.pending
            ? group.ownerId == _currentUserId
            : target.subjectId == _currentUserId) &&
        group.participants.any(
          (p) =>
              p.userId == target.subjectId &&
              p.applicationId == target.applicationId &&
              p.status == expected,
        );
  }

  void _confirmVisibleChat() {
    final target = widget.args.notificationTarget;
    if (target == null ||
        _shareSession == null ||
        !_notificationSessionCurrent ||
        !_shouldRunChat ||
        !_chatLoaded ||
        _chatError != null) {
      return;
    }
    unawaited(
      serviceLocator<NotificationTargetRepository>().tableChat(
        target,
        _shareSession,
        markRead: true,
      ),
    );
  }

  bool get _notificationSessionCurrent =>
      _shareSession != null &&
      identical(_shareSessions?.session, _shareSession) &&
      _shareSession.isAuthenticated &&
      _shareSession.isActive &&
      _shareSession.userId == _currentUserId;

  Future<bool> _approve(String participantId) async {
    if (!_hasActiveChatAccess) return false;
    final target = widget.args.notificationTarget;
    final result =
        target?.subjectId == participantId &&
            target!.pending &&
            _shareSession != null
        ? await serviceLocator<NotificationTargetRepository>()
              .decideTableApplication(target, _shareSession, approve: true)
        : await _repository.approveJoinRequest(
            tableGroupId: widget.args.tableGroupId,
            participantId: participantId,
          );
    if (!mounted) return false;
    _showSnack(
      result.isSuccess
          ? 'Onaylandi'
          : (result.error?.message ?? 'Islem basarisiz'),
      tone: result.isSuccess ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
    return result.isSuccess;
  }

  Future<bool> _reject(String participantId) async {
    if (!_hasActiveChatAccess) return false;
    final target = widget.args.notificationTarget;
    final result =
        target?.subjectId == participantId &&
            target!.pending &&
            _shareSession != null
        ? await serviceLocator<NotificationTargetRepository>()
              .decideTableApplication(target, _shareSession, approve: false)
        : await _repository.rejectJoinRequest(
            tableGroupId: widget.args.tableGroupId,
            participantId: participantId,
          );
    if (!mounted) return false;
    _showSnack(
      result.isSuccess
          ? 'Reddedildi'
          : (result.error?.message ?? 'Islem basarisiz'),
      tone: result.isSuccess ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
    return result.isSuccess;
  }

  Future<void> _confirmKickParticipant(
    TableGroupParticipant participant,
  ) async {
    if (!_isOwner ||
        !_hasActiveChatAccess ||
        participant.userId == _group?.ownerId ||
        _ownerActionInFlightIds.contains(participant.userId)) {
      return;
    }
    final confirmed = await _confirmSessionAction(
      title: 'Katilimciyi masadan cikar',
      message:
          '${_participantDisplayName(participant)} bu masadan ve sohbetten '
          'cikarilacak.',
      confirmLabel: 'Masadan Cikar',
    );
    if (!confirmed || !mounted) return;
    await _runOwnerAction(
      participantId: participant.userId,
      fn: () => _kick(participant.userId),
    );
  }

  Future<bool> _kick(String participantId) async {
    if (!_isOwner ||
        !_hasActiveChatAccess ||
        participantId == _group?.ownerId) {
      return false;
    }
    final result = await _repository.kickParticipant(
      tableGroupId: widget.args.tableGroupId,
      participantId: participantId,
    );
    if (!mounted) return false;
    _showSnack(
      result.isSuccess
          ? 'Katilimci masadan cikarildi'
          : (result.error?.message ?? 'Katilimci cikarilamadi'),
      tone: result.isSuccess ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
    return result.isSuccess;
  }

  Future<void> _leave() async {
    if (_sessionActionInFlight || !_hasActiveChatAccess) return;
    final confirmed = await _confirmSessionAction(
      title: 'Masadan ayrıl',
      message: 'Masadan ayrıldığında bu sohbete erişimin sona erecek.',
      confirmLabel: 'Ayrıl',
    );
    if (!confirmed || !mounted) return;
    _updateView(() => _sessionActionInFlight = true);
    try {
      final result = await _repository.leaveTableGroup(
        tableGroupId: widget.args.tableGroupId,
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        _showSnack(result.error?.message ?? 'Masadan ayrılamadı');
        return;
      }
      _showSnack('Masadan ayrıldın', tone: AppSnackBarTone.success);
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) _updateView(() => _sessionActionInFlight = false);
    }
  }

  Future<void> _cancelTable() async {
    if (_sessionActionInFlight || !_hasActiveChatAccess) return;
    final confirmed = await _confirmSessionAction(
      title: 'Oturumu sonlandir',
      message: 'Oturum sonlandirilacak ve katilimcilar sohbete erisemeyecek.',
      confirmLabel: 'Sonlandir',
    );
    if (!confirmed || !mounted) return;
    _updateView(() => _sessionActionInFlight = true);
    try {
      final result = await _repository.cancelTableGroup(
        tableGroupId: widget.args.tableGroupId,
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        _showSnack(result.error?.message ?? 'Masa sonlandirilamadi');
        return;
      }
      _showSnack('Masa iptal edildi', tone: AppSnackBarTone.success);
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) _updateView(() => _sessionActionInFlight = false);
    }
  }

  Future<bool> _confirmSessionAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.76),
      builder: (context) => _PremiumConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
    return confirmed == true;
  }

  void _showSnack(
    String message, {
    AppSnackBarTone tone = AppSnackBarTone.error,
  }) {
    if (!mounted) return;
    final composer = _chatComposerKey.currentContext?.findRenderObject();
    // The composer lives in the body, so Scaffold cannot anchor above it.
    final bottomMargin = composer is RenderBox && composer.hasSize
        ? (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom -
                  composer.localToGlobal(Offset.zero).dy +
                  12)
              .clamp(18.0, double.infinity)
        : 18.0;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: tone,
        content: Text(message),
        margin: EdgeInsets.fromLTRB(20, 12, 20, bottomMargin),
      ),
    );
  }

  void _handleDetailMenuAction(_DetailMenuAction action) {
    switch (action) {
      case _DetailMenuAction.shareOnProfile:
        unawaited(_openProfileDraft());
        break;
      case _DetailMenuAction.refresh:
        unawaited(_bootstrap());
        break;
      case _DetailMenuAction.closeTable:
        unawaited(_cancelTable());
        break;
      case _DetailMenuAction.leaveTable:
        unawaited(_leave());
        break;
    }
  }

  Future<void> _openChat() async {
    if (_showChat || !_hasActiveChatAccess) return;
    _updateView(() => _showChat = true);
    await _loadMessages(reset: true, followLatest: true);
    if (!mounted || !_shouldRunChat) return;
    await _gameCubit.loadActive(exposeError: false);
    if (!mounted || !_shouldRunChat) return;
    await _connectRealtime();
  }

  Widget _detailOverview(TableGroup group, String? description) {
    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        key: const Key('table_group_detail_overview'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(15, 8, 15, 28),
        children: [
          _detailSummaryCard(group, description),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: _DetailSectionTitle('Masa Hakkında'),
          ),
          const SizedBox(height: 10),
          if (description != null)
            _tableDescriptionCard(description, showInlineTitle: false)
          else
            const _DetailEmptyInfoCard('Bu masa için açıklama eklenmemiş.'),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: _DetailSectionTitle('Katılımcılar'),
                ),
              ),
              _DetailCountPill(
                text: '${group.acceptedCount}/${group.maxPersonCount}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _detailParticipantsCard(group),
        ],
      ),
    );
  }

  Widget _overviewBottomBar(
    TableGroup group, {
    required bool includePublicNavigation,
  }) {
    final action = _overviewAction(group);
    return Material(
      color: TableGroupSurfaceStyle.of(context).pageBase,
      elevation: 18,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 16, 15, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        action.message,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TableGroupSurfaceStyle.of(context).bodyMuted,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailStickyAction(action),
                ],
              ),
            ),
            if (includePublicNavigation)
              ProfilePublicBottomBar(
                currentIndex: 2,
                stageMode: widget.args.bottomBarStageMode,
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailSummaryCard(TableGroup group, String? description) {
    final ownerName = _detailOwnerUsername(group);
    final ownerAvatar = _validUrlOrNull(group.ownerProfileImageUrl);
    return Container(
      key: const Key('table_group_detail_summary'),
      decoration: BoxDecoration(
        gradient: TableGroupSurfaceStyle.of(context).cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TableGroupSurfaceStyle.of(context).cardBorder,
        ),
        boxShadow: TableGroupSurfaceStyle.of(context).cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description ?? 'Masa buluşması',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TableGroupSurfaceStyle.of(context).primaryText,
                    fontSize: 21,
                    height: 1.16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _DetailAvatar(
                      imageUrl: ownerAvatar,
                      initials: _initialsFrom(ownerName),
                      size: 58,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ownerName.startsWith('@')
                                ? ownerName
                                : '@$ownerName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: TableGroupSurfaceStyle.of(
                                context,
                              ).headingMuted,
                              fontSize: 16,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 7,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Masa sahibi',
                                style: TextStyle(
                                  color: TableGroupSurfaceStyle.of(
                                    context,
                                  ).tertiaryText,
                                  fontSize: 14,
                                  height: 1.1,
                                ),
                              ),
                              if (group.isOwnerGhost) const GhostProfileBadge(),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: TableGroupSurfaceStyle.of(
                                  context,
                                ).bodyMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _detailLocationLabel(group),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: TableGroupSurfaceStyle.of(
                                      context,
                                    ).bodyMuted,
                                    fontSize: 14,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: _DetailStatsStrip(
              group: group,
              timeText: _meetingTimeOf(group.meetingAt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailParticipantsCard(TableGroup group) {
    final accepted = group.participants
        .where(
          (participant) =>
              participant.status == TableGroupParticipantStatus.accepted,
        )
        .toList(growable: true);
    if (!accepted.any((participant) => participant.userId == group.ownerId)) {
      accepted.add(
        TableGroupParticipant(
          userId: group.ownerId,
          joinedAt: null,
          status: TableGroupParticipantStatus.accepted,
          joinNote: null,
          username: group.ownerUsername,
          profilePictureUrl: group.ownerProfileImageUrl,
          visibilityMode: group.ownerVisibilityMode,
        ),
      );
    }
    accepted.sort((a, b) {
      if (a.userId == group.ownerId) return -1;
      if (b.userId == group.ownerId) return 1;
      final aTime = a.joinedAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.joinedAt?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });
    final visible = accepted.take(group.maxPersonCount).toList();
    final emptyCount = (group.maxPersonCount - visible.length).clamp(0, 6);
    final rows = <Widget>[
      for (final participant in visible)
        _detailParticipantRow(group, participant),
      for (var index = 0; index < emptyCount; index++)
        _DetailEmptyParticipantRow(index: index),
    ];
    return Container(
      key: const Key('table_group_detail_participants'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: TableGroupSurfaceStyle.of(context).cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TableGroupSurfaceStyle.of(context).cardBorder,
        ),
        boxShadow: TableGroupSurfaceStyle.of(context).cardShadows,
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1)
              Divider(
                height: 1,
                color: TableGroupSurfaceStyle.of(context).divider,
              ),
          ],
        ],
      ),
    );
  }

  Widget _detailParticipantRow(
    TableGroup group,
    TableGroupParticipant participant,
  ) {
    final isOwner = participant.userId == group.ownerId;
    final username = isOwner
        ? _detailOwnerUsername(group)
        : _participantDisplayName(participant);
    final imageUrl = _validUrlOrNull(
      isOwner
          ? group.ownerProfileImageUrl ?? participant.profilePictureUrl
          : participant.profilePictureUrl,
    );
    return InkWell(
      key: ValueKey<String>(
        'table_group_detail_participant-${participant.userId}',
      ),
      onTap: () => _openParticipantProfile(participant),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        child: Row(
          children: [
            _DetailAvatar(
              imageUrl: imageUrl,
              initials: _initialsFrom(username),
              size: 44,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username.startsWith('@') ? username : '@$username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: TableGroupSurfaceStyle.of(
                              context,
                            ).headingMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if ((isOwner && group.isOwnerGhost) ||
                          (!isOwner && participant.isGhost)) ...[
                        const SizedBox(width: 7),
                        const GhostProfileBadge(),
                      ],
                    ],
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Masa sahibi',
                      style: TextStyle(
                        color: TableGroupSurfaceStyle.of(context).tertiaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _DetailOverviewAction _overviewAction(TableGroup group) {
    if (_isAccepted) {
      return _DetailOverviewAction(
        label: 'Masaya git',
        message: 'Sohbete ve masa oyunlarına buradan ulaşabilirsin.',
        icon: Icons.chat_bubble_outline_rounded,
        onTap: () => unawaited(_openChat()),
      );
    }
    if (_myStatus == null && _isTableFull) {
      return const _DetailOverviewAction(
        label: 'Masa dolu',
        message:
            'Bu masadaki tüm yerler dolmuş. Başka bir masaya göz atabilirsin.',
        icon: Icons.group_off_outlined,
      );
    }
    if (_myStatus == null && !_canCreateOrJoin) {
      return const _DetailOverviewAction(
        label: 'Kişisel hesap gerekli',
        message:
            'Masa oluşturma ve katılma işlemleri kişisel hesaplarla kullanılabilir.',
        icon: Icons.lock_outline_rounded,
      );
    }
    return switch (_myStatus) {
      null => _DetailOverviewAction(
        label: _joinInFlight ? 'Katılıyor…' : 'Katıl',
        message: 'Masa sahibi isteğini onayladığında sohbete katılabilirsin.',
        icon: Icons.person_add_alt_1_rounded,
        onTap: _joinInFlight ? null : _join,
        loading: _joinInFlight,
      ),
      TableGroupParticipantStatus.pending => const _DetailOverviewAction(
        label: 'Katılma isteği beklemede',
        message:
            'Masa sahibi isteğini değerlendirdiğinde sana haber vereceğiz.',
        icon: Icons.hourglass_top_rounded,
      ),
      TableGroupParticipantStatus.rejected => const _DetailOverviewAction(
        label: 'İstek reddedildi',
        message: 'Bu masa için gönderdiğin katılma isteği reddedildi.',
        icon: Icons.block_outlined,
      ),
      TableGroupParticipantStatus.kicked => const _DetailOverviewAction(
        label: 'Masadan çıkarıldın',
        message: 'Masa sahibi tarafından bu masadan çıkarıldın.',
        icon: Icons.person_remove_outlined,
      ),
      TableGroupParticipantStatus.left => const _DetailOverviewAction(
        label: 'Masadan ayrıldın',
        message: 'Bu masadan ayrıldığın için sohbete erişemezsin.',
        icon: Icons.logout_rounded,
      ),
      TableGroupParticipantStatus.accepted => _DetailOverviewAction(
        label: 'Masaya git',
        message: 'Sohbete ve masa oyunlarına buradan ulaşabilirsin.',
        icon: Icons.chat_bubble_outline_rounded,
        onTap: () => unawaited(_openChat()),
      ),
    };
  }
}
