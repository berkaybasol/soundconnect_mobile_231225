part of 'band_management_panel_screen.dart';

class _BandMembersWorkspaceScreen extends StatefulWidget {
  final _BandManagementPanelScreenState owner;

  _BandMembersWorkspaceScreen({required this.owner});

  @override
  State<_BandMembersWorkspaceScreen> createState() =>
      _BandMembersWorkspaceScreenState();
}

class _BandMembersWorkspaceScreenState
    extends State<_BandMembersWorkspaceScreen> {
  _BandManagementPanelScreenState get _owner => widget.owner;
  BandProfile get _profile => _owner._profile;
  bool get _loading => _owner._loading;
  bool get _submitting => _owner._submitting;
  String? get _errorText => _owner._errorText;
  final Map<String, String> _resolvedProfileIdsByUserId = <String, String>{};
  final Map<String, String> _resolvedAvatarUrlsByUserId = <String, String>{};
  final Set<String> _resolvingUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _hydrateMembers();
  }

  Future<void> _refreshMembers() async {
    await _owner._refreshProfile();
    await _hydrateMembers();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _inviteMember() async {
    await _owner._inviteMember();
    await _hydrateMembers();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _removeMember(BandMemberSummary member) async {
    await _owner._removeMember(member);
    _resolvedProfileIdsByUserId.remove(member.userId);
    _resolvedAvatarUrlsByUserId.remove(member.userId);
    await _hydrateMembers();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openMemberProfile(BandMemberSummary member) async {
    final String profileId = await _resolveProfileId(member) ?? '';
    if (!mounted) return;
    if (profileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bu üye için profil bilgisi bulunamadı.')),
      );
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.musicianPublicProfile,
      arguments: PublicProfileArgs(profileId: profileId),
    );
  }

  Future<void> _hydrateMembers() async {
    if (_profile.members.isEmpty) return;
    for (final BandMemberSummary member in _profile.members) {
      await _resolveMemberMetadata(member);
    }
  }

  Future<String?> _resolveProfileId(BandMemberSummary member) async {
    final String direct = member.profileId?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final String cached = _resolvedProfileIdsByUserId[member.userId] ?? '';
    if (cached.isNotEmpty) return cached;

    await _resolveMemberMetadata(member);
    final String resolved = _resolvedProfileIdsByUserId[member.userId] ?? '';
    return resolved.isEmpty ? null : resolved;
  }

  String? _effectiveAvatar(BandMemberSummary member) {
    final String direct = member.profilePictureUrl?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final String cached = _resolvedAvatarUrlsByUserId[member.userId] ?? '';
    return cached.isEmpty ? null : cached;
  }

  Future<void> _resolveMemberMetadata(BandMemberSummary member) async {
    final String userId = member.userId.trim();
    if (userId.isEmpty || _resolvingUserIds.contains(userId)) return;

    final bool hasProfileId =
        (member.profileId?.trim().isNotEmpty ?? false) ||
        (_resolvedProfileIdsByUserId[userId]?.trim().isNotEmpty ?? false);
    final bool hasAvatar =
        (member.profilePictureUrl?.trim().isNotEmpty ?? false) ||
        (_resolvedAvatarUrlsByUserId[userId]?.trim().isNotEmpty ?? false);
    if (hasProfileId && hasAvatar) return;

    _resolvingUserIds.add(userId);
    try {
      String? resolvedProfileId = member.profileId?.trim();
      String? resolvedAvatar = member.profilePictureUrl?.trim();
      if (resolvedAvatar != null && resolvedAvatar.isEmpty) {
        resolvedAvatar = null;
      }

      Future<void> bindProfileById(String? candidate) async {
        final String id = candidate?.trim() ?? '';
        if (id.isEmpty) return;
        final result = await _owner._musicianProfileRepository
            .getPublicProfileByProfileId(id);
        if (!result.isSuccess || result.data == null) return;
        final profile = result.data!;
        if (profile.id.trim().isNotEmpty) {
          resolvedProfileId = profile.id.trim();
        }
        final String photo = (profile.profilePicture ?? '').trim();
        if (photo.isNotEmpty) {
          resolvedAvatar = photo;
        }
      }

      await bindProfileById(resolvedProfileId);
      if ((resolvedProfileId ?? '').isEmpty) {
        await bindProfileById(member.userId);
      }

      if ((resolvedProfileId ?? '').isEmpty) {
        final String query = member.username.trim();
        if (query.isNotEmpty) {
          final search = await _owner._musicianSearchRepository.search(query);
          if (search.isSuccess &&
              search.data != null &&
              search.data!.isNotEmpty) {
            final String usernameLower = query.toLowerCase();
            final exact = search.data!.firstWhere(
              (item) =>
                  item.displayName.trim().toLowerCase() == usernameLower ||
                  (item.secondaryLabel?.trim().toLowerCase() ?? '') ==
                      '@$usernameLower',
              orElse: () => search.data!.first,
            );
            resolvedProfileId = exact.profileId.trim();
            final String searchAvatar = (exact.profilePictureUrl ?? '').trim();
            if (searchAvatar.isNotEmpty) {
              resolvedAvatar = searchAvatar;
            }
            await bindProfileById(resolvedProfileId);
          }
        }
      }

      final bool changed = _upsertResolvedMember(
        userId: userId,
        profileId: resolvedProfileId,
        avatarUrl: resolvedAvatar,
      );
      if (changed && mounted) {
        setState(() {});
      }
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
    return Scaffold(
      appBar: AppBar(title: Text('Üyeleri Yönet'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: _buildMembersCard(),
        ),
      ),
    );
  }

  Widget _buildMembersCard() {
    return _GradientOutline(
      radius: 22,
      strokeWidth: 1,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Üyeler',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_profile.members.length} aktif üye listeleniyor',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  tooltip: 'Üye ekle',
                  onPressed: _submitting ? null : _inviteMember,
                  icon: Icon(
                    Icons.person_add_alt_1_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: _submitting ? null : _refreshMembers,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 460,
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _errorText != null
                  ? _EmptyCard(text: _errorText!)
                  : _profile.members.isEmpty
                  ? _EmptyCard(text: 'Bandde henüz üye görünmüyor.')
                  : ListView(
                      children: _profile.members
                          .map(
                            (member) => _MemberCard(
                              member: member,
                              onOpenProfile: () => _openMemberProfile(member),
                              avatarOverrideUrl: _effectiveAvatar(member),
                              onRemove: _submitting || member.isFounder
                                  ? null
                                  : () => _removeMember(member),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
