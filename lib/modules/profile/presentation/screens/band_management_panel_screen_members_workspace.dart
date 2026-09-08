part of 'band_management_panel_screen.dart';

enum _MemberOption { editTitle, remove }

class _BandMembersWorkspaceScreen extends StatefulWidget {
  final _BandManagementPanelScreenState owner;

  _BandMembersWorkspaceScreen({required this.owner});

  @override
  State<_BandMembersWorkspaceScreen> createState() =>
      _BandMembersWorkspaceScreenState();
}

class _BandMembersWorkspaceScreenState
    extends State<_BandMembersWorkspaceScreen>
    with WidgetsBindingObserver {
  _BandManagementPanelScreenState get _owner => widget.owner;
  BandProfile get _profile => _owner._profile;
  bool get _loading => _owner._loading;
  bool get _submitting => _owner._submitting;
  String? get _errorText => _owner._errorText;
  final Map<String, String> _resolvedProfileIdsByUserId = <String, String>{};
  final Map<String, String> _resolvedAvatarUrlsByUserId = <String, String>{};
  final Set<String> _resolvingUserIds = <String>{};
  late final BandMemberProfileResolver _memberProfileResolver =
      BandMemberProfileResolver();
  bool _working = false;
  bool _titleEditorOpen = false;
  bool _memberMenuOpen = false;
  bool _refreshOnResume = false;
  String? _savingTitleUserId;
  AuthSessionManager? _titleSessionManager;
  bool get _busy =>
      _working ||
      _submitting ||
      _loading ||
      _memberMenuOpen ||
      _titleEditorOpen ||
      _savingTitleUserId != null;

  bool get _canManageMembers =>
      !_loading && _errorText == null && _hasFounderSession;

  bool get _hasFounderSession {
    final session = _titleSessionManager?.session;
    final viewerId = session?.userId?.trim() ?? '';
    return _owner.mounted &&
        session?.isAuthenticated == true &&
        session?.isActive == true &&
        session!.hasAnyRole(const ['ROLE_MUSICIAN', 'MUSICIAN']) &&
        viewerId.isNotEmpty &&
        _profile.members.any(
          (candidate) =>
              candidate.userId.trim() == viewerId &&
              candidate.isFounder &&
              candidate.status.trim().toUpperCase() == 'ACTIVE',
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _owner._profileRevision.addListener(_onOwnerChanged);
    _titleSessionManager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    _titleSessionManager?.addListener(_onTitleSessionChanged);
    _hydrateMembers();
  }

  void _onOwnerChanged() {
    if (mounted) setState(() {});
  }

  void _onTitleSessionChanged() {
    _refreshOnResume = false;
    if (mounted) setState(() {});
  }

  void _updateTitleState(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _owner._profileRevision.removeListener(_onOwnerChanged);
    _titleSessionManager?.removeListener(_onTitleSessionChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _hasFounderSession) {
      _refreshOnResume = true;
      _drainResumeRefresh();
    }
  }

  void _drainResumeRefresh() {
    if (!mounted ||
        !_refreshOnResume ||
        !_canManageMembers ||
        _busy ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _refreshOnResume = false;
    unawaited(_refreshMembers());
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy || !mounted || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _working = true);
    try {
      await action();
      if (mounted) await _hydrateMembers();
    } catch (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: const Text('İşlem tamamlanamadı. Lütfen tekrar dene.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
      _drainResumeRefresh();
    }
  }

  Future<void> _refreshMembers() async {
    await _runAction(_owner._refreshProfile);
  }

  Future<void> _inviteMember() async {
    if (!_canManageMembers) return;
    final session = _titleSessionManager?.session;
    final bandId = _profile.id;
    await _runAction(
      () => _owner._inviteMember(
        isCurrent: () =>
            mounted &&
            _canManageMembers &&
            _profile.id == bandId &&
            identical(_titleSessionManager?.session, session),
      ),
    );
  }

  Future<void> _removeMember(BandMemberSummary member) async {
    if (member.isFounder || !_canManageMembers) return;
    final session = _titleSessionManager?.session;
    final bandId = _profile.id;
    await _runAction(() async {
      await _owner._removeMember(
        member,
        isCurrent: () =>
            mounted &&
            _owner.mounted &&
            _canManageMembers &&
            _profile.id == bandId &&
            identical(_titleSessionManager?.session, session) &&
            _sameActionMember(member),
      );
      _resolvedProfileIdsByUserId.remove(member.userId);
      _resolvedAvatarUrlsByUserId.remove(member.userId);
    });
  }

  bool _sameActionMember(BandMemberSummary member) => _profile.members.any(
    (current) =>
        current.userId == member.userId &&
        current.profileId == member.profileId &&
        current.roleCode == member.roleCode &&
        current.status == member.status &&
        current.titleVersion == member.titleVersion &&
        current.memberTitle == member.memberTitle,
  );

  Future<void> _showMemberOptions(BandMemberSummary member) async {
    if (!mounted ||
        !_owner.mounted ||
        !_canManageMembers ||
        _busy ||
        !_sameActionMember(member) ||
        ModalRoute.of(context)?.isCurrent != true) {
      _drainResumeRefresh();
      return;
    }
    final canEdit = _canEditTitle(member);
    if (!canEdit && member.isFounder) return;
    final session = _titleSessionManager?.session;
    final bandId = _profile.id;
    _MemberOption? selected;
    setState(() => _memberMenuOpen = true);
    try {
      selected = await showProfileManagementSheet<_MemberOption>(
        context,
        title: member.username,
        options: [
          if (canEdit)
            ProfileManagementSheetOption(
              key: ValueKey('edit-member-title-${member.userId}'),
              value: _MemberOption.editTitle,
              icon: Icons.edit_outlined,
              label: 'Rolü düzenle',
            ),
          if (!member.isFounder)
            ProfileManagementSheetOption(
              key: ValueKey('remove-member-${member.userId}'),
              value: _MemberOption.remove,
              icon: Icons.person_remove_outlined,
              label: 'Gruptan çıkar',
            ),
        ],
      );
    } finally {
      if (mounted) setState(() => _memberMenuOpen = false);
    }
    // A menu is only a presentation choice. Recheck the captured identity and
    // membership after it closes before invoking either existing action.
    if (!mounted ||
        !_owner.mounted ||
        selected == null ||
        !_canManageMembers ||
        _busy ||
        _profile.id != bandId ||
        !identical(_titleSessionManager?.session, session) ||
        !_sameActionMember(member) ||
        ModalRoute.of(context)?.isCurrent != true) {
      _drainResumeRefresh();
      return;
    }
    switch (selected) {
      case _MemberOption.editTitle:
        await _editMemberTitle(member);
      case _MemberOption.remove:
        await _removeMember(member);
    }
    _drainResumeRefresh();
  }

  Future<void> _openMemberProfile(BandMemberSummary member) async {
    if (_busy) return;
    final bandId = _profile.id;
    await _memberProfileResolver.open(
      context,
      member,
      isMemberCurrent: () =>
          !_busy &&
          _profile.id == bandId &&
          _profile.members.any(
            (current) =>
                current.userId == member.userId &&
                current.profileId == member.profileId,
          ),
    );
    _drainResumeRefresh();
  }

  Future<void> _hydrateMembers() async {
    for (final member in _profile.members) {
      if (!mounted) return;
      await _resolveMemberMetadata(member);
    }
  }

  String? _effectiveAvatar(BandMemberSummary member) {
    final direct = member.profilePictureUrl?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final cached = _resolvedAvatarUrlsByUserId[member.userId]?.trim() ?? '';
    return cached.isEmpty ? null : cached;
  }

  Future<void> _resolveMemberMetadata(BandMemberSummary member) async {
    final userId = member.userId.trim();
    if (userId.isEmpty || _resolvingUserIds.contains(userId)) return;
    final hasProfileId =
        (member.profileId?.trim().isNotEmpty ?? false) ||
        (_resolvedProfileIdsByUserId[userId]?.trim().isNotEmpty ?? false);
    final hasAvatar =
        (member.profilePictureUrl?.trim().isNotEmpty ?? false) ||
        (_resolvedAvatarUrlsByUserId[userId]?.trim().isNotEmpty ?? false);
    if (hasProfileId && hasAvatar) return;

    _resolvingUserIds.add(userId);
    try {
      final profile = await _memberProfileResolver.resolve(member);
      if (!mounted || profile == null) return;
      if (!_profile.members.any(
        (current) =>
            current.userId == member.userId &&
            current.profileId == member.profileId,
      )) {
        return;
      }
      final changed = _upsertResolvedMember(
        userId: userId,
        profileId: profile.id,
        avatarUrl: profile.profilePicture,
      );
      if (changed) setState(() {});
    } finally {
      _resolvingUserIds.remove(userId);
    }
  }

  bool _upsertResolvedMember({
    required String userId,
    required String? profileId,
    required String? avatarUrl,
  }) {
    var changed = false;

    final String profileValue = profileId?.trim() ?? '';
    if (profileValue.isNotEmpty &&
        _resolvedProfileIdsByUserId[userId] != profileValue) {
      _resolvedProfileIdsByUserId[userId] = profileValue;
      changed = true;
    }

    final String avatarValue = avatarUrl?.trim() ?? '';
    if (avatarValue.isNotEmpty &&
        _resolvedAvatarUrlsByUserId[userId] != avatarValue) {
      _resolvedAvatarUrlsByUserId[userId] = avatarValue;
      changed = true;
    }

    return changed;
  }

  @override
  Widget build(BuildContext context) {
    final activeMembers = _profile.members
        .where((member) => member.status.trim().toUpperCase() == 'ACTIVE')
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Üyeleri Yönet'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Üyeleri yenile',
            onPressed: _busy ? null : _refreshMembers,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshMembers,
          child: CustomScrollView(
            key: const Key('band-members-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                sliver: SliverToBoxAdapter(child: _buildMembersHeader()),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: GradientOutlineButton(
                    key: const Key('band-invite-member'),
                    label: 'Üye davet et',
                    leading: _GradientIcon(
                      icon: Icons.person_add_alt_1_rounded,
                      size: 20,
                    ),
                    strokeWidth: 1,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    onPressed: _busy || !_canManageMembers
                        ? null
                        : _inviteMember,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Üyeler',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${activeMembers.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_errorText != null || activeMembers.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _EmptyCard(
                      text: _errorText ?? 'Henüz üye bulunmuyor.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final member = activeMembers[index];
                      return _MemberCard(
                        key: ValueKey('band-member-${member.userId}'),
                        member: member,
                        onOpenProfile: _busy
                            ? null
                            : () => _openMemberProfile(member),
                        avatarOverrideUrl: _effectiveAvatar(member),
                        hasOptions:
                            _canManageMembers &&
                            (_canEditTitle(member) || !member.isFounder),
                        savingTitle: _savingTitleUserId == member.userId,
                        onOptions: _busy
                            ? null
                            : () => _showMemberOptions(member),
                      );
                    }, childCount: activeMembers.length),
                  ),
                ),
              _BandPendingInvitationsSliver(
                profile: _profile,
                canManage: _canManageMembers,
                enabled: !_busy,
                sessionManager: _titleSessionManager,
                session: _titleSessionManager?.session,
                repository: _owner._bandRepository,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersHeader() {
    final avatar = _resolveMemberAvatarUrl(_profile.profilePictureUrl);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: AppColors.brandGradient),
          ),
          child: Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: avatar == null
                ? _GradientIcon(icon: Icons.groups_2_outlined, size: 28)
                : _MemberAvatar(imageUrl: avatar),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientText(
                text: _profile.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                gradient: LinearGradient(colors: AppColors.brandGradient),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Grup yönetimi',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
