import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/profile_brand_title.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';
import '../../domain/entities/listener_profile.dart';
import '../../domain/entities/listener_visibility_mode.dart';
import '../../../event_audience/presentation/event_audience_controller.dart';
import '../../../event_audience/presentation/event_audience_profile_draft.dart';
import '../cubit/listener_profile_cubit.dart';
import '../cubit/listener_profile_state.dart';
import '../listener_visibility_error_message.dart';
import 'listener_ghost_profile_content.dart';
import 'listener_event_posts.dart';
import 'listener_event_draft_composer.dart';
import 'listener_playlist_manager_sheet.dart';
import 'listener_profile_owner_content.dart';
import 'listener_profile_preview_data.dart';
import 'listener_profile_theme.dart';
import 'profile_public_bottom_bar.dart';
import 'profile_screen_support.dart';
import 'spotify_playlist_launcher.dart';

class ListenerProfileScreen extends StatelessWidget {
  const ListenerProfileScreen({
    super.key,
    this.cubitFactory,
    this.showBottomNavigation = true,
    this.eventDraft,
  });

  final ListenerProfileCubit Function()? cubitFactory;
  final bool showBottomNavigation;
  final EventAudienceProfileDraftArgs? eventDraft;

  @override
  Widget build(BuildContext context) {
    return ListenerProfileTheme(
      child: BlocProvider(
        create: (_) =>
            (cubitFactory?.call() ?? serviceLocator<ListenerProfileCubit>())
              ..loadMyProfile(),
        child: _ListenerProfileView(
          showBottomNavigation: showBottomNavigation,
          eventDraft: eventDraft,
        ),
      ),
    );
  }
}

class _ListenerProfileView extends StatefulWidget {
  const _ListenerProfileView({
    required this.showBottomNavigation,
    this.eventDraft,
  });

  final bool showBottomNavigation;
  final EventAudienceProfileDraftArgs? eventDraft;

  @override
  State<_ListenerProfileView> createState() => _ListenerProfileViewState();
}

class _ListenerProfileViewState extends State<_ListenerProfileView> {
  final _eventPostsRefresh = ValueNotifier<int>(0);
  bool _avatarBusy = false;
  bool _choiceRecoveryInFlight = false;
  String? _choiceRecoveryError;
  final _profileScroll = ScrollController();
  final _draftKey = GlobalKey<ListenerEventDraftComposerState>();
  EventAudienceProfileDraftArgs? _activeDraft;
  AuthSessionManager? _draftSessions;
  bool _revealingDraft = false;
  bool _draftRevealed = false;
  bool _allowPop = false;
  bool _leavingDraft = false;

  @override
  void initState() {
    super.initState();
    _activeDraft = widget.eventDraft;
    if (_activeDraft != null &&
        serviceLocator.isRegistered<AuthSessionManager>()) {
      _draftSessions = serviceLocator<AuthSessionManager>();
      _draftSessions!.addListener(_draftSessionChanged);
    }
  }

  void _draftSessionChanged() {
    final draft = _activeDraft;
    final current = _draftSessions?.session;
    if (draft != null &&
        (current == null ||
            !canPublishAudienceProfile(current) ||
            !sameEventAudienceSession(current, draft.expectedSession))) {
      _draftKey.currentState?.invalidate();
      if (mounted) setState(() => _activeDraft = null);
    }
  }

  bool _draftAllowed(ListenerProfile profile) {
    final draft = _activeDraft;
    final current = _draftSessions?.session;
    return draft != null &&
        current != null &&
        canPublishAudienceProfile(current) &&
        sameEventAudienceSession(current, draft.expectedSession) &&
        profile.userId == current.userId &&
        profile.visibilityChoiceCompleted &&
        !profile.isGhost &&
        profile.profileContentVisible &&
        profile.profileContentEditable;
  }

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  void _finishDraft(bool published) {
    if (!mounted) return;
    setState(() => _activeDraft = null);
    if (published) _eventPostsRefresh.value++;
  }

  Future<bool> _beforeLeavingDraft() async {
    final route = ModalRoute.of(context);
    final draft = _activeDraft;
    if (_leavingDraft || !mounted || route?.isCurrent != true) return false;
    _leavingDraft = true;
    try {
      final allowed =
          await (_draftKey.currentState?.canLeave() ?? Future.value(true));
      if (!allowed ||
          !mounted ||
          route?.isCurrent != true ||
          !identical(draft, _activeDraft)) {
        return false;
      }
      final profile = context.read<ListenerProfileCubit>().state.profile;
      if (draft != null && (profile == null || !_draftAllowed(profile))) {
        return false;
      }
      if (_activeDraft != null) setState(() => _activeDraft = null);
      return true;
    } finally {
      _leavingDraft = false;
    }
  }

  Future<void> _backFromDraft() async {
    if (!await _beforeLeavingDraft() || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).maybePop();
      }
    });
  }

  void _revealDraft() {
    if (_activeDraft == null || _draftRevealed || _revealingDraft) return;
    _revealingDraft = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // ListView lazily mounts the posts section. First bring that child
        // into the viewport, then align the actual composer rather than a
        // guessed pixel offset based on avatar/bio/playlist height.
        for (
          var attempt = 0;
          attempt < 5 && mounted && _activeDraft != null;
          attempt++
        ) {
          final target = _draftKey.currentContext;
          if (target != null && target.mounted) {
            final readyBeforeScroll =
                _draftKey.currentState?.readyForReveal == true;
            await Scrollable.ensureVisible(
              target,
              alignment: .04,
              duration: const Duration(milliseconds: 220),
            );
            _draftRevealed = readyBeforeScroll;
            return;
          }
          if (!_profileScroll.hasClients) return;
          _profileScroll.jumpTo(_profileScroll.position.maxScrollExtent);
          await WidgetsBinding.instance.endOfFrame;
        }
      } finally {
        _revealingDraft = false;
        if (mounted &&
            !_draftRevealed &&
            _activeDraft != null &&
            _draftKey.currentState?.readyForReveal == true) {
          _revealDraft();
        }
      }
    });
  }

  @override
  void dispose() {
    _draftSessions?.removeListener(_draftSessionChanged);
    _profileScroll.dispose();
    _eventPostsRefresh.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    if (_draftKey.currentState?.saving == true) return;
    await context.read<ListenerProfileCubit>().loadMyProfile();
    if (mounted) _eventPostsRefresh.value++;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ListenerProfileCubit, ListenerProfileState>(
      listenWhen: (previous, current) =>
          (current.status == ListenerProfileStatus.failure &&
              (previous.status != current.status ||
                  previous.error?.code != current.error?.code)) ||
          (current.status == ListenerProfileStatus.success &&
              current.action == ListenerProfileAction.load &&
              current.profile?.visibilityChoiceCompleted == false &&
              (previous.profile?.visibilityChoiceCompleted != false ||
                  previous.status != current.status)),
      listener: (context, state) {
        final profile = state.profile;
        if (state.status == ListenerProfileStatus.success &&
            state.action == ListenerProfileAction.load &&
            profile?.visibilityChoiceCompleted == false) {
          unawaited(_recoverIncompleteChoice());
          return;
        }
        if (state.profile == null &&
            state.action == ListenerProfileAction.load) {
          return;
        }
        final message = state.action == ListenerProfileAction.updateVisibility
            ? listenerVisibilityErrorMessage(state.error)
            : state.error?.message.trim() ?? '';
        if (message.isEmpty) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            appSnackBar(
              context,
              tone: AppSnackBarTone.error,
              content: Text(message),
            ),
          );
      },
      builder: (context, state) {
        final profile = state.profile;
        // Resolve projection changes before computing PopScope and busy flags.
        // Otherwise a removed ghost/restricted draft can leave an obsolete
        // canPop:false scope with no draft callback able to release it.
        if (profile != null &&
            _activeDraft != null &&
            !_draftAllowed(profile)) {
          _activeDraft = null;
        }
        final avatarUrl = profile?.profilePictureUrl?.trim();
        final showRefreshProgress =
            profile != null && state.status == ListenerProfileStatus.loading;

        return PopScope(
          canPop: _allowPop || _activeDraft == null,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _activeDraft != null) unawaited(_backFromDraft());
          },
          child: Scaffold(
            appBar: _listenerOwnerAppBar(
              context,
              onSettings: _openSettings,
              onBeforeMenu: _beforeLeavingDraft,
            ),
            body: Stack(
              children: [
                Positioned.fill(child: _buildBody(context, state)),
                if (showRefreshProgress)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
            bottomNavigationBar: widget.showBottomNavigation
                ? ProfilePublicBottomBar(
                    currentIndex: 4,
                    profileImageUrl: isValidNetworkImageUrl(avatarUrl)
                        ? avatarUrl
                        : null,
                    stageMode: StageMode.mainstage,
                    onBeforeNavigate: _beforeLeavingDraft,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ListenerProfileState state) {
    final profile = state.profile;
    if (profile == null) {
      if (state.status == ListenerProfileStatus.failure) {
        return _ListenerLoadFailure(
          message: state.error?.message,
          onRetry: () => context.read<ListenerProfileCubit>().loadMyProfile(),
        );
      }
      return const _ListenerInitialLoading();
    }

    if (!profile.visibilityChoiceCompleted) {
      final recoveryError = _choiceRecoveryError;
      if (recoveryError != null) {
        return _ListenerLoadFailure(
          message: recoveryError,
          onRetry: _recoverIncompleteChoice,
        );
      }
      return const _ListenerInitialLoading();
    }

    final actionBusy =
        _avatarBusy ||
        state.status == ListenerProfileStatus.saving ||
        _activeDraft != null;
    if (profile.isGhost) {
      return ListenerGhostProfileContent(
        username: profile.username ?? '',
        profilePictureUrl: profile.profilePictureUrl,
        owner: true,
        busy: actionBusy,
        onRefresh: _refreshProfile,
        onEditAvatar: profile.avatarEditable
            ? () => _openAvatarActions(profile)
            : null,
        onSwitchToStandard: () => unawaited(_confirmStandardMode()),
        privatePlansAction: ListenerEventPlansButton(
          listenerProfileId: profile.id,
          userId: profile.userId,
          username: profile.username ?? '',
          avatarUrl: profile.profilePictureUrl,
        ),
      );
    }

    _revealDraft();
    return RefreshIndicator(
      onRefresh: _refreshProfile,
      child: ListenerProfileOwnerContent(
        profile: profile,
        scrollController: _profileScroll,
        previewData: listenerOwnerPreviewData,
        showPreviewSections: true,
        actionBusy: actionBusy,
        onEditProfile: () => unawaited(_openSettings()),
        onEditAvatar: () => _openAvatarActions(profile),
        onEditPlaylists: () => unawaited(_openPlaylistManager(profile)),
        onPlaylistTap: (playlist) async {
          if (!await _beforeLeavingDraft() || !context.mounted) return;
          await launchSpotifyPlaylist(context, playlist.spotifyUrl);
        },
        onPreviewAction: _showUnavailableMessage,
        eventPlansAction: _activeDraft != null
            ? null
            : ListenerEventPlansButton(
                listenerProfileId: profile.id,
                userId: profile.userId,
                username: profile.username ?? '',
                avatarUrl: profile.profilePictureUrl,
              ),
        eventPosts: _activeDraft != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ListenerEventDraftComposer(
                  key: _draftKey,
                  draft: _activeDraft!,
                  profile: profile,
                  onFinished: _finishDraft,
                  onStateChanged: _draftChanged,
                ),
              )
            : ListenerEventPostsSection(
                key: ValueKey('listener-owner-event-posts-${profile.id}'),
                listenerProfileId: profile.id,
                ownerUserId: profile.userId,
                username: profile.username ?? '',
                avatarUrl: profile.profilePictureUrl,
                refreshSignal: _eventPostsRefresh,
              ),
      ),
    );
  }

  Future<void> _recoverIncompleteChoice() async {
    if (_choiceRecoveryInFlight || !mounted) return;
    final sessionManager = serviceLocator<AuthSessionManager>();
    final expectedUserId = sessionManager.session.userId;
    final expectedToken = sessionManager.session.token;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _choiceRecoveryInFlight = true;
      _choiceRecoveryError = null;
    });
    try {
      final repaired = await sessionManager.requireListenerProfileChoice(
        expectedUserId: expectedUserId,
        expectedToken: expectedToken,
      );
      if (!mounted) return;
      if (!repaired) {
        setState(() {
          _choiceRecoveryInFlight = false;
          _choiceRecoveryError =
              'Oturum değişti. Profil tercihini yeniden kontrol et.';
        });
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !navigator.mounted || route?.isCurrent != true) return;
        navigator.pushNamedAndRemoveUntil<void>(
          AppRoutes.listenerProfileChoice,
          (_) => false,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _choiceRecoveryInFlight = false;
        _choiceRecoveryError =
            'Profil tercihin doğrulanamadı. Lütfen tekrar dene.';
      });
    }
  }

  Future<void> _openSettings() async {
    final route = ModalRoute.of(context);
    if (!await _beforeLeavingDraft() || !mounted) return;
    if (route?.isCurrent != true) return;
    await Navigator.of(context).pushNamed(AppRoutes.settings);
    if (!mounted) return;
    await context.read<ListenerProfileCubit>().loadMyProfile();
  }

  Future<void> _confirmStandardMode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xD9070A12),
      builder: (dialogContext) => _StandardModeConfirmationDialog(
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ListenerProfileCubit>().updateVisibility(
      ListenerVisibilityMode.standard,
    );
  }

  Future<void> _openAvatarActions(ListenerProfile profile) async {
    if (_avatarBusy) return;
    final hasAvatar =
        (profile.profilePictureMediaId?.trim().isNotEmpty ?? false) ||
        isValidNetworkImageUrl(profile.profilePictureUrl);
    final action = await showModalBottomSheet<_ListenerAvatarAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('listener-avatar-pick'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Yeni fotoğraf seç'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ListenerAvatarAction.pick),
            ),
            if (hasAvatar)
              ListTile(
                key: const Key('listener-avatar-remove'),
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Fotoğrafı kaldır'),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(_ListenerAvatarAction.remove),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _ListenerAvatarAction.remove) {
      await _removeAvatar();
      return;
    }
    await _uploadAvatar(profile);
  }

  Future<void> _uploadAvatar(ListenerProfile profile) async {
    setState(() => _avatarBusy = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: ImagePicker(),
        ownerType: 'LISTENER_PROFILE',
        ownerId: profile.id,
        profilePhotoTargetId: profile.id,
        profilePhotoExpectedVersion: profile.version,
        cropTitle: 'Profil fotoğrafını kırp',
      );
      if (uploaded == null || !mounted) return;

      // The durable attachment pipeline already called the listener avatar
      // PATCH. Reload for its incremented version; a second PATCH would
      // advance optimistic locking twice.
      await context.read<ListenerProfileCubit>().loadMyProfile();
    } catch (error) {
      if (mounted) _showError(_readableError(error));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Profil fotoğrafı kaldırılsın mı?'),
        content: const Text('Bu işlem profilindeki mevcut fotoğrafı kaldırır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('listener-confirm-remove-avatar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ListenerProfileCubit>().updateAvatar(null);
  }

  Future<void> _openPlaylistManager(ListenerProfile profile) async {
    if (!profile.profileContentEditable) return;
    final cubit = context.read<ListenerProfileCubit>();
    await showListenerPlaylistManagerSheet(
      context: context,
      initialPlaylists: profile.playlists,
      onSave: (spotifyUrls) async {
        await cubit.replacePlaylists(spotifyUrls);
        final result = cubit.state;
        if (result.status == ListenerProfileStatus.success &&
            result.action == ListenerProfileAction.updatePlaylists) {
          return ListenerPlaylistSaveResult.success(
            latestPlaylists: result.profile?.playlists,
          );
        }
        if (_isVersionConflict(result.error?.code) &&
            result.profile != null &&
            result.profile!.version != profile.version) {
          return ListenerPlaylistSaveResult.conflict(
            message:
                'Profil başka bir oturumda değişti. Güncel çalma listelerini yükledik; yapmak istediğin değişikliği yeniden uygula.',
            latestPlaylists: result.profile!.playlists,
          );
        }
        return ListenerPlaylistSaveResult.failure(
          result.error?.message ??
              'Çalma listeleri güncellenemedi. Lütfen tekrar dene.',
        );
      },
    );
  }

  bool _isVersionConflict(String? rawCode) {
    final code = rawCode?.trim().toUpperCase();
    return code == '1304' || code == 'LISTENER_PROFILE_VERSION_CONFLICT';
  }

  void _showUnavailableMessage(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.info,
          content: Text('$label henüz kullanıma hazır değil.'),
        ),
      );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text(message),
        ),
      );
  }
}

enum _ListenerAvatarAction { pick, remove }

class _StandardModeConfirmationDialog extends StatelessWidget {
  const _StandardModeConfirmationDialog({
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Sosyal profile dönülsün mü?',
      child: Dialog(
        key: const Key('listener-standard-mode-dialog'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(1.2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.coralAlt.withValues(alpha: 0.9),
                  AppColors.socialPink.withValues(alpha: 0.82),
                  AppColors.socialPurple.withValues(alpha: 0.76),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.socialPurple.withValues(alpha: 0.24),
                  blurRadius: 34,
                  spreadRadius: -8,
                  offset: const Offset(0, 18),
                ),
                const BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 28,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: const Color(0xFF101827),
                child: Stack(
                  children: [
                    Positioned(
                      top: -90,
                      right: -72,
                      child: IgnorePointer(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.socialPurple.withValues(alpha: 0.2),
                                AppColors.socialPurple.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _StandardModeDialogIcon(),
                          const SizedBox(height: 16),
                          const Text(
                            'GÖRÜNÜRLÜK TERCİHİ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFF0A9E9),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sosyal profile dönülsün mü?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Korunan profil içeriklerin yeniden görünür olur ve profilin tekrar takipçi kabul eder.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFC4CDDA),
                              fontSize: 12.5,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _StandardModeRestoreNotice(),
                          const SizedBox(height: 22),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stackActions =
                                  constraints.maxWidth < 300 || textScale > 1.3;
                              final cancel = _StandardModeCancelButton(
                                onPressed: onCancel,
                              );
                              final confirm = _StandardModeConfirmButton(
                                onPressed: onConfirm,
                              );
                              if (stackActions) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    confirm,
                                    const SizedBox(height: 10),
                                    cancel,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: cancel),
                                  const SizedBox(width: 10),
                                  Expanded(flex: 2, child: confirm),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StandardModeDialogIcon extends StatelessWidget {
  const _StandardModeDialogIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 66,
        height: 66,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF35203C), Color(0xFF202944)],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.socialPink.withValues(alpha: 0.18),
              blurRadius: 22,
              spreadRadius: -4,
            ),
          ],
        ),
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.brandGradient,
          ).createShader(bounds),
          child: Image.asset(
            'assets/ghost (1).png',
            key: const Key('listener-standard-mode-dialog-icon'),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

class _StandardModeRestoreNotice extends StatelessWidget {
  const _StandardModeRestoreNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('listener-standard-mode-restore-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A78).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFFF8C96).withValues(alpha: 0.2),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 18,
            color: Color(0xFFFF9AA5),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Daha önce kaldırılan takipçiler geri yüklenmez.',
              style: TextStyle(
                color: Color(0xFFE4C7CD),
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardModeCancelButton extends StatelessWidget {
  const _StandardModeCancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('listener-cancel-disable-ghost'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: const Color(0xFFD3DAE5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text(
        'Vazgeç',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StandardModeConfirmButton extends StatelessWidget {
  const _StandardModeConfirmButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: GradientOutlineButton(
        key: const Key('listener-confirm-disable-ghost'),
        label: 'Sosyal Profile Dön',
        onPressed: onPressed,
        backgroundColor: const Color(0xFF101827),
        horizontalPadding: 16,
        leading: const Icon(Icons.visibility_outlined, size: 18),
      ),
    );
  }
}

PreferredSizeWidget _listenerOwnerAppBar(
  BuildContext context, {
  required ProfileQuickMenuAction onSettings,
  Future<bool> Function()? onBeforeMenu,
}) {
  return AppBar(
    title: const ProfileBrandTitle(),
    centerTitle: true,
    actions: [
      IconButton(
        key: const Key('listener-owner-menu'),
        tooltip: 'Profil menüsü',
        onPressed: () async {
          if (onBeforeMenu != null && !await onBeforeMenu()) return;
          if (!context.mounted) return;
          await showProfileQuickMenu(
            context,
            settingsTileKey: const Key('listener-account-settings'),
            onSettings: onSettings,
          );
        },
        icon: Image.asset(
          'assets/logo.png',
          width: 28,
          height: 28,
          fit: BoxFit.contain,
        ),
      ),
      const SizedBox(width: 4),
    ],
  );
}

class _ListenerInitialLoading extends StatelessWidget {
  const _ListenerInitialLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('listener-profile-loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _ListenerLoadFailure extends StatelessWidget {
  const _ListenerLoadFailure({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final resolvedMessage = message?.trim() ?? '';
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        key: const Key('listener-profile-load-failure'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            resolvedMessage.isEmpty
                ? 'Dinleyici profili yüklenemedi.'
                : resolvedMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              key: const Key('listener-profile-retry'),
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ),
        ],
      ),
    );
  }
}

String _readableError(Object error) {
  final text = error.toString().trim();
  const exceptionPrefix = 'Exception: ';
  if (text.startsWith(exceptionPrefix)) {
    return text.substring(exceptionPrefix.length);
  }
  return text.isEmpty ? 'Profil fotoğrafı güncellenemedi.' : text;
}
