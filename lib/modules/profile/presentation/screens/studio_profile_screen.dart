import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../dm/presentation/screens/dm_chat_screen.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_state.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_state.dart';
import '../../domain/entities/studio_profile.dart';
import '../../domain/studio_profile_repository.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/studio_profile_cubit.dart';
import '../cubit/studio_profile_state.dart';
import 'profile_common_widgets.dart';
import 'profile_media_tabs.dart';
import 'profile_public_bottom_bar.dart';
import 'profile_route_args.dart';
import 'profile_screen_support.dart';
import 'profile_section_support.dart';

class StudioProfileScreen extends StatelessWidget {
  const StudioProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => serviceLocator<StudioProfileCubit>()..loadMyProfile(),
        ),
        BlocProvider(create: (_) => serviceLocator<ProfileMediaCubit>()),
        BlocProvider(create: (_) => serviceLocator<FollowCountCubit>()),
      ],
      child: const _StudioProfileView(isPublic: false),
    );
  }
}

class StudioPublicProfileScreen extends StatelessWidget {
  const StudioPublicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => serviceLocator<StudioProfileCubit>()),
        BlocProvider(create: (_) => serviceLocator<ProfileMediaCubit>()),
        BlocProvider(create: (_) => serviceLocator<FollowCountCubit>()),
        BlocProvider(create: (_) => serviceLocator<FollowActionCubit>()),
      ],
      child: const _StudioProfileView(isPublic: true),
    );
  }
}

class _StudioProfileView extends StatefulWidget {
  final bool isPublic;

  const _StudioProfileView({required this.isPublic});

  @override
  State<_StudioProfileView> createState() => _StudioProfileViewState();
}

class _StudioProfileViewState extends State<_StudioProfileView> {
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  final _imagePicker = ImagePicker();
  String? _targetProfileId;
  String? _viewerUserId;
  bool _viewerResolved = false;
  bool _editMode = false;
  bool _photoUploading = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _facilityController = TextEditingController();
  List<String> _facilities = const [];
  String? _profilePictureMediaId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isPublic && _targetProfileId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is PublicProfileArgs) {
        _targetProfileId = args.profileId;
        _viewerUserId = args.viewerUserId;
      } else if (args is Map<String, dynamic>) {
        _targetProfileId = args['profileId']?.toString();
        _viewerUserId = args['viewerUserId']?.toString();
      } else if (args is String) {
        _targetProfileId = args;
      }
      final id = _targetProfileId?.trim() ?? '';
      if (id.isNotEmpty) {
        context.read<StudioProfileCubit>().loadPublicProfile(id);
      }
    }
    if (!_viewerResolved) {
      _viewerResolved = true;
      _resolveViewer();
    }
  }

  Future<void> _resolveViewer() async {
    if ((_viewerUserId ?? '').trim().isNotEmpty) return;
    final resolved = await resolveCurrentViewerUserId();
    if (!mounted) return;
    setState(() => _viewerUserId = resolved);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _facilityController.dispose();
    super.dispose();
  }

  void _syncForm(StudioProfile profile) {
    if (_editMode) return;
    _nameController.text = profile.name ?? '';
    _descriptionController.text = profile.description ?? '';
    _addressController.text = profile.address ?? '';
    _phoneController.text = profile.phone ?? '';
    _websiteController.text = profile.website ?? '';
    _instagramController.text = profile.instagramUrl ?? '';
    _youtubeController.text = profile.youtubeUrl ?? '';
    _facilities = profile.facilities;
    _profilePictureMediaId = profile.profilePictureMediaId;
  }

  Future<void> _refresh() {
    final cubit = context.read<StudioProfileCubit>();
    if (widget.isPublic) {
      final id = _targetProfileId?.trim() ?? '';
      if (id.isNotEmpty) return cubit.loadPublicProfile(id);
      return Future.value();
    }
    return cubit.loadMyProfile();
  }

  Future<void> _save() async {
    await context.read<StudioProfileCubit>().updateMyProfile(
      StudioProfileSaveRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        profilePictureMediaId: _profilePictureMediaId,
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        website: _websiteController.text.trim(),
        facilities: _facilities,
        instagramUrl: _instagramController.text.trim(),
        youtubeUrl: _youtubeController.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _editMode = false);
  }

  Future<void> _pickPhoto(StudioProfile profile) async {
    setState(() => _photoUploading = true);
    try {
      final result = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'STUDIO_PROFILE',
        ownerId: profile.id,
        cropTitle: 'Studio profil fotografi',
      );
      if (result == null) return;
      _profilePictureMediaId = result.assetId;
      await context.read<StudioProfileCubit>().updateMyProfile(
        StudioProfileSaveRequest(profilePictureMediaId: result.assetId),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StudioProfileCubit, StudioProfileState>(
      listener: (context, state) {
        if (state.status == StudioProfileStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error?.message ?? 'Studio profili alinamadi'),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.status == StudioProfileStatus.loading &&
            state.profile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = state.profile;
        if (profile == null) {
          return Scaffold(
            appBar: _appBar(),
            body: Center(
              child: Text(state.error?.message ?? 'Studio profili bulunamadi'),
            ),
          );
        }
        _syncForm(profile);
        _scheduleLoads(profile);
        final followState = context.watch<FollowCountCubit>().state;
        final followersCount = followState.status == FollowCountStatus.loading
            ? null
            : followState.followersCount;
        final followingCount = followState.status == FollowCountStatus.loading
            ? null
            : followState.followingCount;
        return DefaultTabController(
          initialIndex: 2,
          length: 3,
          child: Scaffold(
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _StudioDashboardContent(
                  profile: profile,
                  location: _studioLocationText(profile) ?? '',
                  followersCount: followersCount,
                  followingCount: followingCount,
                  isPublic: widget.isPublic,
                  photoUploading: _photoUploading,
                  onBack: () => Navigator.of(context).maybePop(),
                  onMenu: widget.isPublic
                      ? null
                      : () => _showOwnerQuickMenu(context),
                  onEditPhoto: widget.isPublic
                      ? null
                      : () => _pickPhoto(profile),
                  onPrimaryAction: widget.isPublic
                      ? () => _openDm(profile)
                      : () => _openManagementPanel(context),
                  onReservation: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rezervasyon yakında açılacak.'),
                      ),
                    );
                  },
                ),
              ),
            ),
            bottomNavigationBar: ProfilePublicBottomBar(
              currentIndex: 4,
              profileImageUrl: profile.profilePictureUrl,
              profileTapAlwaysOpensOwnProfile: widget.isPublic,
            ),
          ),
        );
      },
    );
  }

  void _openDm(StudioProfile profile) {
    final viewerUserId = _viewerUserId?.trim() ?? '';
    if (profile.userId.isEmpty) return;
    Navigator.of(context).pushNamed(
      AppRoutes.dmChat,
      arguments: DmChatScreenArgs(
        otherUserId: profile.userId,
        otherUsername: profile.displayName,
        otherUserProfilePicture: profile.profilePictureUrl,
        currentUserId: viewerUserId,
      ),
    );
  }

  PreferredSizeWidget _appBar({StudioProfile? profile, bool saving = false}) {
    return AppBar(
      leading: const BackButton(),
      title: GradientText(
        text: 'SoundConnect',
        gradient: LinearGradient(colors: AppColors.brandGradient),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
      actions: !widget.isPublic && profile != null
          ? [
              IconButton(
                tooltip: 'Menü',
                onPressed: () => _showOwnerQuickMenu(context),
                icon: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ]
          : null,
    );
  }

  void _scheduleLoads(StudioProfile profile) {
    _loadCoordinator.scheduleMediaLoad(
      context,
      mounted: mounted,
      profileId: profile.id,
      profileType: ProfileMediaOwnerType.studio,
    );
    _loadCoordinator.scheduleFollowCountsLoad(
      context,
      mounted: mounted,
      userId: profile.userId,
    );
    if (widget.isPublic) {
      _loadCoordinator.scheduleFollowStatusLoad(
        context,
        mounted: mounted,
        followerId: _viewerUserId ?? '',
        followingId: profile.userId,
      );
    }
  }

  String? _studioLocationText(StudioProfile profile) {
    final address = profile.address?.trim();
    return address == null || address.isEmpty
        ? 'Kadıköy / İstanbul / Türkiye'
        : address;
  }

  Widget _followSummary() {
    final followState = context.watch<FollowCountCubit>().state;
    return ProfileFollowerSummary(
      followersCount: followState.status == FollowCountStatus.loading
          ? null
          : followState.followersCount,
      followingCount: followState.status == FollowCountStatus.loading
          ? null
          : followState.followingCount,
    );
  }

  Widget _publicActions(StudioProfile profile) {
    final viewerUserId = _viewerUserId?.trim() ?? '';
    final isSelf = viewerUserId.isNotEmpty && viewerUserId == profile.userId;
    final actionState = context.watch<FollowActionCubit>().state;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        if (!isSelf)
          FilledButton.icon(
            onPressed: viewerUserId.isEmpty ||
                    actionState.status == FollowActionStatus.loading
                ? null
                : () async {
                    final cubit = context.read<FollowActionCubit>();
                    await cubit.toggleFollow(
                      followerId: viewerUserId,
                      followingId: profile.userId,
                    );
                    if (!context.mounted) return;
                    context.read<FollowCountCubit>().loadCounts(profile.userId);
                  },
            icon: Icon(actionState.isFollowing ? Icons.check : Icons.add),
            label: Text(actionState.isFollowing ? 'Takiptesin' : 'Takip et'),
          ),
        if (!isSelf)
          OutlinedButton.icon(
            onPressed: profile.userId.isEmpty
                ? null
                : () => Navigator.of(context).pushNamed(
                      AppRoutes.dmChat,
                      arguments: DmChatScreenArgs(
                        otherUserId: profile.userId,
                        otherUsername: profile.displayName,
                        otherUserProfilePicture: profile.profilePictureUrl,
                        currentUserId: viewerUserId,
                      ),
                    ),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('DM'),
          ),
        if ((profile.phone ?? '').isNotEmpty)
          IconButton.filledTonal(
            tooltip: 'Ara',
            onPressed: () => _launch('tel:${profile.phone}'),
            icon: const Icon(Icons.phone_outlined),
          ),
        if ((profile.website ?? '').isNotEmpty)
          IconButton.filledTonal(
            tooltip: 'Website',
            onPressed: () => _launch(profile.website!),
            icon: const Icon(Icons.language),
          ),
      ],
    );
  }

  Widget _editForm() {
    return Column(
      children: [
        _StudioTextField(controller: _nameController, label: 'Studio adi'),
        _StudioTextField(
          controller: _descriptionController,
          label: 'Aciklama',
          maxLines: 4,
        ),
        _StudioTextField(controller: _addressController, label: 'Adres'),
        _StudioTextField(controller: _phoneController, label: 'Telefon'),
        _StudioTextField(controller: _websiteController, label: 'Website'),
        _StudioTextField(controller: _instagramController, label: 'Instagram'),
        _StudioTextField(controller: _youtubeController, label: 'YouTube'),
      ],
    );
  }

  Future<void> _saveDescription(String value) async {
    await context.read<StudioProfileCubit>().updateMyProfile(
      StudioProfileSaveRequest(description: value.trim()),
    );
  }

  Widget _managementPanelButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: AppColors.brandGradient),
        ),
        child: Padding(
          padding: const EdgeInsets.all(0.7),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: TextButton.icon(
                onPressed: () => _openManagementPanel(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.white,
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(
                  Icons.dashboard_customize_outlined,
                  color: AppColors.white,
                ),
                label: const Text(
                  'Yönetim Paneli',
                  style: TextStyle(color: AppColors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showManagementPanelPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stüdyo yönetim paneli yakında.')),
    );
  }

  void _openManagementPanel(BuildContext context) {
    final profile = context.read<StudioProfileCubit>().state.profile;
    if (profile == null) {
      _showManagementPanelPlaceholder(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudioManagementPanelScreen(profile: profile),
      ),
    );
  }

  Future<void> _showOwnerQuickMenu(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.58,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.surface,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  left: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Opacity(
                          opacity: 0.72,
                          child: ListTile(
                            enabled: false,
                            leading: Icon(Icons.settings_outlined),
                            title: Text('Ayarlar'),
                          ),
                        ),
                        const Opacity(
                          opacity: 0.72,
                          child: ListTile(
                            enabled: false,
                            leading: Icon(Icons.assignment_outlined),
                            title: Text('Başvurularım'),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.dashboard_customize_outlined,
                          ),
                          title: const Text('Yönetim Paneli'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _openManagementPanel(context);
                          },
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _addFacility() {
    final value = _facilityController.text.trim();
    if (value.isEmpty) return;
    if (_facilities.any((item) => item.toLowerCase() == value.toLowerCase())) {
      _facilityController.clear();
      return;
    }
    setState(() {
      _facilities = [..._facilities, value];
      _facilityController.clear();
    });
  }

  void _removeFacility(String value) {
    setState(() {
      _facilities = _facilities.where((item) => item != value).toList();
    });
  }

  Future<void> _launch(String raw) async {
    final normalized =
        raw.startsWith('http://') ||
            raw.startsWith('https://') ||
            raw.startsWith('tel:')
        ? raw
        : 'https://$raw';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _StudioDashboardContent extends StatelessWidget {
  final StudioProfile profile;
  final String location;
  final int? followersCount;
  final int? followingCount;
  final bool isPublic;
  final bool photoUploading;
  final VoidCallback onBack;
  final VoidCallback? onMenu;
  final VoidCallback? onEditPhoto;
  final VoidCallback onPrimaryAction;
  final VoidCallback onReservation;

  const _StudioDashboardContent({
    required this.profile,
    required this.location,
    required this.followersCount,
    required this.followingCount,
    required this.isPublic,
    required this.photoUploading,
    required this.onBack,
    required this.onMenu,
    required this.onEditPhoto,
    required this.onPrimaryAction,
    required this.onReservation,
  });

  @override
  Widget build(BuildContext context) {
    final description = profile.description?.trim().isNotEmpty == true
        ? profile.description!.trim()
        : 'Prova, kayıt, mix & mastering ve backline kiralama hizmeti.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudioTopChrome(onBack: onBack, onMenu: onMenu),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudioHeroAvatar(
                imageUrl: profile.profilePictureUrl,
                uploading: photoUploading,
                onEditPhoto: onEditPhoto,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF8C95A3),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFA3ABB8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFC1C8D2),
                          fontSize: 12,
                          height: 1.42,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (false) ...[
            const SizedBox(height: 12),
            EditableBioSection(
              bio: profile.description,
              editable: true,
              onSave: null,
              addLabel: 'Stüdyonu birkaç cümleyle anlat',
              hintText: 'Kayıt, prova, ekipman ve atmosferini anlat...',
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: _StudioMetricCard(
                  icon: Icons.meeting_room_outlined,
                  value: '4',
                  label: 'Oda',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StudioMetricCard(
                  icon: Icons.people_outline,
                  value: _formatCount(followersCount),
                  label: 'Takipçi',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StudioMetricCard(
                  icon: Icons.person_add_alt_1_outlined,
                  value: _formatCount(followingCount),
                  label: 'Takip',
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: _StudioMetricCard(
                  icon: Icons.settings_input_component_outlined,
                  value: '32',
                  label: 'Backline',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StudioActionButton(
                  icon: isPublic
                      ? Icons.chat_bubble_outline
                      : Icons.dashboard_customize_outlined,
                  label: isPublic ? 'Mesaj Gönder' : 'Yönetim Paneli',
                  outlined: true,
                  onTap: onPrimaryAction,
                ),
              ),
              if (isPublic) const SizedBox(width: 10),
              if (isPublic)
                Expanded(
                  child: _StudioActionButton(
                  icon: Icons.calendar_month_outlined,
                  label: 'Rezervasyon İste',
                  outlined: false,
                  onTap: onReservation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _StudioDarkTabs(),
        ],
      ),
    );
  }

  static String _formatCount(int? value) {
    if (value == null) return '...';
    if (value >= 1000) {
      final compact = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
      return '${compact.replaceAll('.0', '')}K';
    }
    return value.toString();
  }
}

class _StudioTopChrome extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onMenu;

  const _StudioTopChrome({required this.onBack, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Spacer(),
        IconButton(
          onPressed: onMenu,
          icon: const Icon(Icons.more_horiz, color: Colors.white),
        ),
      ],
    );
  }
}

class _StudioHeroAvatar extends StatelessWidget {
  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onEditPhoto;

  const _StudioHeroAvatar({
    required this.imageUrl,
    required this.uploading,
    required this.onEditPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = isValidNetworkImageUrl(imageUrl);
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF7A45), Color(0xFF8B2CFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B2CFF).withValues(alpha: 0.22),
                  blurRadius: 18,
                ),
              ],
            ),
            padding: const EdgeInsets.all(1.2),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF070B13),
                child: hasImage
                    ? Image.network(imageUrl!, fit: BoxFit.cover)
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/logotransparent.png',
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
          ),
          if (onEditPhoto != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: uploading ? null : onEditPhoto,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.brandGradient),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF050910), width: 2),
                  ),
                  child: uploading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.edit, size: 13, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudioMetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StudioMetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StudioSocialGradientIcon(icon, size: 15),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFA0A9B6), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _StudioActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool outlined;
  final VoidCallback onTap;

  const _StudioActionButton({
    required this.icon,
    required this.label,
    required this.outlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final innerRadius = BorderRadius.circular(7.3);
    final child = InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: outlined
              ? LinearGradient(colors: AppColors.brandGradient)
              : const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFF7C3AED)],
                ),
        ),
        padding: outlined ? const EdgeInsets.all(0.7) : EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: outlined ? innerRadius : borderRadius,
            color: outlined
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return child;
  }
}

class _StudioSocialGradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _StudioSocialGradientIcon(this.icon, {required this.size});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.socialOrange,
          AppColors.socialPink,
          AppColors.socialPurple,
        ],
      ).createShader(bounds),
      child: Icon(icon, size: size, color: AppColors.white),
    );
  }
}

class _StudioDarkTabs extends StatelessWidget {
  const _StudioDarkTabs();

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          labelColor: const Color(0xFFFF8A8A),
          unselectedLabelColor: const Color(0xFFB1B8C4),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: const _StudioTabIndicator(),
          dividerColor: const Color(0xFF151D29),
          tabs: const [
            Tab(text: 'Odalar'),
            Tab(text: 'Kayıtlar'),
            Tab(text: 'Backline'),
          ],
        ),
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return IndexedStack(
              index: controller.index,
              children: const [
                _StudioComingSoonPanel(
                  icon: Icons.meeting_room_outlined,
                  title: 'Odalar yakında',
                ),
                _StudioComingSoonPanel(
                  icon: Icons.graphic_eq,
                  title: 'Kayıtlar yakında',
                ),
                _StudioBacklinePanel(),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StudioTabIndicator extends Decoration {
  const _StudioTabIndicator();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _StudioTabIndicatorPainter();
  }
}

class _StudioTabIndicatorPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = Rect.fromLTWH(
      offset.dx + 8,
      offset.dy + size.height - 2,
      size.width - 16,
      2,
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF7A45), Color(0xFF8B2CFF)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      paint,
    );
  }
}

class _StudioComingSoonPanel extends StatelessWidget {
  final IconData icon;
  final String title;

  const _StudioComingSoonPanel({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _StudioPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Column(
            children: [
              _StudioSocialGradientIcon(icon, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioBacklinePanel extends StatelessWidget {
  const _StudioBacklinePanel();

  static const _items = [
    _BacklineItem(
      title: 'Marshall DSL40',
      type: 'Gitar Amfisi',
      status: 'Kısmen Müsait',
      statusColor: Color(0xFFB17400),
      icon: Icons.music_note_outlined,
      total: 2,
      available: 1,
      usage: 'Kiralık',
    ),
    _BacklineItem(
      title: 'Shure SM58',
      type: 'Dinamik Mikrofon',
      status: 'Müsait',
      statusColor: Color(0xFF0E8F2F),
      icon: Icons.mic_none_outlined,
      total: 6,
      available: 4,
      usage: 'Kiralık',
    ),
    _BacklineItem(
      title: 'Yamaha Stage Custom',
      type: 'Davul Seti',
      status: 'Dolu',
      statusColor: Color(0xFF9E1F24),
      icon: Icons.circle_outlined,
      total: 1,
      available: 0,
      usage: 'Stüdyo İçi',
    ),
    _BacklineItem(
      title: 'Nord Stage 3',
      type: 'Klavye',
      status: 'Müsait',
      statusColor: Color(0xFF0E8F2F),
      icon: Icons.keyboard_outlined,
      total: 1,
      available: 1,
      usage: 'Stüdyo İçi',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _StudioPanel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'Backline Envanteri',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'Stüdyo içi ve kiralanabilir ekipmanlar',
                  style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: _BacklineSummary(
                      icon: Icons.inventory_2_outlined,
                      value: '28',
                      label: 'Ekipman',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _BacklineSummary(
                      icon: Icons.check_circle_outline,
                      value: '17',
                      label: 'Müsait',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _BacklineSummary(
                      icon: Icons.build_outlined,
                      value: '3',
                      label: 'Bakımda',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _BacklineFilters(),
              const SizedBox(height: 10),
              const _BacklineSearch(),
              const SizedBox(height: 10),
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BacklineItemCard(item: item),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioPanel extends StatelessWidget {
  final Widget child;

  const _StudioPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B111B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E2836)),
      ),
      child: child,
    );
  }
}

class _BacklineSummary extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _BacklineSummary({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StudioSocialGradientIcon(icon, size: 15),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _BacklineFilters extends StatefulWidget {
  const _BacklineFilters();

  @override
  State<_BacklineFilters> createState() => _BacklineFiltersState();
}

class _BacklineFiltersState extends State<_BacklineFilters> {
  String? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    const filters = [
      'Tümü',
      'Amfi',
      'Mikrofon',
      'Davul',
      'Klavye',
      'PA',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < filters.length; i++) ...[
            _BacklineFilterChip(
              label: filters[i],
              selected: _selectedFilter == filters[i],
              onTap: () {
                setState(() {
                  _selectedFilter = _selectedFilter == filters[i]
                      ? null
                      : filters[i];
                });
              },
            ),
            const SizedBox(width: 8),
          ],
          _BacklineFilterChip(
            label: 'Tüm Kategoriler',
            selected: false,
            trailingIcon: Icons.chevron_right,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _BacklineCategoriesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BacklineFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  const _BacklineFilterChip({
    required this.label,
    required this.selected,
    this.trailingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(0.8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF7A45), Color(0xFF8B2CFF)],
                )
              : null,
          borderRadius: radius,
          border: selected
              ? null
              : Border.all(color: const Color(0xFF263244)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF101722),
            borderRadius: BorderRadius.circular(7.2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFFF8A8A)
                      : const Color(0xFFB5BDCA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(
                  trailingIcon,
                  color: const Color(0xFFB5BDCA),
                  size: 15,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BacklineCategoriesScreen extends StatelessWidget {
  const _BacklineCategoriesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tüm Kategoriler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101722),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF202B3A)),
          ),
          child: const Text(
            'Kategori listesi yakında burada olacak.',
            style: TextStyle(
              color: Color(0xFFB5BDCA),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _BacklineSearch extends StatelessWidget {
  const _BacklineSearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF090F18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF273244)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Row(
        children: [
          Icon(Icons.search, color: Color(0xFF758092), size: 18),
          SizedBox(width: 8),
          Text(
            'Ekipman ara...',
            style: TextStyle(color: Color(0xFF758092), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BacklineItem {
  final String title;
  final String type;
  final String status;
  final Color statusColor;
  final IconData icon;
  final int total;
  final int available;
  final String usage;

  const _BacklineItem({
    required this.title,
    required this.type,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.total,
    required this.available,
    required this.usage,
  });
}

class _BacklineItemCard extends StatelessWidget {
  final _BacklineItem item;

  const _BacklineItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _BacklineItemDetailScreen(item: item),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF101722),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF202B3A)),
        ),
        child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF080D15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF263244)),
            ),
            child: Icon(item.icon, color: const Color(0xFFD4D9E2), size: 34),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _BacklineStatus(label: item.status, color: item.statusColor),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.type,
                  style: const TextStyle(
                    color: Color(0xFFB7C0CE),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _MiniMeta(label: 'Toplam', value: item.total.toString()),
                    const SizedBox(width: 6),
                    _MiniMeta(
                      label: 'Müsait',
                      value: item.available.toString(),
                      dotColor: const Color(0xFF15C46B),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _MiniMeta(
                        label: '',
                        value: item.usage,
                        dotColor: const Color(0xFF8B2CFF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: const [
                    _TinyButton(icon: Icons.info_outline, label: 'Detay'),
                    SizedBox(width: 8),
                    _TinyButton(
                      icon: Icons.calendar_month_outlined,
                      label: 'Takvimi Gör',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            color: Color(0xFF7B8493),
            size: 20,
          ),
        ],
        ),
      ),
    );
  }
}

class _BacklineItemDetailScreen extends StatelessWidget {
  final _BacklineItem item;

  const _BacklineItemDetailScreen({required this.item});

  String get _price {
    if (item.title.contains('Marshall')) return '\u20BA450 / saat\n\u20BA2.500 / g\u00FCn';
    if (item.title.contains('Shure')) return '\u20BA150 / saat\n\u20BA700 / g\u00FCn';
    return item.usage;
  }

  String get _deposit {
    if (item.title.contains('Marshall')) return '\u20BA2.000';
    if (item.title.contains('Shure')) return '\u20BA500';
    return 'Yok';
  }

  String get _description {
    if (item.title.contains('Marshall')) {
      return '40 Watt, 2 kanal, reverb, FX loop, footswitch dahil.';
    }
    if (item.title.contains('Shure')) {
      return 'Dinamik vokal mikrofonu, sahne ve prova kullan\u0131m\u0131na uygun.';
    }
    if (item.title.contains('Yamaha')) {
      return 'Akustik davul seti, prova odas\u0131 kullan\u0131m\u0131na dahildir.';
    }
    return 'Sahne klavyesi, piyano ve synth tonlar\u0131 haz\u0131r.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BacklineDetailChrome(
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 8),
              _BacklineDetailHero(item: item),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.type,
                          style: const TextStyle(
                            color: Color(0xFFB7C0CE),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _BacklineStatus(label: item.status, color: item.statusColor),
                ],
              ),
              const SizedBox(height: 18),
              _BacklineInventorySummary(item: item),
              const SizedBox(height: 12),
              _BacklineDetailInfoCard(
                usage: item.usage,
                price: _price,
                deposit: _deposit,
                description: _description,
              ),
              const SizedBox(height: 18),
              _BacklineDetailGradientButton(
                icon: Icons.calendar_month_outlined,
                label: 'Talep Et',
                filled: true,
                onTap: () => _showComingSoon(context),
              ),
              const SizedBox(height: 18),
              _BacklineAvailabilityCalendar(item: item),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu aksiyon yak\u0131nda a\u00E7\u0131lacak.')),
    );
  }
}

class _BacklineDetailChrome extends StatelessWidget {
  final VoidCallback onBack;

  const _BacklineDetailChrome({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.ios_share_outlined, color: Colors.white),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_horiz, color: Colors.white),
        ),
      ],
    );
  }
}

class _BacklineDetailHero extends StatefulWidget {
  final _BacklineItem item;

  const _BacklineDetailHero({required this.item});

  @override
  State<_BacklineDetailHero> createState() => _BacklineDetailHeroState();
}

class _BacklineDetailHeroState extends State<_BacklineDetailHero> {
  static const _photoLimit = 5;
  final _pageController = PageController();
  int _activePage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _photoLimit,
            onPageChanged: (index) => setState(() => _activePage = index),
            itemBuilder: (context, index) {
              return _BacklineDetailHeroImage(
                item: widget.item,
                index: index,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _photoLimit,
            (index) => _BacklineHeroDot(active: index == _activePage),
          ),
        ),
      ],
    );
  }
}

class _BacklineDetailHeroImage extends StatelessWidget {
  final _BacklineItem item;
  final int index;

  const _BacklineDetailHeroImage({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.05,
          colors: [
            AppColors.socialPurple.withValues(alpha: 0.18),
            const Color(0xFF111824),
            const Color(0xFF070B12),
          ],
        ),
        border: Border.all(color: const Color(0xFF202B3A)),
        boxShadow: [
          BoxShadow(
            color: AppColors.pureBlack.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 176,
          height: 122,
          decoration: BoxDecoration(
            color: const Color(0xFF101722),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF313B4D)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StudioSocialGradientIcon(item.icon, size: 46),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${index + 1}/5',
                style: const TextStyle(
                  color: Color(0xFF8791A1),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BacklineHeroDot extends StatelessWidget {
  final bool active;

  const _BacklineHeroDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: active
            ? LinearGradient(
                colors: [
                  AppColors.socialOrange,
                  AppColors.socialPink,
                  AppColors.socialPurple,
                ],
              )
            : null,
        color: active ? null : const Color(0xFF626C7A),
      ),
    );
  }
}

class _BacklineInventorySummary extends StatelessWidget {
  final _BacklineItem item;

  const _BacklineInventorySummary({required this.item});

  @override
  Widget build(BuildContext context) {
    final reserved = item.total - item.available > 0 ? 1 : 0;
    final maintenance = item.status.contains('Bak') ? 1 : 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Row(
        children: [
          _BacklineCountCell(label: 'Toplam Adet', value: item.total.toString()),
          _BacklineCountDivider(),
          _BacklineCountCell(
            label: 'M\u00FCsait',
            value: item.available.toString(),
            color: const Color(0xFF15C46B),
          ),
          _BacklineCountDivider(),
          _BacklineCountCell(
            label: 'Rezerve',
            value: reserved.toString(),
            color: const Color(0xFFFFA000),
          ),
          _BacklineCountDivider(),
          _BacklineCountCell(
            label: 'Bak\u0131mda',
            value: maintenance.toString(),
          ),
        ],
      ),
    );
  }
}

class _BacklineCountCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _BacklineCountCell({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFB5BDCA), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineCountDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: const Color(0xFF273244));
  }
}

class _BacklineDetailInfoCard extends StatelessWidget {
  final String usage;
  final String price;
  final String deposit;
  final String description;

  const _BacklineDetailInfoCard({
    required this.usage,
    required this.price,
    required this.deposit,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        children: [
          _BacklineInfoRow(
            icon: Icons.work_outline,
            label: 'Kullan\u0131m',
            value: usage,
          ),
          _BacklineInfoRow(
            icon: Icons.paid_outlined,
            label: 'Kiralama Fiyat\u0131',
            value: price,
          ),
          _BacklineInfoRow(
            icon: Icons.lock_outline,
            label: 'Depozito',
            value: deposit,
          ),
          _BacklineInfoRow(
            icon: Icons.notes_outlined,
            label: 'A\u00E7\u0131klama',
            value: description,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _BacklineAvailabilityCalendar extends StatefulWidget {
  final _BacklineItem item;

  const _BacklineAvailabilityCalendar({required this.item});

  @override
  State<_BacklineAvailabilityCalendar> createState() =>
      _BacklineAvailabilityCalendarState();
}

class _BacklineAvailabilityCalendarState
    extends State<_BacklineAvailabilityCalendar> {
  String _selectedMode = 'daily';
  DateTime _selectedDate = DateTime(2025, 6, 3);
  static final DateTime _calendarToday = DateTime(2025, 6, 3);

  static const _hours = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'M\u00FCsaitlik Takvimi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item.title,
            style: const TextStyle(color: Color(0xFFB5BDCA), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _CalendarArrowButton(
                icon: Icons.arrow_back,
                onTap: _canMoveBackward ? () => _moveCalendar(-1) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openCalendarPicker,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A101A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF263244)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: Color(0xFFF06C86),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _calendarTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CalendarArrowButton(
                icon: Icons.arrow_forward,
                onTap: () => _moveCalendar(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CalendarModeSwitch(
            selectedMode: _selectedMode,
            onChanged: (mode) {
              setState(() {
                _selectedMode = mode;
              });
            },
          ),
          const SizedBox(height: 16),
          if (_selectedMode == 'weekly')
            _WeeklyAvailabilityGrid(
              item: widget.item,
              startDate: _selectedDate,
              isDatePast: _isPastDate,
              onDayTap: (date) {
                setState(() {
                  _selectedDate = date;
                  _selectedMode = 'daily';
                });
              },
            )
          else ...[
            const Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    'Saat',
                    style: TextStyle(color: Color(0xFFCDD3DE), fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Adet M\u00FCsait',
                      style: TextStyle(color: Color(0xFFCDD3DE), fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(
              _hours.length,
              (index) => _CalendarAvailabilityRow(
                hour: _hours[index],
                values: _availabilityValues(index, widget.item.available),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const _CalendarLegend(),
        ],
      ),
    );
  }

  static bool _isPastDate(DateTime date) {
    return _dateOnly(date).isBefore(_dateOnly(_calendarToday));
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _openCalendarPicker() async {
    final initialDate = _isPastDate(_selectedDate)
        ? _calendarToday
        : _selectedDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _calendarToday,
      lastDate: _calendarToday.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.socialPink,
              onPrimary: Colors.white,
              surface: const Color(0xFF101722),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF101722),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    setState(() {
      _selectedDate = _dateOnly(pickedDate);
    });
  }

  static List<int> _availabilityValues(int rowIndex, int available) {
    final maxAvailable = available.clamp(0, 2).toInt();
    const pattern = [
      [2, 2, 2, 2],
      [2, 2, 1, 1],
      [1, 1, 1, 1],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [2, 2, 2, 2],
    ];
    return pattern[rowIndex % pattern.length]
        .map((value) => value > maxAvailable ? maxAvailable : value)
        .toList(growable: false);
  }

  String get _calendarTitle {
    if (_selectedMode == 'weekly') {
      return _formatDateRange(
        _selectedDate,
        _selectedDate.add(const Duration(days: 6)),
      );
    }
    return _formatFullDate(_selectedDate);
  }

  void _moveCalendar(int direction) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: direction));
    });
  }

  bool get _canMoveBackward {
    if (_selectedMode == 'weekly') return true;
    return !_isPastDate(_selectedDate.add(const Duration(days: -1)));
  }

  static String _formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${start.day}-${end.day} ${_monthLong(start.month)} ${start.year}';
    }
    if (start.year == end.year) {
      return '${start.day} ${_monthShort(start.month)}-${end.day} ${_monthLong(end.month)} ${start.year}';
    }
    return '${start.day} ${_monthShort(start.month)} ${start.year}-${end.day} ${_monthShort(end.month)} ${end.year}';
  }

  static String _formatFullDate(DateTime date) {
    return '${date.day} ${_monthLong(date.month)} ${date.year} ${_weekdayLong(date.weekday)}';
  }

  static String _monthShort(int month) {
    const months = [
      'Oca',
      '\u015Eub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'A\u011Fu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return months[month - 1];
  }

  static String _monthLong(int month) {
    const months = [
      'Ocak',
      '\u015Eubat',
      'Mart',
      'Nisan',
      'May\u0131s',
      'Haziran',
      'Temmuz',
      'A\u011Fustos',
      'Eyl\u00FCl',
      'Ekim',
      'Kas\u0131m',
      'Aral\u0131k',
    ];
    return months[month - 1];
  }

  static String _weekdayShort(int weekday) {
    const days = ['Pzt', 'Sal', '\u00C7ar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[weekday - 1];
  }

  static String _weekdayLong(int weekday) {
    const days = [
      'Pazartesi',
      'Sal\u0131',
      '\u00C7ar\u015Famba',
      'Per\u015Fembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    return days[weekday - 1];
  }
}

class _WeeklyAvailabilityGrid extends StatelessWidget {
  final _BacklineItem item;
  final DateTime startDate;
  final bool Function(DateTime date) isDatePast;
  final ValueChanged<DateTime> onDayTap;

  const _WeeklyAvailabilityGrid({
    required this.item,
    required this.startDate,
    required this.isDatePast,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (index) {
      final date = startDate.add(Duration(days: index));
      return _WeeklyDay(
        day: _BacklineAvailabilityCalendarState._weekdayShort(date.weekday),
        date: date.day.toString(),
        month: _BacklineAvailabilityCalendarState._monthShort(date.month),
        dateValue: date,
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hafta \u00D6zeti',
          style: TextStyle(
            color: Color(0xFFCDD3DE),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              days.length,
              (index) {
                final values =
                    _BacklineAvailabilityCalendarState._availabilityValues(
                  index + 1,
                  item.available,
                );
                final disabled = isDatePast(days[index].dateValue);
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == days.length - 1 ? 0 : 8,
                  ),
                  child: _WeeklyDateCard(
                    day: days[index],
                    status: _WeeklyDayStatus.fromValues(values),
                    disabled: disabled,
                    onTap: disabled
                        ? null
                        : () => onDayTap(days[index].dateValue),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyDay {
  final String day;
  final String date;
  final String month;
  final DateTime dateValue;

  const _WeeklyDay({
    required this.day,
    required this.date,
    required this.month,
    required this.dateValue,
  });
}

class _WeeklyDayStatus {
  final String label;
  final Color color;

  const _WeeklyDayStatus({
    required this.label,
    required this.color,
  });

  factory _WeeklyDayStatus.fromValues(List<int> values) {
    if (values.every((value) => value == 0)) {
      return const _WeeklyDayStatus(
        label: 'Dolu',
        color: Color(0xFFB8323B),
      );
    }
    if (values.any((value) => value == 1)) {
      return _WeeklyDayStatus(
        label: 'K\u0131smen',
        color: AppColors.socialOrange,
      );
    }
    return const _WeeklyDayStatus(
      label: 'M\u00FCsait',
      color: Color(0xFF1EAF4D),
    );
  }
}

class _WeeklyDateCard extends StatelessWidget {
  final _WeeklyDay day;
  final _WeeklyDayStatus status;
  final bool disabled;
  final VoidCallback? onTap;

  const _WeeklyDateCard({
    required this.day,
    required this.status,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = disabled ? const Color(0xFF6B7280) : status.color;
    final statusLabel = disabled ? 'Ge\u00E7ti' : status.label;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFF090D14) : const Color(0xFF0A101A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled ? const Color(0xFF1A2230) : const Color(0xFF263244),
          ),
        ),
        child: Column(
          children: [
            Text(
              day.day,
              style: TextStyle(
                color: disabled
                    ? const Color(0xFF5F6876)
                    : const Color(0xFFB5BDCA),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              day.date,
              style: TextStyle(
                color: disabled ? const Color(0xFF77808E) : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              day.month,
              style: TextStyle(
                color: disabled
                    ? const Color(0xFF5F6876)
                    : const Color(0xFF8E98A7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: disabled ? 0.09 : 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: statusColor.withValues(alpha: disabled ? 0.2 : 0.35),
                ),
              ),
              child: Text(
                statusLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CalendarArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF0A101A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFF263244) : const Color(0xFF1A2230),
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.socialPink : const Color(0xFF596272),
          size: 20,
        ),
      ),
    );
  }
}

class _CalendarModeSwitch extends StatelessWidget {
  final String selectedMode;
  final ValueChanged<String> onChanged;

  const _CalendarModeSwitch({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF0A101A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CalendarModeOption(
              label: 'G\u00FCnl\u00FCk',
              selected: selectedMode == 'daily',
              onTap: () {
                onChanged('daily');
              },
            ),
          ),
          Expanded(
            child: _CalendarModeOption(
              label: 'Haftal\u0131k',
              selected: selectedMode == 'weekly',
              onTap: () {
                onChanged('weekly');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarModeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CalendarModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(7);
    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(0.8),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF7A45), Color(0xFF8B2CFF)],
                )
              : null,
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.2),
            color: selected ? const Color(0xFF15111F) : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFFFF8A8A) : const Color(0xFFCDD3DE),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarAvailabilityRow extends StatelessWidget {
  final String hour;
  final List<int> values;

  const _CalendarAvailabilityRow({
    required this.hour,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              hour,
              style: const TextStyle(color: Color(0xFFE1E6EF), fontSize: 13),
            ),
          ),
          for (final value in values) ...[
            Expanded(child: _CalendarAvailabilityCell(value: value)),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _CalendarAvailabilityCell extends StatelessWidget {
  final int value;

  const _CalendarAvailabilityCell({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      0 => const Color(0xFF9E2730),
      1 => const Color(0xFFB87505),
      _ => const Color(0xFF176B31),
    };
    return Container(
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.58)),
      ),
      child: Text(
        value.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        const _CalendarLegendItem(
          color: Color(0xFF1EAF4D),
          label: 'M\u00FCsait',
        ),
        _CalendarLegendItem(
          color: AppColors.socialOrange,
          label: 'K\u0131smen M\u00FCsait',
        ),
        const _CalendarLegendItem(color: Color(0xFFB8323B), label: 'Dolu'),
        const _CalendarLegendItem(
          color: Color(0xFF6B7280),
          label: 'Bak\u0131mda',
        ),
      ],
    );
  }
}

class _CalendarLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFCDD3DE), fontSize: 12),
        ),
      ],
    );
  }
}

class _BacklineInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  const _BacklineInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF273244))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFB5BDCA), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFCDD3DE), fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFE5E9F0),
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineDetailGradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _BacklineDetailGradientButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Container(
        height: 54,
        padding: filled ? EdgeInsets.zero : const EdgeInsets.all(0.8),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: [
              AppColors.socialOrange,
              AppColors.socialPink,
              AppColors.socialPurple,
            ],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: filled ? radius : BorderRadius.circular(7.2),
            color: filled
                ? null
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BacklineStatus extends StatelessWidget {
  final String label;
  final Color color;

  const _BacklineStatus({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.computeLuminance() > 0.4 ? color : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final String label;
  final String value;
  final Color? dotColor;

  const _MiniMeta({required this.label, required this.value, this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0xFF8D97A6), fontSize: 10),
          ),
        if (dotColor != null) ...[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE1E6EF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TinyButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TinyButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF273244)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioAvatar extends StatelessWidget {
  final String? imageUrl;
  final bool uploading;
  final bool editable;
  final VoidCallback onTap;

  const _StudioAvatar({
    required this.imageUrl,
    required this.uploading,
    required this.editable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = isValidNetworkImageUrl(imageUrl);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: editable && !uploading ? onTap : null,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient[2].withValues(alpha: 0.28),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: hasImage
                    ? Image.network(imageUrl!, fit: BoxFit.cover)
                    : Icon(
                        Icons.graphic_eq_outlined,
                        size: 42,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
          ),
          if (editable)
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: uploading ? null : onTap,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navBlueDeep, width: 2),
                  ),
                  child: uploading
                      ? Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Icon(Icons.edit, size: 14, color: AppColors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudioTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _StudioTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _StudioFacilities extends StatelessWidget {
  final List<String> facilities;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _StudioFacilities({
    required this.facilities,
    required this.editing,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Olanaklar',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        if (editing)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAdd(),
                  decoration: const InputDecoration(
                    labelText: 'Olanak ekle',
                    prefixIcon: Icon(Icons.add_circle_outline),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        if (editing) const SizedBox(height: 10),
        if (facilities.isEmpty)
          Text(
            'Henuz olanak eklenmemis.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: facilities
                .map(
                  (facility) => InputChip(
                    label: Text(facility),
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    onDeleted: editing ? () => onRemove(facility) : null,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _StudioInfoSection extends StatelessWidget {
  final StudioProfile profile;

  const _StudioInfoSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final items = <_InfoItem>[
      _InfoItem(Icons.location_on_outlined, 'Adres', profile.address),
      _InfoItem(Icons.phone_outlined, 'Telefon', profile.phone),
      _InfoItem(Icons.language, 'Website', profile.website),
      _InfoItem(Icons.camera_alt_outlined, 'Instagram', profile.instagramUrl),
      _InfoItem(Icons.play_circle_outline, 'YouTube', profile.youtubeUrl),
    ].where((item) => (item.value ?? '').trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items
            .map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.icon, color: AppColors.coralAlt),
                title: Text(item.label),
                subtitle: Text(item.value!),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StudioProfileTabs extends StatelessWidget {
  const _StudioProfileTabs();

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileMediaTabs(
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.meeting_room_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Odalar'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.graphic_eq, size: 18),
                  SizedBox(width: 6),
                  Text('Kayıtlar'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings_input_component_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Backline'),
                ],
              ),
            ),
          ],
        ),
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return IndexedStack(
              index: controller.index,
              children: const [
                _StudioTabPlaceholder(
                  icon: Icons.meeting_room_outlined,
                  title: 'Odalar yakında',
                ),
                _StudioTabPlaceholder(
                  icon: Icons.graphic_eq,
                  title: 'Kayıtlar yakında',
                ),
                _StudioTabPlaceholder(
                  icon: Icons.settings_input_component_outlined,
                  title: 'Backline yakında',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StudioTabPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;

  const _StudioTabPlaceholder({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
          ),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoItem(this.icon, this.label, this.value);
}

class StudioManagementPanelScreen extends StatelessWidget {
  final StudioProfile profile;

  const StudioManagementPanelScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final profileName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'Studio';
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim Paneli'), centerTitle: true),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      Theme.of(context).colorScheme.surfaceContainer,
                    ],
                  ),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      text: profileName,
                      gradient: LinearGradient(
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
                    Text(
                      'Buradan stüdyo profilini destekleyen yönetim araçlarına erişebilirsin.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _StudioManagementActionCard(
                icon: Icons.tune_outlined,
                title: 'Stüdyo Bilgileri',
                message: 'Yakında burada açılacak.',
                trailingLabel: 'Yakında!',
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.photo_library_outlined,
                title: 'Galeri ve Medya',
                message: 'Yakında burada açılacak.',
                trailingLabel: 'Yakında!',
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.event_available_outlined,
                title: 'Randevu / Takvim',
                message: 'Yakında burada açılacak.',
                trailingLabel: 'Yakında!',
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.mode_comment_outlined,
                title: 'Yorumlar ve Geri Bildirimler',
                message: 'Yakında burada açılacak.',
                trailingLabel: 'Yakında!',
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.insights_outlined,
                title: 'Profil İstatistikleri',
                message: 'Yakında burada açılacak.',
                trailingLabel: 'Yakında!',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioManagementActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? trailingLabel;
  final VoidCallback? onTap;

  const _StudioManagementActionCard({
    required this.icon,
    required this.title,
    required this.message,
    this.trailingLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
      borderRadius: BorderRadius.circular(18),
      child: _StudioGradientOutline(
        radius: 18,
        strokeWidth: 1,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(context).colorScheme.surfaceContainer,
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
                    trailingLabel!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioGradientOutline extends StatelessWidget {
  final Widget child;
  final double radius;
  final double strokeWidth;

  const _StudioGradientOutline({
    required this.child,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StudioGradientOutlinePainter(
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

class _StudioGradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;

  const _StudioGradientOutlinePainter({
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
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _StudioGradientOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
