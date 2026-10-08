import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../modules/engagement/presentation/widgets/comment_thread_view.dart';
import '../../modules/engagement/presentation/widgets/like_users_sheet.dart';
import '../../modules/musician_feed/domain/musician_feed_like_users_target.dart';
import '../../modules/musician_feed/domain/musician_feed_models.dart';
import '../../modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';
import '../../modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import '../../modules/musician_feed/presentation/screens/musician_feed_view.dart';
import '../../modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import '../../modules/profile/presentation/screens/media_detail_screen.dart';
import '../../modules/profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../modules/profile/presentation/screens/stage_home_top_bar.dart';
import '../../modules/profile/presentation/screens/video_reel_screen.dart';
import '../../modules/promotion/presentation/screens/announcement_detail_screen.dart';
import '../../modules/promotion/presentation/screens/announcement_directory_screen.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../services/preview_service_bundle.dart';

part 'feed_preview_actions.dart';
part 'feed_preview_navigation.dart';

enum _PreviewMode { feed, catalogue }

class FeedPreviewScreen extends StatefulWidget {
  const FeedPreviewScreen({
    super.key,
    required this.services,
    this.videoDataSourceFactory,
    this.onReset,
  });
  final PreviewServiceBundle services;
  final VideoReelDataSourceFactory? videoDataSourceFactory;
  final VoidCallback? onReset;

  @override
  State<FeedPreviewScreen> createState() => _FeedPreviewScreenState();
}

class _FeedPreviewScreenState extends State<FeedPreviewScreen> {
  late MusicianFeedCubit _cubit;
  final _registry = MusicianFeedCardRegistry.standard();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  _PreviewMode _mode = _PreviewMode.feed;
  String? _type;
  String _query = '';
  int _revision = 0;
  bool _routeCurrent = true;
  bool _refreshOnReturn = false;
  PreviewServiceBundle get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _cubit = _services.createFeedCubit();
    unawaited(_cubit.initialize());
    _search.addListener(_searchChanged);
    _services.store.addListener(_storeChanged);
  }

  void _storeChanged() {
    // Detail, comments and the shared named directory route use their own
    // repository-backed state. Refresh the feed snapshot when they return.
    if (!_routeCurrent) _refreshOnReturn = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current && !_routeCurrent && _refreshOnReturn) {
      _refreshOnReturn = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_cubit.refresh());
      });
    }
    _routeCurrent = current;
  }

  void _searchChanged() =>
      setState(() => _query = _search.text.trim().toLowerCase());

  @override
  void dispose() {
    _services.store.removeListener(_storeChanged);
    unawaited(_cubit.close());
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _reset() {
    widget.onReset?.call();
    _refreshOnReturn = false;
    _services.store.reset();
    final previous = _cubit;
    setState(() {
      _revision++;
      _cubit = _services.createFeedCubit();
    });
    unawaited(previous.close());
    unawaited(_cubit.initialize());
    _notice('Önizleme başlangıç durumuna döndü.');
  }

  void _showCatalogue({String? type, String? query}) {
    setState(() {
      _mode = _PreviewMode.catalogue;
      _type = type;
      _search.text = query ?? '';
    });
  }

  void _showFeed() {
    setState(() => _mode = _PreviewMode.feed);
    unawaited(_cubit.refresh());
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: MusicianFeedThemeScope(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _previewControls(),
              StageHomeTopBar(
                unreadCountOverride: 0,
                onSearchTap: () {
                  _showCatalogue();
                  _searchFocus.requestFocus();
                },
                onNotificationsTap: () => _notice(
                  'Bu uygulamadaki etkileşimler yalnızca önizlemede kalır.',
                ),
                onMenuTap: _openMenu,
              ),
              Expanded(
                child: _mode == _PreviewMode.feed
                    ? MusicianFeedView(
                        key: ValueKey('preview-feed-$_revision'),
                        registry: _registry,
                        actionsBuilder: (context, cubit, registry) =>
                            _actions(context, cubit, registry),
                      )
                    : _catalogue(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ProfilePublicBottomBar(
          currentIndex: 0,
          unreadCountOverride: 0,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                _showFeed();
              case 1:
                _showCatalogue(type: 'COLLAB');
              case 2:
                _openMenu();
              case 3:
                _notice('Mesajlaşma yerine akış kartlarını inceleyebilirsin.');
              case 4:
                _showCatalogue(type: 'PROFILE');
            }
          },
        ),
      ),
    ),
  );

  Widget _previewControls() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: SegmentedButton<_PreviewMode>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _PreviewMode.feed, label: Text('Dolu akış')),
              ButtonSegment(
                value: _PreviewMode.catalogue,
                label: Text('Kart kataloğu'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) {
              if (value.single == _PreviewMode.feed) {
                _showFeed();
              } else {
                setState(() => _mode = value.single);
              }
            },
          ),
        ),
        IconButton(
          tooltip: 'Önizlemeyi sıfırla',
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt_rounded),
        ),
      ],
    ),
  );

  Widget _catalogue() => AnimatedBuilder(
    animation: _services.store,
    builder: (context, _) {
      final rows = _services.store.catalogue.where((scenario) {
        if (_type != null && scenario.item.type.apiValue != _type) return false;
        final text =
            '${scenario.id} ${scenario.label} '
                    '${scenario.category} ${scenario.item.type.apiValue}'
                .toLowerCase();
        return _query.isEmpty || text.contains(_query);
      }).toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: TextField(
              key: const ValueKey('preview-catalogue-search'),
              controller: _search,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: 'Kart adı veya kimliğiyle bul',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        onPressed: _search.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _typeChip('Tümü', null),
                for (final type in MusicianFeedItemType.values)
                  _typeChip(_typeLabel(type), type.apiValue),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${rows.length} kart görünümü',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('Bu aramayla eşleşen kart yok.'))
                : ListView.separated(
                    key: ValueKey('preview-catalogue-$_type-$_query'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 24),
                    itemBuilder: (context, index) {
                      final scenario = rows[index];
                      return Column(
                        key: ValueKey('preview-scenario-${scenario.id}'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${scenario.id} · ${scenario.label}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          if (_services.store.isHidden(scenario.item.id))
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text('Akışta gizli · katalogda görünür'),
                            ),
                          _registry.build(
                            context,
                            scenario.item,
                            _actions(context, _cubit, _registry),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );

  Widget _typeChip(String label, String? type) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label),
      selected: _type == type,
      onSelected: (_) => setState(() => _type = type),
    ),
  );

  Future<void> _openMenu() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('SoundConnect Önizleme'),
            subtitle: Text(
              'Kartlar ve etkileşimler bu cihazdaki örnek verilerdir.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.view_stream_outlined),
            title: const Text('Dolu akış'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showFeed();
            },
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Kart kataloğu · kimliğe git'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showCatalogue();
              _searchFocus.requestFocus();
            },
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Tüm duyurular'),
            onTap: () {
              Navigator.pop(sheetContext);
              unawaited(_openAnnouncements());
            },
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Tüm etkileşimleri sıfırla'),
            onTap: () {
              Navigator.pop(sheetContext);
              _reset();
            },
          ),
        ],
      ),
    ),
  );

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(context, tone: AppSnackBarTone.info, content: Text(text)),
      );
  }
}

String _typeLabel(MusicianFeedItemType type) => switch (type) {
  MusicianFeedItemType.track => 'Şarkı',
  MusicianFeedItemType.profileMedia => 'Medya',
  MusicianFeedItemType.collab => 'Collab',
  MusicianFeedItemType.event => 'Etkinlik',
  MusicianFeedItemType.eventProfileShare => 'Etkinlik paylaşımı',
  MusicianFeedItemType.overthinkingProfileShare => 'Overthinking',
  MusicianFeedItemType.tableGroupProfileShare => 'Müzik Birleştirir',
  MusicianFeedItemType.activityFollow => 'Takip hareketi',
  MusicianFeedItemType.activityLike => 'Beğeni hareketi',
  MusicianFeedItemType.activityComment => 'Yorum hareketi',
  MusicianFeedItemType.profile => 'Profil',
  MusicianFeedItemType.profileCompletion => 'Profil tamamlama',
  MusicianFeedItemType.sponsored => 'Sponsorlu',
  MusicianFeedItemType.announcement => 'Duyuru',
};
