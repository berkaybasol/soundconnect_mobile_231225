import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/admin_collab_report.dart';
import '../cubit/admin_panel_cubit.dart';
import '../cubit/admin_panel_state.dart';

class AdminCollabReportsSection {
  const AdminCollabReportsSection._();

  static List<Widget> buildSlivers(
    BuildContext context,
    AdminPanelState state,
  ) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _CollabReportFilters(state: state),
        ),
      ),
      if (state.status == AdminPanelStatus.loading &&
          state.collabReports.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (state.applicationsError != null && state.collabReports.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _LoadError(
            message: state.applicationsError!.message,
            onRetry: () =>
                context.read<AdminPanelCubit>().loadCollabReportsList(
                  state.selectedCollabReportStatus,
                  state.selectedCollabReportReason,
                ),
          ),
        )
      else if (state.collabReports.isEmpty)
        const SliverFillRemaining(hasScrollBody: false, child: _EmptyReports())
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index.isOdd) return const SizedBox(height: 10);
              final report = state.collabReports[index ~/ 2];
              return _CollabReportTile(
                key: Key('admin-collab-report-${report.id}'),
                report: report,
                loading: state.actionIds.contains(report.id),
              );
            }, childCount: state.collabReports.length * 2 - 1),
          ),
        ),
      if (state.collabReportsHasNext || state.collabReportsLoadingMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: OutlinedButton.icon(
              onPressed: state.collabReportsLoadingMore
                  ? null
                  : context.read<AdminPanelCubit>().loadMoreCollabReports,
              icon: state.collabReportsLoadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Daha fazla yükle'),
            ),
          ),
        ),
    ];
  }
}

class _CollabReportFilters extends StatelessWidget {
  const _CollabReportFilters({required this.state});

  final AdminPanelState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Durum',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in <(AdminCollabReportStatus?, String)>[
              (null, 'Tümü'),
              for (final status in AdminCollabReportStatus.values)
                (status, status.label),
            ])
              ChoiceChip(
                key: Key(
                  'admin-collab-report-status-'
                  '${option.$1?.apiValue ?? 'ALL'}',
                ),
                label: Text(option.$2),
                selected: state.selectedCollabReportStatus == option.$1,
                onSelected: (selected) {
                  if (!selected) return;
                  context.read<AdminPanelCubit>().loadCollabReportsList(
                    option.$1,
                    state.selectedCollabReportReason,
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Neden',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in <(AdminCollabReportReason?, String)>[
              (null, 'Tümü'),
              for (final reason in AdminCollabReportReason.values)
                (reason, reason.label),
            ])
              ChoiceChip(
                key: Key(
                  'admin-collab-report-reason-'
                  '${option.$1?.apiValue ?? 'ALL'}',
                ),
                label: Text(option.$2),
                selected: state.selectedCollabReportReason == option.$1,
                onSelected: (selected) {
                  if (!selected) return;
                  context.read<AdminPanelCubit>().loadCollabReportsList(
                    state.selectedCollabReportStatus,
                    option.$1,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _CollabReportTile extends StatelessWidget {
  const _CollabReportTile({
    super.key,
    required this.report,
    required this.loading,
  });

  final AdminCollabReport report;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final canReview = report.status == AdminCollabReportStatus.open;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navBlueSoft.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.listingTitle,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      report.reason.label,
                      style: TextStyle(
                        color: AppColors.coralLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(status: report.status),
            ],
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.schedule_outlined,
            text: 'Bildirim: ${_formatDateTime(report.reportedAt)}',
          ),
          _InfoLine(
            icon: Icons.article_outlined,
            text: 'Rapor anındaki durum: ${report.listingStatusAtReport}',
          ),
          _InfoLine(
            icon: Icons.update_outlined,
            text: 'Güncel durum: ${report.listingStatus}',
          ),
          _InfoLine(icon: Icons.fingerprint, text: 'İlan: ${report.listingId}'),
          _InfoLine(
            icon: Icons.description_outlined,
            text: 'İlan açıklaması: ${report.listingDescription}',
          ),
          _InfoLine(
            icon: Icons.campaign_outlined,
            text:
                'Yayınlayan: ${report.publisherDisplayName} '
                '(${report.publisherActorId})',
          ),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: 'Şehir: ${report.cityName}',
          ),
          _InfoLine(
            icon: Icons.work_outline,
            text:
                'İlan tipi / aranan: ${report.cadence} / ${report.wantedType}',
          ),
          _InfoLine(
            icon: Icons.music_note_outlined,
            text: 'Uzmanlık: ${_specialtyEvidence(report)}',
          ),
          _InfoLine(
            icon: Icons.library_music_outlined,
            text:
                'Tarzlar: ${report.listingGenres.isEmpty ? 'Belirtilmedi' : report.listingGenres.join(', ')}',
          ),
          _InfoLine(
            icon: Icons.event_outlined,
            text: report.scheduledAt == null
                ? 'Planlanan zaman: Yok'
                : 'Planlanan zaman: ${_formatDateTime(report.scheduledAt!)}',
          ),
          _InfoLine(
            icon: Icons.payments_outlined,
            text: 'Ücret: ${_formatExactFee(report)}',
          ),
          _InfoLine(
            icon: Icons.person_outline,
            text: 'Bildiren kullanıcı: ${report.reporterUserId}',
          ),
          if ((report.details ?? '').isNotEmpty)
            _InfoLine(
              icon: Icons.notes_outlined,
              text: 'Rapor açıklaması: ${report.details}',
            ),
          if ((report.resolutionNote ?? '').isNotEmpty)
            _InfoLine(
              icon: Icons.fact_check_outlined,
              text: 'Moderasyon notu: ${report.resolutionNote}',
            ),
          if (report.reviewedAt != null)
            _InfoLine(
              icon: Icons.verified_user_outlined,
              text: 'Sonuç: ${_formatDateTime(report.reviewedAt!)}',
            ),
          if (canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('admin-collab-report-dismiss-${report.id}'),
                    onPressed: loading ? null : () => _review(context, false),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('İhlal yok'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: Key('admin-collab-report-remove-${report.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: loading ? null : () => _review(context, true),
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.remove_circle_outline),
                    label: const Text('İlanı kaldır'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _review(BuildContext context, bool removeListing) async {
    final note = await _showReviewDialog(context, removeListing);
    if (note == null || !context.mounted) return;
    final cubit = context.read<AdminPanelCubit>();
    if (removeListing) {
      await cubit.removeReportedCollabListing(
        id: report.id,
        expectedVersion: report.version,
        resolutionNote: note,
      );
    } else {
      await cubit.dismissCollabReport(
        id: report.id,
        expectedVersion: report.version,
        resolutionNote: note,
      );
    }
  }

  Future<String?> _showReviewDialog(
    BuildContext context,
    bool removeListing,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: !loading,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final note = controller.text.trim();
          final canSubmit = note.length >= 5 && note.length <= 500;
          return AlertDialog(
            title: Text(
              removeListing ? 'İlanı yayından kaldır' : 'İhlal yok kararı ver',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  removeListing
                      ? 'Bu işlem ilanı kapatır, bekleyen başvuruları geçersizleştirir ve ilgili kişilere bildirim gönderir.'
                      : 'Rapor kapatılacak ve bildirimi yapan kullanıcıya sonuç iletilecek.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Moderasyon gerekçesi',
                    helperText: 'En az 5 karakter',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                style: removeListing
                    ? FilledButton.styleFrom(backgroundColor: Colors.redAccent)
                    : null,
                onPressed: canSubmit
                    ? () => Navigator.of(dialogContext).pop(note)
                    : null,
                child: Text(removeListing ? 'Kaldır' : 'Raporu kapat'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AdminCollabReportStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AdminCollabReportStatus.open => AppColors.coralAlt,
      AdminCollabReportStatus.dismissed => Colors.grey,
      AdminCollabReportStatus.actioned => AppColors.spotifyGreen,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.textMuted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 42, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'Bu filtrede Collab raporu yok.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.coralLight),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _specialtyEvidence(AdminCollabReport report) {
  final instrument = report.instrumentName?.trim() ?? '';
  if (instrument.isNotEmpty) return 'Enstrüman: $instrument';
  final branch = report.branch?.trim() ?? '';
  final custom = report.customSpecialty?.trim() ?? '';
  if (branch.isEmpty && custom.isEmpty) return 'Belirtilmedi';
  if (branch.isEmpty) return custom;
  return custom.isEmpty ? branch : '$branch · $custom';
}

String _formatExactFee(AdminCollabReport report) {
  final amountMinor = report.feeAmountMinor;
  if (amountMinor == null) return 'Belirtilmedi';
  final major = amountMinor ~/ 100;
  final minor = (amountMinor % 100).abs().toString().padLeft(2, '0');
  final currency = report.currency?.trim().isNotEmpty == true
      ? report.currency!.trim().toUpperCase()
      : 'TRY';
  return '${_groupThousands(major)},$minor $currency '
      '($amountMinor minor)';
}

String _groupThousands(int value) {
  final negative = value.isNegative;
  final digits = value.abs().toString();
  final firstGroupLength = digits.length % 3 == 0 ? 3 : digits.length % 3;
  final groups = <String>[digits.substring(0, firstGroupLength)];
  for (var index = firstGroupLength; index < digits.length; index += 3) {
    groups.add(digits.substring(index, index + 3));
  }
  return '${negative ? '-' : ''}${groups.join('.')}';
}
