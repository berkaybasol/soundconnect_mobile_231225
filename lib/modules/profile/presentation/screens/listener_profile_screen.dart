import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/session_logout_action.dart';
import '../cubit/listener_profile_cubit.dart';
import '../cubit/listener_profile_state.dart';
import 'profile_common_widgets.dart';
import 'profile_public_bottom_bar.dart';
import 'profile_screen_support.dart';

class ListenerProfileScreen extends StatelessWidget {
  ListenerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<ListenerProfileCubit>()..loadMyProfile(),
      child: _ListenerProfileView(),
    );
  }
}

class _ListenerProfileView extends StatelessWidget {
  _ListenerProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ListenerProfileCubit, ListenerProfileState>(
      builder: (context, state) {
        if (state.status == ListenerProfileStatus.loading) {
          return Scaffold(
            appBar: _listenerAppBar(context, showBackButton: false),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.status == ListenerProfileStatus.failure ||
            state.profile == null) {
          return Scaffold(
            appBar: _listenerAppBar(context, showBackButton: false),
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.error?.message ?? 'Listener profili getirilemedi',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          context.read<ListenerProfileCubit>().loadMyProfile(),
                      child: Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = state.profile!;
        final avatarUrl = profile.profilePictureUrl?.trim();
        final hasAvatar = isValidNetworkImageUrl(avatarUrl);

        return Scaffold(
          appBar: _listenerAppBar(context),
          body: RefreshIndicator(
            onRefresh: () =>
                context.read<ListenerProfileCubit>().loadMyProfile(),
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileTopSection(
                    header: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandGradient[2].withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: hasAvatar
                              ? AppCachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  cacheWidth:
                                      (96 *
                                              MediaQuery.devicePixelRatioOf(
                                                context,
                                              ))
                                          .round(),
                                  errorBuilder: (context) => Icon(
                                    Icons.person_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    size: 40,
                                  ),
                                )
                              : Icon(
                                  Icons.person_outline,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  size: 40,
                                ),
                        ),
                      ),
                    ),
                    identity: ProfileIdentityHeader(
                      username: profile.username,
                      secondaryText: 'Listener',
                      fallbackName: 'Listener',
                    ),
                    followerSummary: ProfileFollowerSummary(
                      followersCount: profile.followerCount,
                      followingCount: profile.followingCount,
                    ),
                    actionButtons: SizedBox.shrink(),
                    bioSection: EditableBioSection(
                      bio: profile.bio,
                      editable: false,
                      onSave: null,
                    ),
                  ),
                  SizedBox(height: 28),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Bu gecici listener profil ekranidir. Diger modullere gecis icin temel profil bilgileri aktif.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
          bottomNavigationBar: ProfilePublicBottomBar(
            currentIndex: 4,
            profileImageUrl: hasAvatar ? avatarUrl : null,
            stageMode: StageMode.mainstage,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _listenerAppBar(
    BuildContext context, {
    bool showBackButton = true,
  }) {
    return AppBar(
      title: GradientText(
        text: 'SoundConnect',
        gradient: LinearGradient(colors: AppColors.brandGradient),
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
      automaticallyImplyLeading: showBackButton,
      actions: [
        IconButton(
          key: const Key('listener-account-settings'),
          tooltip: 'Ayarlar',
          onPressed: () async {
            await Navigator.of(context).pushNamed(AppRoutes.settings);
            if (!context.mounted) return;
            await context.read<ListenerProfileCubit>().loadMyProfile();
          },
          icon: const Icon(Icons.settings_outlined),
        ),
        const SessionLogoutIconButton(),
      ],
    );
  }
}
