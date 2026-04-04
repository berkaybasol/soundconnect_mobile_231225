import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_member_summary.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/entities/musician_search_option.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/musician_search_repository.dart';

class BandManagementPanelScreen extends StatefulWidget {
  final BandProfile profile;

  const BandManagementPanelScreen({super.key, required this.profile});

  @override
  State<BandManagementPanelScreen> createState() =>
      _BandManagementPanelScreenState();
}

class _BandManagementPanelScreenState extends State<BandManagementPanelScreen> {
  late final BandRepository _bandRepository = serviceLocator<BandRepository>();
  late final MusicianSearchRepository _musicianSearchRepository =
      serviceLocator<MusicianSearchRepository>();
  late final MusicianProfileRepository _musicianProfileRepository =
      serviceLocator<MusicianProfileRepository>();

  late BandProfile _profile = widget.profile;
  bool _loading = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    final result = await _bandRepository.getBandById(_profile.id);
    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      setState(() {
        _loading = false;
        _errorText = result.error?.message ?? 'Band detaylari yuklenemedi.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _profile = result.data!;
    });
  }

  Future<void> _inviteMember() async {
    final selection = await _showMusicianPicker();
    if (selection == null || !mounted) return;

    setState(() => _submitting = true);
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
        setState(() => _submitting = false);
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

    setState(() => _submitting = true);
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
        setState(() => _submitting = false);
      }
    }
  }

  Future<MusicianSearchOption?> _showMusicianPicker() async {
    final queryController = TextEditingController();
    Timer? searchDebounce;
    int lastSearchToken = 0;

    final selected = await showModalBottomSheet<MusicianSearchOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var loading = false;
        var results = <MusicianSearchOption>[];
        var errorText = '';
        final existingUsernames = _profile.members
            .map((member) => member.username.trim().toLowerCase())
            .toSet();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> runSearch() async {
              final query = queryController.text.trim();
              final token = ++lastSearchToken;
              if (query.length < 2) {
                setSheetState(() {
                  results = const [];
                  errorText = 'En az 2 karakter yaz.';
                });
                return;
              }

              setSheetState(() {
                loading = true;
                errorText = '';
              });

              final result = await _musicianSearchRepository.search(query);
              if (!sheetContext.mounted || token != lastSearchToken) return;

              setSheetState(() {
                loading = false;
                if (result.isSuccess && result.data != null) {
                  results = result.data!;
                  if (results.isEmpty) {
                    errorText = 'Sonuc bulunamadi.';
                  }
                } else {
                  errorText = result.error?.message ?? 'Arama basarisiz.';
                }
              });
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.78,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: queryController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => runSearch(),
                          onChanged: (value) {
                            searchDebounce?.cancel();
                            if (value.trim().length >= 2) {
                              searchDebounce = Timer(
                                const Duration(milliseconds: 320),
                                runSearch,
                              );
                            } else {
                              setSheetState(() {
                                results = const [];
                                errorText = '';
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Muzisyen ara...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              onPressed: runSearch,
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (loading) ...[
                          const LinearProgressIndicator(minHeight: 2),
                          const SizedBox(height: 12),
                        ],
                        if (!loading && errorText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              errorText,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final musician = results[index];
                              final alreadyMember = existingUsernames.contains(
                                musician.displayName.trim().toLowerCase(),
                              );
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.navBlueSoft,
                                      backgroundImage:
                                          musician.profilePictureUrl
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? NetworkImage(
                                              musician.profilePictureUrl!,
                                            )
                                          : null,
                                      child:
                                          musician.profilePictureUrl
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? null
                                          : const Icon(
                                              Icons.person_outline,
                                              color: AppColors.textMuted,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            musician.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: alreadyMember
                                                  ? AppColors.textMuted
                                                  : AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if ((musician.secondaryLabel ?? '')
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              musician.secondaryLabel!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (alreadyMember)
                                      const Text(
                                        'Uye',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      IconButton(
                                        onPressed: () => Navigator.of(
                                          sheetContext,
                                        ).pop(musician),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          color: AppColors.coralAlt,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchDebounce?.cancel();
    queryController.dispose();
    return selected;
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

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
    String? trailingLabel,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
      borderRadius: BorderRadius.circular(18),
      child: _GradientOutline(
        radius: 18,
        strokeWidth: 1,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.inputFill, AppColors.navBlueSoft],
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              if (trailingLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    trailingLabel,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shiftedBannerImage(Widget child) {
    return ClipRect(
      child: Transform.translate(offset: const Offset(0, 4), child: child),
    );
  }

  Widget _adPlaceholderCard() {
    return _GradientOutline(
      radius: 22,
      strokeWidth: 1,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.inputFill, AppColors.navBlueSoft],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                    ),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Reklam Alani',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 1240 / 400,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.navBlueDeep,
                      AppColors.navBlueSoft.withValues(alpha: 0.94),
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _shiftedBannerImage(
                    Image.asset(
                      'assets/buraya bakarlar v3.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Band Yonetimi'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.inputFill, AppColors.navBlueSoft],
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      text: _profile.name,
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.brandGradient,
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Buradan band profilini destekleyecek yonetim araclarina erisebilirsin.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _actionCard(
                context: context,
                icon: Icons.group_add_outlined,
                title: 'Uyeleri Yonet',
                message: 'Uye yonetimi aciliyor.',
                trailingLabel: '${_profile.members.length} uye',
                onTap: _submitting ? null : _openMembersSheet,
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.edit_note_outlined,
                title: 'Band Bilgilerini Duzenle',
                message:
                    'Band bilgilerini yonetme paneli siradaki adimda eklenecek.',
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.perm_media_outlined,
                title: 'Medya ve Icerik Yonetimi',
                message: 'Band medya akislari siradaki adimda eklenecek.',
              ),
              const SizedBox(height: 14),
              _actionCard(
                context: context,
                icon: Icons.analytics_outlined,
                title: 'Etkilesim ve Istatistikler',
                message: 'Band istatistik paneli siradaki adimda eklenecek.',
              ),
              const SizedBox(height: 18),
              _adPlaceholderCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final BandMemberSummary member;
  final VoidCallback? onRemove;

  const _MemberCard({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.navBlueSoft,
            backgroundImage: member.profilePictureUrl?.trim().isNotEmpty == true
                ? NetworkImage(member.profilePictureUrl!.trim())
                : null,
            child: member.profilePictureUrl?.trim().isNotEmpty == true
                ? null
                : const Icon(Icons.person_outline, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.username,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member.role,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (member.role.toUpperCase() == 'FOUNDER')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.16),
                ),
              ),
              child: const Text(
                'Founder',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Uyeyi cikar',
              onPressed: onRemove,
              icon: const Icon(
                Icons.person_remove_outlined,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}

class _GradientOutline extends StatelessWidget {
  final Widget child;
  final double radius;
  final double strokeWidth;

  const _GradientOutline({
    required this.child,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GradientOutlinePainter(
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _GradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;

  const _GradientOutlinePainter({
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
