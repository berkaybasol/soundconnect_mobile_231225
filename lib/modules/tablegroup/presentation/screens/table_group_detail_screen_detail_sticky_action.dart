part of 'table_group_detail_screen.dart';

extension _TableGroupDetailScreenStateDetailStickyActionMethods
    on _TableGroupDetailScreenState {
  Widget _detailStickyAction(_DetailOverviewAction action) {
    final enabled = action.onTap != null;
    final colors = enabled
        ? TableGroupSurfaceStyle.of(context).brandGradient
        : <Color>[
            (AppColors.isOriginalDark
                ? Theme.of(context).colorScheme.outline
                : AppColors.navBlueSoft),
            (AppColors.isOriginalDark
                ? Theme.of(context).colorScheme.outline
                : AppColors.navBlueSoft),
          ];
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('table_group_detail_sticky_action'),
          borderRadius: BorderRadius.circular(14),
          onTap: action.onTap,
          child: CustomPaint(
            painter: _GradientOutlinePainter(
              radius: 14,
              strokeWidth: 1.5,
              colors: colors,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (action.loading)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          action.icon,
                          size: 28,
                          color: enabled
                              ? TableGroupSurfaceStyle.of(context).primaryText
                              : (AppColors.isOriginalDark
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : AppColors.textMuted),
                        ),
                      const SizedBox(width: 12),
                      Text(
                        action.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: enabled
                              ? TableGroupSurfaceStyle.of(context).primaryText
                              : (AppColors.isOriginalDark
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : AppColors.textMuted),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _detailOwnerUsername(TableGroup group) {
    final username = group.ownerUsername?.trim();
    if (username != null && username.isNotEmpty) {
      return username.startsWith('@') ? username.substring(1) : username;
    }
    final ownerId = group.ownerId.trim();
    if (ownerId.isEmpty) return 'kullanıcı';
    return ownerId.length <= 8 ? ownerId : ownerId.substring(0, 8);
  }

  String _detailLocationLabel(TableGroup group) {
    final district = group.district?.name.trim();
    final city = group.city.name.trim();
    if (district != null && district.isNotEmpty && city.isNotEmpty) {
      return '$district · $city';
    }
    if (district != null && district.isNotEmpty) return district;
    return city.isEmpty ? 'Konum belirtilmedi' : city;
  }

  String? _tableDescription(TableGroup? group) {
    final description = group?.description?.trim();
    return description == null || description.isEmpty ? null : description;
  }

  Widget _tableDescriptionCard(
    String description, {
    bool showInlineTitle = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        key: const Key('table_group_description_card'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: TableGroupSurfaceStyle.of(context).cardGradient,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: TableGroupSurfaceStyle.of(context).cardBorder,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTableDescription(description),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 13, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showInlineTitle) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Masa hakkında',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.open_in_full_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    description,
                    key: const Key('table_group_description'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: TableGroupSurfaceStyle.of(context).bodyMuted,
                      fontSize: 15,
                      height: 1.42,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTableDescription(String description) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.76),
      builder: (dialogContext) =>
          _PremiumDescriptionDialog(description: description),
    );
  }

  Widget _chatPanel({required bool fullScreen}) {
    final group = _group;
    final participants = group == null
        ? const <TableGroupParticipant>[]
        : group.participants
              .where(
                (participant) =>
                    participant.status == TableGroupParticipantStatus.accepted,
              )
              .toList(growable: false);

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!fullScreen)
            const Text('Sohbet', style: TextStyle(fontWeight: FontWeight.w700)),
          if (_isOwner || (!_isOwner && _isAccepted)) ...[
            if (!fullScreen) const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!_isOwner && _isAccepted)
                    SizedBox(
                      width: 120,
                      child: _brandOutlineButton(
                        label: _sessionActionInFlight ? 'Bekleyin...' : 'Ayril',
                        onTap: _sessionActionInFlight || !_hasActiveChatAccess
                            ? null
                            : _leave,
                      ),
                    ),
                  if (_isOwner)
                    SizedBox(
                      width: 170,
                      child: _brandOutlineButton(
                        label: _sessionActionInFlight
                            ? 'Sonlandiriliyor...'
                            : 'Oturumu Sonlandir',
                        onTap: _sessionActionInFlight || !_hasActiveChatAccess
                            ? null
                            : _cancelTable,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (_realtimeError != null) ...[
            _chatStatusBanner(
              message: _realtimeError!,
              icon: Icons.wifi_off_rounded,
              actionLabel: _connectingRealtime ? 'Baglaniyor...' : 'Baglan',
              onAction: _connectingRealtime ? null : _recoverRealtime,
            ),
            const SizedBox(height: 8),
          ] else if (_connectingRealtime) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
          ],
          if (_chatError != null) ...[
            _chatStatusBanner(
              message: _chatError!,
              icon: Icons.history_rounded,
              actionLabel: 'Tekrar dene',
              onAction: _chatLoading
                  ? null
                  : () => _loadMessages(
                      reset: _chatRetryReset,
                      followLatest: _chatRetryReset && _messages.isEmpty,
                    ),
            ),
            const SizedBox(height: 8),
          ],
          if (fullScreen)
            Expanded(
              child: NotificationTargetReady(
                ready:
                    widget.args.notificationTarget?.pending == true &&
                    !_loading &&
                    _error == null &&
                    _chatLoaded &&
                    !_chatLoading &&
                    _chatError == null &&
                    _shouldRunChat,
                acknowledge: false,
                contentIdentity: widget.args.notificationTarget,
                onVisible: _confirmVisibleChat,
                child: _chatRoom(participants),
              ),
            )
          else
            SizedBox(height: 440, child: _chatRoom(participants)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_chatHasNext)
                TextButton(
                  onPressed: _chatLoading || !_shouldRunChat
                      ? null
                      : () => _loadMessages(reset: false),
                  child: const Text('Daha eski mesajlar'),
                ),
              if (_chatLoading && _messages.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            key: _chatComposerKey,
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz',
                    counterText: '',
                    prefixIcon: IconButton(
                      key: const ValueKey<String>('table-group-game-launcher'),
                      tooltip: 'Oyunlar',
                      onPressed:
                          !_shouldRunChat ||
                              _gameLauncherOpen ||
                              _gameState.loading ||
                              _gameState.actionInFlight
                          ? null
                          : _openGameLauncher,
                      icon: const BrandGradientIcon(
                        Icons.sports_esports_rounded,
                        semanticLabel: 'Oyunlar',
                      ),
                    ),
                  ),
                  enabled: _shouldRunChat,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 116,
                child: _brandOutlineButton(
                  label: _sending ? 'Gonderiliyor...' : 'Gonder',
                  onTap: (_sending || !_shouldRunChat) ? null : _sendMessage,
                  compact: true,
                ),
              ),
            ],
          ),
          if (!_shouldRunChat)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Bu sohbet artik yeni mesaja kapali'),
            ),
        ],
      ),
    );

    if (fullScreen) return content;
    return Card(child: content);
  }

  Widget _pendingRequestsPanel() {
    final requests = _pendingJoinRequests;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index],
              target = widget.args.notificationTarget;
          final card = _joinRequestCard(request);
          if (target == null ||
              !target.pending ||
              request.userId != target.subjectId ||
              request.applicationId != target.applicationId) {
            return card;
          }
          return NotificationTargetReady(
            key: ValueKey('table-exact-application-${target.applicationId}'),
            ready:
                !_loading &&
                _error == null &&
                _group != null &&
                _notificationMatches(_group!) &&
                _showChat,
            requireVisibleBounds: true,
            contentIdentity: target,
            child: card,
          );
        },
      ),
    );
  }

  Widget _chatRoom(List<TableGroupParticipant> participants) {
    final pendingRequests = _isOwner
        ? _pendingJoinRequests
        : const <TableGroupParticipant>[];
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              if (pendingRequests.isNotEmpty)
                Flexible(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _pendingRequestsPanel(),
                  ),
                ),
              Expanded(
                child: _messages.isEmpty && _chatLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _chatScrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final mine = msg.senderId == _currentUserId;
                          final sender = _participantByUserId(msg.senderId);
                          return _chatMessageRow(
                            message: msg,
                            mine: mine,
                            sender: sender,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    final avatarUrl = _validUrlOrNull(p.profilePictureUrl);
                    final canKick =
                        _isOwner &&
                        p.userId != _group?.ownerId &&
                        _shouldRunChat;
                    final actionInFlight = _ownerActionInFlightIds.contains(
                      p.userId,
                    );
                    return Center(
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 4,
                              top: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => _openParticipantProfile(p),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _participantStatusColor(p.status),
                                      width: 1.3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundImage: avatarUrl != null
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            _initialsFrom(
                                              _participantDisplayName(p),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            if (canKick)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Tooltip(
                                  message:
                                      '${_participantDisplayName(p)} '
                                      'kullanicisini masadan cikar',
                                  child: InkWell(
                                    key: ValueKey<String>('kick-${p.userId}'),
                                    onTap: actionInFlight
                                        ? null
                                        : () => _confirmKickParticipant(p),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.errorContainer,
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: actionInFlight
                                          ? const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                              ),
                                            )
                                          : Icon(
                                              Icons.remove_rounded,
                                              size: 15,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onErrorContainer,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_isGhostParticipant(p))
                              const Positioned(
                                right: 0,
                                top: 0,
                                child: GhostProfileBadge(showLabel: false),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _closedSessionPanel(TableGroup group) {
    final expiresAt = group.expiresAt?.toLocal();
    final description = _tableDescription(group);
    final normalizedVenue = group.venueName?.trim();
    final venue = normalizedVenue?.isNotEmpty == true
        ? normalizedVenue!
        : TableGroupOverviewStyle.unspecifiedVenueLabel;
    final status = group.status.trim().toUpperCase();
    final cancelled = status == 'CANCELLED';
    final expired =
        !cancelled &&
        (status == 'INACTIVE' || group.expiresAt?.isAfter(_now()) == false);
    final locationParts = <String>[
      group.city.name,
      if (group.district?.name.trim().isNotEmpty == true) group.district!.name,
      if (group.neighborhood?.name.trim().isNotEmpty == true)
        group.neighborhood!.name,
    ];
    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 48),
          Icon(
            expired ? Icons.schedule_rounded : Icons.event_busy_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            expired ? 'Bu masa sona erdi' : 'Bu masa kapatildi',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Masa bilgilerini gorebilirsin ancak katilim ve sohbet '
            'aksiyonlari artik kullanilamaz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (description != null) ...[
            _tableDescriptionCard(description),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    key: const Key('table_group_closed_venue'),
                    children: [
                      const Icon(Icons.storefront_outlined, size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          venue,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(locationParts.join(' • ')),
                  const SizedBox(height: 8),
                  Text('${group.acceptedCount} katilimci'),
                  if (expiresAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Bitis: '
                      '${expiresAt.day.toString().padLeft(2, '0')}.'
                      '${expiresAt.month.toString().padLeft(2, '0')}.'
                      '${expiresAt.year} '
                      '${_timeOf(expiresAt)}',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatStatusBanner({
    required String message,
    required IconData icon,
    required String actionLabel,
    required Future<void> Function()? onAction,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  String _timeOf(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _meetingTimeOf(DateTime? value) =>
      formatTableGroupMeetingAt(value, now: _now());

  List<TableGroupParticipant> get _pendingJoinRequests {
    final group = _group;
    if (group == null) return const <TableGroupParticipant>[];
    final pending = group.participants
        .where(
          (participant) =>
              participant.status == TableGroupParticipantStatus.pending &&
              participant.userId != group.ownerId,
        )
        .toList();
    pending.sort((a, b) {
      final aa = a.joinedAt?.millisecondsSinceEpoch ?? 0;
      final bb = b.joinedAt?.millisecondsSinceEpoch ?? 0;
      return bb.compareTo(aa);
    });
    final target = widget.args.notificationTarget;
    if (target?.pending == true) {
      final index = pending.indexWhere(
        (p) =>
            p.userId == target!.subjectId &&
            p.applicationId == target.applicationId,
      );
      if (index > 0) pending.insert(0, pending.removeAt(index));
    }
    return pending;
  }

  String _participantDisplayName(TableGroupParticipant participant) {
    final username = participant.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    final shortId = participant.userId.length > 8
        ? participant.userId.substring(0, 8)
        : participant.userId;
    return shortId;
  }

  bool _isGhostParticipant(TableGroupParticipant? participant) {
    if (participant == null) return false;
    final group = _group;
    return participant.isGhost ||
        (group != null &&
            group.isOwnerGhost &&
            participant.userId == group.ownerId);
  }
}
