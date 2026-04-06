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
        _errorText = result.error?.message ?? 'Band detaylari yuklenemedi.';
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
              profileResult.error?.message ?? 'Muzisyen bilgisi alinamadi.',
            ),
          ),
        );
        return;
      }

      final invitedUserId = profileResult.data!.userId.trim();
      if (invitedUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Davet edilecek kullanici bulunamadi.')),
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
              inviteResult.error?.message ?? 'Band daveti gonderilemedi.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selection.displayName} icin davet gonderildi.'),
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
          title: const Text('Uyeyi Cikar'),
          content: Text(
            '${member.username} bandden cikarilsin mi?',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Iptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cikar'),
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
            content: Text(result.error?.message ?? 'Band uyesi cikarilamadi.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.username} bandden cikarildi.')),
      );
      await _refreshProfile();
    } finally {
      if (mounted) {
        _updateState(() => _submitting = false);
      }
    }
  }

  Future<void> _openMembersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refreshSheet() async {
              await _refreshProfile();
              if (sheetContext.mounted) {
                setSheetState(() {});
              }
            }

            Future<void> inviteFromSheet() async {
              await _inviteMember();
              if (sheetContext.mounted) {
                setSheetState(() {});
              }
            }

            Future<void> removeFromSheet(BandMemberSummary member) async {
              await _removeMember(member);
              if (sheetContext.mounted) {
                setSheetState(() {});
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Uyeleri Yonet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _submitting ? null : inviteFromSheet,
                          icon: const Icon(
                            Icons.group_add_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                        IconButton(
                          onPressed: _submitting ? null : refreshSheet,
                          icon: const Icon(
                            Icons.refresh_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorText != null
                          ? Center(
                              child: Text(
                                _errorText!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFFB4B4),
                                ),
                              ),
                            )
                          : _profile.members.isEmpty
                          ? const _EmptyCard(
                              text: 'Bandde henuz aktif uye gorunmuyor.',
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: _profile.members
                                  .map(
                                    (member) => _MemberCard(
                                      member: member,
                                      onRemove:
                                          _submitting ||
                                              member.role.toUpperCase() ==
                                                  'FOUNDER'
                                          ? null
                                          : () => removeFromSheet(member),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
