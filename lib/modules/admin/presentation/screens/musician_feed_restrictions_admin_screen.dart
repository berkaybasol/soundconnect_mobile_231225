import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/theme/backstage_palette.dart';
import '../../domain/musician_feed_report_admin.dart';
import '../../domain/musician_feed_report_admin_repository.dart';
import '../cubit/musician_feed_report_admin_cubit.dart';
import '../cubit/musician_feed_restrictions_admin_cubit.dart';

class MusicianFeedRestrictionsAdminScreen extends StatefulWidget {
  const MusicianFeedRestrictionsAdminScreen({
    super.key,
    required this.repository,
    required this.sessions,
    required this.expectedIdentity,
  });
  final MusicianFeedReportAdminRepository repository;
  final AuthSessionManager sessions;
  final MusicianFeedReportAdminIdentity expectedIdentity;
  @override
  State<MusicianFeedRestrictionsAdminScreen> createState() =>
      _MusicianFeedRestrictionsAdminScreenState();
}

class _MusicianFeedRestrictionsAdminScreenState
    extends State<MusicianFeedRestrictionsAdminScreen> {
  late final MusicianFeedRestrictionsAdminCubit _cubit;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _cubit = MusicianFeedRestrictionsAdminCubit(
      widget.repository,
      widget.sessions,
      expectedIdentity: widget.expectedIdentity,
    );
    unawaited(_cubit.refresh());
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _restore(MusicianFeedOrphanRestriction restriction) async {
    final epoch = _cubit.sessionEpoch;
    if (!_cubit.canRestore(restriction, epoch)) return;
    final note = await showDialog<String>(
      context: context,
      builder: (_) =>
          _RestoreDialog(cubit: _cubit, restriction: restriction, epoch: epoch),
    );
    if (!mounted || note == null) return;
    await _cubit.restore(restriction, note, expectedEpoch: epoch);
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
    appBar: AppBar(title: const Text('Kısıtlamalar')),
    body: SafeArea(
      child:
          BlocBuilder<
            MusicianFeedRestrictionsAdminCubit,
            MusicianFeedRestrictionsAdminState
          >(
            bloc: _cubit,
            builder: (context, state) {
              if (state.status == MusicianFeedReportLoadStatus.accessDenied) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      state.error!.message,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _cubit.refresh,
                child: ListView.builder(
                  key: const Key('feed-orphan-restrictions'),
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Şikâyet kaydı silinmiş olsa da devam eden kısıtlamalar',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Kaynak şikâyet ve içerik önizlemesi bu listede bulunmaz. Geri almadan önce hedef ve karar kimliğini doğrula.',
                          ),
                          const SizedBox(height: 20),
                          if (state.notice != null)
                            Semantics(
                              liveRegion: true,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(state.notice!),
                              ),
                            ),
                          if (state.error != null) ...[
                            Text(state.error!.message),
                            TextButton(
                              onPressed: state.submittingId == null
                                  ? _cubit.refresh
                                  : null,
                              child: const Text('Listeyi yeniden yükle'),
                            ),
                          ],
                          if (state.status ==
                              MusicianFeedReportLoadStatus.loading)
                            const Center(child: CircularProgressIndicator()),
                          if (state.status ==
                                  MusicianFeedReportLoadStatus.ready &&
                              state.items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'Kaydı silinmiş etkin kısıtlama bulunmuyor.',
                              ),
                            ),
                        ],
                      );
                    }
                    if (index <= state.items.length) {
                      final row = state.items[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  row.scopeDescription,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                const Text('Hedef kimliği'),
                                SelectableText(row.scopeKey),
                                const SizedBox(height: 12),
                                const Text('Karar kimliği'),
                                SelectableText(row.reportId),
                                const SizedBox(height: 12),
                                Text(
                                  'Kararı uygulayan: ${row.appliedByUserId}',
                                ),
                                Text('Uygulandı: ${_date(row.appliedAt)}'),
                                Text('Güncellendi: ${_date(row.updatedAt)}'),
                                const SizedBox(height: 16),
                                if (state.submittingId == row.reportId)
                                  const LinearProgressIndicator(),
                                OutlinedButton(
                                  key: ValueKey(
                                    'restore-restriction-${row.reportId}',
                                  ),
                                  onPressed: state.submittingId == null
                                      ? () => _restore(row)
                                      : null,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Bu kaldırma kararını geri al',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        if (state.loadingMore)
                          const CircularProgressIndicator(),
                        if (state.hasMore && !state.loadingMore)
                          OutlinedButton(
                            onPressed: state.submittingId == null
                                ? _cubit.loadMore
                                : null,
                            child: const Text('Daha fazla göster'),
                          ),
                        const SizedBox(height: 20),
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

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({
    required this.cubit,
    required this.restriction,
    required this.epoch,
  });
  final MusicianFeedRestrictionsAdminCubit cubit;
  final MusicianFeedOrphanRestriction restriction;
  final int epoch;
  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  final _note = TextEditingController();
  bool _invalid = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<
        MusicianFeedRestrictionsAdminCubit,
        MusicianFeedRestrictionsAdminState
      >(
        bloc: widget.cubit,
        builder: (context, state) {
          final current =
              widget.cubit.hasAccess &&
              widget.epoch == widget.cubit.sessionEpoch &&
              state.items.any(
                (row) =>
                    row.reportId == widget.restriction.reportId &&
                    row.updatedAt == widget.restriction.updatedAt,
              );
          if (!current) {
            return AlertDialog(
              scrollable: true,
              title: const Text('Kısıtlama bilgileri değişti'),
              content: const Text(
                'İşlem gönderilmedi. Güncel listeyi yeniden aç.',
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
            title: const Text('Bu kaldırma kararını geri al'),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.restriction.scopeDescription),
                const SizedBox(height: 10),
                const Text(
                  'Başka etkin kaldırma kararları varsa içerik akışta kısıtlı kalabilir.',
                ),
                const SizedBox(height: 16),
                const Text('Karar gerekçesi'),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Karar gerekçesi',
                  child: TextField(
                    key: const Key('restriction-resolution-note'),
                    controller: _note,
                    minLines: 3,
                    maxLines: 7,
                    maxLength: 500,
                    decoration: InputDecoration(
                      errorMaxLines: 3,
                      errorText: _invalid
                          ? '5–500 karakterlik bir gerekçe yaz.'
                          : null,
                    ),
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
                key: const Key('restriction-restore-confirm'),
                onPressed: () {
                  if (!widget.cubit.canRestore(
                    widget.restriction,
                    widget.epoch,
                  )) {
                    return;
                  }
                  if (!isValidMusicianFeedResolutionNote(_note.text)) {
                    setState(() => _invalid = true);
                    return;
                  }
                  Navigator.of(context).pop(_note.text.trim());
                },
                child: const Text('Kararı geri al'),
              ),
            ],
          );
        },
      );
}

String _date(DateTime value) {
  final local = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}
