import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_member_summary.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/musician_search_repository.dart';
import 'band_profile_screen.dart';
import 'profile_route_args.dart';

class BandInviteDecisionScreenArgs {
  final String bandId;
  final String? bandName;
  final String? title;
  final String? message;

  const BandInviteDecisionScreenArgs({
    required this.bandId,
    this.bandName,
    this.title,
    this.message,
  });
}

class BandInviteDecisionScreen extends StatefulWidget {
  final BandInviteDecisionScreenArgs args;

  const BandInviteDecisionScreen({super.key, required this.args});

  @override
  State<BandInviteDecisionScreen> createState() =>
      _BandInviteDecisionScreenState();
}

class _BandInviteDecisionScreenState extends State<BandInviteDecisionScreen> {
  late final BandRepository _bandRepository = serviceLocator<BandRepository>();
  late final MusicianProfileRepository _musicianProfileRepository =
      serviceLocator<MusicianProfileRepository>();
  late final MusicianSearchRepository _musicianSearchRepository =
      serviceLocator<MusicianSearchRepository>();
  final Map<String, String> _resolvedProfileIdsByUserId = {};
  final Map<String, String> _resolvedAvatarUrlsByUserId = {};
  final Set<String> _resolvingUserIds = {};
  BandProfile? _profile;
  bool _loadingProfile = false;
  bool _submitting = false;
  String? _errorText;

  String get _bandName {
    final profileName = _profile?.name.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;
    final payloadName = widget.args.bandName?.trim() ?? '';
    return payloadName.isEmpty ? 'Band' : payloadName;
  }

  @override
  void initState() {
    super.initState();
    _loadBandPreview();
  }

  Future<void> _loadBandPreview() async {
    setState(() {
      _loadingProfile = true;
      _errorText = null;
    });

    final result = await _bandRepository.getPublicBandById(widget.args.bandId);
    if (!mounted) return;

    setState(() {
      _loadingProfile = false;
      if (result.isSuccess && result.data != null) {
        _profile = result.data!;
      } else {
        _errorText = result.error?.message ?? 'Band bilgileri yüklenemedi.';
      }
    });

    if (result.isSuccess && result.data != null) {
      await _hydrateMembers(result.data!.members);
    }
  }

  Future<void> _acceptInvite() async {
    setState(() => _submitting = true);
    final result = await _bandRepository.acceptInvite(
      bandId: widget.args.bandId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      _showMessage(result.error?.message ?? 'Band daveti kabul edilemedi.');
      return;
    }

    _showMessage('Band daveti kabul edildi.');
    await Navigator.of(context).pushReplacementNamed(
      AppRoutes.bandMemberProfile,
      arguments: BandProfileScreenArgs(
        bandId: widget.args.bandId,
        viewMode: BandProfileViewMode.member,
      ),
    );
  }

  Future<void> _rejectInvite() async {
    setState(() => _submitting = true);
    final result = await _bandRepository.rejectInvite(
      bandId: widget.args.bandId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      _showMessage(result.error?.message ?? 'Band daveti reddedilemedi.');
      return;
    }

    _showMessage('Band daveti reddedildi.');
    Navigator.of(context).pop();
  }

  Future<void> _openMemberProfile(BandMemberSummary member) async {
    final profileId = await _resolveProfileId(member) ?? '';
    if (!mounted) return;
    if (profileId.isEmpty) {
      _showMessage('Bu üye için profil bilgisi bulunamadı.');
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.musicianPublicProfile,
      arguments: PublicProfileArgs(profileId: profileId),
    );
  }

  Future<void> _hydrateMembers(List<BandMemberSummary> members) async {
    for (final member in members) {
      await _resolveMemberMetadata(member);
    }
  }

  Future<String?> _resolveProfileId(BandMemberSummary member) async {
    final direct = member.profileId?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final cached = _resolvedProfileIdsByUserId[member.userId]?.trim() ?? '';
    if (cached.isNotEmpty) return cached;

    await _resolveMemberMetadata(member);
    final resolved = _resolvedProfileIdsByUserId[member.userId]?.trim() ?? '';
    return resolved.isEmpty ? null : resolved;
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
      String? resolvedProfileId = member.profileId?.trim();
      String? resolvedAvatar = member.profilePictureUrl?.trim();
      if (resolvedAvatar != null && resolvedAvatar.isEmpty) {
        resolvedAvatar = null;
      }

      Future<void> bindProfileById(String? candidate) async {
        final id = candidate?.trim() ?? '';
        if (id.isEmpty) return;
        final result = await _musicianProfileRepository
            .getPublicProfileByProfileId(id);
        if (!result.isSuccess || result.data == null) return;
        final profile = result.data!;
        if (profile.id.trim().isNotEmpty) {
          resolvedProfileId = profile.id.trim();
        }
        final photo = (profile.profilePicture ?? '').trim();
        if (photo.isNotEmpty) {
          resolvedAvatar = photo;
        }
      }

      await bindProfileById(resolvedProfileId);
      if ((resolvedProfileId ?? '').isEmpty) {
        await bindProfileById(member.userId);
      }

      if ((resolvedProfileId ?? '').isEmpty) {
        final query = member.username.trim();
        if (query.isNotEmpty) {
          final search = await _musicianSearchRepository.search(query);
          if (search.isSuccess &&
              search.data != null &&
              search.data!.isNotEmpty) {
            final usernameLower = query.toLowerCase();
            final exact = search.data!.firstWhere(
              (item) =>
                  item.displayName.trim().toLowerCase() == usernameLower ||
                  (item.secondaryLabel?.trim().toLowerCase() ?? '') ==
                      '@$usernameLower',
              orElse: () => search.data!.first,
            );
            resolvedProfileId = exact.profileId.trim();
            final searchAvatar = (exact.profilePictureUrl ?? '').trim();
            if (searchAvatar.isNotEmpty) {
              resolvedAvatar = searchAvatar;
            }
            await bindProfileById(resolvedProfileId);
          }
        }
      }

      final changed = _upsertResolvedMember(
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
    final profileValue = profileId?.trim() ?? '';
    if (profileValue.isNotEmpty &&
        _resolvedProfileIdsByUserId[userId] != profileValue) {
      _resolvedProfileIdsByUserId[userId] = profileValue;
      changed = true;
    }

    final avatarValue = avatarUrl?.trim() ?? '';
    if (avatarValue.isNotEmpty &&
        _resolvedAvatarUrlsByUserId[userId] != avatarValue) {
      _resolvedAvatarUrlsByUserId[userId] = avatarValue;
      changed = true;
    }
    return changed;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = widget.args.title?.trim() ?? '';
    final message = widget.args.message?.trim() ?? '';
    final profile = _profile;
    final members = (profile?.members ?? const <BandMemberSummary>[])
        .where((member) => member.status.trim().toUpperCase() == 'ACTIVE')
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Band Daveti'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BandInviteHero(
                        bandName: _bandName,
                        imageUrl: profile?.profilePictureUrl,
                        title: title.isEmpty
                            ? '$_bandName seni banda davet etti'
                            : title,
                        message: message,
                      ),
                      const SizedBox(height: 16),
                      if (_loadingProfile)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_errorText != null)
                        _InlineInfoMessage(
                          icon: Icons.info_outline_rounded,
                          message: _errorText!,
                        )
                      else ...[
                        Text(
                          'Mevcut Üyeler',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (members.isEmpty)
                          const _InlineInfoMessage(
                            icon: Icons.groups_outlined,
                            message: 'Bu band için aktif üye bilgisi yok.',
                          )
                        else
                          ...members.map(
                            (member) => _BandInviteMemberTile(
                              member: member,
                              avatarUrl: _effectiveAvatar(member),
                              onTap: () => _openMemberProfile(member),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bu daveti kabul edersen $_bandName üyeliğin aktif olur.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GradientOutlineButton(
                      onPressed: _submitting ? null : _acceptInvite,
                      label: 'Kabul et',
                      loading: _submitting,
                      leading: const Icon(Icons.check_rounded),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _rejectInvite,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reddet'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BandInviteHero extends StatelessWidget {
  final String bandName;
  final String? imageUrl;
  final String title;
  final String message;

  const _BandInviteHero({
    required this.bandName,
    required this.imageUrl,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasImage = _hasImage(imageUrl);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: AppColors.brandGradient),
            ),
            padding: const EdgeInsets.all(2.5),
            child: CircleAvatar(
              backgroundColor: colors.surfaceContainer,
              backgroundImage: hasImage ? NetworkImage(imageUrl!.trim()) : null,
              child: hasImage
                  ? null
                  : Icon(
                      Icons.groups_2_outlined,
                      color: colors.onSurfaceVariant,
                      size: 42,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            bandName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BandInviteMemberTile extends StatelessWidget {
  final BandMemberSummary member;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _BandInviteMemberTile({
    required this.member,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl = avatarUrl?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colors.surfaceContainer,
          backgroundImage: _hasImage(imageUrl) ? NetworkImage(imageUrl) : null,
          child: _hasImage(imageUrl)
              ? null
              : Icon(
                  Icons.person_outline_rounded,
                  color: colors.onSurfaceVariant,
                ),
        ),
        title: Text(
          member.username.trim().isEmpty ? 'Üye' : member.username.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          member.localizedRoleLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _InlineInfoMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InlineInfoMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _hasImage(String? value) {
  final url = value?.trim() ?? '';
  return url.startsWith('http://') || url.startsWith('https://');
}
