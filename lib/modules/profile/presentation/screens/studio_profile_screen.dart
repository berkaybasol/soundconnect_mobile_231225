import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';
import '../../../../shared/widgets/session_logout_action.dart';
import '../../../dm/presentation/screens/dm_chat_screen.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_state.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_state.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../studio/data/studio_room_repository_impl.dart';
import '../../../studio/domain/entities/studio_reservation.dart';
import '../../../studio/domain/entities/studio_room.dart';
import '../../../studio/domain/entities/backline_catalog.dart';
import '../../../studio/domain/entities/studio_equipment.dart';
import '../../../studio/domain/backline_catalog_repository.dart';
import '../../../studio/domain/studio_booking_policy.dart';
import '../../../studio/domain/studio_equipment_repository.dart';
import '../../../studio/domain/studio_room_repository.dart';
import '../../domain/entities/studio_profile.dart';
import '../../domain/entities/track.dart';
import '../../domain/studio_profile_repository.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/studio_profile_cubit.dart';
import '../cubit/studio_profile_state.dart';
import 'profile_audio_tab_shared.dart';
import 'profile_common_widgets.dart';
import 'profile_media_tabs.dart';
import 'profile_public_bottom_bar.dart';
import 'profile_route_args.dart';
import 'profile_screen_support.dart';
import 'profile_section_support.dart';
import 'profile_social_support.dart';

part 'studio_profile_backline_taxonomy.dart';
part 'studio_owner_backline_management.dart';
part 'studio_owner_backline_inventory_item_management.dart';
part 'studio_owner_backline_availability_management.dart';
part 'studio_owner_rooms_management.dart';
part 'studio_owner_room_settings.dart';
part 'studio_owner_reservations_hub.dart';
part 'studio_public_profile_content.dart';
part 'studio_profile_room_detail.dart';
part 'studio_profile_recordings.dart';

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
        BlocProvider(create: (_) => serviceLocator<InteractionStatsCubit>()),
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
        BlocProvider(create: (_) => serviceLocator<InteractionStatsCubit>()),
      ],
      child: const _StudioProfileView(isPublic: true),
    );
  }
}

class StudioReservationCalendarArgs {
  const StudioReservationCalendarArgs({
    required this.roomId,
    required this.studioProfileId,
    required this.ownerMode,
    this.timeZone = 'Europe/Istanbul',
    this.reservationDate,
    this.reservationId,
  });

  final String roomId;
  final String studioProfileId;
  final bool ownerMode;
  final String timeZone;
  final DateTime? reservationDate;
  final String? reservationId;
}

class StudioReservationCalendarScreen extends StatefulWidget {
  const StudioReservationCalendarScreen({required this.args, super.key});

  final StudioReservationCalendarArgs args;

  @override
  State<StudioReservationCalendarScreen> createState() =>
      _StudioReservationCalendarScreenState();
}

class _StudioReservationCalendarScreenState
    extends State<StudioReservationCalendarScreen> {
  final StudioRoomRepository _repository =
      serviceLocator<StudioRoomRepository>();
  _StudioRoomItem? _room;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room != null) {
      return _StudioRoomDetailScreen(
        room: room,
        studioProfileId: widget.args.studioProfileId,
        canReserve: !widget.args.ownerMode,
        ownerRooms: widget.args.ownerMode ? [room] : const [],
        initialDate: widget.args.reservationDate,
        initialReservationId: widget.args.reservationId,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervasyon Takvimi'),
        centerTitle: true,
      ),
      body: Center(
        child: _errorMessage == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: _StudioRoomsErrorState(
                  message: _errorMessage!,
                  onRetry: _loadRoom,
                ),
              ),
      ),
    );
  }

  Future<void> _loadRoom() async {
    setState(() {
      _room = null;
      _errorMessage = null;
    });
    final result = widget.args.ownerMode
        ? await _repository.getOwnerRoom(widget.args.roomId)
        : await _repository.getPublicRoom(
            widget.args.studioProfileId,
            widget.args.roomId,
          );
    if (!mounted) return;
    final room = result.data;
    if (!result.isSuccess || room == null) {
      setState(() {
        _errorMessage =
            result.error?.message ?? 'Rezervasyon takvimi getirilemedi.';
      });
      return;
    }
    setState(() {
      _room = _StudioRoomItem.fromDomain(room, timeZone: widget.args.timeZone);
    });
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
  int _contentRevision = 0;

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

  Future<void> _refresh() async {
    final cubit = context.read<StudioProfileCubit>();
    if (widget.isPublic) {
      final id = _targetProfileId?.trim() ?? '';
      if (id.isNotEmpty) await cubit.loadPublicProfile(id);
    } else {
      await cubit.loadMyProfile();
    }
    if (mounted) setState(() => _contentRevision++);
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
    final profileCubit = context.read<StudioProfileCubit>();
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
      if (!mounted) return;
      _profilePictureMediaId = result.assetId;
      // The upload pipeline already attaches the media through the Studio
      // profile endpoint, which advances the optimistic version. Reload the
      // authoritative profile instead of issuing a stale duplicate update.
      await profileCubit.loadMyProfile();
      if (!mounted) return;
      _profilePictureMediaId =
          profileCubit.state.profile?.profilePictureMediaId ?? result.assetId;
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
        final followActionState = widget.isPublic
            ? context.watch<FollowActionCubit>().state
            : const FollowActionState.idle();
        final viewerUserId = (_viewerUserId ?? '').trim();
        final canFollow =
            widget.isPublic &&
            viewerUserId.isNotEmpty &&
            viewerUserId != profile.userId;
        return DefaultTabController(
          initialIndex: 0,
          length: 3,
          child: Scaffold(
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: widget.isPublic
                    ? _StudioPublicDashboardContent(
                        profile: profile,
                        location: _studioLocationText(profile) ?? '',
                        followersCount: followersCount,
                        followingCount: followingCount,
                        onBack: () => Navigator.of(context).maybePop(),
                        onMessage: () => _openDm(profile),
                        isFollowing: followActionState.isFollowing,
                        followLoading:
                            followActionState.status ==
                            FollowActionStatus.loading,
                        contentRevision: _contentRevision,
                        onFollow: canFollow
                            ? () => _toggleFollow(profile)
                            : null,
                      )
                    : _StudioOwnerDashboardContent(
                        profile: profile,
                        location: _studioLocationText(profile) ?? '',
                        followersCount: followersCount,
                        followingCount: followingCount,
                        photoUploading: _photoUploading,
                        onBack: () => Navigator.of(context).maybePop(),
                        onMenu: () => _showOwnerQuickMenu(context),
                        onEditPhoto: () => _pickPhoto(profile),
                        onEditDescription: () =>
                            _showDescriptionEditor(profile.description),
                        onEditSocialLink: (platform) =>
                            _editSocialLink(profile, platform),
                        contentRevision: _contentRevision,
                        onManagement: () => _openManagementPanel(context),
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

  Future<void> _toggleFollow(StudioProfile profile) async {
    final viewerUserId = (_viewerUserId ?? '').trim();
    if (viewerUserId.isEmpty || viewerUserId == profile.userId) return;

    final actionCubit = context.read<FollowActionCubit>();
    await actionCubit.toggleFollow(
      followerId: viewerUserId,
      followingId: profile.userId,
    );
    if (!mounted) return;
    final actionState = actionCubit.state;
    if (actionState.status == FollowActionStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actionState.error?.message ?? 'Takip durumu güncellenemedi.',
          ),
        ),
      );
      return;
    }
    context.read<FollowCountCubit>().loadCounts(profile.userId);
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
    final locationParts = <String>[
      if ((profile.neighborhoodName ?? '').trim().isNotEmpty)
        profile.neighborhoodName!.trim(),
      if ((profile.districtName ?? '').trim().isNotEmpty)
        profile.districtName!.trim(),
      if ((profile.cityName ?? '').trim().isNotEmpty) profile.cityName!.trim(),
    ];
    if (locationParts.isNotEmpty) return locationParts.join(', ');
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
            onPressed:
                viewerUserId.isEmpty ||
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

  Future<void> _showDescriptionEditor(String? currentDescription) async {
    final profileCubit = context.read<StudioProfileCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudioDescriptionEditorSheet(
        initialValue: currentDescription ?? '',
        onSave: (value) async {
          await profileCubit.updateMyProfile(
            StudioProfileSaveRequest(description: value),
          );
          final state = profileCubit.state;
          if (state.status == StudioProfileStatus.failure) {
            return state.error?.message ?? 'Açıklama kaydedilemedi.';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _editSocialLink(
    StudioProfile profile,
    ProfileSocialPlatform platform,
  ) async {
    final currentUrl = socialUrlForStudioProfile(profile, platform) ?? '';
    final normalizedUrl = await promptForSocialLink(
      context,
      platform: platform,
      initialValue: currentUrl,
    );
    if (!mounted ||
        normalizedUrl == null ||
        normalizedUrl == currentUrl.trim()) {
      return;
    }
    await context.read<StudioProfileCubit>().updateMyProfile(
      buildStudioSocialLinkRequest(platform, normalizedUrl),
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

  Future<void> _openManagementPanel(BuildContext context) async {
    final profile = context.read<StudioProfileCubit>().state.profile;
    if (profile == null) {
      _showManagementPanelPlaceholder(context);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StudioManagementPanelScreen(profile: profile),
      ),
    );
    if (mounted) setState(() => _contentRevision++);
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
                        ListTile(
                          key: const Key('studio-account-settings'),
                          leading: const Icon(Icons.settings_outlined),
                          title: const Text('Ayarlar'),
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.settings);
                            if (!context.mounted) return;
                            await context
                                .read<StudioProfileCubit>()
                                .loadMyProfile();
                          },
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
                        ListTile(
                          key: profileMenuThemeTileKey,
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('Tema'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            showProfileMenuThemePicker(context);
                          },
                        ),
                        ListTile(
                          key: profileMenuSupportTileKey,
                          leading: const Icon(Icons.support_agent_rounded),
                          title: const Text('Destek'),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            showProfileMenuSupport(context);
                          },
                        ),
                        const Spacer(),
                        SessionLogoutMenuTile(
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await confirmAndLogoutSession(context);
                          },
                        ),
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

class _StudioDescriptionEditorSheet extends StatefulWidget {
  final String initialValue;
  final Future<String?> Function(String value) onSave;

  const _StudioDescriptionEditorSheet({
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<_StudioDescriptionEditorSheet> createState() =>
      _StudioDescriptionEditorSheetState();
}

class _StudioDescriptionEditorSheetState
    extends State<_StudioDescriptionEditorSheet> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final errorMessage = await widget.onSave(_controller.text.trim());
    if (!mounted) return;
    if (errorMessage != null) {
      setState(() {
        _saving = false;
        _errorMessage = errorMessage;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Profil Açıklaması',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Stüdyonu ve sunduğun hizmetleri kısaca anlat.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                enabled: !_saving,
                autofocus: true,
                minLines: 4,
                maxLines: 7,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Kayıt, prova, ekipman ve atmosferini anlat...',
                  alignLabelWithHint: true,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientOutlineButton(
                      onPressed: _saving ? null : _save,
                      loading: _saving,
                      label: _saving ? 'Kaydediliyor...' : 'Kaydet',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioOwnerDashboardContent extends StatelessWidget {
  final StudioProfile profile;
  final String location;
  final int? followersCount;
  final int? followingCount;
  final bool photoUploading;
  final VoidCallback onBack;
  final VoidCallback? onMenu;
  final VoidCallback? onEditPhoto;
  final VoidCallback onEditDescription;
  final ValueChanged<ProfileSocialPlatform> onEditSocialLink;
  final int contentRevision;
  final VoidCallback onManagement;

  const _StudioOwnerDashboardContent({
    required this.profile,
    required this.location,
    required this.followersCount,
    required this.followingCount,
    required this.photoUploading,
    required this.onBack,
    required this.onMenu,
    required this.onEditPhoto,
    required this.onEditDescription,
    required this.onEditSocialLink,
    required this.contentRevision,
    required this.onManagement,
  });

  @override
  Widget build(BuildContext context) {
    final description = profile.description?.trim();
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
                      _StudioOwnerDescription(
                        description: description,
                        onEdit: onEditDescription,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StudioProfileMetrics(
            followersCount: followersCount,
            followingCount: followingCount,
            roomCount: profile.activeRoomCount,
            backlineCount: profile.backlineUnitCount,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StudioActionButton(
                  icon: Icons.dashboard_customize_outlined,
                  label: 'Yönetim Paneli',
                  outlined: true,
                  onTap: onManagement,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StudioOwnerTabs(
            profileId: profile.id,
            timeZone: profile.timeZone,
            contentRevision: contentRevision,
          ),
          const SizedBox(height: 18),
          ProfileSocialLinksRow(
            pillWidth: 74,
            items: studioSocialPlatforms
                .map(
                  (platform) => ProfileSocialLinkItem(
                    platform: platform,
                    url: socialUrlForStudioProfile(profile, platform),
                  ),
                )
                .toList(),
            editable: true,
            onAddLink: onEditSocialLink,
          ),
        ],
      ),
    );
  }
}

class _StudioOwnerDescription extends StatelessWidget {
  final String? description;
  final VoidCallback onEdit;

  const _StudioOwnerDescription({
    required this.description,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final value = description?.trim() ?? '';
    if (value.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onEdit,
          style: TextButton.styleFrom(
            foregroundColor: _roomFormIconColor,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'Açıklama ekle',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFC1C8D2),
              fontSize: 12,
              height: 1.42,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Açıklamayı düzenle',
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: Color(0xFF9FA9B8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudioProfileMetrics extends StatelessWidget {
  final int? followersCount;
  final int? followingCount;
  final int roomCount;
  final int backlineCount;

  const _StudioProfileMetrics({
    required this.followersCount,
    required this.followingCount,
    required this.roomCount,
    required this.backlineCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StudioMetricCard(
            icon: Icons.meeting_room_outlined,
            value: roomCount.toString(),
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
        Expanded(
          child: _StudioMetricCard(
            icon: Icons.settings_input_component_outlined,
            value: backlineCount.toString(),
            label: 'Backline',
          ),
        ),
      ],
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
                    border: Border.all(
                      color: const Color(0xFF050910),
                      width: 2,
                    ),
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
  final VoidCallback? onTap;

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
    return AnimatedOpacity(
      opacity: onTap == null ? 0.58 : 1,
      duration: const Duration(milliseconds: 160),
      child: child,
    );
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

class _StudioOwnerTabs extends StatelessWidget {
  final String profileId;
  final String timeZone;
  final int contentRevision;

  const _StudioOwnerTabs({
    required this.profileId,
    required this.timeZone,
    required this.contentRevision,
  });

  @override
  Widget build(BuildContext context) {
    return _StudioTabsFrame(
      profileId: profileId,
      canReserve: false,
      ownerMode: true,
      phone: null,
      timeZone: timeZone,
      contentRevision: contentRevision,
    );
  }
}

class _StudioTabsFrame extends StatelessWidget {
  final String profileId;
  final bool canReserve;
  final bool ownerMode;
  final String? phone;
  final String timeZone;
  final int contentRevision;

  const _StudioTabsFrame({
    required this.profileId,
    required this.canReserve,
    required this.ownerMode,
    required this.phone,
    required this.timeZone,
    required this.contentRevision,
  });

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
              children: [
                _StudioRoomsPanel(
                  profileId: profileId,
                  canReserve: canReserve,
                  ownerMode: ownerMode,
                  timeZone: timeZone,
                ),
                _StudioRecordingsPanel(
                  profileId: profileId,
                  ownerMode: ownerMode,
                  initialSpotifyTracks:
                      context
                          .watch<StudioProfileCubit>()
                          .state
                          .profile
                          ?.spotifyTracks ??
                      const <SpotifyTrackPreview>[],
                ),
                _StudioBacklinePanel(
                  profileId: profileId,
                  ownerMode: ownerMode,
                  phone: phone,
                  contentRevision: contentRevision,
                ),
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

const _maximumStudioRoomCount = 10;

class _StudioRoomsPanel extends StatefulWidget {
  final String profileId;
  final bool canReserve;
  final bool ownerMode;
  final String timeZone;

  const _StudioRoomsPanel({
    required this.profileId,
    required this.timeZone,
    this.canReserve = false,
    this.ownerMode = false,
  });

  @override
  State<_StudioRoomsPanel> createState() => _StudioRoomsPanelState();
}

class _StudioRoomsPanelState extends State<_StudioRoomsPanel> {
  final StudioRoomRepository _repository =
      serviceLocator<StudioRoomRepository>();
  List<_StudioRoomItem> _rooms = const [];
  bool _loading = true;
  String? _errorMessage;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void didUpdateWidget(covariant _StudioRoomsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.ownerMode != widget.ownerMode ||
        oldWidget.timeZone != widget.timeZone) {
      _loadRooms();
    }
  }

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Stüdyo Odaları',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _StudioRoomLimitPill(count: _rooms.length),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'Prova, kayıt ve vokal çalışmaları için uygun alanlar',
                  style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                _StudioRoomsErrorState(
                  message: _errorMessage!,
                  onRetry: _loadRooms,
                )
              else if (_rooms.isEmpty)
                _StudioRoomsEmptyState(
                  ownerMode: widget.ownerMode,
                  ownerTabMode: widget.ownerMode,
                  onCreateRoom: widget.ownerMode ? _createRoom : null,
                )
              else
                ..._rooms.map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StudioRoomCard(
                      room: room,
                      profileId: widget.profileId,
                      canReserve: widget.canReserve,
                      ownerMode: widget.ownerMode,
                      onRoomUpdated: (_) => _loadRooms(),
                      onRoomDeleted: _loadRooms,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadRooms() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    final result = widget.ownerMode
        ? await _repository.listOwnerRooms(size: _maximumStudioRoomCount)
        : await _repository.listPublicRooms(
            widget.profileId,
            size: _maximumStudioRoomCount,
          );
    if (!mounted || generation != _loadGeneration) return;
    final page = result.data;
    if (!result.isSuccess || page == null) {
      setState(() {
        _loading = false;
        _errorMessage = result.error?.message ?? 'Odalar getirilemedi.';
      });
      return;
    }
    setState(() {
      _rooms = page.items
          .map(
            (room) =>
                _StudioRoomItem.fromDomain(room, timeZone: widget.timeZone),
          )
          .toList(growable: false);
      _loading = false;
      _errorMessage = null;
    });
  }

  Future<void> _createRoom() async {
    if (_rooms.length >= _maximumStudioRoomCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En fazla 10 oda oluşturabilirsin.')),
      );
      return;
    }
    final room = await showModalBottomSheet<_StudioRoomItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewStudioRoomSheet(
        repository: _repository,
        studioProfileId: widget.profileId,
      ),
    );
    if (!mounted || room == null) return;
    await _loadRooms();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${room.name} oluşturuldu.')));
  }
}

class _StudioRoomsErrorState extends StatelessWidget {
  const _StudioRoomsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF9EA8B7)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB5BDCA), fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomLimitPill extends StatelessWidget {
  final int count;

  const _StudioRoomLimitPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Text(
        '$count / 10',
        style: const TextStyle(
          color: Color(0xFFB5BDCA),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StudioRoomCard extends StatelessWidget {
  final _StudioRoomItem room;
  final String profileId;
  final bool canReserve;
  final bool ownerMode;
  final ValueChanged<_StudioRoomItem>? onRoomUpdated;
  final VoidCallback? onRoomDeleted;

  const _StudioRoomCard({
    required this.room,
    required this.profileId,
    required this.canReserve,
    required this.ownerMode,
    this.onRoomUpdated,
    this.onRoomDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => ownerMode ? _openSettings(context) : _openRoom(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF101722),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF202B3A)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudioRoomPhoto(room: room),
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
                              room.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (ownerMode)
                            _StudioRoomReservationSummaryPill(
                              count: room.reservationCount,
                            )
                          else
                            _StudioRoomStatusPill(room: room),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (room.type.trim().isNotEmpty)
                        Text(
                          room.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFB5BDCA),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: _StudioRoomMeta(
                              icon: Icons.people_outline,
                              label: room.capacity,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StudioRoomMeta(
                              icon: Icons.payments_outlined,
                              label: room.price,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!ownerMode) ...[
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerLeft,
                child: _StudioRoomApprovalStatusPill(
                  approvalRequired: room.reservationApprovalRequired,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final feature in room.features)
                    _StudioRoomFeatureChip(label: feature),
                ],
              ),
            ),
            if (ownerMode) ...[
              const SizedBox(height: 10),
              _StudioRoomSettingsButton(onTap: () => _openSettings(context)),
            ] else if (canReserve) ...[
              const SizedBox(height: 10),
              _StudioActionButton(
                icon: Icons.event_available_outlined,
                label: 'Rezervasyon Yap',
                outlined: true,
                onTap: () => _openRoom(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openRoom(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StudioRoomDetailScreen(
          room: room,
          studioProfileId: profileId,
          canReserve: canReserve,
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final result = await Navigator.of(context).push<_StudioRoomSettingsResult>(
      MaterialPageRoute<_StudioRoomSettingsResult>(
        builder: (_) =>
            _StudioRoomSettingsScreen(room: room, studioProfileId: profileId),
      ),
    );
    if (result == null) return;
    if (result.deleted) {
      onRoomDeleted?.call();
      return;
    }
    final updatedRoom = result.updatedRoom;
    if (updatedRoom != null) onRoomUpdated?.call(updatedRoom);
  }
}

class _StudioRoomApprovalStatusPill extends StatelessWidget {
  const _StudioRoomApprovalStatusPill({required this.approvalRequired});

  final bool approvalRequired;

  @override
  Widget build(BuildContext context) {
    final color = approvalRequired
        ? const Color(0xFFE7B85C)
        : const Color(0xFF67D6A1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approvalRequired ? Icons.approval_outlined : Icons.bolt_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            approvalRequired ? 'Stüdyo onayı gerekir' : 'Anında rezervasyon',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomSettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StudioRoomSettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _StudioActionButton(
      icon: Icons.settings_outlined,
      label: 'Oda Ayarları',
      outlined: true,
      onTap: onTap,
    );
  }
}

class _StudioRoomPhoto extends StatelessWidget {
  final _StudioRoomItem room;

  const _StudioRoomPhoto({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 86,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: room.gradient,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2B3546)),
      ),
      child: Stack(
        children: [
          if (room.photoUrls.isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.network(
                  room.photoUrls.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (room.photoUrls.isNotEmpty)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          Positioned(
            right: -18,
            bottom: -20,
            child: Icon(
              room.icon,
              size: 78,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Icon(room.icon, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomStatusPill extends StatelessWidget {
  final _StudioRoomItem room;

  const _StudioRoomStatusPill({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: room.statusColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: room.statusColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        room.status,
        style: TextStyle(
          color: room.statusColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StudioRoomReservationSummaryPill extends StatelessWidget {
  final int count;

  const _StudioRoomReservationSummaryPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final hasReservations = count > 0;
    final color = hasReservations
        ? const Color(0xFF67D6A1)
        : const Color(0xFF9AA4B2);
    return Container(
      constraints: const BoxConstraints(maxWidth: 142),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasReservations
                ? Icons.event_available_outlined
                : Icons.event_busy_outlined,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              hasReservations ? '$count rezervasyon' : 'Henüz rezervasyon yok',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StudioRoomMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StudioSocialGradientIcon(icon, size: 14),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD5DBE5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudioRoomFeatureChip extends StatelessWidget {
  final String label;

  const _StudioRoomFeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFB5BDCA),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StudioRoomItem {
  final String id;
  final String studioProfileId;
  final int slotIndex;
  final String name;
  final String type;
  final int capacityCount;
  final int minimumCapacityCount;
  final int? hourlyPriceMinor;
  final String? currency;
  final String status;
  final Color statusColor;
  final IconData icon;
  final List<Color> gradient;
  final List<String> features;
  final List<StudioRoomPhoto> photos;
  final int reservationCount;
  final int reservedHours;
  final bool reservationApprovalRequired;
  final bool? pendingReservationApprovalRequired;
  final DateTime? reservationApprovalPolicyEffectiveAt;
  final DateTime todayLocalDate;
  final String timeZone;
  final int version;

  const _StudioRoomItem({
    required this.id,
    required this.studioProfileId,
    required this.slotIndex,
    required this.name,
    required this.type,
    required this.capacityCount,
    required this.minimumCapacityCount,
    required this.hourlyPriceMinor,
    required this.currency,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.gradient,
    required this.features,
    this.photos = const [],
    this.reservationCount = 0,
    this.reservedHours = 0,
    this.reservationApprovalRequired = true,
    this.pendingReservationApprovalRequired,
    this.reservationApprovalPolicyEffectiveAt,
    required this.todayLocalDate,
    required this.timeZone,
    required this.version,
  });

  factory _StudioRoomItem.fromDomain(
    StudioRoom room, {
    String timeZone = 'Europe/Istanbul',
  }) {
    final visual = _roomVisual(room.name, room.slotIndex);
    final (status, statusColor) = switch (room.todayAvailabilityStatus) {
      StudioRoomAvailabilityStatus.fullyBooked => (
        'Dolu',
        const Color(0xFFCF5E69),
      ),
      StudioRoomAvailabilityStatus.partiallyAvailable => (
        'Kısmen Müsait',
        const Color(0xFFB17400),
      ),
      StudioRoomAvailabilityStatus.available => (
        'Müsait',
        const Color(0xFF0E8F2F),
      ),
    };
    return _StudioRoomItem(
      id: room.id,
      studioProfileId: room.studioProfileId,
      slotIndex: room.slotIndex,
      name: room.name,
      type: room.shortDescription,
      capacityCount: room.capacity,
      minimumCapacityCount: room.minimumCapacity ?? room.capacity,
      hourlyPriceMinor: room.hourlyPriceMinor,
      currency: room.currency,
      status: status,
      statusColor: statusColor,
      icon: visual.$1,
      gradient: visual.$2,
      features: room.features,
      photos: room.photos,
      reservationCount: room.todayReservationCount,
      reservedHours: room.todayOccupiedHours,
      reservationApprovalRequired: room.reservationApprovalRequired,
      pendingReservationApprovalRequired:
          room.pendingReservationApprovalRequired,
      reservationApprovalPolicyEffectiveAt:
          room.reservationApprovalPolicyEffectiveAt,
      todayLocalDate: room.todayLocalDate,
      timeZone: timeZone,
      version: room.version,
    );
  }

  String get capacity => minimumCapacityCount == capacityCount
      ? '$capacityCount kişi'
      : '$minimumCapacityCount-$capacityCount kişi';

  String get price {
    final minor = hourlyPriceMinor;
    if (minor == null) return 'Fiyat belirtilmedi';
    final whole = minor ~/ 100;
    final fraction = minor.remainder(100);
    final grouped = whole.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final amount = fraction == 0
        ? grouped
        : '$grouped,${fraction.toString().padLeft(2, '0')}';
    final symbol = currency == 'TRY' || currency == null ? '₺' : '$currency ';
    return '$symbol$amount / saat';
  }

  List<String> get photoUrls => photos.map((photo) => photo.url).toList();

  List<String> get photoMediaIds => photos
      .map((photo) => photo.mediaAssetId?.trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  static (IconData, List<Color>) _roomVisual(String name, int slotIndex) {
    final normalized = name.toLowerCase();
    final icon = normalized.contains('kayıt') || normalized.contains('kayit')
        ? Icons.graphic_eq
        : normalized.contains('vokal') || normalized.contains('podcast')
        ? Icons.mic_none_outlined
        : normalized.contains('prova')
        ? Icons.groups_2_outlined
        : Icons.meeting_room_outlined;
    const gradients = <List<Color>>[
      [Color(0xFF1C2B3F), Color(0xFF4B2D52)],
      [Color(0xFF172A3A), Color(0xFF3B2747)],
      [Color(0xFF1E2538), Color(0xFF563040)],
    ];
    return (icon, gradients[slotIndex.abs() % gradients.length]);
  }
}

class _StudioBacklinePanel extends StatefulWidget {
  final String profileId;
  final bool ownerMode;
  final String? phone;
  final int contentRevision;

  const _StudioBacklinePanel({
    required this.profileId,
    required this.ownerMode,
    required this.phone,
    required this.contentRevision,
  });

  @override
  State<_StudioBacklinePanel> createState() => _StudioBacklinePanelState();
}

class _StudioBacklinePanelState extends State<_StudioBacklinePanel> {
  static const _pageSize = 20;
  late final StudioEquipmentRepository _repository;
  late final BacklineCatalogRepository _catalogRepository;
  List<_BacklineItem> _items = const [];
  List<_BacklineCategory> _categories = const [];
  String _selectedFilter = 'Tümü';
  String _searchQuery = '';
  int _pageIndex = 0;
  int _totalItems = 0;
  int _totalPages = 0;
  int _loadGeneration = 0;
  int _searchGeneration = 0;
  bool _isLoading = true;
  bool _isCatalogLoading = true;
  String? _error;
  String? _catalogError;

  @override
  void initState() {
    super.initState();
    _repository = serviceLocator<StudioEquipmentRepository>();
    _catalogRepository = serviceLocator<BacklineCatalogRepository>();
    _loadCatalog();
    _loadPage(0);
  }

  @override
  void didUpdateWidget(covariant _StudioBacklinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.ownerMode != widget.ownerMode ||
        oldWidget.contentRevision != widget.contentRevision) {
      _loadPage(oldWidget.profileId == widget.profileId ? _pageIndex : 0);
    }
  }

  int get _pageTotal => _items.fold(0, (sum, item) => sum + item.total);
  int get _pageAvailable => _items.fold(0, (sum, item) => sum + item.available);
  int get _pageMaintenance =>
      _items.fold(0, (sum, item) => sum + item.maintenance);

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
              Row(
                children: [
                  Expanded(
                    child: _BacklineSummary(
                      icon: Icons.inventory_2_outlined,
                      value: _pageTotal.toString(),
                      label: 'Bu Sayfa',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BacklineSummary(
                      icon: Icons.check_circle_outline,
                      value: _pageAvailable.toString(),
                      label: 'Müsait',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BacklineSummary(
                      icon: Icons.build_outlined,
                      value: _pageMaintenance.toString(),
                      label: 'Bakımda',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BacklineFilters(
                selectedFilter: _selectedFilter,
                onChanged: (value) {
                  if (value == _selectedFilter) return;
                  if (value != 'Tümü' && _categories.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _catalogError ??
                              (_isCatalogLoading
                                  ? 'Kategoriler yükleniyor.'
                                  : 'Kategori filtresi kullanılamıyor.'),
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _selectedFilter = value);
                  _loadPage(0);
                },
              ),
              const SizedBox(height: 10),
              _BacklineSearch(onChanged: _onSearchChanged),
              const SizedBox(height: 10),
              if (_isLoading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && _items.isEmpty)
                _StudioOwnerBacklineErrorState(
                  message: _error!,
                  onRetry: () => _loadPage(_pageIndex),
                )
              else if (_items.isEmpty)
                const _BacklineSearchEmptyState()
              else
                ..._items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BacklineItemCard(
                      item: item,
                      ownerMode: widget.ownerMode,
                      phone: widget.phone,
                      onReturn: widget.ownerMode
                          ? () => _loadPage(_pageIndex)
                          : null,
                    ),
                  ),
                ),
              if (_isLoading && _items.isNotEmpty)
                const LinearProgressIndicator(minHeight: 2),
              if (_totalPages > 1) ...[
                const SizedBox(height: 8),
                _StudioOwnerBacklinePagination(
                  pageIndex: _pageIndex,
                  totalPages: _totalPages,
                  enabled: !_isLoading,
                  onPrevious: _pageIndex > 0
                      ? () => _loadPage(_pageIndex - 1)
                      : null,
                  onNext: _pageIndex + 1 < _totalPages
                      ? () => _loadPage(_pageIndex + 1)
                      : null,
                ),
              ],
              if (_totalItems > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Toplam $_totalItems ekipman kaydı',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7F8998),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    final generation = ++_searchGeneration;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || generation != _searchGeneration) return;
      _loadPage(0);
    });
  }

  Future<void> _loadCatalog() async {
    final result = await _loadCompleteBacklineCatalog(_catalogRepository);
    if (!mounted) return;
    if (result.$1 == null) {
      setState(() {
        _isCatalogLoading = false;
        _catalogError = result.$2 ?? 'Kategoriler yüklenemedi.';
      });
      return;
    }
    setState(() {
      _categories = result.$1!;
      _isCatalogLoading = false;
      _catalogError = null;
    });
    if (_selectedFilter != 'Tümü') await _loadPage(0);
  }

  Future<void> _loadPage(int page) async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
      _items = const [];
    });
    final selectedCategoryId = _selectedCategoryId;
    final result = widget.ownerMode
        ? await _repository.listOwnerEquipment(
            query: _searchQuery,
            categoryId: selectedCategoryId,
            page: page,
            size: _pageSize,
          )
        : await _repository.listPublicEquipment(
            studioProfileId: widget.profileId,
            query: _searchQuery,
            categoryId: selectedCategoryId,
            page: page,
            size: _pageSize,
          );
    if (!mounted || generation != _loadGeneration) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _isLoading = false;
        _error = result.error?.message ?? 'Backline envanteri yüklenemedi.';
      });
      return;
    }
    setState(() {
      _items = result.data!.items
          .map(
            (equipment) => _BacklineItem.fromDomain(
              equipment,
              studioProfileId: widget.profileId,
            ),
          )
          .toList(growable: false);
      _pageIndex = result.data!.pageIndex;
      _totalItems = result.data!.totalItems;
      _totalPages = result.data!.totalPages;
      _isLoading = false;
      _error = null;
    });
  }

  String? get _selectedCategoryId {
    if (_selectedFilter == 'Tümü') return null;
    final selectedName = switch (_selectedFilter) {
      'Bas Amfileri' => 'Bas Gitar Amfileri',
      'Piyano & Klavye' => 'Piyano, Klavye & Synth',
      _ => _selectedFilter,
    };
    for (final category in _categories) {
      if (category.name == selectedName) return category.id;
      for (final child in category.children) {
        if (child == selectedName) return category.childId(child);
      }
    }
    return null;
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

class _BacklineFilters extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onChanged;

  const _BacklineFilters({
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filters = _backlineQuickFilters;
    final hasCustomSelection = !filters.contains(selectedFilter);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < filters.length; i++) ...[
            _BacklineFilterChip(
              label: filters[i],
              selected: selectedFilter == filters[i],
              onTap: () => onChanged(filters[i]),
            ),
            const SizedBox(width: 8),
          ],
          _BacklineFilterChip(
            label: hasCustomSelection ? selectedFilter : 'Tüm Kategoriler',
            selected: hasCustomSelection,
            trailingIcon: Icons.chevron_right,
            onTap: () async {
              final selected = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const _BacklineCategoriesScreen(),
                ),
              );
              if (selected == null) return;
              onChanged(selected);
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
          border: selected ? null : Border.all(color: const Color(0xFF263244)),
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
                Icon(trailingIcon, color: const Color(0xFFB5BDCA), size: 15),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BacklineSearch extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _BacklineSearch({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Ekipman ara...',
          prefixIcon: Icon(Icons.search, size: 18),
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _BacklineSearchEmptyState extends StatelessWidget {
  const _BacklineSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: Color(0xFF8C95A3), size: 28),
          SizedBox(height: 8),
          Text(
            'Eşleşen ekipman bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB5BDCA),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineItem {
  final String id;
  final String studioProfileId;
  final String title;
  final String type;
  final String subcategory;
  final String model;
  final String description;
  final List<String> features;
  final List<String> photoUrls;
  final String status;
  final Color statusColor;
  final IconData icon;
  final int total;
  final int available;
  final int busy;
  final int maintenance;
  final DateTime referenceDate;

  const _BacklineItem({
    required this.id,
    required this.studioProfileId,
    required this.title,
    required this.type,
    required this.subcategory,
    required this.model,
    required this.description,
    required this.features,
    required this.photoUrls,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.total,
    required this.available,
    required this.busy,
    required this.maintenance,
    required this.referenceDate,
  });

  factory _BacklineItem.fromDomain(
    StudioEquipment equipment, {
    required String studioProfileId,
  }) {
    final availability = equipment.todayAvailability;
    final status = switch (availability.status) {
      StudioEquipmentAvailabilityStatus.available => 'Müsait',
      StudioEquipmentAvailabilityStatus.partiallyAvailable => 'Kısmen Müsait',
      StudioEquipmentAvailabilityStatus.busy => 'Dolu',
      StudioEquipmentAvailabilityStatus.maintenance => 'Bakımda',
      StudioEquipmentAvailabilityStatus.mixedUnavailable => 'Müsait Değil',
      StudioEquipmentAvailabilityStatus.unknown =>
        availability.availableQuantity > 0 ? 'Kısmen Müsait' : 'Müsait Değil',
    };
    final brand = equipment.brand?.trim() ?? '';
    final model = equipment.model?.trim() ?? '';
    return _BacklineItem(
      id: equipment.id,
      studioProfileId: studioProfileId,
      title: equipment.name,
      type: equipment.categoryName,
      subcategory: equipment.subcategoryName,
      model: [
        if (brand.isNotEmpty) brand,
        if (model.isNotEmpty) model,
      ].join(' • '),
      description: equipment.description?.trim() ?? '',
      features: equipment.features,
      photoUrls: equipment.photos.map((photo) => photo.url).toList(),
      status: status,
      statusColor: _availabilityColor(
        availability.availableQuantity,
        availability.totalQuantity,
        maintenanceCount: availability.maintenanceQuantity,
      ),
      icon: _backlineIconFor(
        code: equipment.categoryCode,
        iconKey: equipment.categoryIconKey,
        name: equipment.categoryName,
      ),
      total: availability.totalQuantity,
      available: availability.availableQuantity,
      busy: availability.busyQuantity,
      maintenance: availability.maintenanceQuantity,
      referenceDate: availability.date,
    );
  }
}

class _BacklineItemCard extends StatelessWidget {
  final _BacklineItem item;
  final bool ownerMode;
  final String? phone;
  final VoidCallback? onReturn;

  const _BacklineItemCard({
    required this.item,
    required this.ownerMode,
    required this.phone,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => _BacklineItemDetailScreen(
              item: item,
              ownerMode: ownerMode,
              phone: phone,
            ),
          ),
        );
        onReturn?.call();
      },
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
              clipBehavior: Clip.antiAlias,
              child: item.photoUrls.isNotEmpty
                  ? Image.network(
                      item.photoUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        item.icon,
                        color: const Color(0xFFD4D9E2),
                        size: 34,
                      ),
                    )
                  : Icon(item.icon, color: const Color(0xFFD4D9E2), size: 34),
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
                      _BacklineStatus(
                        label: item.status,
                        color: item.statusColor,
                      ),
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
            const Icon(Icons.chevron_right, color: Color(0xFF7B8493), size: 20),
          ],
        ),
      ),
    );
  }
}

class _BacklineItemDetailScreen extends StatelessWidget {
  final _BacklineItem item;
  final bool ownerMode;
  final String? phone;
  final GlobalKey _calendarKey = GlobalKey();

  _BacklineItemDetailScreen({
    required this.item,
    required this.ownerMode,
    required this.phone,
  });

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
              _BacklineDetailInfoCard(item: item),
              const SizedBox(height: 18),
              _BacklineDetailGradientButton(
                icon: ownerMode
                    ? Icons.edit_calendar_outlined
                    : Icons.phone_outlined,
                label: ownerMode
                    ? 'Müsaitlik Takvimini Güncelle'
                    : 'Stüdyoyu Ara',
                filled: true,
                onTap: ownerMode
                    ? () => _scrollToCalendar(context)
                    : () => _callStudio(context),
              ),
              const SizedBox(height: 18),
              KeyedSubtree(
                key: _calendarKey,
                child: _BacklineAvailabilityCalendar(
                  item: item,
                  editable: ownerMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scrollToCalendar(BuildContext context) async {
    final calendarContext = _calendarKey.currentContext;
    if (calendarContext == null) return;
    await Scrollable.ensureVisible(
      calendarContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _callStudio(BuildContext context) async {
    final value = phone?.trim();
    if (value == null || value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stüdyonun telefon bilgisi bulunmuyor.')),
      );
      return;
    }
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: value),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon uygulaması açılamadı.')),
      );
    }
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
  final _pageController = PageController();
  int _activePage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.item.photoUrls.isEmpty
        ? 1
        : widget.item.photoUrls.length;
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: (index) => setState(() => _activePage = index),
            itemBuilder: (context, index) {
              return _BacklineDetailHeroImage(item: widget.item, index: index);
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pageCount,
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
    final hasPhoto = index < item.photoUrls.length;
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
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  item.photoUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _BacklineDetailPhotoPlaceholder(item: item),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC070B12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${index + 1}/${item.photoUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _BacklineDetailPhotoPlaceholder(item: item),
    );
  }
}

class _BacklineDetailPhotoPlaceholder extends StatelessWidget {
  final _BacklineItem item;

  const _BacklineDetailPhotoPlaceholder({required this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
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
          ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Row(
        children: [
          _BacklineCountCell(
            label: 'Toplam Adet',
            value: item.total.toString(),
          ),
          _BacklineCountDivider(),
          _BacklineCountCell(
            label: 'M\u00FCsait',
            value: item.available.toString(),
            color: const Color(0xFF15C46B),
          ),
          _BacklineCountDivider(),
          _BacklineCountCell(
            label: 'Dolu',
            value: item.busy.toString(),
            color: const Color(0xFFFFA000),
          ),
          _BacklineCountDivider(),
          _BacklineCountCell(
            label: 'Bak\u0131mda',
            value: item.maintenance.toString(),
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
  final _BacklineItem item;

  const _BacklineDetailInfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.model.isNotEmpty)
            _BacklineInfoRow(
              icon: Icons.label_outline_rounded,
              label: 'Marka / Model',
              value: item.model,
            ),
          _BacklineInfoRow(
            icon: Icons.account_tree_outlined,
            label: 'Alt Kategori',
            value: item.subcategory,
            last: item.description.isEmpty && item.features.isEmpty,
          ),
          if (item.description.isNotEmpty)
            _BacklineInfoRow(
              icon: Icons.notes_outlined,
              label: 'A\u00E7\u0131klama',
              value: item.description,
              last: item.features.isEmpty,
            ),
          if (item.features.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                'Teknik Özellikler',
                style: TextStyle(
                  color: Color(0xFFB5BDCA),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final feature in item.features)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(feature),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _BacklineAvailabilityCalendar extends StatefulWidget {
  final _BacklineItem item;
  final bool editable;

  const _BacklineAvailabilityCalendar({
    required this.item,
    required this.editable,
  });

  @override
  State<_BacklineAvailabilityCalendar> createState() =>
      _BacklineAvailabilityCalendarState();
}

class _BacklineAvailabilityCalendarState
    extends State<_BacklineAvailabilityCalendar> {
  @override
  Widget build(BuildContext context) {
    return _BacklineDateAvailabilityCalendar(
      repository: serviceLocator<StudioEquipmentRepository>(),
      equipmentId: widget.item.id,
      studioProfileId: widget.item.studioProfileId,
      referenceDate: widget.item.referenceDate,
      equipmentName: widget.item.title,
      total: widget.item.total,
      initiallyAvailable: widget.item.available,
      initiallyMaintenance: widget.item.maintenance,
      editable: widget.editable,
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
              color: selected
                  ? const Color(0xFFFF8A8A)
                  : const Color(0xFFCDD3DE),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
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
        const _CalendarRatioLegendItem(),
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

class _CalendarRatioLegendItem extends StatelessWidget {
  const _CalendarRatioLegendItem();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              colors: [Color(0xFFD85B47), Color(0xFFF59E0B), Color(0xFF1EAF4D)],
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Kısmen Müsait',
          style: TextStyle(color: Color(0xFFCDD3DE), fontSize: 12),
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
                icon: Icons.meeting_room_outlined,
                title: 'Odalar',
                message: 'Mevcut odaları yönet ve yeni oda oluştur.',
                trailingLabel: 'Yönet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _StudioRoomsManagementScreen(
                      studioProfileId: profile.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.event_available_outlined,
                title: 'Rezervasyon Yönetimi',
                message: 'Tüm odaların rezervasyonlarını yönet.',
                trailingLabel: 'Yönet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _StudioReservationsHubScreen(
                      studioProfileId: profile.id,
                      timeZone: profile.timeZone,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.inventory_2_outlined,
                title: 'Envanter Yönetimi',
                message: 'Backline ekipmanlarını ekle, düzenle veya kaldır.',
                trailingLabel: 'Yönet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _StudioBacklineInventoryScreen(
                      studioProfileId: profile.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.event_available_outlined,
                title: 'Ekipman Takvimi',
                message: 'Ekipmanların dolu ve bakımda olduğu tarihleri yönet.',
                trailingLabel: 'Yönet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const _BacklineAvailabilityManagementScreen(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
                ),
              ),
              _StudioManagementActionCard(
                icon: Icons.add_circle_outline_rounded,
                title: 'Kategori Talep Et',
                message: 'Yeni bir backline kategorisi veya alt kategori öner.',
                trailingLabel: 'Talep Et',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const _StudioBacklineCategoryManagementScreen(),
                  ),
                ),
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
