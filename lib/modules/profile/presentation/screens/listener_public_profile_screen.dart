import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../dm/presentation/screens/dm_chat_screen.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_state.dart';
import '../../domain/entities/listener_public_profile.dart';
import '../cubit/listener_profile_cubit.dart';
import '../cubit/listener_profile_state.dart';
import 'listener_ghost_profile_content.dart';
import 'listener_profile_theme.dart';
import 'listener_public_profile_content.dart';
import 'profile_route_args.dart';

class ListenerPublicProfileScreen extends StatelessWidget {
  const ListenerPublicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenerProfileTheme(
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => serviceLocator<ListenerProfileCubit>()),
          BlocProvider(create: (_) => serviceLocator<FollowActionCubit>()),
        ],
        child: const _ListenerPublicProfileView(),
      ),
    );
  }
}

class _ListenerPublicProfileView extends StatefulWidget {
  const _ListenerPublicProfileView();

  @override
  State<_ListenerPublicProfileView> createState() =>
      _ListenerPublicProfileViewState();
}

class _ListenerPublicProfileViewState
    extends State<_ListenerPublicProfileView> {
  bool _initialized = false;
  String _profileId = '';
  String _viewerUserId = '';
  bool _viewerResolutionComplete = false;
  String? _loadedFollowKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is PublicProfileArgs) {
      _profileId = args.profileId?.trim() ?? '';
    } else if (args is Map) {
      _profileId = args['profileId']?.toString().trim() ?? '';
    } else if (args is String) {
      _profileId = args.trim();
    }

    if (_profileId.isNotEmpty) {
      unawaited(
        context.read<ListenerProfileCubit>().loadPublicProfile(_profileId),
      );
    }
    _resolveViewerFromAuthenticatedSession();
  }

  void _resolveViewerFromAuthenticatedSession() {
    _viewerResolutionComplete = true;
    if (!serviceLocator.isRegistered<AuthSessionManager>()) return;

    final session = serviceLocator<AuthSessionManager>().session;
    if (!session.isAuthenticated) return;
    _viewerUserId = session.userId?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ListenerProfileCubit, ListenerProfileState>(
      listenWhen: (previous, current) =>
          current.status == ListenerProfileStatus.failure &&
          current.publicProfile != null &&
          (previous.status != current.status ||
              previous.error?.code != current.error?.code),
      listener: (context, state) {
        final message = state.error?.message.trim() ?? '';
        if (message.isEmpty) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        appBar: _publicAppBar(),
        body: BlocBuilder<ListenerProfileCubit, ListenerProfileState>(
          builder: (context, state) {
            if (_profileId.isEmpty) {
              return const _PublicProfileFailure(
                message: 'Dinleyici profil bağlantısı geçersiz.',
              );
            }

            final profile = state.publicProfile;
            if (profile == null) {
              if (state.status == ListenerProfileStatus.failure) {
                return _PublicProfileFailure(
                  message: state.error?.message,
                  onRetry: _refresh,
                );
              }
              return const Center(
                key: Key('listener-public-profile-loading'),
                child: CircularProgressIndicator(),
              );
            }

            if (profile.isGhost) {
              return ListenerGhostProfileContent(
                username: profile.username,
                profilePictureUrl: profile.profilePictureUrl,
                owner: false,
                busy: false,
                onRefresh: _refresh,
                onMessage: _canMessage(profile)
                    ? () => _openMessage(profile)
                    : null,
              );
            }

            _scheduleFollowStatus(profile);
            return BlocBuilder<FollowActionCubit, FollowActionState>(
              builder: (context, followState) {
                final canFollow = _canFollow(profile);
                return ListenerPublicProfileContent(
                  profile: profile,
                  isFollowing: followState.isFollowing,
                  followBusy: followState.status == FollowActionStatus.loading,
                  onRefresh: _refresh,
                  onFollow: canFollow
                      ? () => unawaited(_toggleFollow(profile))
                      : null,
                  onMessage: _canMessage(profile)
                      ? () => _openMessage(profile)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _canFollow(ListenerPublicProfile profile) {
    return profile.canFollow &&
        _viewerResolutionComplete &&
        _viewerUserId.isNotEmpty &&
        _viewerUserId != profile.userId;
  }

  bool _canMessage(ListenerPublicProfile profile) {
    return profile.canMessage &&
        _viewerResolutionComplete &&
        _viewerUserId.isNotEmpty &&
        _viewerUserId != profile.userId;
  }

  void _scheduleFollowStatus(ListenerPublicProfile profile) {
    if (!_canFollow(profile)) return;
    final key = '$_viewerUserId:${profile.userId}';
    if (_loadedFollowKey == key) return;
    _loadedFollowKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadedFollowKey != key) return;
      unawaited(
        context.read<FollowActionCubit>().loadStatus(
          followerId: _viewerUserId,
          followingId: profile.userId,
        ),
      );
    });
  }

  Future<void> _toggleFollow(ListenerPublicProfile profile) async {
    if (!_canFollow(profile)) return;
    final cubit = context.read<FollowActionCubit>();
    await cubit.toggleFollow(
      followerId: _viewerUserId,
      followingId: profile.userId,
    );
    if (!mounted) return;
    final followState = cubit.state;
    if (followState.status == FollowActionStatus.failure) {
      final message = followState.error?.message.trim() ?? '';
      final refreshProjection = _followFailureRequiresProfileRefresh(
        followState.error?.code,
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              message.isEmpty ? 'Takip işlemi tamamlanamadı.' : message,
            ),
          ),
        );
      if (refreshProjection) {
        // The target may have entered ghost mode after this STANDARD
        // projection was loaded. Re-fetch so stale follow controls disappear
        // immediately after the authoritative backend rejection.
        await _refresh();
      }
      return;
    }
    await _refresh();
  }

  void _openMessage(ListenerPublicProfile profile) {
    if (!_canMessage(profile)) return;
    Navigator.of(context).pushNamed(
      AppRoutes.dmChat,
      arguments: DmChatScreenArgs(
        otherUserId: profile.userId,
        otherUsername: profile.username,
        otherUserProfilePicture: profile.profilePictureUrl,
        currentUserId: _viewerUserId.isEmpty ? null : _viewerUserId,
        otherUserVisibilityMode: profile.visibilityMode,
      ),
    );
  }

  Future<void> _refresh() {
    _loadedFollowKey = null;
    return context.read<ListenerProfileCubit>().loadPublicProfile(_profileId);
  }
}

bool _followFailureRequiresProfileRefresh(String? rawCode) {
  final code = rawCode?.trim().toUpperCase();
  return code == '1206' ||
      code == 'GHOST_PROFILE_CANNOT_BE_FOLLOWED' ||
      code == '1207' ||
      code == 'FOLLOW_GRAPH_PRIVATE';
}

PreferredSizeWidget _publicAppBar() {
  return AppBar(
    title: GradientText(
      text: 'SoundConnect',
      gradient: LinearGradient(colors: AppColors.brandGradient),
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
    centerTitle: true,
  );
}

class _PublicProfileFailure extends StatelessWidget {
  const _PublicProfileFailure({required this.message, this.onRetry});

  final String? message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final resolvedMessage = message?.trim() ?? '';
    return ListView(
      key: const Key('listener-public-profile-failure'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(
          Icons.person_off_outlined,
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
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              key: const Key('listener-public-profile-retry'),
              onPressed: () => unawaited(onRetry!()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ),
        ],
      ],
    );
  }
}
