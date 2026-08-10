import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../data/collab_application_mock_data.dart';
import '../../domain/collab_application_models.dart';
import '../../domain/collab_discovery_models.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';
import 'collab_profile_selection_screen.dart';

class CollabApplicationComposeScreen extends StatefulWidget {
  const CollabApplicationComposeScreen({
    required this.listing,
    required this.initialProfile,
    this.initialPhoneNumber = collabMockPhoneNumber,
    this.initialMessage = collabMockApplicationMessage,
    this.showBottomNavigation = true,
    this.onSubmitted,
    super.key,
  });

  final CollabDiscoveryListing listing;
  final CollabApplicantProfile initialProfile;
  final String initialPhoneNumber;
  final String initialMessage;
  final bool showBottomNavigation;
  final bool Function(CollabApplicationDraft)? onSubmitted;

  @override
  State<CollabApplicationComposeScreen> createState() =>
      _CollabApplicationComposeScreenState();
}

class _CollabApplicationComposeScreenState
    extends State<CollabApplicationComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _messageController;
  late CollabApplicantProfile _profile;
  bool _submitting = false;

  bool get _isOffer => widget.listing.direction == CollabDirection.available;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _phoneController = TextEditingController(text: widget.initialPhoneNumber);
    _messageController = TextEditingController(text: widget.initialMessage)
      ..addListener(_refreshCharacterCount);
  }

  @override
  void dispose() {
    _messageController.removeListener(_refreshCharacterCount);
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _refreshCharacterCount() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionNoun = _isOffer ? 'teklif' : 'başvuru';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOffer ? 'İş Teklifi Gönder' : 'Başvuru Yap'),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 3, 14, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isOffer
                      ? 'Müsait profil sahibine iş teklifini gönder.'
                      : 'İlan sahibine mesajını gönder.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                _SelectedProfileHeader(
                  profile: _profile,
                  onChange: _submitting ? null : _changeProfile,
                ),
                const SizedBox(height: 22),
                const CollabSectionTitle('İletişim Bilgisi'),
                const SizedBox(height: 9),
                TextFormField(
                  key: const ValueKey('collab-phone-field'),
                  controller: _phoneController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\s-]')),
                    LengthLimitingTextInputFormatter(25),
                  ],
                  decoration: const InputDecoration(
                    hintText: '+90 5xx xxx xx xx',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    if (RegExp(r'[^0-9+()\s-]').hasMatch(value ?? '')) {
                      return 'Geçerli bir telefon numarası gir.';
                    }
                    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                    if (digits.length < 10 || digits.length > 15) {
                      return 'Geçerli bir telefon numarası gir.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Telefon numaran yalnızca $actionNoun gönderdiğin profil '
                        'sahibiyle paylaşılacak.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 21),
                const CollabSectionTitle('Mesajın'),
                const SizedBox(height: 9),
                TextFormField(
                  key: const ValueKey('collab-message-field'),
                  controller: _messageController,
                  enabled: !_submitting,
                  minLines: 5,
                  maxLines: 8,
                  maxLength: 500,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) {
                        return Text(
                          '$currentLength/$maxLength',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10.5,
                          ),
                        );
                      },
                  decoration: InputDecoration(
                    hintText: _isOffer
                        ? 'İşin detaylarını ve teklifini kısaca anlat.'
                        : 'Kendini ve neden uygun olduğunu kısaca anlat.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if ((value?.trim().isEmpty ?? true)) {
                      return 'Mesaj alanı boş bırakılamaz.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const CollabSectionTitle('İlan Özeti'),
                const SizedBox(height: 9),
                _ApplicationListingSummary(listing: widget.listing),
                const SizedBox(height: 18),
                CollabPrimaryAction(
                  key: const ValueKey('collab-apply-submit'),
                  label: _isOffer ? 'Teklifi Gönder' : 'Başvuruyu Gönder',
                  icon: Icons.send_outlined,
                  busy: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: 9),
                CollabOutlineAction(
                  key: const ValueKey('collab-apply-cancel'),
                  label: 'Vazgeç',
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 13),
                const _DmInfoBanner(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? ProfilePublicBottomBar(currentIndex: 1)
          : null,
    );
  }

  Future<void> _changeProfile() async {
    final profile = await Navigator.of(context).push<CollabApplicantProfile>(
      collabPageRoute(
        builder: (_) => CollabProfileSelectionScreen(
          listing: widget.listing,
          initialProfile: _profile,
          showBottomNavigation: false,
        ),
      ),
    );
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final draft = CollabApplicationDraft(
      listing: widget.listing,
      profile: _profile,
      phoneNumber: _phoneController.text.trim(),
      message: _messageController.text.trim(),
    );
    final accepted = widget.onSubmitted?.call(draft) ?? true;
    if (!accepted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Bu profil ile bu ilana daha önce başvuru veya teklif gönderdin.',
            ),
          ),
        );
      return;
    }
    Navigator.of(context).pop(draft);
  }
}

class _SelectedProfileHeader extends StatelessWidget {
  const _SelectedProfileHeader({required this.profile, required this.onChange});

  final CollabApplicantProfile profile;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabGradientFrame(
      highlighted: true,
      radius: 18,
      strokeWidth: 1.2,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          CollabIdentityAvatar(
            initials: profile.initials,
            profileKind: profile.profileKind,
            avatarAsset: profile.avatarAsset,
            size: 53,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onChange, child: const Text('Profil Değiştir')),
        ],
      ),
    );
  }
}

class _ApplicationListingSummary extends StatelessWidget {
  const _ApplicationListingSummary({required this.listing});

  final CollabDiscoveryListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabGradientFrame(
      radius: 18,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CollabProfileAvatar(listing: listing, size: 48),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        CollabStatusPill(
                          label: listing.cadence.label,
                          color: AppColors.socialPink,
                        ),
                        CollabStatusPill(
                          label: listing.wantedSummary,
                          color: listing.direction == CollabDirection.seeking
                              ? AppColors.socialOrange
                              : AppColors.spotifyGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 9,
                children: [
                  _SummaryMeta(
                    width: width,
                    icon: Icons.location_on_outlined,
                    label: listing.location,
                  ),
                  _SummaryMeta(
                    width: width,
                    icon: Icons.calendar_month_outlined,
                    label: listing.timeLabel == null
                        ? listing.scheduleLabel
                        : '${listing.scheduleLabel} · ${listing.timeLabel}',
                  ),
                  _SummaryMeta(
                    width: width,
                    icon: Icons.payments_outlined,
                    label: _feeText(listing.feeAmount),
                  ),
                  _SummaryMeta(
                    width: width,
                    icon: Icons.music_note_rounded,
                    label: listing.role,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  const _SummaryMeta({
    required this.width,
    required this.icon,
    required this.label,
  });

  final double width;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _DmInfoBanner extends StatelessWidget {
  const _DmInfoBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.spotifyGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.spotifyGreen.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.spotifyGreen,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sohbete DM üzerinden de devam edebilirsin.',
                  style: TextStyle(
                    color: AppColors.spotifyGreen,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'İlan sahibiyle olan mevcut DM sohbetinizde iletişime '
                  'devam edebilirsiniz.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _feeText(int? amount) {
  if (amount == null) return 'Ücret belirtilmemiş';
  final value = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '₺$value';
}
