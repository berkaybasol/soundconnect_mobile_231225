part of 'band_management_panel_screen.dart';

extension _BandManagementPanelScreenStateMemberActions
    on _BandManagementPanelScreenState {
  Future<void> _refreshProfile() async {
    _updateState(() {
      _loading = true;
      _errorText = null;
    });

    final result = await _bandRepository.getBandById(_profile.id);
    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
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

  Future<void> _inviteMember() async {
    final selection = await _showMusicianPicker();
    if (selection == null || !mounted) return;

    _updateState(() => _submitting = true);
    try {
      final profileResult = await _musicianProfileRepository
          .getPublicProfileByProfileId(selection.profileId);
      if (!mounted) return;
      if (!profileResult.isSuccess || profileResult.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
          const SnackBar(content: Text('Davet edilecek kullanıcı bulunamadı.')),
        );
        return;
      }

      final inviteResult = await _bandRepository.inviteMember(
        bandId: _profile.id,
        invitedUserId: invitedUserId,
      );
      if (!mounted) return;

      if (!inviteResult.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              inviteResult.error?.message ?? 'Band daveti gönderilemedi.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

  Future<void> _removeMember(BandMemberSummary member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.navBlueDeep,
          title: const Text('Üyeyi Çıkar'),
          content: Text(
            '${member.username} bandden çıkarılsın mı?',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Çıkar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    _updateState(() => _submitting = true);
    try {
      final result = await _bandRepository.removeMember(
        bandId: _profile.id,
        userId: member.userId,
      );
      if (!mounted) return;

      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error?.message ?? 'Band üyesi çıkarılamadı.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.username} bandden çıkarıldı.')),
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
