import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../instrument/domain/entities/instrument.dart';
import '../../../instrument/presentation/cubit/instrument_cubit.dart';
import '../../../instrument/presentation/cubit/instrument_state.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/track.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/musician_profile_state.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/profile_media_state.dart';

class MusicianProfileScreen extends StatelessWidget {
  const MusicianProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => serviceLocator<MusicianProfileCubit>()..loadMyProfile(),
        ),
        BlocProvider(
          create: (_) => serviceLocator<InstrumentCubit>()..loadAll(),
        ),
        BlocProvider(
          create: (_) => serviceLocator<ProfileMediaCubit>(),
        ),
      ],
      child: const _MusicianProfileView(),
    );
  }
}

class _MusicianProfileView extends StatefulWidget {
  const _MusicianProfileView();

  @override
  State<_MusicianProfileView> createState() => _MusicianProfileViewState();
}

class _MusicianProfileViewState extends State<_MusicianProfileView> {
  bool _isEditing = false;
  String? _profileId;
  String? _mediaProfileId;
  bool _instrumentSelectionInitialized = false;

  final _stageNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _instagramController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _soundcloudController = TextEditingController();
  final _spotifyEmbedController = TextEditingController();
  final _spotifyArtistController = TextEditingController();

  List<Instrument> _allInstruments = const [];
  Set<String> _selectedInstrumentIds = <String>{};

  @override
  void dispose() {
    _stageNameController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _soundcloudController.dispose();
    _spotifyEmbedController.dispose();
    _spotifyArtistController.dispose();
    super.dispose();
  }

  void _syncControllers(MusicianProfile profile) {
    _profileId = profile.id;
    _stageNameController.text = profile.stageName ?? '';
    _bioController.text = profile.bio ?? '';
    _instagramController.text = profile.instagramUrl ?? '';
    _youtubeController.text = profile.youtubeUrl ?? '';
    _soundcloudController.text = profile.soundcloudUrl ?? '';
    _spotifyEmbedController.text = profile.spotifyEmbedUrl ?? '';
    _spotifyArtistController.text = profile.spotifyArtistId ?? '';
  }

  void _syncInstrumentSelection(MusicianProfile profile) {
    if (_instrumentSelectionInitialized || _allInstruments.isEmpty) return;
    final selected = <String>{};
    for (final instrument in _allInstruments) {
      if (profile.instruments.contains(instrument.name)) {
        selected.add(instrument.id);
      }
    }
    _selectedInstrumentIds = selected;
    _instrumentSelectionInitialized = true;
  }

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

  void _toggleEdit(MusicianProfile profile) {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        _syncControllers(profile);
        _syncInstrumentSelection(profile);
      }
    });
  }

  void _cancelEdit(MusicianProfile profile) {
    setState(() {
      _isEditing = false;
      _syncControllers(profile);
      _syncInstrumentSelection(profile);
    });
  }

  void _saveProfile(BuildContext context) {
    final request = MusicianProfileSaveRequest(
      stageName: _stageNameController.text,
      description: _bioController.text,
      instagramUrl: _instagramController.text,
      youtubeUrl: _youtubeController.text,
      soundcloudUrl: _soundcloudController.text,
      spotifyEmbedUrl: _spotifyEmbedController.text,
      spotifyArtistId: _spotifyArtistController.text,
      instrumentIds: _selectedInstrumentIds.toList(),
    );

    context.read<MusicianProfileCubit>().updateProfile(request);
  }

  Future<void> _openInstrumentPicker(BuildContext context) async {
    if (_allInstruments.isEmpty) return;
    final selected = Set<String>.from(_selectedInstrumentIds);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enstrumanlarini sec',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _allInstruments.length,
                      itemBuilder: (context, index) {
                        final instrument = _allInstruments[index];
                        final isSelected = selected.contains(instrument.id);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setSheetState(() {
                              if (value == true) {
                                selected.add(instrument.id);
                              } else {
                                selected.remove(instrument.id);
                              }
                            });
                          },
                          activeColor: AppColors.coralAlt,
                          checkColor: AppColors.white,
                          title: Text(
                            instrument.name,
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('Secimi kaydet'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedInstrumentIds = result;
      });
    }
  }

  List<String> _selectedInstrumentNames() {
    if (_allInstruments.isEmpty) return const [];
    final names = <String>[];
    for (final instrument in _allInstruments) {
      if (_selectedInstrumentIds.contains(instrument.id)) {
        names.add(instrument.name);
      }
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<InstrumentCubit, InstrumentState>(
          listener: (context, state) {
            if (state.status == InstrumentStatus.success) {
              setState(() {
                _allInstruments = state.instruments;
                _instrumentSelectionInitialized = false;
              });
              final profile =
                  context.read<MusicianProfileCubit>().state.profile;
              if (profile != null) {
                _syncInstrumentSelection(profile);
              }
            }
          },
        ),
        BlocListener<MusicianProfileCubit, MusicianProfileState>(
          listener: (context, state) {
            if (state.action == MusicianProfileAction.update) {
              if (state.status == MusicianProfileStatus.success) {
                if (state.profile != null) {
                  _syncControllers(state.profile!);
                  _instrumentSelectionInitialized = false;
                  _syncInstrumentSelection(state.profile!);
                  _loadMediaForProfile(state.profile!.id);
                }
                setState(() {
                  _isEditing = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil guncellendi.')),
                );
              } else if (state.status == MusicianProfileStatus.failure) {
                final message = state.error?.message ?? 'Profil guncellenemedi';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              }
            }
          },
        ),
      ],
      child: BlocBuilder<MusicianProfileCubit, MusicianProfileState>(
        builder: (context, state) {
          if (state.status == MusicianProfileStatus.loading &&
              state.action == MusicianProfileAction.load &&
              state.profile == null) {
            return const AppScaffold(
              title: 'Profil',
              centerContent: true,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.status == MusicianProfileStatus.failure &&
              state.profile == null) {
            final message = state.error?.message ?? 'Profil getirilemedi';
            return AppScaffold(
              title: 'Profil',
              centerContent: true,
              child: Center(child: Text(message)),
            );
          }

          final profile = state.profile;
          if (profile == null) {
            return const AppScaffold(
              title: 'Profil',
              centerContent: true,
              child: Center(child: Text('Profil bulunamadi')),
            );
          }

        if (!_isEditing && _profileId != profile.id) {
          _syncControllers(profile);
          _instrumentSelectionInitialized = false;
          _syncInstrumentSelection(profile);
        }

        _loadMediaForProfile(profile.id);

        final isSaving = state.status == MusicianProfileStatus.loading &&
            state.action == MusicianProfileAction.update;
          final selectedInstrumentNames = _selectedInstrumentNames();

          return Scaffold(
            appBar: AppBar(
              title: const Text('Profil'),
              actions: [
                if (_isEditing) ...[
                  TextButton(
                    onPressed: isSaving ? null : () => _cancelEdit(profile),
                    child: const Text('Iptal'),
                  ),
                  TextButton(
                    onPressed: isSaving ? null : () => _saveProfile(context),
                    child: const Text('Kaydet'),
                  ),
                ] else
                  IconButton(
                    onPressed: () => _toggleEdit(profile),
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            body: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHeader(profile: profile),
                      const SizedBox(height: 16),
                      if (_isEditing) ...[
                        _EditSection(
                          title: 'Sahne adi',
                          child: TextField(
                            controller: _stageNameController,
                            decoration: const InputDecoration(
                              hintText: 'Orn. Nova Band',
                            ),
                          ),
                        ),
                        _EditSection(
                          title: 'Hakkinda',
                          child: TextField(
                            controller: _bioController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Kisa bir biyografi ekle',
                            ),
                          ),
                        ),
                        _EditSection(
                          title: 'Enstrumanlar',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (selectedInstrumentNames.isEmpty)
                                const Text(
                                  'Henuz enstruman secilmedi.',
                                  style: TextStyle(color: AppColors.textMuted),
                                )
                              else
                                _ChipWrap(
                                  items: selectedInstrumentNames,
                                  emptyText: '',
                                ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: () =>
                                    _openInstrumentPicker(context),
                                child: const Text('Enstruman sec'),
                              ),
                            ],
                          ),
                        ),
                        _EditSection(
                          title: 'Sosyal linkler',
                          child: Column(
                            children: [
                              TextField(
                                controller: _instagramController,
                                decoration: const InputDecoration(
                                  labelText: 'Instagram',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _youtubeController,
                                decoration: const InputDecoration(
                                  labelText: 'YouTube',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _soundcloudController,
                                decoration: const InputDecoration(
                                  labelText: 'SoundCloud',
                                ),
                              ),
                            ],
                          ),
                        ),
                        _EditSection(
                          title: 'Spotify',
                          child: Column(
                            children: [
                              TextField(
                                controller: _spotifyEmbedController,
                                decoration: const InputDecoration(
                                  labelText: 'Spotify embed URL',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _spotifyArtistController,
                                decoration: const InputDecoration(
                                  labelText: 'Spotify artist ID',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        _ProfileMediaSection(),
                        _ProfileSection(
                          title: 'Hakkinda',
                          child: Text(
                            profile.bio?.trim().isNotEmpty == true
                                ? profile.bio!
                                : 'Henuz bir aciklama eklenmedi.',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                        _ProfileSection(
                          title: 'Enstrumanlar',
                          child: _ChipWrap(
                            items: profile.instruments,
                            emptyText: 'Enstruman eklenmedi.',
                          ),
                        ),
                        _ProfileSection(
                          title: 'Aktif mekanlar',
                          child: _CardList(
                            items: profile.activeVenues,
                            emptyText: 'Mekan bilgisi yok.',
                          ),
                        ),
                        _ProfileSection(
                          title: 'Bandlar',
                          child: _CardList(
                            items: profile.bands,
                            emptyText: 'Band bilgisi yok.',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                if (isSaving)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final MusicianProfile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.navBlueSoft,
                AppColors.navBlueDeep,
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: -48,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Avatar(url: profile.profilePicture),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.stageName?.trim().isNotEmpty == true
                          ? profile.stageName!
                          : 'Sahne adi ekle',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _SocialRow(
                      instagramUrl: profile.instagramUrl,
                      youtubeUrl: profile.youtubeUrl,
                      soundcloudUrl: profile.soundcloudUrl,
                      spotifyUrl: profile.spotifyEmbedUrl,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 248),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;

  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty && url!.startsWith('http');
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.inputFill,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.musicianBlue.withOpacity(0.25),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: hasUrl
            ? Image.network(url!, fit: BoxFit.cover)
            : const Icon(
                Icons.person_outline,
                color: AppColors.textMuted,
                size: 40,
              ),
      ),
    );
  }
}

class _SocialRow extends StatelessWidget {
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? soundcloudUrl;
  final String? spotifyUrl;

  const _SocialRow({
    required this.instagramUrl,
    required this.youtubeUrl,
    required this.soundcloudUrl,
    required this.spotifyUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SocialIcon(
          icon: Icons.camera_alt_outlined,
          enabled: instagramUrl?.isNotEmpty == true,
        ),
        _SocialIcon(
          icon: Icons.play_circle_outline,
          enabled: youtubeUrl?.isNotEmpty == true,
        ),
        _SocialIcon(
          icon: Icons.cloud_outlined,
          enabled: soundcloudUrl?.isNotEmpty == true,
        ),
        _SocialIcon(
          icon: Icons.music_note,
          enabled: spotifyUrl?.isNotEmpty == true,
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final bool enabled;

  const _SocialIcon({required this.icon, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(
        icon,
        size: 18,
        color: enabled ? AppColors.coralAlt : AppColors.textMuted,
      ),
    );
  }
}

class _ProfileMediaSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileMediaCubit, ProfileMediaState>(
      builder: (context, state) {
        if (state.status == ProfileMediaStatus.loading && state.media == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: LinearProgressIndicator(),
          );
        }

        if (state.media == null) {
          return const _ProfileSection(
            title: 'Medya',
            child: Text(
              'Medya yuklenmedi.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final media = state.media!;

        return _ProfileSection(
          title: 'Medya',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MediaSubTitle(label: 'Featured video'),
              _FeaturedVideoCard(asset: media.featuredVideo),
              const SizedBox(height: 16),
              const _MediaSubTitle(label: 'Videolar'),
              _VideoGrid(items: media.videos),
              const SizedBox(height: 16),
              const _MediaSubTitle(label: 'Sesler'),
              _AudioList(items: media.audios),
            ],
          ),
        );
      },
    );
  }
}

class _MediaSubTitle extends StatelessWidget {
  final String label;

  const _MediaSubTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeaturedVideoCard extends StatelessWidget {
  final MediaAsset? asset;

  const _FeaturedVideoCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    if (asset == null) {
      return const Text(
        'Featured video eklenmedi.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    final thumbnail = asset!.thumbnailUrl ?? asset!.playbackUrl;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        image: thumbnail != null
            ? DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover)
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.navBlueDeep.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                asset!.title ?? 'Featured video',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_fill,
              color: AppColors.white,
              size: 54,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoGrid extends StatelessWidget {
  final List<MediaAsset> items;

  const _VideoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'Video eklenmedi.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
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
                child: Text(
                  item.title ?? 'Video',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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

class _AudioList extends StatelessWidget {
  final List<Track> items;

  const _AudioList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'Ses eklenmedi.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    return Column(
      children: items
          .map(
            (track) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, color: AppColors.coralAlt),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(track.durationSeconds),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_arrow, color: AppColors.textMuted),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _ProfileSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _EditSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> items;
  final String emptyText;

  const _ChipWrap({required this.items, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyText, style: const TextStyle(color: AppColors.textMuted));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.navBlueSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CardList extends StatelessWidget {
  final List<String> items;
  final String emptyText;

  const _CardList({required this.items, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyText, style: const TextStyle(color: AppColors.textMuted));
    }
    return Column(
      children: items
          .map(
            (item) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
