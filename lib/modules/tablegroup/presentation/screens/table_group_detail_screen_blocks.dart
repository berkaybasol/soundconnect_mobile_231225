part of 'table_group_detail_screen.dart';

String _blockedMemberName(TableGroupParticipant member) {
  final name = member.username?.trim();
  if (name == null || name.isEmpty) return 'bir kullanıcı';
  return name.startsWith('@') ? name : '@$name';
}

extension _TableGroupDetailBlockMethods on _TableGroupDetailScreenState {
  void _onRoomChange(TableGroupRoomChange change) {
    if (!mounted || !_sameTableSession || !_isSessionActive) return;
    if (change == TableGroupRoomChange.membership) {
      unawaited(_loadDetail(replaceScreenOnFailure: false));
      return;
    }
    final followLatest = _isNearLatest;
    _discardChatProjection();
    final refresh = _refreshVisibility(_visibilityGeneration, followLatest);
    _reconciliationInFlight = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (identical(_reconciliationInFlight, refresh)) {
          _reconciliationInFlight = null;
        }
      }),
    );
  }

  void _discardChatProjection() {
    _visibilityGeneration++;
    _gameCubit.clear();
    _updateView(() {
      _messages = const [];
      _gameState = const TableGroupGameState.idle();
      _chatLoaded = false;
      _chatLoading = false;
      _chatPage = 0;
      _chatHasNext = false;
      _clearGameExpiryRetry();
    });
  }

  Future<void> _refreshVisibility(int generation, bool followLatest) async {
    await _loadDetail(replaceScreenOnFailure: false);
    if (!mounted || generation != _visibilityGeneration || !_shouldRunChat) {
      return;
    }
    await _loadMessages(reset: true, followLatest: followLatest);
    if (!mounted || generation != _visibilityGeneration || !_shouldRunChat) {
      return;
    }
    await _gameCubit.loadActive(exposeError: false);
  }

  void _scheduleArrivalWarning() {
    if (_presentingArrival ||
        !_hasActiveChatAccess ||
        !_group!.participants.any((p) => p.blockedArrival && p.blockedByMe)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_presentingArrival &&
          _sameTableSession &&
          _hasActiveChatAccess &&
          ModalRoute.of(context)?.isCurrent == true &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        unawaited(_showArrivalWarnings());
      }
    });
  }

  Future<void> _showArrivalWarnings() async {
    _presentingArrival = true;
    try {
      final storageKey = 'table.blocked-arrivals.${_currentUserId!}';
      SharedPreferences? preferences;
      try {
        preferences = await SharedPreferences.getInstance();
      } catch (_) {
        // The current screen still remembers the user's choice without storage.
      }
      if (!mounted || !_sameTableSession || !_hasActiveChatAccess) return;
      _handledArrivals.addAll(
        preferences?.getStringList(storageKey) ?? const [],
      );
      while (mounted &&
          _sameTableSession &&
          _hasActiveChatAccess &&
          ModalRoute.of(context)?.isCurrent == true) {
        final group = _group!;
        final viewer = _participantByUserId(_currentUserId);
        final viewerMembership =
            viewer?.applicationId ??
            viewer?.joinedAt?.toUtc().toIso8601String();
        String key(TableGroupParticipant member) {
          final memberKey =
              '${group.id}/${member.userId}/${member.applicationId ?? member.joinedAt?.toUtc().toIso8601String() ?? ''}';
          return _isOwner || viewerMembership == null
              ? memberKey
              : '$memberKey/$viewerMembership';
        }

        final member = group.participants
            .where(
              (person) =>
                  person.status == TableGroupParticipantStatus.accepted &&
                  person.blockedByMe &&
                  person.blockedArrival &&
                  !_handledArrivals.contains(key(person)),
            )
            .firstOrNull;
        if (member == null) return;
        final arrivalKey = key(member);
        final leave = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _tableOverlayContent(
            context,
            _PremiumConfirmationDialog(
              title: 'Masaya katılım',
              message:
                  'Engellediğiniz ${_blockedMemberName(member)} masaya katıldı.',
              cancelLabel: 'Masada kal',
              confirmLabel: 'Masadan ayrıl',
            ),
          ),
        );
        if (!mounted ||
            !_sameTableSession ||
            !_hasActiveChatAccess ||
            leave == null) {
          return;
        }
        _handledArrivals.add(arrivalKey);
        if (preferences != null) {
          final recent = _handledArrivals.toList();
          try {
            await preferences.setStringList(
              storageKey,
              recent.length > 200
                  ? recent.sublist(recent.length - 200)
                  : recent,
            );
          } catch (_) {
            // The in-memory choice remains valid for this screen.
          }
        }
        if (!mounted || !_sameTableSession || !_hasActiveChatAccess) return;
        if (leave) {
          if (_isOwner) {
            await _cancelTable();
          } else {
            await _leave(alreadyConfirmed: true);
          }
          return;
        }
      }
    } finally {
      _presentingArrival = false;
    }
  }
}
