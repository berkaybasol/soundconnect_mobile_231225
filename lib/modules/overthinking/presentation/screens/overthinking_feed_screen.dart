import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../engagement/domain/entities/comment_item.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_state.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../../profile/presentation/screens/stage_home_top_bar.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../spotify/domain/spotify_repository.dart';
import '../../domain/entities/overthinking_post.dart';
import '../cubit/overthinking_feed_cubit.dart';
import '../cubit/overthinking_feed_state.dart';
import 'overthinking_manage_screen.dart';

class OverthinkingFeedArgs {
  final StageMode bottomBarStageMode;

  const OverthinkingFeedArgs({this.bottomBarStageMode = StageMode.mainstage});
}

class OverthinkingFeedScreen extends StatelessWidget {
  final StageMode bottomBarStageMode;

  const OverthinkingFeedScreen({
    super.key,
    this.bottomBarStageMode = StageMode.mainstage,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<OverthinkingFeedCubit>()..load(),
      child: _OverthinkingFeedView(bottomBarStageMode: bottomBarStageMode),
    );
  }
}

class _OverthinkingFeedView extends StatefulWidget {
  final StageMode bottomBarStageMode;

  const _OverthinkingFeedView({required this.bottomBarStageMode});

  @override
  State<_OverthinkingFeedView> createState() => _OverthinkingFeedViewState();
}

class _OverthinkingFeedViewState extends State<_OverthinkingFeedView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 220;
    if (_scrollController.position.pixels >= threshold) {
      context.read<OverthinkingFeedCubit>().loadMore();
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<OverthinkingFeedCubit>(),
          child: const OverthinkingCreateScreen(),
        ),
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Paylasim olusturuldu')));
    }
  }

  Future<void> _openManage({int initialTabIndex = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OverthinkingManageScreen(
          bottomBarStageMode: widget.bottomBarStageMode,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
    if (!mounted) return;
    await context.read<OverthinkingFeedCubit>().load();
  }

  Future<void> _openComments(OverthinkingPost post) async {
    final feedCubit = context.read<OverthinkingFeedCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider(
        create: (_) => serviceLocator<CommentThreadCubit>()
          ..load(
            targetType: OverthinkingFeedCubit.targetType,
            targetId: post.id,
          ),
        child: _OverthinkingCommentsSheet(
          post: post,
          onCommentCreated: () => feedCubit.incrementCommentCount(post.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OverthinkingFeedCubit, OverthinkingFeedState>(
      listener: (context, state) {
        if (state.status == OverthinkingFeedStatus.failure &&
            state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!.message)));
        }
      },
      builder: (context, state) {
        final loading = state.status == OverthinkingFeedStatus.loading;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                const StageHomeTopBar(),
                _OverthinkingHeader(onCreate: _openCreateSheet),
                _OverthinkingScopeTabs(
                  onMine: () => _openManage(initialTabIndex: 0),
                  onIncoming: () => _openManage(initialTabIndex: 1),
                  onSent: () => _openManage(initialTabIndex: 2),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        context.read<OverthinkingFeedCubit>().load(),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 104),
                      itemCount: loading
                          ? 1
                          : state.posts.isEmpty
                          ? 1
                          : state.posts.length +
                                (state.status ==
                                        OverthinkingFeedStatus.loadingMore
                                    ? 1
                                    : 0),
                      itemBuilder: (context, index) {
                        if (loading) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 160),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (state.posts.isEmpty) {
                          return const _EmptyOverthinkingFeed();
                        }
                        if (index >= state.posts.length) {
                          return const Padding(
                            padding: EdgeInsets.all(18),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final post = state.posts[index];
                        return _OverthinkingPostCard(
                          post: post,
                          onLike: () => context
                              .read<OverthinkingFeedCubit>()
                              .toggleLike(post),
                          onComments: () => _openComments(post),
                          onTap: () async {
                            await context
                                .read<OverthinkingFeedCubit>()
                                .refreshPost(post.id);
                            if (!context.mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MultiBlocProvider(
                                  providers: [
                                    BlocProvider.value(
                                      value: context
                                          .read<OverthinkingFeedCubit>(),
                                    ),
                                    BlocProvider(
                                      create: (_) =>
                                          serviceLocator<CommentThreadCubit>()
                                            ..load(
                                              targetType: OverthinkingFeedCubit
                                                  .targetType,
                                              targetId: post.id,
                                            ),
                                    ),
                                  ],
                                  child: OverthinkingDetailScreen(
                                    post: post,
                                    revealRequesting: state.revealRequestingIds
                                        .contains(post.id),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: ProfilePublicBottomBar(
            currentIndex: widget.bottomBarStageMode == StageMode.mainstage
                ? 1
                : 2,
            stageMode: widget.bottomBarStageMode,
          ),
        );
      },
    );
  }
}

class OverthinkingCreateScreen extends StatefulWidget {
  const OverthinkingCreateScreen({super.key});

  @override
  State<OverthinkingCreateScreen> createState() =>
      _OverthinkingCreateScreenState();
}

class _OverthinkingCreateScreenState extends State<OverthinkingCreateScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _anonymous = true;
  SpotifyTrackPreview? _selectedTrack;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Baslik ve metin zorunlu')));
      return;
    }
    if (_selectedTrack != null &&
        (_selectedTrack!.spotifyUrl?.trim().isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secilen sarkinin Spotify baglantisi bulunamadi'),
        ),
      );
      return;
    }

    final ok = await context.read<OverthinkingFeedCubit>().createPost(
      title: title,
      content: content,
      anonymous: _anonymous,
      spotifyTrackUrl: _selectedTrack?.spotifyUrl,
      spotifyArtistId: _selectedTrack?.artistIds.isNotEmpty == true
          ? _selectedTrack!.artistIds.first
          : null,
      spotifyTrackName: _selectedTrack?.name,
      spotifyArtistName: _selectedTrack?.artistNames.join(', '),
      spotifyAlbumImageUrl: _selectedTrack?.albumImageUrl,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    final error = context.read<OverthinkingFeedCubit>().state.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.message ?? 'Paylasim olusturulamadi')),
    );
  }

  Future<void> _pickSpotifyTrack() async {
    final selected = await showModalBottomSheet<SpotifyTrackPreview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _OverthinkingSpotifyPickerSheet(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedTrack = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OverthinkingFeedCubit, OverthinkingFeedState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Yeni Overthinking'),
            centerTitle: false,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Aklindakini toparla',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Baslik kisa kalsin, metin icerde nefes alsin.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _titleController,
                        maxLength: 64,
                        textInputAction: TextInputAction.next,
                        decoration: _sheetInputDecoration(context, 'Baslik'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        maxLength: 10240,
                        minLines: 8,
                        maxLines: 14,
                        textInputAction: TextInputAction.newline,
                        decoration: _sheetInputDecoration(
                          context,
                          'Ne dusunuyorsun?',
                        ),
                      ),
                      const SizedBox(height: 4),
                      _MusicPromptCard(
                        selectedTrack: _selectedTrack,
                        onPick: _pickSpotifyTrack,
                        onClear: _selectedTrack == null
                            ? null
                            : () => setState(() => _selectedTrack = null),
                      ),
                      const SizedBox(height: 14),
                      _AnonymousShareCard(
                        value: _anonymous,
                        onChanged: (value) =>
                            setState(() => _anonymous = value),
                      ),
                      const SizedBox(height: 18),
                      _GradientOutlineSubmitButton(
                        onPressed: state.submitting ? null : _submit,
                        label: state.submitting ? 'Paylasiliyor...' : 'Paylas',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MusicPromptCard extends StatelessWidget {
  final SpotifyTrackPreview? selectedTrack;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const _MusicPromptCard({
    required this.selectedTrack,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paragrafların hangi melodiyle şekillendi?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Okuyucularının seninle aynı duyguyu paylaşabilmesi için bu önemli. Unutma, müzik birleştirir!',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (selectedTrack == null)
            FilledButton.icon(
              onPressed: onPick,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.spotifyGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const FaIcon(FontAwesomeIcons.spotify, size: 18),
              label: const Text('Spotify ile sarki sec'),
            )
          else
            _SelectedSpotifyTrackTile(
              track: selectedTrack!,
              onChange: onPick,
              onClear: onClear,
            ),
        ],
      ),
    );
  }
}

class _AnonymousShareCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AnonymousShareCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kimlik modu',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _IdentityModeSegment(
                  selected: value,
                  icon: Icons.visibility_off_rounded,
                  label: 'Anonim',
                  description: 'Izinle acilir',
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IdentityModeSegment(
                  selected: !value,
                  icon: Icons.visibility_rounded,
                  label: 'Gorunur',
                  description: 'Profilin acik',
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IdentityModeSegment extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _IdentityModeSegment({
    required this.selected,
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandGradient[2].withValues(alpha: 0.13)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.brandGradient[2]
                : theme.dividerColor.withValues(alpha: 0.85),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.brandGradient[2]
                    : theme.colorScheme.surfaceContainer,
              ),
              child: Icon(
                icon,
                color: selected
                    ? AppColors.white
                    : theme.colorScheme.onSurfaceVariant,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientOutlineSubmitButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const _GradientOutlineSubmitButton({
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(14);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          colors: enabled
              ? AppColors.brandGradient
              : [
                  theme.disabledColor.withValues(alpha: 0.42),
                  theme.disabledColor.withValues(alpha: 0.18),
                ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedSpotifyTrackTile extends StatelessWidget {
  final SpotifyTrackPreview track;
  final VoidCallback onChange;
  final VoidCallback? onClear;

  const _SelectedSpotifyTrackTile({
    required this.track,
    required this.onChange,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          _SpotifyArtwork(url: track.albumImageUrl, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.artistNames.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onChange,
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Degistir',
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Kaldir',
          ),
        ],
      ),
    );
  }
}

class _OverthinkingSpotifyPickerSheet extends StatefulWidget {
  const _OverthinkingSpotifyPickerSheet();

  @override
  State<_OverthinkingSpotifyPickerSheet> createState() =>
      _OverthinkingSpotifyPickerSheetState();
}

class _OverthinkingSpotifyPickerSheetState
    extends State<_OverthinkingSpotifyPickerSheet> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  int _searchToken = 0;
  bool _loading = false;
  String _errorText = '';
  List<SpotifyTrackPreview> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    final token = ++_searchToken;
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _errorText = 'En az 2 karakter yaz.';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorText = '';
    });

    final result = await serviceLocator<SpotifyRepository>().searchTracks(
      query,
      limit: 10,
    );
    if (!mounted || token != _searchToken) return;

    setState(() {
      _loading = false;
      if (result.isSuccess && result.data != null) {
        _results = result.data!;
        _errorText = _results.isEmpty ? 'Sonuc bulunamadi.' : '';
      } else {
        _results = const [];
        _errorText = result.error?.message ?? 'Arama basarisiz.';
      }
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _errorText = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), _search);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sarki sec',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  onChanged: _onQueryChanged,
                  decoration:
                      _sheetInputDecoration(
                        context,
                        'Spotify parcasi ara...',
                      ).copyWith(
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          onPressed: _search,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                ),
                const SizedBox(height: 12),
                if (_loading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12),
                ],
                if (!_loading && _errorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _errorText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = _results[index];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(track),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              _SpotifyArtwork(
                                url: track.albumImageUrl,
                                size: 44,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      track.artistNames.join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.add_circle_outline_rounded,
                                color: AppColors.coralAlt,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotifyArtwork extends StatelessWidget {
  final String? url;
  final double size;

  const _SpotifyArtwork({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl?.isNotEmpty == true
          ? Image.network(imageUrl!, fit: BoxFit.cover)
          : Icon(
              Icons.music_note_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
    );
  }
}

class OverthinkingDetailScreen extends StatelessWidget {
  final OverthinkingPost post;
  final bool revealRequesting;

  const OverthinkingDetailScreen({
    super.key,
    required this.post,
    required this.revealRequesting,
  });

  Future<void> _requestReveal(
    BuildContext context,
    OverthinkingPost currentPost,
  ) async {
    final ok = await context.read<OverthinkingFeedCubit>().requestReveal(
      currentPost,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Goruntuleme istegi gonderildi'
              : 'Goruntuleme istegi gonderilemedi',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OverthinkingFeedCubit, OverthinkingFeedState>(
      builder: (context, state) {
        OverthinkingPost currentPost = post;
        for (final item in state.posts) {
          if (item.id == post.id) {
            currentPost = item;
            break;
          }
        }
        final isRevealRequesting =
            state.revealRequestingIds.contains(currentPost.id) ||
            revealRequesting;
        final anonymousLocked =
            currentPost.anonymous && !currentPost.canViewAuthor;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(title: const Text('Overthinking'), centerTitle: false),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _AuthorAvatar(post: currentPost),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  anonymousLocked
                                      ? 'Kimliğini açıklamak istemeyen yazar'
                                      : '@${currentPost.authorUsername}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentPost.anonymous
                                      ? currentPost.canViewAuthor
                                            ? 'Kimligi acik'
                                            : 'Kimligi gizli'
                                      : 'Gorunur paylasim',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (anonymousLocked)
                            TextButton(
                              onPressed: isRevealRequesting
                                  ? null
                                  : () => _requestReveal(context, currentPost),
                              child: Text(
                                isRevealRequesting ? 'Isteniyor' : 'Kim?',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        currentPost.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        currentPost.content,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      if (currentPost.spotifyTrackUrl != null ||
                          currentPost.musicianTrackId != null ||
                          currentPost.bandTrackId != null) ...[
                        const SizedBox(height: 14),
                        _MusicChip(post: currentPost),
                      ],
                      const SizedBox(height: 16),
                      _LikeSentence(
                        post: currentPost,
                        onTap: () => context
                            .read<OverthinkingFeedCubit>()
                            .toggleLike(currentPost),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _OverthinkingInlineComments(
                  post: currentPost,
                  onCommentCreated: () => context
                      .read<OverthinkingFeedCubit>()
                      .incrementCommentCount(currentPost.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverthinkingHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const _OverthinkingHeader({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overthinking',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Aklindan gecenleri bir sarkiya yasla.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onCreate,
            borderRadius: BorderRadius.circular(16),
            child: const _GradientOutlineAddButton(),
          ),
        ],
      ),
    );
  }
}

class _GradientOutlineAddButton extends StatelessWidget {
  const _GradientOutlineAddButton();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
        borderRadius: radius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: radius,
          ),
          child: Icon(
            Icons.add_rounded,
            color: Theme.of(context).colorScheme.onSurface,
            size: 25,
          ),
        ),
      ),
    );
  }
}

class _OverthinkingScopeTabs extends StatelessWidget {
  final VoidCallback onMine;
  final VoidCallback onIncoming;
  final VoidCallback onSent;

  const _OverthinkingScopeTabs({
    required this.onMine,
    required this.onIncoming,
    required this.onSent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        children: [
          const _ScopeTab(label: 'Yazılar', selected: true),
          _ScopeTab(label: 'Benim kalemimden', onTap: onMine),
          _ScopeTab(label: 'Gelen İstekler', onTap: onIncoming),
          _ScopeTab(label: 'Giden İstekler', onTap: onSent),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ScopeTab({required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.coralAlt
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.coralAlt.withValues(alpha: 0.13)
                : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.coralAlt.withValues(alpha: 0.45)
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyOverthinkingFeed extends StatelessWidget {
  const _EmptyOverthinkingFeed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.psychology_alt_outlined,
              size: 46,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Henuz paylasim yok',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ilk dusunceyi sen birak.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverthinkingPostCard extends StatelessWidget {
  final OverthinkingPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onComments;

  const _OverthinkingPostCard({
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onComments,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AuthorAvatar(post: post),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ),
            if (post.content.trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                post.content.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (post.content.trim().length > 120) ...[
                const SizedBox(height: 5),
                const _ReadMoreHint(),
              ],
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionPill(
                  icon: post.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: post.likeCount.toString(),
                  active: post.likedByMe,
                  onTap: onLike,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.mode_comment_outlined,
                  label: post.commentCount.toString(),
                  active: false,
                  onTap: onComments,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final OverthinkingPost post;

  const _AuthorAvatar({required this.post});

  @override
  Widget build(BuildContext context) {
    final lockedAnonymous = post.anonymous && !post.canViewAuthor;
    final showImage =
        post.canViewAuthor &&
        (post.authorAvatarUrl?.trim().isNotEmpty ?? false);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: lockedAnonymous
              ? [AppColors.coralAlt, AppColors.gradientC]
              : AppColors.brandGradient,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: showImage
          ? Image.network(post.authorAvatarUrl!.trim(), fit: BoxFit.cover)
          : lockedAnonymous
          ? Image.asset(
              'assets/who.png',
              width: 42,
              height: 42,
              fit: BoxFit.cover,
            )
          : Icon(Icons.person_outline, color: AppColors.white, size: 20),
    );
  }
}

class _MusicChip extends StatefulWidget {
  final OverthinkingPost post;

  const _MusicChip({required this.post});

  @override
  State<_MusicChip> createState() => _MusicChipState();
}

class _MusicChipState extends State<_MusicChip> {
  late final Future<SpotifyTrackPreview?> _trackFuture = _loadTrack();

  Future<void> _openSpotify(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Spotify acilamadi.')));
    }
  }

  Future<SpotifyTrackPreview?> _loadTrack() async {
    if (_hasBackendMetadata) return null;
    final trackId = _extractSpotifyTrackId(widget.post.spotifyTrackUrl);
    if (trackId == null) return null;
    final result = await serviceLocator<SpotifyRepository>().getTracksByIds([
      trackId,
    ]);
    if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
      return null;
    }
    return result.data!.first;
  }

  String? _extractSpotifyTrackId(String? url) {
    final text = url?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri != null) {
      final segments = uri.pathSegments;
      final trackIndex = segments.indexOf('track');
      if (trackIndex >= 0 && trackIndex + 1 < segments.length) {
        return segments[trackIndex + 1];
      }
    }
    final match = RegExp(r'track/([A-Za-z0-9]+)').firstMatch(text);
    return match?.group(1);
  }

  bool get _hasBackendMetadata {
    return (widget.post.spotifyTrackName?.trim().isNotEmpty ?? false) ||
        (widget.post.spotifyAlbumImageUrl?.trim().isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final spotifyUrl = widget.post.spotifyTrackUrl?.trim();
    if (spotifyUrl?.isNotEmpty == true) {
      return FutureBuilder<SpotifyTrackPreview?>(
        future: _trackFuture,
        builder: (context, snapshot) {
          final track = snapshot.data;
          final backendTitle = widget.post.spotifyTrackName?.trim();
          final backendArtist = widget.post.spotifyArtistName?.trim();
          final backendArtwork = widget.post.spotifyAlbumImageUrl?.trim();
          final title = backendTitle?.isNotEmpty == true
              ? backendTitle!
              : track?.name.trim().isNotEmpty == true
              ? track!.name.trim()
              : 'Spotify parcasi';
          final artists = backendArtist?.isNotEmpty == true
              ? backendArtist!
              : track?.artistNames.join(', ').trim() ?? '';
          final artworkUrl = backendArtwork?.isNotEmpty == true
              ? backendArtwork
              : track?.albumImageUrl;

          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _SpotifyArtwork(url: artworkUrl, size: 46),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.spotifyGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: FaIcon(
                          FontAwesomeIcons.spotify,
                          size: 11,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (artists.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _openSpotify(context, spotifyUrl!),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.spotifyGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    "Spotify'da dinle",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final label =
        widget.post.spotifyTrackUrl != null && widget.post.artistId != null
        ? 'SoundConnect sanatcisi eslesti'
        : widget.post.spotifyTrackUrl != null
        ? 'Spotify baglantisi'
        : widget.post.bandTrackId != null
        ? 'Band parcasi'
        : 'Muzisyen parcasi';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadMoreHint extends StatelessWidget {
  const _ReadMoreHint();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: AppColors.brandGradient,
        ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
        blendMode: BlendMode.srcIn,
        child: const Text(
          '... Devamini gor',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.coralAlt
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeSentence extends StatelessWidget {
  final OverthinkingPost post;
  final VoidCallback onTap;

  const _LikeSentence({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = post.likedByMe
        ? AppColors.coralAlt
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final text = post.likeCount == 0
        ? 'Ilk begenen sen ol'
        : '${post.likeCount} kisi bu yaziyi begendi';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              post.likedByMe
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: color,
              size: 17,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverthinkingInlineComments extends StatefulWidget {
  final OverthinkingPost post;
  final VoidCallback onCommentCreated;

  const _OverthinkingInlineComments({
    required this.post,
    required this.onCommentCreated,
  });

  @override
  State<_OverthinkingInlineComments> createState() =>
      _OverthinkingInlineCommentsState();
}

class _OverthinkingInlineCommentsState
    extends State<_OverthinkingInlineComments> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await context.read<CommentThreadCubit>().create(
      targetType: OverthinkingFeedCubit.targetType,
      targetId: widget.post.id,
      text: text,
    );
    if (!mounted) return;
    if (context.read<CommentThreadCubit>().state.error == null) {
      _controller.clear();
      widget.onCommentCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.post.commentCount == 0
              ? 'Yorumlar'
              : '${widget.post.commentCount} yorum',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        BlocBuilder<CommentThreadCubit, CommentThreadState>(
          builder: (context, state) {
            if (state.loading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state.comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Henuz yorum yok',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _CommentRow(comment: state.comments[index]),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                decoration: _sheetInputDecoration(context, 'Yorum yaz...'),
              ),
            ),
            const SizedBox(width: 8),
            BlocBuilder<CommentThreadCubit, CommentThreadState>(
              builder: (context, state) {
                return IconButton.filled(
                  onPressed: state.submitting ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _OverthinkingCommentsSheet extends StatefulWidget {
  final OverthinkingPost post;
  final VoidCallback onCommentCreated;

  const _OverthinkingCommentsSheet({
    required this.post,
    required this.onCommentCreated,
  });

  @override
  State<_OverthinkingCommentsSheet> createState() =>
      _OverthinkingCommentsSheetState();
}

class _OverthinkingCommentsSheetState
    extends State<_OverthinkingCommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await context.read<CommentThreadCubit>().create(
      targetType: OverthinkingFeedCubit.targetType,
      targetId: widget.post.id,
      text: text,
    );
    if (!mounted) return;
    if (context.read<CommentThreadCubit>().state.error == null) {
      _controller.clear();
      widget.onCommentCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Yorumlar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BlocBuilder<CommentThreadCubit, CommentThreadState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.comments.isEmpty) {
                    return Center(
                      child: Text(
                        'Henuz yorum yok',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: state.comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _CommentRow(comment: state.comments[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: _sheetInputDecoration(context, 'Yorum yaz...'),
                  ),
                ),
                const SizedBox(width: 8),
                BlocBuilder<CommentThreadCubit, CommentThreadState>(
                  builder: (context, state) {
                    return IconButton.filled(
                      onPressed: state.submitting ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  final CommentItem comment;

  const _CommentRow({required this.comment});

  @override
  Widget build(BuildContext context) {
    final username = comment.anonymousAuthor
        ? 'Kimliğini açıklamak istemeyen yazar'
        : comment.user.username;
    final avatarUrl = comment.user.avatarUrl?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          backgroundImage: avatarUrl?.isNotEmpty == true
              ? NetworkImage(avatarUrl!)
              : null,
          child: avatarUrl?.isNotEmpty == true
              ? null
              : Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$username',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _sheetInputDecoration(BuildContext context, String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.gradientC, width: 1.2),
    ),
  );
}
