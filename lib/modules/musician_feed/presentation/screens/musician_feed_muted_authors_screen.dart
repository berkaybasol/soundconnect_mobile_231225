import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../domain/musician_feed_models.dart';
import '../../domain/musician_feed_muted_authors.dart';
import '../../domain/musician_feed_muted_authors_repository.dart';
import '../cubit/musician_feed_muted_authors_cubit.dart';
import '../musician_feed_visual_theme.dart';

class MusicianFeedMutedAuthorsScreen extends StatefulWidget {
  const MusicianFeedMutedAuthorsScreen({
    super.key,
    required this.repository,
    required this.sessions,
    this.onUnmuted,
  });

  final MusicianFeedMutedAuthorsRepository repository;
  final AuthSessionManager sessions;
  final ValueChanged<MusicianFeedAuthorProfileIdentity>? onUnmuted;

  @override
  State<MusicianFeedMutedAuthorsScreen> createState() =>
      _MusicianFeedMutedAuthorsScreenState();
}

class _MusicianFeedMutedAuthorsScreenState
    extends State<MusicianFeedMutedAuthorsScreen> {
  late MusicianFeedMutedAuthorsCubit _cubit;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _createCubit();
    _scroll.addListener(_onScroll);
  }

  void _createCubit() {
    _cubit = MusicianFeedMutedAuthorsCubit(
      widget.repository,
      widget.sessions,
      onUnmuted: (author) => widget.onUnmuted?.call(author),
    );
    unawaited(_cubit.initialize());
  }

  @override
  void didUpdateWidget(covariant MusicianFeedMutedAuthorsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.sessions, widget.sessions)) {
      unawaited(_cubit.close());
      _createCubit();
    }
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 240 &&
        _cubit.state.pagingError == null) {
      unawaited(_cubit.loadMore());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MusicianFeedThemeScope(
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: math.max(
            kToolbarHeight,
            MediaQuery.textScalerOf(context).scale(18) * 2 + 16,
          ),
          title: const Text(
            'Akışta sessize alınanlar',
            maxLines: 2,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          top: false,
          child:
              BlocConsumer<
                MusicianFeedMutedAuthorsCubit,
                MusicianFeedMutedAuthorsState
              >(
                bloc: _cubit,
                listenWhen: (previous, current) =>
                    previous.noticeSerial != current.noticeSerial,
                listener: (context, state) {
                  final error = state.actionError;
                  if (error == null) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      appSnackBar(
                        context,
                        tone: AppSnackBarTone.error,
                        content: Text(error.message),
                      ),
                    );
                },
                builder: (context, state) {
                  if (state.status == MusicianFeedMutedAuthorsStatus.initial ||
                      state.status == MusicianFeedMutedAuthorsStatus.loading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Sessize alınan hesaplar yükleniyor',
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _cubit.refresh,
                    child: ListView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: math.max(1, state.items.length) + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 20),
                            child: Text(
                              'Sessizini kaldırdığın hesapların paylaşımları yeniden akışında görünebilir.',
                            ),
                          );
                        }
                        if (index == 1 &&
                            state.status ==
                                MusicianFeedMutedAuthorsStatus.failure) {
                          return _ListMessage(
                            icon: Icons.wifi_off_rounded,
                            message:
                                state.error?.message ?? 'Liste yüklenemedi.',
                            action: 'Tekrar dene',
                            onAction: _cubit.refresh,
                          );
                        }
                        if (index == 1 && state.items.isEmpty) {
                          return const _ListMessage(
                            icon: Icons.volume_up_outlined,
                            message: 'Akışında sessize aldığın hesap yok.',
                          );
                        }
                        if (index <= state.items.length) {
                          final author = state.items[index - 1];
                          return Padding(
                            key: ValueKey(author.identity),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MutedAuthorRow(
                              author: author,
                              pending: state.pendingAuthors.contains(
                                author.identity,
                              ),
                              onUnmute: () =>
                                  unawaited(_cubit.unmute(author.identity)),
                            ),
                          );
                        }
                        if (state.loadingMore) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                semanticsLabel: 'Listenin devamı yükleniyor',
                              ),
                            ),
                          );
                        }
                        if (state.pagingError != null) {
                          return _ListMessage(
                            icon: Icons.sync_problem_rounded,
                            message: state.pagingError!.message,
                            action: 'Devamını tekrar yükle',
                            onAction: _cubit.loadMore,
                          );
                        }
                        if (state.hasMore) {
                          return TextButton.icon(
                            onPressed: _cubit.loadMore,
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text('Daha fazla göster'),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  );
                },
              ),
        ),
      ),
    ),
  );
}

class _MutedAuthorRow extends StatelessWidget {
  const _MutedAuthorRow({
    required this.author,
    required this.pending,
    required this.onUnmute,
  });
  final MusicianFeedMutedAuthor author;
  final bool pending;
  final VoidCallback onUnmute;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: ClipOval(
                  child: AppCachedNetworkImage(
                    imageUrl: author.visibleAvatarUrl,
                    width: 44,
                    height: 44,
                    cacheWidth: 96,
                    cacheHeight: 96,
                    placeholderBuilder: _avatarFallback,
                    errorBuilder: _avatarFallback,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.visibleName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!author.available) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Bu hesap şu anda kullanılamıyor.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              container: true,
              label:
                  '${author.visibleName}: ${pending ? 'Sessiz kaldırılıyor' : 'Sessizi kaldır'}',
              button: true,
              enabled: !pending,
              liveRegion: pending,
              onTap: pending ? null : onUnmute,
              child: ExcludeSemantics(
                child: TextButton.icon(
                  onPressed: pending ? null : onUnmute,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: pending
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.volume_up_outlined, size: 20),
                  label: Text(pending ? 'Kaldırılıyor…' : 'Sessizi kaldır'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _avatarFallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: const Center(child: Icon(Icons.person_outline_rounded)),
  );
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(icon, size: 36),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}
