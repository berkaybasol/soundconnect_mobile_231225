part of 'band_management_panel_screen.dart';

extension _BandManagementPanelScreenStateMemberActions
    on _BandManagementPanelScreenState {
  Future<void> _refreshProfile() async {
    final generation = ++_profileLoadGeneration;
    final bandId = _profile.id;
    final manager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    final session = manager?.session;
    bool current() => mounted && generation == _profileLoadGeneration;
    _updateState(() {
      _loading = true;
      _errorText = null;
    });

    final Result<BandProfile> result;
    try {
      result = await _bandRepository.getBandById(bandId);
    } catch (_) {
      if (!current()) return;
      _updateState(() {
        _loading = false;
        _errorText = 'Üyeler yüklenemedi. Lütfen tekrar dene.';
      });
      return;
    }
    if (!current()) return;

    if (!identical(manager?.session, session)) {
      _updateState(() {
        _loading = false;
        _errorText = 'Oturum değişti. Bu sayfayı yeniden aç.';
      });
      return;
    }

    if (!result.isSuccess ||
        result.data == null ||
        result.data!.id.trim() != bandId.trim()) {
      _updateState(() {
        _loading = false;
        _errorText = result.error?.message ?? 'Band detayları yüklenemedi.';
      });
      return;
    }

    _updateState(() {
      _loading = false;
      _profile = result.data!;
    });
  }

  Future<void> _inviteMember({bool Function()? isCurrent}) async {
    final session = ProfileActionSession(
      roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
    );
    final bandId = _profile.id;
    bool current() =>
        mounted &&
        session.isCurrent &&
        _profile.id == bandId &&
        _profile.members.any(
          (member) =>
              member.userId.trim() == session.userId?.trim() &&
              member.isFounder &&
              member.status.trim().toUpperCase() == 'ACTIVE',
        ) &&
        (isCurrent?.call() ?? true);
    if (_submitting || !current()) return;
    _updateState(() => _submitting = true);
    try {
      final selection = await _showMusicianPicker(isCurrent: current);
      if (!mounted || selection == null || !current()) return;
      final profileResult = await _musicianProfileRepository
          .getPublicProfileByProfileId(selection.profileId);
      if (!mounted || !current()) return;
      if (!profileResult.isSuccess ||
          profileResult.data == null ||
          profileResult.data!.id.trim() != selection.profileId.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: Text(
              profileResult.error?.message ?? 'Müzisyen bilgisi alınamadı.',
            ),
          ),
        );
        return;
      }

      final invitedUserId = profileResult.data!.userId.trim();
      if (invitedUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.warning,
            content: Text('Davet edilecek kullanıcı bulunamadı.'),
          ),
        );
        return;
      }

      final inviteResult = await _bandRepository.inviteMember(
        bandId: bandId,
        invitedUserId: invitedUserId,
        expectedSessionKey: session.userId,
      );
      if (!mounted || !current()) return;

      if (!inviteResult.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: Text(
              inviteResult.error?.message ?? 'Band daveti gönderilemedi.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: Text('${selection.displayName} için davet gönderildi.'),
        ),
      );
      await _refreshProfile();
    } finally {
      if (mounted) {
        _updateState(() => _submitting = false);
      }
    }
  }

  Future<void> _removeMember(
    BandMemberSummary member, {
    bool Function()? isCurrent,
  }) async {
    final session = ProfileActionSession(
      roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
    );
    final bandId = _profile.id;
    bool current() =>
        mounted &&
        session.isCurrent &&
        _profile.id == bandId &&
        _profile.members.any(
          (candidate) =>
              candidate.userId.trim() == session.userId?.trim() &&
              candidate.isFounder &&
              candidate.status.trim().toUpperCase() == 'ACTIVE',
        ) &&
        (isCurrent?.call() ?? true);
    if (_submitting || member.isFounder || !current()) return;
    var decisionDelivered = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        void decide(bool decision) {
          if (decisionDelivered ||
              !dialogContext.mounted ||
              ModalRoute.of(dialogContext)?.isCurrent != true) {
            return;
          }
          decisionDelivered = true;
          Navigator.of(dialogContext).pop(decision);
        }

        return AlertDialog(
          backgroundColor: AppColors.navBlueDeep,
          title: Text('Üyeyi Çıkar'),
          content: Text(
            '${member.username} gruptan çıkarılsın mı?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(onPressed: () => decide(false), child: Text('İptal')),
            FilledButton(onPressed: () => decide(true), child: Text('Çıkar')),
          ],
        );
      },
    );

    if (confirmed != true || !current() || _submitting) return;

    _updateState(() => _submitting = true);
    try {
      final result = await _bandRepository.removeMember(
        bandId: bandId,
        userId: member.userId,
        expectedSessionKey: session.userId,
        expectedTitleVersion: member.titleVersion,
      );
      if (!mounted || !current()) return;

      if (!result.isSuccess) {
        if (result.error?.code == '9221') {
          await _refreshProfile();
          if (!mounted || !session.isCurrent) return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: Text(
              result.error?.code == '9221'
                  ? 'Üyelik bilgileri değişti. Üyeleri yenileyip tekrar seç.'
                  : result.error?.message ?? 'Band üyesi çıkarılamadı.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: Text('${member.username} gruptan çıkarıldı.'),
        ),
      );
      await _refreshProfile();
    } finally {
      if (mounted) {
        _updateState(() => _submitting = false);
      }
    }
  }

  Future<void> _openMembersPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _BandMembersWorkspaceScreen(owner: this),
      ),
    );
  }
}
