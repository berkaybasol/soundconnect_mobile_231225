import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../analytics/data/analytics_tracker.dart';
import '../../../analytics/presentation/widgets/analytics_exposure.dart';
import '../../../musician_feed/presentation/musician_feed_visual_theme.dart';
import '../../../profile/presentation/screens/video_reel_screen.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/promotion_repository.dart';
import '../cubit/announcement_list_cubit.dart';
import '../widgets/announcement_content.dart';
import 'announcement_detail_screen.dart';
import 'announcement_editor_screen.dart';

class AnnouncementDirectoryScreen extends StatefulWidget {
  const AnnouncementDirectoryScreen({
    super.key,
    this.admin = false,
    this.repository,
    this.sessions,
    this.videoDataSourceFactory,
  });
  final bool admin;
  final PromotionRepository? repository;
  final AuthSessionManager? sessions;
  final VideoReelDataSourceFactory? videoDataSourceFactory;
  @override
  State<AnnouncementDirectoryScreen> createState() =>
      _AnnouncementDirectoryScreenState();
}

class _AnnouncementDirectoryScreenState
    extends State<AnnouncementDirectoryScreen> {
  late final _cubit = AnnouncementListCubit(
    widget.repository ?? serviceLocator<PromotionRepository>(),
    widget.sessions ?? serviceLocator<AuthSessionManager>(),
    admin: widget.admin,
  );
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_more);
    unawaited(_cubit.refresh());
  }

  void _more() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 500) {
      unawaited(_cubit.loadMore());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _open(Announcement? item) async {
    if (_cubit.state.accessRevoked) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.admin
            ? AnnouncementEditorScreen(
                id: item?.id,
                repository: _cubit.repository,
                sessions: _cubit.sessions,
              )
            : AnnouncementDetailScreen(
                id: item!.id,
                videoDataSourceFactory: widget.videoDataSourceFactory,
                source: 'DIRECTORY',
                repository: _cubit.repository,
                sessions: _cubit.sessions,
              ),
      ),
    );
    if (mounted) await _cubit.refresh(filter: _cubit.state.filter);
  }

  @override
  Widget build(BuildContext context) => MusicianFeedThemeScope(
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.admin ? 'Akış Yönetimi · Duyurular' : 'Tüm duyurular',
          ),
        ),
        floatingActionButton: widget.admin
            ? FloatingActionButton.extended(
                onPressed: _cubit.state.accessRevoked
                    ? null
                    : () => _open(null),
                icon: const Icon(Icons.add),
                label: const Text('Duyuru oluştur'),
              )
            : null,
        body: BlocBuilder<AnnouncementListCubit, AnnouncementListState>(
          bloc: _cubit,
          builder: (context, state) => Column(
            children: [
              if (widget.admin)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<AnnouncementStatus>(
                    initialValue: state.filter,
                    decoration: const InputDecoration(labelText: 'Durum'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tümü')),
                      for (final status in AnnouncementStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: state.accessRevoked
                        ? null
                        : (value) => _cubit.refresh(filter: value),
                  ),
                ),
              if (!widget.admin)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'En yeni duyurular önce gösterilir. Akışta gizlediklerin burada yer alır.',
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _cubit.refresh(filter: state.filter),
                  child: ListView.separated(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: state.items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: state.loading || state.loadingMore
                              ? const Center(child: CircularProgressIndicator())
                              : state.error != null
                              ? Column(
                                  children: [
                                    Text(state.error!),
                                    if (!state.accessRevoked)
                                      TextButton(
                                        onPressed:
                                            state.items.isEmpty ||
                                                !state.hasMore
                                            ? () => _cubit.refresh(
                                                filter: state.filter,
                                              )
                                            : _cubit.loadMore,
                                        child: const Text('Yeniden dene'),
                                      ),
                                  ],
                                )
                              : state.items.isEmpty
                              ? const Center(child: Text('Henüz duyuru yok.'))
                              : state.hasMore
                              ? TextButton(
                                  onPressed: _cubit.loadMore,
                                  child: const Text('Daha fazla'),
                                )
                              : const SizedBox.shrink(),
                        );
                      }
                      final item = state.items[index];
                      final card = Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.admin)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    item.status.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              AnnouncementContent(
                                announcement: item,
                                showDirectory: false,
                                showOpenButton: !widget.admin,
                                onOpen: () => _open(item),
                              ),
                              if (widget.admin)
                                OutlinedButton.icon(
                                  onPressed: () => _open(item),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Yönet'),
                                )
                              else
                                Text(
                                  '${item.engagement.likeCount} beğeni · ${item.engagement.commentCount} yorum',
                                ),
                            ],
                          ),
                        ),
                      );
                      return widget.admin
                          ? card
                          : AnalyticsExposure(
                              key: ValueKey(
                                'announcement-directory-${item.id}',
                              ),
                              onExposed: () {
                                if (serviceLocator
                                    .isRegistered<AnalyticsTracker>()) {
                                  serviceLocator<AnalyticsTracker>()
                                      .recordAnnouncementImpression(
                                        announcementId: item.id,
                                        source: 'DIRECTORY',
                                      );
                                }
                              },
                              child: card,
                            );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
