import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_actor.dart';
import '../../domain/entities/collab_listing.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_action_widgets.dart';
import '../widgets/collab_discovery_widgets.dart';
import '../cubit/collab_listing_detail_cubit.dart';
import '../cubit/collab_listing_detail_state.dart';
import 'collab_profile_selection_screen.dart';

class CollabApplicationComposeScreen extends StatefulWidget {
  const CollabApplicationComposeScreen({
    required this.listing,
    required this.initialActor,
    required this.eligibleActors,
    this.showBottomNavigation = true,
    super.key,
  });

  final CollabListing listing;
  final CollabActor initialActor;
  final List<CollabActor> eligibleActors;
  final bool showBottomNavigation;

  @override
  State<CollabApplicationComposeScreen> createState() =>
      _CollabApplicationComposeScreenState();
}

class _CollabApplicationComposeScreenState
    extends State<CollabApplicationComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _messageController;
  late CollabActor _actor;

  @override
  void initState() {
    super.initState();
    _actor = widget.initialActor;
    _phoneController = TextEditingController();
    _messageController = TextEditingController()..addListener(_refreshCounter);
  }

  @override
  void dispose() {
    _messageController.removeListener(_refreshCounter);
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _refreshCounter() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CollabListingDetailCubit, CollabListingDetailState>(
      listenWhen: (previous, current) =>
          previous.isApplying && !current.isApplying,
      listener: (context, state) {
        if (state.application != null) {
          Navigator.of(context).pop(true);
          return;
        }
        final error = state.actionError;
        if (error != null) _showMessage(error.message);
      },
      builder: (context, state) =>
          _buildScaffold(context, submitting: state.isApplying),
    );
  }

  Widget _buildScaffold(BuildContext context, {required bool submitting}) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Başvuru Yap')),
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
                  'İlan sahibine iletişim bilgini ve mesajını güvenli biçimde gönder.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                _SelectedActorHeader(
                  actor: _actor,
                  onChange: submitting || widget.eligibleActors.length < 2
                      ? null
                      : _changeActor,
                ),
                const SizedBox(height: 22),
                const CollabSectionTitle('İletişim Bilgisi'),
                const SizedBox(height: 9),
                TextFormField(
                  key: const ValueKey<String>('collab-phone-field'),
                  controller: _phoneController,
                  enabled: !submitting,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.telephoneNumber],
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+().\s-]')),
                    LengthLimitingTextInputFormatter(32),
                  ],
                  decoration: const InputDecoration(
                    hintText: '+90 5xx xxx xx xx',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: _validatePhone,
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
                        'Telefon numaran yalnızca senin ve ilan sahibinin başvuru ekranında görünür.',
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
                const CollabSectionTitle('Mesajın (Opsiyonel)'),
                const SizedBox(height: 9),
                TextFormField(
                  key: const ValueKey<String>('collab-message-field'),
                  controller: _messageController,
                  enabled: !submitting,
                  minLines: 5,
                  maxLines: 8,
                  maxLength: 500,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => Text(
                        '$currentLength/$maxLength',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                  decoration: const InputDecoration(
                    hintText: 'Kendini ve neden uygun olduğunu kısaca anlat.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                const CollabSectionTitle('İlan Özeti'),
                const SizedBox(height: 9),
                _ApplicationListingSummary(listing: widget.listing),
                const SizedBox(height: 18),
                CollabPrimaryAction(
                  key: const ValueKey<String>('collab-apply-submit'),
                  label: 'Başvuruyu Gönder',
                  icon: Icons.send_outlined,
                  busy: submitting,
                  onPressed: submitting ? null : _submit,
                ),
                const SizedBox(height: 9),
                CollabOutlineAction(
                  key: const ValueKey<String>('collab-apply-cancel'),
                  label: 'Vazgeç',
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
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

  String? _validatePhone(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty || RegExp(r'[^0-9+().\s-]').hasMatch(raw)) {
      return 'Geçerli bir telefon numarası gir.';
    }
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Telefon numarası 7-15 rakam içermelidir.';
    }
    if ('+'.allMatches(raw).length > 1 ||
        (raw.contains('+') && !raw.startsWith('+'))) {
      return '+ işareti yalnızca numaranın başında olabilir.';
    }
    return null;
  }

  Future<void> _changeActor() async {
    final actor = await Navigator.of(context).push<CollabActor>(
      collabPageRoute(
        builder: (_) => CollabProfileSelectionScreen(
          actors: widget.eligibleActors,
          wantedType: widget.listing.wantedType,
          initialActor: _actor,
          showBottomNavigation: false,
        ),
      ),
    );
    if (mounted && actor != null) setState(() => _actor = actor);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<CollabListingDetailCubit>().apply(
      CollabApplicationInput(
        applicantActorId: _actor.actorId,
        phone: _phoneController.text.trim(),
        message: _messageController.text.trim(),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SelectedActorHeader extends StatelessWidget {
  const _SelectedActorHeader({required this.actor, required this.onChange});

  final CollabActor actor;
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
            initials: actor.initials,
            profileKind: actor.profileType,
            avatarUrl: actor.avatarUrl,
            size: 53,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actor.displayName,
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
                  actor.profileType.label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              child: const Text('Profil Değiştir'),
            ),
        ],
      ),
    );
  }
}

class _ApplicationListingSummary extends StatelessWidget {
  const _ApplicationListingSummary({required this.listing});

  final CollabListing listing;

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
              CollabIdentityAvatar(
                initials: listing.publisher.initials,
                profileKind: listing.publisher.profileType,
                avatarUrl: listing.publisher.avatarUrl,
                size: 48,
              ),
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
                          label: _wantedSummary(listing),
                          color: AppColors.socialOrange,
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
                    label: listing.city.name,
                  ),
                  if (listing.cadence == CollabCadence.extra)
                    _SummaryMeta(
                      width: width,
                      icon: Icons.calendar_month_outlined,
                      label: _dateTimeText(listing.scheduledAt),
                    ),
                  if (_supportsFee(listing))
                    _SummaryMeta(
                      width: width,
                      icon: Icons.payments_outlined,
                      label: _feeText(listing),
                    ),
                  _SummaryMeta(
                    width: width,
                    icon: Icons.music_note_rounded,
                    label: listing.specialtyLabel ?? listing.wantedType.label,
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
                  'İlan sahibinin profilinden gerçek DM sohbetini açabilirsin.',
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

bool _supportsFee(CollabListing listing) =>
    listing.cadence == CollabCadence.extra ||
    (listing.cadence == CollabCadence.regular &&
        listing.publisher.profileType == CollabProfileKind.venue);

String _wantedSummary(CollabListing listing) {
  final base = listing.wantedType.wantedLabel;
  final specialty = listing.specialtyLabel;
  return listing.wantedType == CollabProfileKind.musician && specialty != null
      ? '$base: $specialty'
      : base;
}

String _dateTimeText(DateTime? value) {
  if (value == null) return 'Tarih belirtilmemiş';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} · '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _feeText(CollabListing listing) {
  final minor = listing.feeAmountMinor;
  if (minor == null) return 'Ücret belirtilmemiş';
  final major = minor ~/ 100;
  final fraction = minor.remainder(100).abs();
  final grouped = major.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final amount = fraction == 0
      ? grouped
      : '$grouped,${fraction.toString().padLeft(2, '0')}';
  return listing.currency == 'TRY'
      ? '₺$amount'
      : '$amount ${listing.currency ?? ''}'.trim();
}
