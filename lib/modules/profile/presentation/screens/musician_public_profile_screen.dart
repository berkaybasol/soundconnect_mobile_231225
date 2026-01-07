import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/track.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/musician_profile_state.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/profile_media_state.dart';

class MusicianPublicProfileScreen extends StatelessWidget {
  const MusicianPublicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const useMockData = true;
    if (useMockData) {
      final mockProfile = MusicianProfile(
        id: 'mock-profile',
        stageName: 'Joe Doe',
        bio:
            'One Republic grubunda batarist. Egstas sapien etiam viverra amet '
            'enim risus dui. Purus phasellus nulla luctus proin interdum '
            'consequat id. Integer vitae dignissim et.',
        profilePicture: null,
        instagramUrl: 'https://instagram.com',
        youtubeUrl: 'https://youtube.com',
        soundcloudUrl: 'https://soundcloud.com',
        spotifyEmbedUrl: 'https://open.spotify.com',
        spotifyArtistId: null,
        instruments: const ['Bateri', 'Davul'],
        activeVenues: const ['Blue Jeans', 'Klein', 'Peyote'],
        bands: const ['One Republic'],
      );
      final mockMedia = ProfileMedia(
        featuredVideo: const MediaAsset(
          sourceUrl: null,
          playbackUrl: null,
          thumbnailUrl: null,
          title: 'Featured',
          durationSeconds: 120,
        ),
        videos: List.generate(
          6,
          (index) => const MediaAsset(
            sourceUrl: null,
            playbackUrl: null,
            thumbnailUrl: null,
            title: null,
            durationSeconds: 90,
          ),
        ),
        audios: List.generate(
          5,
          (index) => Track(
            id: 'track-$index',
            title: 'Ses Dosyasi ${index + 1}',
            playbackUrl: null,
            durationSeconds: 120,
            bpm: null,
          ),
        ),
      );

      return _MusicianPublicProfileContent(
        profile: mockProfile,
        media: mockMedia,
        followers: '10k Takipci',
        following: '356 Takip',
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => serviceLocator<MusicianProfileCubit>()..loadMyProfile(),
        ),
        BlocProvider(
          create: (_) => serviceLocator<ProfileMediaCubit>(),
        ),
      ],
      child: const _MusicianPublicProfileView(),
    );
  }
}

class _MusicianPublicProfileView extends StatefulWidget {
  const _MusicianPublicProfileView();

  @override
  State<_MusicianPublicProfileView> createState() =>
      _MusicianPublicProfileViewState();
}

class _MusicianPublicProfileViewState
    extends State<_MusicianPublicProfileView> {
  String? _mediaProfileId;

  void _loadMediaForProfile(String profileId) {
    if (_mediaProfileId == profileId) return;
    _mediaProfileId = profileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileMediaCubit>().loadMedia(
            profileType: 'MUSICIAN',
            profileId: profileId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicianProfileCubit, MusicianProfileState>(
      builder: (context, state) {
        if (state.status == MusicianProfileStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.status == MusicianProfileStatus.failure ||
            state.profile == null) {
          return Scaffold(
            body: Center(
              child: Text(state.error?.message ?? 'Profil getirilemedi'),
            ),
          );
        }

        final profile = state.profile!;
        _loadMediaForProfile(profile.id);
        final media = context.watch<ProfileMediaCubit>().state.media;

        return _MusicianPublicProfileContent(
          profile: profile,
          media: media,
          followers: '0 Takipci',
          following: '0 Takip',
        );
      },
    );
  }
}

class _MusicianPublicProfileContent extends StatelessWidget {
  final MusicianProfile profile;
  final ProfileMedia? media;
  final String followers;
  final String following;

  const _MusicianPublicProfileContent({
    required this.profile,
    required this.media,
    required this.followers,
    required this.following,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SoundConnect'),
          leading: const BackButton(),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: _ProfileHeader(profile: profile),
              ),
              const SizedBox(height: 16),
              _ProfileIdentity(profile: profile),
              const SizedBox(height: 14),
              _FollowerRow(
                followers: followers,
                following: following,
              ),
              const SizedBox(height: 14),
              _SocialButtonRow(profile: profile),
              const SizedBox(height: 12),
              _ActionButtons(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  profile.bio?.trim().isNotEmpty == true
                      ? profile.bio!
                      : 'Henuz bir aciklama eklenmedi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionHeader(
                title: 'Caldigi Mekanlar',
                actionLabel: 'Tumu',
              ),
              _VenueCarousel(items: profile.activeVenues),
              const SizedBox(height: 12),
              _MediaTabs(),
              _MediaContent(media: media),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: _BottomBar(),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final MusicianProfile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 0),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.inputFill,
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient[2].withOpacity(0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: profile.profilePicture?.startsWith('http') == true
                    ? Image.network(profile.profilePicture!, fit: BoxFit.cover)
                    : const Icon(
                        Icons.person_outline,
                        color: AppColors.textMuted,
                        size: 40,
                      ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.brandGradient,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navBlueDeep, width: 2),
                ),
                child: const Icon(
                  Icons.music_note,
                  size: 14,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  final MusicianProfile profile;

  const _ProfileIdentity({required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile.stageName?.trim().isNotEmpty == true
        ? profile.stageName!
        : 'Sahne adi';
    final bandName = profile.bands.isNotEmpty ? profile.bands.first : null;

    return Column(
      children: [
        GradientText(
          text: name,
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.brandGradient,
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (bandName != null) ...[
          const SizedBox(height: 6),
          Text(
            bandName,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _FollowerRow extends StatelessWidget {
  final String followers;
  final String following;

  const _FollowerRow({
    required this.followers,
    required this.following,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PillBadge(text: followers),
        const SizedBox(width: 12),
        _PillBadge(text: following),
      ],
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String text;

  const _PillBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SocialButtonRow extends StatelessWidget {
  final MusicianProfile profile;

  const _SocialButtonRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialPill(
          icon: FontAwesomeIcons.soundcloud,
          active: profile.soundcloudUrl?.isNotEmpty == true,
        ),
        _SocialPill(
          icon: FontAwesomeIcons.instagram,
          active: profile.instagramUrl?.isNotEmpty == true,
        ),
        _SocialPill(
          icon: FontAwesomeIcons.youtube,
          active: profile.youtubeUrl?.isNotEmpty == true,
        ),
        _SocialPill(
          icon: FontAwesomeIcons.spotify,
          active: profile.spotifyEmbedUrl?.isNotEmpty == true,
        ),
      ],
    );
  }
}

class _SocialPill extends StatefulWidget {
  final IconData icon;
  final bool active;

  const _SocialPill({required this.icon, required this.active});

  @override
  State<_SocialPill> createState() => _SocialPillState();
}

class _SocialPillState extends State<_SocialPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const iconGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFF7A3D),
        Color(0xFFEF5F86),
        Color(0xFFB85CFF),
      ],
    );

    final borderColor =
        _pressed ? AppColors.textMuted : AppColors.border;
    final shadowOpacity = _pressed ? 0.12 : 0.05;

    return GestureDetector(
      onTapDown: widget.active ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.active ? () => setState(() => _pressed = false) : null,
      onTapUp: widget.active ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: 78,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(shadowOpacity),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => iconGradient.createShader(bounds),
              child: FaIcon(
                widget.icon,
                size: 20,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Takip Et'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coralAlt,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Mesaj Gonder'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            Text(
              actionLabel!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _VenueCarousel extends StatelessWidget {
  final List<String> items;

  const _VenueCarousel({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Text(
          'Mekan bilgisi yok.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final name = items[index];
          return Container(
            width: 160,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.inputFill,
                  AppColors.navBlueSoft,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.navBlueSoft,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.white.withOpacity(0.08),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.coralAlt,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GradientText(
                        text: name,
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: AppColors.brandGradient,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Sali-Carsamba Â· 21:00',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

class _MediaTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        indicatorColor: AppColors.coralAlt,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorWeight: 3,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.graphic_eq, size: 18),
                SizedBox(width: 6),
                Text('Sesler'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 18),
                SizedBox(width: 6),
                Text('Video'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaContent extends StatelessWidget {
  final ProfileMedia? media;

  const _MediaContent({required this.media});

  @override
  Widget build(BuildContext context) {
    final audioItems = media?.audios ?? const <Track>[];
    final videoItems = media?.videos ?? const <MediaAsset>[];
    final controller = DefaultTabController.of(context);
    if (controller == null) {
      return _AudioTab(items: audioItems);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return controller.index == 0
            ? _AudioTab(items: audioItems)
            : _VideoTab(items: videoItems);
      },
    );
  }
}

class _AudioTab extends StatelessWidget {
  final List<Track> items;

  const _AudioTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Ses eklenmedi.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(items.length, (index) {
          final track = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                const _WaveformStub(),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _WaveformStub extends StatelessWidget {
  const _WaveformStub();

  static const _samples = [
    0.18, 0.32, 0.24, 0.58, 0.4, 0.7, 0.28, 0.82, 0.36,
    0.6, 0.22, 0.76, 0.44, 0.88, 0.3, 0.64, 0.2, 0.72,
    0.52, 0.34, 0.84, 0.26, 0.62, 0.4, 0.78, 0.24, 0.56,
    0.38, 0.86, 0.32, 0.68, 0.22, 0.74, 0.48, 0.9, 0.28,
    0.6, 0.3, 0.8, 0.42, 0.66, 0.2, 0.76, 0.36, 0.58,
    0.26, 0.88, 0.4, 0.7, 0.22, 0.64, 0.34, 0.82, 0.3,
    0.72, 0.24, 0.6, 0.46, 0.78, 0.28, 0.68, 0.38, 0.84,
    0.0, 0.0, 0.0,
    0.2, 0.62, 0.32, 0.74, 0.26, 0.56, 0.4, 0.8, 0.3,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.navBlueSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.music_note,
              size: 16,
              color: AppColors.coralAlt,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 44,
              child: CustomPaint(
                painter: _WaveformPainter(
                  samples: _samples,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.navBlueSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;

  const _WaveformPainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final rect = Offset.zero & size;
    final centerY = rect.height / 2;
    final maxAmp = rect.height / 2;
    final barCount = samples.length;
    final gap = 1.5;
    final barWidth =
        ((rect.width - (gap * (barCount - 1))) / barCount).clamp(1.2, 3.0);
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: AppColors.brandGradient,
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    double x = rect.left;
    for (var i = 0; i < barCount; i++) {
      final amp = samples[i] * maxAmp;
      final top = centerY - amp;
      final barHeight = amp * 2;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rrect, paint);
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}

class _VideoTab extends StatelessWidget {
  final List<MediaAsset> items;

  const _VideoTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Video eklenmedi.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final thumbnail = item.thumbnailUrl ?? item.playbackUrl;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            image: thumbnail != null
                ? DecorationImage(
                    image: NetworkImage(thumbnail),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                left: 10,
                bottom: 10,
                child: Row(
                  children: const [
                    Icon(Icons.remove_red_eye, color: AppColors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '2,1 Mn',
                      style: TextStyle(color: AppColors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: AppColors.white,
                  size: 36,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.navBlueDeep,
      selectedItemColor: AppColors.coralAlt,
      unselectedItemColor: AppColors.textMuted,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart_outlined),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mail_outline),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: '',
        ),
      ],
    );
  }
}




