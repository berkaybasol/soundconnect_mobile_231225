import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../cubit/listener_profile_cubit.dart';
import '../cubit/listener_profile_state.dart';
import 'profile_common_widgets.dart';
import 'profile_screen_support.dart';

class ListenerProfileScreen extends StatelessWidget {
  const ListenerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<ListenerProfileCubit>()..loadMyProfile(),
      child: const _ListenerProfileView(),
    );
  }
}

class _ListenerProfileView extends StatelessWidget {
  const _ListenerProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ListenerProfileCubit, ListenerProfileState>(
      builder: (context, state) {
        if (state.status == ListenerProfileStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.status == ListenerProfileStatus.failure ||
            state.profile == null) {
          return Scaffold(
            appBar: AppBar(
              title: const GradientText(
                text: 'SoundConnect',
                gradient: LinearGradient(colors: AppColors.brandGradient),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              centerTitle: true,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.error?.message ?? 'Listener profili getirilemedi',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          context.read<ListenerProfileCubit>().loadMyProfile(),
                      child: const Text('Tekrar dene'),
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
          appBar: AppBar(
            title: const GradientText(
              text: 'SoundConnect',
              gradient: LinearGradient(colors: AppColors.brandGradient),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
            leading: const BackButton(),
          ),
          body: RefreshIndicator(
            onRefresh: () =>
                context.read<ListenerProfileCubit>().loadMyProfile(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileTopSection(
                    header: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.inputFill,
                          border: Border.all(color: AppColors.border),
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
                              ? Image.network(avatarUrl!, fit: BoxFit.cover)
                              : const Icon(
                                  Icons.person_outline,
                                  color: AppColors.textMuted,
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
                    actionButtons: const SizedBox.shrink(),
                    bioSection: EditableBioSection(
                      bio: profile.bio,
                      editable: false,
                      onSave: null,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Bu gecici listener profil ekranidir. Diger modullere gecis icin temel profil bilgileri aktif.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
