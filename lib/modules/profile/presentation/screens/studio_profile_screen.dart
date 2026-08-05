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
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_border_action_button.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';
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
import '../../../studio/domain/studio_civil_date.dart';
import '../../../studio/domain/studio_equipment_repository.dart';
import '../../../studio/domain/studio_room_repository.dart';
import '../../domain/entities/studio_profile.dart';
import '../../domain/profile_contact_uri.dart';
import '../../domain/entities/track.dart';
import '../../domain/studio_profile_repository.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/studio_profile_cubit.dart';
import '../cubit/studio_profile_state.dart';
import 'profile_audio_tab_shared.dart';
import 'profile_public_bottom_bar.dart';
import 'profile_route_args.dart';
import 'profile_screen_support.dart';
import 'profile_social_support.dart';
import 'studio_profile_website_link.dart';
import 'studio_room_photo_order_controls.dart';

part 'studio_profile_backline_taxonomy.dart';
part 'studio_owner_backline_management.dart';
part 'studio_owner_backline_inventory_support.dart';
part 'studio_owner_backline_inventory_editor.dart';
part 'studio_owner_backline_photo_editor.dart';
part 'studio_owner_backline_inventory_widgets.dart';
part 'studio_owner_backline_category_screen.dart';
part 'studio_owner_backline_category_request.dart';
part 'studio_owner_backline_inventory_item_management.dart';
part 'studio_owner_backline_availability_management.dart';
part 'studio_owner_backline_availability_components.dart';
part 'studio_owner_rooms_management.dart';
part 'studio_owner_room_settings.dart';
part 'studio_owner_room_settings_components.dart';
part 'studio_owner_reservations_hub.dart';
part 'studio_profile_contact_editor.dart';
part 'studio_profile_owner_dashboard_widgets.dart';
part 'studio_profile_rooms_panel.dart';
part 'studio_profile_backline_panel.dart';
part 'studio_profile_backline_detail.dart';
part 'studio_management_panel.dart';
part 'studio_public_profile_content.dart';
part 'studio_profile_room_detail.dart';
part 'studio_profile_room_detail_view.dart';
part 'studio_profile_room_detail_actions.dart';
part 'studio_profile_room_detail_data.dart';
part 'studio_profile_room_detail_dialogs.dart';
part 'studio_profile_room_detail_reservation_widgets.dart';
part 'studio_profile_room_detail_sheet_widgets.dart';
part 'studio_profile_recordings.dart';

class StudioProfileScreenArgs {
  const StudioProfileScreenArgs({this.openContactEditor = false});

  final bool openContactEditor;
}

class StudioProfileScreen extends StatelessWidget {
  const StudioProfileScreen({this.openContactEditor = false, super.key});

  final bool openContactEditor;

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
      child: _StudioProfileView(
        isPublic: false,
        openContactEditor: openContactEditor,
      ),
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
      child: const _StudioProfileView(isPublic: true, openContactEditor: false),
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
  int _loadGeneration = 0;

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
    final generation = ++_loadGeneration;
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
    if (!mounted || generation != _loadGeneration) return;
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
  final bool openContactEditor;

  const _StudioProfileView({
    required this.isPublic,
    required this.openContactEditor,
  });

  @override
  State<_StudioProfileView> createState() => _StudioProfileViewState();
}

class _StudioProfileViewState extends State<_StudioProfileView> {
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  final _imagePicker = ImagePicker();
  String? _targetProfileId;
  String? _viewerUserId;
  bool _viewerResolved = false;
  bool _photoUploading = false;
  bool _contactEditorScheduled = false;
  int _contentRevision = 0;

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

  Future<void> _refresh() async {
    final profileCubit = context.read<StudioProfileCubit>();
    if (widget.isPublic) {
      final id = _targetProfileId?.trim() ?? '';
      if (id.isNotEmpty) await profileCubit.loadPublicProfile(id);
    } else {
      await profileCubit.loadMyProfile();
    }
    if (!mounted) return;

    final profile = profileCubit.state.profile;
    if (profile != null) {
      final refreshes = <Future<void>>[
        context.read<ProfileMediaCubit>().loadMedia(
          profileType: ProfileMediaOwnerType.studio.apiValue,
          profileId: profile.id,
        ),
        context.read<FollowCountCubit>().loadCounts(profile.userId),
      ];
      final viewerUserId = (_viewerUserId ?? '').trim();
      if (widget.isPublic &&
          viewerUserId.isNotEmpty &&
          viewerUserId != profile.userId) {
        refreshes.add(
          context.read<FollowActionCubit>().loadStatus(
            followerId: viewerUserId,
            followingId: profile.userId,
          ),
        );
      }
      await Future.wait(refreshes);
    }
    if (mounted) setState(() => _contentRevision++);
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
      // The upload pipeline already attaches the media through the Studio
      // profile endpoint, which advances the optimistic version. Reload the
      // authoritative profile instead of issuing a stale duplicate update.
      await profileCubit.loadMyProfile();
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      state.error?.message ??
                          (widget.isPublic &&
                                  (_targetProfileId?.trim().isEmpty ?? true)
                              ? 'Stüdyo profil bağlantısı geçersiz.'
                              : 'Stüdyo profili bulunamadı.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed:
                          widget.isPublic &&
                              (_targetProfileId?.trim().isEmpty ?? true)
                          ? null
                          : _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!widget.isPublic &&
            widget.openContactEditor &&
            !_contactEditorScheduled) {
          _contactEditorScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showProfileContactEditor();
          });
        }
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

  PreferredSizeWidget _appBar() {
    return AppBar(
      leading: const BackButton(),
      title: GradientText(
        text: 'SoundConnect',
        gradient: LinearGradient(colors: AppColors.brandGradient),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
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
    return address == null || address.isEmpty ? 'Konum belirtilmedi' : address;
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
      allowRemoval: true,
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

  void _showManagementProfileUnavailable(
    BuildContext context,
    StudioProfileCubit profileCubit,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profil henüz yüklenemedi; tekrar dene.'),
        action: SnackBarAction(
          label: 'Tekrar Dene',
          onPressed: () async {
            if (!profileCubit.isClosed) await profileCubit.loadMyProfile();
          },
        ),
      ),
    );
  }

  Future<void> _openManagementPanel(BuildContext context) async {
    final profileCubit = context.read<StudioProfileCubit>();
    final profile = profileCubit.state.profile;
    if (profile == null) {
      _showManagementProfileUnavailable(context, profileCubit);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StudioManagementPanelScreen(profile: profile),
      ),
    );
    if (!mounted) return;
    await profileCubit.loadMyProfile();
    if (mounted) setState(() => _contentRevision++);
  }

  Future<void> _showOwnerQuickMenu(BuildContext context) async {
    await showProfileQuickMenu(
      context,
      settingsTileKey: const Key('studio-account-settings'),
      profileContactTileKey: const Key('studio-profile-contact-editor'),
      onSettings: () async {
        await Navigator.of(context).pushNamed(AppRoutes.settings);
        if (!context.mounted) return;
        await context.read<StudioProfileCubit>().loadMyProfile();
      },
      onProfileContact: _showProfileContactEditor,
      onManagement: () => _openManagementPanel(context),
    );
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
                maxLength: 1024,
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
