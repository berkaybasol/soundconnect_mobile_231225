import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_member_summary.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/entities/band_received_invitation.dart';
import '../navigation/band_member_profile_resolver.dart';
import 'band_profile_screen.dart';
import 'band_member_caption.dart';

class BandInviteDecisionScreenArgs {
  final String bandId;
  final String? bandName;
  final String? title;
  final String? message;
  final String? expectedSessionKey;
  final String? invitationId;

  const BandInviteDecisionScreenArgs({
    required this.bandId,
    this.bandName,
    this.title,
    this.message,
    this.expectedSessionKey,
    this.invitationId,
  });

  // Previously stored notifications keep their original copy on the server.
  // Normalize only the old template suffix, preserving names and custom text.
  String get displayTitle => _replaceLegacySuffix(
    title,
    ' seni banda davet etti',
    ' seni gruba davet etti',
  );

  String get displayMessage => _replaceLegacySuffix(
    message,
    ' tarafından band daveti aldın.',
    ' tarafından davet aldın.',
  );

  static String _replaceLegacySuffix(
    String? text,
    String oldSuffix,
    String newSuffix,
  ) {
    final value = text?.trim() ?? '';
    return value.endsWith(oldSuffix)
        ? '${value.substring(0, value.length - oldSuffix.length)}$newSuffix'
        : value;
  }
}

class BandInviteDecisionScreen extends StatefulWidget {
  final BandInviteDecisionScreenArgs args;

  const BandInviteDecisionScreen({super.key, required this.args});

  @override
  State<BandInviteDecisionScreen> createState() =>
      _BandInviteDecisionScreenState();
}

class _BandInviteDecisionScreenState extends State<BandInviteDecisionScreen>
    with WidgetsBindingObserver {
  late final AuthSessionManager? _sessions =
      serviceLocator.isRegistered<AuthSessionManager>()
      ? serviceLocator<AuthSessionManager>()
      : null;
  late final AuthSession? _entrySession = _sessions?.session;
  bool get _validSession =>
      _entrySession != null &&
      identical(_sessions?.session, _entrySession) &&
      _entrySession.isAuthenticated &&
      _entrySession.isActive &&
      (_entrySession.userId?.trim().isNotEmpty ?? false) &&
      _entrySession.hasAnyRole(const ['ROLE_MUSICIAN', 'MUSICIAN']) &&
      (widget.args.expectedSessionKey == null ||
          widget.args.expectedSessionKey == _entrySession.userId);

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  late final BandRepository _bandRepository = serviceLocator<BandRepository>();
  late final BandMemberProfileResolver _memberProfileResolver =
      BandMemberProfileResolver();
  final Map<String, String> _resolvedProfileIdsByUserId = {};
  final Map<String, String> _resolvedAvatarUrlsByUserId = {};
  final Set<String> _resolvingUserIds = {};
  BandProfile? _profile;
  bool _loadingProfile = false;
  bool _submitting = false;
  String? _errorText;
  BandReceivedInvitation? _currentInvitation;
  bool _checkingInvitation = true;
  String? _invitationError;
  int _invitationGeneration = 0;

  bool get _currentInviteMatches =>
      !_checkingInvitation &&
      _invitationError == null &&
      widget.args.invitationId?.isNotEmpty == true &&
      _currentInvitation?.invitationId == widget.args.invitationId;

  String get _bandName {
    final profileName = _profile?.name.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;
    final payloadName = widget.args.bandName?.trim() ?? '';
    return payloadName.isEmpty ? 'Grup' : payloadName;
  }

  @override
  void initState() {
    super.initState();
    // Capture identity before any async read or user action.
    final valid = _validSession;
    _sessions?.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    if (valid) {
      unawaited(_checkInvitation());
      unawaited(_loadBandPreview());
    }
  }

  @override
  void dispose() {
    _sessions?.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _validSession && !_submitting) {
      unawaited(_checkInvitation());
    }
  }

  Future<void> _checkInvitation() async {
    if (!mounted || !_validSession) return;
    final generation = ++_invitationGeneration;
    setState(() {
      _checkingInvitation = true;
      _invitationError = null;
    });
    try {
      final result = await _bandRepository.getCurrentReceivedInvitation(
        bandId: widget.args.bandId,
        expectedSessionKey: _entrySession!.userId!,
      );
      if (!mounted || !_validSession || generation != _invitationGeneration) {
        return;
      }
      setState(() {
        _checkingInvitation = false;
        _currentInvitation = result.isSuccess ? result.data : null;
        if (!result.isSuccess || result.data == null) {
          _invitationError = const {'9206', '9220'}.contains(result.error?.code)
              ? 'Bu davet artık geçerli değil.'
              : result.error?.message ?? 'Güncel davet yüklenemedi.';
        }
      });
    } catch (_) {
      if (!mounted || !_validSession || generation != _invitationGeneration) {
        return;
      }
      setState(() {
        _checkingInvitation = false;
        _currentInvitation = null;
        _invitationError = 'Güncel davet yüklenemedi. Tekrar dene.';
      });
    }
  }

  void _openCurrentInvitation() {
    final current = _currentInvitation;
    if (!_validSession ||
        _checkingInvitation ||
        current?.invitationId?.isNotEmpty != true) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BandInviteDecisionScreen(
          args: BandInviteDecisionScreenArgs(
            bandId: current!.bandId,
            bandName: current.bandName,
            invitationId: current.invitationId,
            expectedSessionKey: _entrySession!.userId,
          ),
        ),
      ),
    );
  }

  Future<void> _loadBandPreview() async {
    setState(() {
      _loadingProfile = true;
      _errorText = null;
    });

    try {
      final result = await _bandRepository.getPublicBandById(
        widget.args.bandId,
      );
      if (!mounted || !_validSession) return;
      setState(() {
        _loadingProfile = false;
        if (result.isSuccess && result.data != null) {
          _profile = result.data!;
        } else {
          _errorText = result.error?.message ?? 'Grup bilgileri yüklenemedi.';
        }
      });
      if (result.isSuccess && result.data != null) {
        await _hydrateMembers(result.data!.members);
      }
    } catch (_) {
      if (!mounted || !_validSession) return;
      setState(() {
        _loadingProfile = false;
        _errorText = 'Grup bilgileri yüklenemedi.';
      });
    }
  }

  Future<void> _acceptInvite() => _respondToInvitation(accept: true);

  Future<void> _rejectInvite() => _respondToInvitation(accept: false);

  Future<void> _respondToInvitation({required bool accept}) async {
    if (!_validSession ||
        !_currentInviteMatches ||
        _submitting ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _submitting = true);
    final failure = accept
        ? 'Grup daveti kabul edilemedi.'
        : 'Grup daveti reddedilemedi.';
    try {
      final result = accept
          ? await _bandRepository.acceptInvite(
              bandId: widget.args.bandId,
              expectedSessionKey: _entrySession!.userId,
              invitationId: widget.args.invitationId,
            )
          : await _bandRepository.rejectInvite(
              bandId: widget.args.bandId,
              expectedSessionKey: _entrySession!.userId,
              invitationId: widget.args.invitationId,
            );
      if (!mounted || !_validSession) return;
      if (!result.isSuccess) {
        await _checkInvitation();
        if (!mounted || !_validSession) return;
        _showMessage(result.error?.message ?? failure);
        return;
      }
      setState(() => _submitting = false);
      _showMessage(
        accept ? 'Band daveti kabul edildi.' : 'Band daveti reddedildi.',
        tone: AppSnackBarTone.success,
      );
      if (accept) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.bandMemberProfile,
          arguments: BandProfileScreenArgs(
            bandId: widget.args.bandId,
            viewMode: BandProfileViewMode.member,
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted || !_validSession) return;
      await _checkInvitation();
      if (!mounted || !_validSession) return;
      _showMessage(failure);
    } finally {
      if (mounted && _validSession) setState(() => _submitting = false);
    }
  }

  Future<void> _openMemberProfile(BandMemberSummary member) async {
    if (!_validSession || _submitting) return;
    final bandId = _profile?.id;
    await _memberProfileResolver.open(
      context,
      member,
      isMemberCurrent: () =>
          _profile?.id == bandId &&
          (_profile?.members.any(
                (current) =>
                    current.userId == member.userId &&
                    current.profileId == member.profileId,
              ) ??
              false),
    );
    if (mounted && _validSession) await _checkInvitation();
  }

  Future<void> _hydrateMembers(List<BandMemberSummary> members) async {
    for (final member in members) {
      if (!mounted || !_validSession) return;
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
      if (!(_profile?.members.any(
            (current) =>
                current.userId == member.userId &&
                current.profileId == member.profileId,
          ) ??
          false)) {
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

  void _showMessage(
    String message, {
    AppSnackBarTone tone = AppSnackBarTone.error,
  }) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(appSnackBar(context, tone: tone, content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_validSession) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grup Daveti')),
        body: const Center(
          child: Text('Davetini görmek için sayfayı hesabından yeniden aç.'),
        ),
      );
    }
    if (!_currentInviteMatches) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grup Daveti')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _checkingInvitation
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _invitationError ??
                            'Bu davet artık geçerli değil. Güncel daveti açarak devam edebilirsin.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (_currentInvitation?.invitationId?.isNotEmpty == true)
                        GradientOutlineButton(
                          label: 'Güncel daveti aç',
                          onPressed: _openCurrentInvitation,
                        )
                      else
                        GradientOutlineButton(
                          label: 'Tekrar dene',
                          onPressed: _checkInvitation,
                        ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          if (_validSession) {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed(AppRoutes.myBands);
                          }
                        },
                        child: const Text('Gelen davetleri aç'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    final title = widget.args.displayTitle;
    final message = widget.args.displayMessage;
    final profile = _profile;
    final members = (profile?.members ?? const <BandMemberSummary>[])
        .where((member) => member.status.trim().toUpperCase() == 'ACTIVE')
        .toList();

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Grup Daveti'), centerTitle: true),
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
                              ? '$_bandName seni gruba davet etti'
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
                              message: 'Bu grup için aktif üye bilgisi yok.',
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
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.88,
                    ),
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
              child: ClipOval(
                child: hasImage
                    ? AppCachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 99,
                        height: 99,
                        cacheWidth: 297,
                        cacheHeight: 297,
                        errorBuilder: (context) => Icon(
                          Icons.groups_2_outlined,
                          color: colors.onSurfaceVariant,
                          size: 42,
                        ),
                      )
                    : Icon(
                        Icons.groups_2_outlined,
                        color: colors.onSurfaceVariant,
                        size: 42,
                      ),
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
          child: ClipOval(
            child: _hasImage(imageUrl)
                ? AppCachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 40,
                    height: 40,
                    cacheWidth: 120,
                    cacheHeight: 120,
                    errorBuilder: (context) => Icon(
                      Icons.person_outline_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    Icons.person_outline_rounded,
                    color: colors.onSurfaceVariant,
                  ),
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
        subtitle: member.isFounder || member.displayTitle != null
            ? BandMemberCaption(member: member)
            : null,
        isThreeLine: member.isFounder && member.displayTitle != null,
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
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
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
