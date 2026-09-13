import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/network/app_media_url.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/backstage_palette.dart';
import '../../domain/musician_feed_report_admin.dart';
import '../../domain/musician_feed_report_admin_repository.dart';
import '../cubit/musician_feed_report_admin_cubit.dart';
import 'musician_feed_restrictions_admin_screen.dart';

class MusicianFeedReportAdminScreen extends StatefulWidget {
  const MusicianFeedReportAdminScreen({
    super.key,
    required this.repository,
    required this.sessions,
  });
  final MusicianFeedReportAdminRepository repository;
  final AuthSessionManager sessions;
  @override
  State<MusicianFeedReportAdminScreen> createState() =>
      _MusicianFeedReportAdminScreenState();
}

class _MusicianFeedReportAdminScreenState
    extends State<MusicianFeedReportAdminScreen> {
  late final MusicianFeedReportAdminCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = MusicianFeedReportAdminCubit(widget.repository, widget.sessions);
    unawaited(_cubit.initialize());
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _open(MusicianFeedReportSummary report) async {
    if (!_cubit.canOpen(report.id)) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MusicianFeedReportAdminDetailScreen(
          repository: widget.repository,
          sessions: widget.sessions,
          reportId: report.id,
          expectedIdentity: _cubit.owner,
        ),
      ),
    );
    if (mounted && _cubit.checkAccess()) await _cubit.refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BackstagePalette.canvas,
    appBar: AppBar(
      title: const Text('Akış şikâyetleri'),
      actions: [
        IconButton(
          tooltip: 'Kısıtlamalar',
          icon: const Icon(Icons.shield_outlined),
          onPressed: () {
            if (!_cubit.checkAccess()) return;
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => MusicianFeedRestrictionsAdminScreen(
                  repository: widget.repository,
                  sessions: widget.sessions,
                  expectedIdentity: _cubit.owner!,
                ),
              ),
            );
          },
        ),
      ],
    ),
    body: SafeArea(
      child: BlocBuilder<MusicianFeedReportAdminCubit, MusicianFeedReportAdminState>(
        bloc: _cubit,
        builder: (context, state) {
          if (state.loadStatus == MusicianFeedReportLoadStatus.accessDenied) {
            return _StatusMessage(
              message: state.error!.message,
              icon: Icons.lock_outline,
            );
          }
          final loading =
              state.loadStatus == MusicianFeedReportLoadStatus.loading;
          final items = state.items;
          return RefreshIndicator(
            onRefresh: _cubit.refresh,
            child: ListView.builder(
              key: const Key('feed-report-queue'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Müzisyen akışındaki içerik bildirimleri'),
                      const SizedBox(height: 8),
                      Text(
                        'İş birliği ilanları kendi moderasyon sürecinde incelenir.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<MusicianFeedReportStatus>(
                        key: ValueKey(
                          'report-status-${state.filterStatus.name}',
                        ),
                        initialValue: state.filterStatus,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: const InputDecoration(labelText: 'Durum'),
                        items: MusicianFeedReportStatus.values
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                            )
                            .toList(),
                        onChanged: (status) {
                          if (status != null) {
                            unawaited(
                              _cubit.filter(
                                status: status,
                                itemType: state.itemType,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey('report-type-${state.itemType}'),
                        initialValue: state.itemType ?? '',
                        isExpanded: true,
                        itemHeight: null,
                        decoration: const InputDecoration(
                          labelText: 'İçerik türü',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Tüm içerik türleri'),
                          ),
                          ...musicianFeedReportItemTypes.entries
                              .where(
                                (entry) => !{
                                  'COLLAB',
                                  'PROFILE_COMPLETION',
                                }.contains(entry.key),
                              )
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              ),
                        ],
                        onChanged: (type) {
                          if (type != null) {
                            unawaited(
                              _cubit.filter(
                                status: state.filterStatus,
                                itemType: type.isEmpty ? null : type,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      if (state.refreshing) const LinearProgressIndicator(),
                      if (state.error != null)
                        _InlineMessage(
                          message: state.error!.message,
                          action: TextButton(
                            onPressed: _cubit.refresh,
                            child: const Text('Yeniden dene'),
                          ),
                        ),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (!loading && state.error == null && items.isEmpty)
                        const _StatusMessage(
                          message: 'Bu filtrelerde şikâyet bulunmuyor.',
                          icon: Icons.fact_check_outlined,
                        ),
                    ],
                  );
                }
                if (index <= items.length) {
                  final report = items[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('feed-report-${report.id}'),
                        onTap: () => _open(report),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.title,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${musicianFeedReportItemTypes[report.itemType] ?? 'Akış içeriği'} · ${report.status.label}',
                              ),
                              if (report.authorDisplayName != null)
                                Text(
                                  report.authorDisplayName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 8),
                              Text(
                                report.reason ??
                                    'Bildiren kişi açıklama eklememiş.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _date(report.reportedAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                key: ValueKey('feed-report-open-${report.id}'),
                                onPressed: () => _open(report),
                                child: const Text('Kaydı incele'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                if (state.loadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Column(
                  children: [
                    if (state.pagingError != null)
                      _InlineMessage(message: state.pagingError!.message),
                    if (state.hasMore)
                      OutlinedButton(
                        onPressed: _cubit.loadMore,
                        child: Text(
                          state.pagingError != null
                              ? 'Devamını yeniden yükle'
                              : 'Daha fazla göster',
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          );
        },
      ),
    ),
  );
}

class MusicianFeedReportAdminDetailScreen extends StatefulWidget {
  const MusicianFeedReportAdminDetailScreen({
    super.key,
    required this.repository,
    required this.sessions,
    required this.reportId,
    this.expectedIdentity,
  });
  final MusicianFeedReportAdminRepository repository;
  final AuthSessionManager sessions;
  final String reportId;
  final MusicianFeedReportAdminIdentity? expectedIdentity;
  @override
  State<MusicianFeedReportAdminDetailScreen> createState() =>
      _MusicianFeedReportAdminDetailScreenState();
}

class _MusicianFeedReportAdminDetailScreenState
    extends State<MusicianFeedReportAdminDetailScreen> {
  late final MusicianFeedReportDetailCubit _cubit;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _cubit = MusicianFeedReportDetailCubit(
      widget.repository,
      widget.sessions,
      widget.reportId,
      expectedIdentity: widget.expectedIdentity,
    );
    unawaited(_cubit.load());
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _review(MusicianFeedReportDecision decision) async {
    if (!_cubit.checkAccess() || _cubit.state.submitting) return;
    final detail = _cubit.state.detail;
    if (detail == null || !detail.allowedDecisions.contains(decision)) return;
    final version = detail.report.version;
    final epoch = _cubit.sessionEpoch;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(
        cubit: _cubit,
        decision: decision,
        expectedVersion: version,
        expectedEpoch: epoch,
      ),
    );
    if (!mounted || note == null) return;
    await _cubit.review(
      decision,
      note,
      expectedVersion: version,
      expectedEpoch: epoch,
    );
    // A completed decision changes the header and may replace all available
    // actions. Reveal that authoritative result even after a long evidence card.
    if (mounted && _cubit.checkAccess() && _scroll.hasClients) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BackstagePalette.canvas,
    appBar: AppBar(title: const Text('Şikâyet incelemesi')),
    body: SafeArea(
      child: BlocBuilder<MusicianFeedReportDetailCubit, MusicianFeedReportDetailState>(
        bloc: _cubit,
        builder: (context, state) {
          if (state.loadStatus == MusicianFeedReportLoadStatus.accessDenied) {
            return _StatusMessage(
              message: state.error!.message,
              icon: Icons.lock_outline,
            );
          }
          return RefreshIndicator(
            onRefresh: _cubit.load,
            child: ListView(
              key: const Key('feed-report-detail'),
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (state.notice != null)
                  _InlineMessage(message: state.notice!),
                if (state.error != null)
                  _InlineMessage(
                    message: state.error!.message,
                    action: state.detail == null
                        ? TextButton(
                            onPressed: _cubit.load,
                            child: const Text('Yeniden dene'),
                          )
                        : null,
                  ),
                if (state.loadStatus == MusicianFeedReportLoadStatus.loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (state.detail case final detail?) ...[
                  Text(
                    detail.report.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${detail.report.status.label} · ${_date(detail.report.reportedAt)}',
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Bildirim nedeni',
                    child: Text(
                      detail.report.reason ??
                          'Bildiren kişi açıklama eklememiş.',
                    ),
                  ),
                  _EvidencePreview(detail: detail),
                  _Section(
                    title: 'Kararın kapsamı',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.scopeDescription ??
                              'Bu karar müzisyen akışındaki gösterimi etkiler.',
                        ),
                        const SizedBox(height: 8),
                        const Text('Kaynak içerik ve hesap silinmez.'),
                        if (detail.activeRestriction) ...[
                          const SizedBox(height: 12),
                          Text(
                            detail.report.status ==
                                    MusicianFeedReportStatus.restored
                                ? 'Bu karar geri alındı. İçerik başka bir etkin kaldırma kararı nedeniyle akışta kısıtlı kalıyor.'
                                : 'İçerik şu anda müzisyen akışında kısıtlı.',
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (detail.allowedDecisions.isNotEmpty)
                    _Section(
                      title: 'İnceleme kararı',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.submitting)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(),
                            ),
                          for (final decision in detail.allowedDecisions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: OutlinedButton(
                                key: ValueKey('review-${decision.apiValue}'),
                                onPressed: state.submitting
                                    ? null
                                    : () => _review(decision),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    decision.label,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  _Section(
                    title: 'İşlem geçmişi',
                    child: detail.history.isEmpty
                        ? const Text('Bu kayıt için henüz karar verilmemiş.')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final entry in detail.history)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.decision.label,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      Text(
                                        '${entry.previousStatus.label} → ${entry.status.label}',
                                      ),
                                      Text(entry.resolutionNote),
                                      const SizedBox(height: 6),
                                      Text(
                                        _date(entry.occurredAt),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      Text(
                                        'İşlemi yapan: ${entry.actorUserId}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  ExpansionTile(
                    title: const Text('Kayıt bilgileri'),
                    childrenPadding: const EdgeInsets.all(12),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          'Kayıt: ${detail.report.id}\nBildiren hesap: ${detail.reporterUserId}\nİçerik: ${detail.report.itemId}',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.cubit,
    required this.decision,
    required this.expectedVersion,
    required this.expectedEpoch,
  });
  final MusicianFeedReportDetailCubit cubit;
  final MusicianFeedReportDecision decision;
  final int expectedVersion;
  final int expectedEpoch;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _note = TextEditingController();
  bool _attempted = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<MusicianFeedReportDetailCubit, MusicianFeedReportDetailState>(
    bloc: widget.cubit,
    builder: (context, state) {
      final current =
          widget.cubit.hasAccess &&
          widget.expectedEpoch == widget.cubit.sessionEpoch &&
          state.detail?.report.version == widget.expectedVersion &&
          state.detail!.allowedDecisions.contains(widget.decision);
      if (!current) {
        return AlertDialog(
          scrollable: true,
          title: const Text('İnceleme bilgileri değişti'),
          content: const Text(
            'Bu işlem gönderilmedi. Sayfayı yeniden açıp güncel bilgileri incele.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      }
      return AlertDialog(
        title: Text(widget.decision.label),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.detail!.scopeDescription ??
                  'Karar müzisyen akışındaki gösterime uygulanır.',
            ),
            if (widget.decision ==
                MusicianFeedReportDecision.restoreToFeed) ...[
              const SizedBox(height: 10),
              const Text(
                'Başka etkin kaldırma kararları varsa içerik akışta kısıtlı kalabilir.',
              ),
            ],
            const SizedBox(height: 16),
            const Text('Karar gerekçesi'),
            const SizedBox(height: 8),
            Semantics(
              label: 'Karar gerekçesi',
              child: TextField(
                key: const Key('feed-report-resolution-note'),
                controller: _note,
                minLines: 3,
                maxLines: 7,
                maxLength: 500,
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  errorText:
                      _attempted &&
                          !isValidMusicianFeedResolutionNote(_note.text)
                      ? '5–500 karakterlik bir gerekçe yaz.'
                      : null,
                ),
                onChanged: (_) {
                  if (_attempted) setState(() {});
                },
              ),
            ),
            const Text('5–500 karakter'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('feed-report-review-confirm'),
            onPressed: () {
              if (!widget.cubit.checkAccess() ||
                  widget.expectedEpoch != widget.cubit.sessionEpoch) {
                return;
              }
              if (!isValidMusicianFeedResolutionNote(_note.text)) {
                setState(() => _attempted = true);
                return;
              }
              Navigator.of(context).pop(_note.text.trim());
            },
            child: const Text('Kararı kaydet'),
          ),
        ],
      );
    },
  );
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({required this.detail});
  final MusicianFeedReportDetail detail;
  @override
  Widget build(BuildContext context) {
    final evidence = detail.evidence;
    final payload = _object(evidence['payload']);
    final author = _object(evidence['author']);
    final text = <String>{};
    String? image;
    // Only known snapshot fields are projected. Links, routes, HTML and scripts
    // from the evidence are never dispatched or rendered as interactive content.
    void collect(Map<String, Object?> value, int depth) {
      if (depth > 3) return;
      for (final key in [
        'title',
        'name',
        'description',
        'body',
        'content',
        'note',
        'bio',
        'location',
      ]) {
        final candidate = _plain(value[key]);
        if (candidate != null && text.length < 12) text.add(candidate);
      }
      for (final key in ['thumbnailUrl', 'displayUrl', 'avatarUrl']) {
        final candidate = _plain(value[key]);
        if (image == null &&
            candidate != null &&
            isSafeMediaReference(candidate)) {
          image = candidate;
        }
      }
      for (final key in ['targetPayload', 'event', 'listing', 'source']) {
        collect(_object(value[key]), depth + 1);
      }
    }

    final omitted = payload['omitted'] == true || payload.isEmpty;
    if (!omitted) collect(payload, 0);
    return _Section(
      title: 'Şikâyete eklenen içerik kaydı',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            musicianFeedReportItemTypes[detail.report.itemType] ??
                'Akış içeriği',
          ),
          if (_plain(author['displayName']) ?? detail.report.authorDisplayName
              case final name?)
            Text(name),
          const SizedBox(height: 12),
          if (omitted)
            const Text('İçerik önizlemesi kayda alınmamış.')
          else ...[
            if (image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppCachedNetworkImage(
                    imageUrl: image!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_) => const SizedBox(
                      height: 60,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            for (final paragraph in text)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(paragraph),
              ),
            if (text.isEmpty && image == null)
              const Text('Bu kayıt için metin önizlemesi bulunmuyor.'),
          ],
          if (detail.report.itemType == 'ACTIVITY_COMMENT') ...[
            const SizedBox(height: 10),
            const Text(
              'Yorum metni bu kayda alınmamış. Varsa önizleme, yorumun bağlı olduğu içeriğe aittir.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(message), if (action != null) action!],
      ),
    ),
  );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.icon});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _date(DateTime value) {
  final local = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

Map<String, Object?> _object(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const {};
String? _plain(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
