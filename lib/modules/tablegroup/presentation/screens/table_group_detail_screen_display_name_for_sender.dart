part of 'table_group_detail_screen.dart';

extension _TableGroupDetailScreenStateDisplayNameForSenderMethods
    on _TableGroupDetailScreenState {
  String _displayNameForSender(
    TableGroupParticipant? sender,
    String senderUserId,
  ) {
    if (sender != null) return _participantDisplayName(sender);
    return senderUserId.length > 8
        ? senderUserId.substring(0, 8)
        : senderUserId;
  }

  String? _validUrlOrNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    return text;
  }

  String _initialsFrom(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final one = parts.first;
      return one.length >= 2
          ? one.substring(0, 2).toUpperCase()
          : one.toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  Color _participantStatusColor(TableGroupParticipantStatus status) {
    return switch (status) {
      TableGroupParticipantStatus.accepted => const Color(0xFF2FB46E),
      TableGroupParticipantStatus.pending => const Color(0xFFE0A200),
      TableGroupParticipantStatus.rejected => const Color(0xFFD06363),
      TableGroupParticipantStatus.kicked => const Color(0xFFD06363),
      TableGroupParticipantStatus.left => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
  }

  Future<void> _openParticipantProfile(
    TableGroupParticipant participant,
  ) async {
    if (!mounted) return;
    final resolver = serviceLocator<DmUserProfileResolver>();
    final resolvedTargets = await resolver.resolveByUserId(
      userId: participant.userId,
      usernameHint: participant.username,
    );
    if (!mounted) return;
    final isCurrentUser = participant.userId == _currentUserId;
    final targets = resolvedTargets
        .where((target) => isCurrentUser || dmProfileRouteFor(target) != null)
        .toList(growable: false);
    if (targets.isEmpty) {
      _showSnack(
        'Bu kullanici icin acik profil bulunamadi',
        tone: AppSnackBarTone.warning,
      );
      return;
    }
    if (targets.length == 1) {
      if (isCurrentUser) {
        _navigateToOwnerProfileTarget(targets.first);
      } else {
        _navigateToProfileTarget(targets.first);
      }
      return;
    }
    final selected = await showModalBottomSheet<DmProfileTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => _TableGroupProfileTargetSheet(items: targets),
    );
    if (!mounted || selected == null) return;
    if (isCurrentUser) {
      _navigateToOwnerProfileTarget(selected);
    } else {
      _navigateToProfileTarget(selected);
    }
  }

  void _navigateToOwnerProfileTarget(DmProfileTarget target) {
    Navigator.of(context).pushNamed(ownerProfileRouteFor(target.type));
  }

  void _navigateToProfileTarget(DmProfileTarget target) {
    final route = dmProfileRouteFor(target);
    if (route == null) return;
    Navigator.of(
      context,
    ).pushNamed(route.routeName, arguments: route.arguments);
  }

  Future<void> _approvePendingRequest(TableGroupParticipant participant) async {
    final displayName = _participantDisplayName(participant);
    final username = displayName.startsWith('@')
        ? displayName
        : '@$displayName';
    final confirmed = await _confirmSessionAction(
      title: 'Katılım talebini onayla?',
      message: "$username'nin masaya katılım talebini onaylıyor musunuz?",
      confirmLabel: 'Onayla',
    );
    if (!confirmed || !mounted) return;
    await _runOwnerAction(
      participantId: participant.userId,
      fn: () => _approve(participant.userId),
    );
  }

  Future<void> _rejectPendingRequest(TableGroupParticipant participant) async {
    final displayName = _participantDisplayName(participant);
    final confirmed = await _confirmSessionAction(
      title: 'Başvuruyu reddet?',
      message: '$displayName kullanıcısının katılma isteği reddedilecek.',
      confirmLabel: 'Reddet',
    );
    if (!confirmed || !mounted) return;
    await _runOwnerAction(
      participantId: participant.userId,
      fn: () => _reject(participant.userId),
    );
  }

  Widget _joinRequestCard(TableGroupParticipant participant) {
    final avatarUrl = _validUrlOrNull(participant.profilePictureUrl);
    final loading = _ownerActionInFlightIds.contains(participant.userId);
    final displayName = _participantDisplayName(participant);
    final joinNote = participant.joinNote?.trim();
    return CustomPaint(
      painter: _GradientOutlinePainter(
        radius: 14,
        strokeWidth: 1.2,
        colors: AppColors.decorativeGradient,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      _initialsFrom(displayName),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yeni katılma isteği',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (participant.isGhost) ...[
                        const SizedBox(width: 7),
                        const GhostProfileBadge(),
                      ],
                    ],
                  ),
                  if (joinNote != null && joinNote.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      joinNote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (loading)
              const SizedBox(
                width: 48,
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _requestActionIcon(
                key: ValueKey<String>(
                  'table_group_approve-${participant.userId}',
                ),
                label: '$displayName kullanıcısını onayla',
                icon: Icons.check_rounded,
                color: const Color(0xFF2FB46E),
                onTap: () => _approvePendingRequest(participant),
              ),
              const SizedBox(width: 6),
              _requestActionIcon(
                key: ValueKey<String>(
                  'table_group_reject-${participant.userId}',
                ),
                label: '$displayName kullanıcısını reddet',
                icon: Icons.close_rounded,
                color: const Color(0xFFE45656),
                onTap: () => _rejectPendingRequest(participant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _requestActionIcon({
    required Key key,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      key: key,
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(color: color, width: 1.25),
          backgroundColor: color.withValues(alpha: 0.12),
        ),
        icon: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _brandOutlineButton({
    required String label,
    required VoidCallback? onTap,
    bool compact = false,
  }) {
    final disabled = onTap == null;
    const radius = 18.0;
    final borderColors = disabled
        ? [
            Theme.of(context).dividerColor.withValues(alpha: 0.7),
            Theme.of(context).dividerColor.withValues(alpha: 0.7),
          ]
        : AppColors.decorativeGradient;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: CustomPaint(
          painter: _GradientOutlinePainter(
            radius: radius,
            strokeWidth: 1.3,
            colors: borderColors,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: disabled
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableGroupParticipant? _participantByUserId(String userId) {
    final group = _group;
    if (group == null) return null;
    for (final participant in group.participants) {
      if (participant.userId == userId) return participant;
    }
    return null;
  }

  Widget _chatMessageRow({
    required TableGroupMessage message,
    required bool mine,
    required TableGroupParticipant? sender,
  }) {
    final game = message.game;
    if (message.messageType == 'GAME' && game != null) {
      final currentGame = _gameState.game;
      return TableGroupGameMessageCard(
        message: message,
        currentUserId: _currentUserId,
        canCancelGame: _isOwner || _currentUserId == game.createdBy,
        actionInFlight: _gameState.actionInFlight,
        actionCommitted: _gameState.isActionCommittedFor(game),
        interactionEnabled:
            _shouldRunChat &&
            currentGame?.gameId == game.gameId &&
            currentGame?.revision == game.revision,
        onJoin: () => unawaited(_joinGame(game)),
        onLeave: () => unawaited(_leaveGame(game)),
        onStart: () => unawaited(_startGame(game)),
        onCancel: () => unawaited(_cancelGame(game)),
        onAction: (action, targetUserId) =>
            unawaited(_submitGameAction(game, action, targetUserId)),
        onExpired: () => _reconcileExpiredGame(game),
        now: _now,
      );
    }
    final avatarUrl = sender == null
        ? null
        : _validUrlOrNull(sender.profilePictureUrl);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: mine
            ? LinearGradient(
                colors: AppColors.isLight
                    ? AppColors.actionGradient
                    : [AppColors.gradientA, AppColors.gradientC],
              )
            : null,
        color: mine
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(mine ? 14 : 6),
          bottomRight: Radius.circular(mine ? 6 : 14),
        ),
        border: Border.all(
          color: mine ? Colors.transparent : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: mine && AppColors.isLight
                  ? AppColors.onAccent
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _timeOf(message.sentAt),
            style: TextStyle(
              fontSize: 11,
              color: mine
                  ? AppColors.onAccent.withValues(alpha: 0.84)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (mine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainer,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          _initialsFrom(
                            _displayNameForSender(sender, message.senderId),
                          ),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                if (_isGhostParticipant(sender))
                  const Positioned(
                    right: -3,
                    bottom: -2,
                    child: GhostProfileBadge(showLabel: false),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
