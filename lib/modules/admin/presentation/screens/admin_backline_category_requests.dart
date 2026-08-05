import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/admin_backline_category_request.dart';
import '../cubit/admin_panel_cubit.dart';
import '../cubit/admin_panel_state.dart';

class AdminBacklineCategoryRequestsSection {
  const AdminBacklineCategoryRequestsSection._();

  static List<Widget> buildSlivers(
    BuildContext context,
    AdminPanelState state,
  ) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _BacklineCategoryRequestFilters(state: state),
        ),
      ),
      if (state.status == AdminPanelStatus.loading &&
          state.backlineCategoryRequests.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (state.applicationsError != null &&
          state.backlineCategoryRequests.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CategoryRequestLoadError(
            message: state.applicationsError!.message,
            onRetry: () => context
                .read<AdminPanelCubit>()
                .loadBacklineCategoryRequestsList(
                  state.selectedBacklineCategoryRequestStatus,
                ),
          ),
        )
      else if (state.backlineCategoryRequests.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyBacklineCategoryRequests(),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index.isOdd) return const SizedBox(height: 10);
              final request = state.backlineCategoryRequests[index ~/ 2];
              return _BacklineCategoryRequestTile(
                key: Key('admin-backline-category-request-${request.id}'),
                request: request,
                loading: state.actionIds.contains(request.id),
              );
            }, childCount: state.backlineCategoryRequests.length * 2 - 1),
          ),
        ),
      if (state.backlineCategoryRequestsHasNext ||
          state.backlineCategoryRequestsLoadingMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: OutlinedButton.icon(
              onPressed: state.backlineCategoryRequestsLoadingMore
                  ? null
                  : context
                        .read<AdminPanelCubit>()
                        .loadMoreBacklineCategoryRequests,
              icon: state.backlineCategoryRequestsLoadingMore
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

class _BacklineCategoryRequestFilters extends StatelessWidget {
  const _BacklineCategoryRequestFilters({required this.state});

  final AdminPanelState state;

  @override
  Widget build(BuildContext context) {
    final options = <(AdminBacklineCategoryRequestStatus?, String)>[
      (null, 'Tümü'),
      for (final status in AdminBacklineCategoryRequestStatus.values)
        (status, status.label),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            key: Key(
              'admin-backline-category-filter-'
              '${option.$1?.apiValue ?? 'ALL'}',
            ),
            label: Text(option.$2),
            selected: state.selectedBacklineCategoryRequestStatus == option.$1,
            onSelected: (selected) {
              if (!selected) return;
              context.read<AdminPanelCubit>().loadBacklineCategoryRequestsList(
                option.$1,
              );
            },
          ),
      ],
    );
  }
}

class _BacklineCategoryRequestTile extends StatelessWidget {
  const _BacklineCategoryRequestTile({
    super.key,
    required this.request,
    required this.loading,
  });

  final AdminBacklineCategoryRequest request;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final canReview =
        request.status == AdminBacklineCategoryRequestStatus.pending;
    final proposedChildren = request.proposedChildren
        .map((child) => child.name)
        .join(', ');
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
                      request.requestedName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.type.label,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _BacklineCategoryRequestStatusPill(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.business_outlined,
            text: 'Stüdyo: ${request.studioName}',
          ),
          _InfoLine(
            icon: Icons.fingerprint,
            text: 'Stüdyo kimliği: ${request.studioProfileId}',
          ),
          _InfoLine(
            icon: Icons.schedule_outlined,
            text: 'Talep tarihi: ${_formatAdminDateTime(request.createdAt)}',
          ),
          if ((request.parentCategoryName ?? '').isNotEmpty)
            _InfoLine(
              icon: Icons.account_tree_outlined,
              text: 'Üst kategori: ${request.parentCategoryName}',
            ),
          if (proposedChildren.isNotEmpty)
            _InfoLine(
              icon: Icons.subdirectory_arrow_right,
              text: 'Önerilen alt kategoriler: $proposedChildren',
            ),
          if ((request.requesterNote ?? '').isNotEmpty)
            _InfoLine(
              icon: Icons.notes_outlined,
              text: 'Stüdyo notu: ${request.requesterNote}',
            ),
          if ((request.decisionNote ?? '').isNotEmpty)
            _InfoLine(
              icon: Icons.fact_check_outlined,
              text: 'İnceleme notu: ${request.decisionNote}',
            ),
          if (canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('admin-backline-category-reject-${request.id}'),
                    onPressed: loading ? null : () => _reject(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: Key('admin-backline-category-approve-${request.id}'),
                    onPressed: loading ? null : () => _approve(context),
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Onayla'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    final note = await _showReviewDialog(context, approve: true);
    if (note == null || !context.mounted) return;
    await context.read<AdminPanelCubit>().approveBacklineCategoryRequest(
      id: request.id,
      note: note,
    );
  }

  Future<void> _reject(BuildContext context) async {
    final reason = await _showReviewDialog(context, approve: false);
    if (reason == null || reason.trim().isEmpty || !context.mounted) return;
    await context.read<AdminPanelCubit>().rejectBacklineCategoryRequest(
      id: request.id,
      reason: reason,
    );
  }

  Future<String?> _showReviewDialog(
    BuildContext context, {
    required bool approve,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: !loading,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canSubmit = approve || controller.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(
              approve ? 'Kategori talebini onayla' : 'Kategori talebini reddet',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  approve
                      ? 'Onaylandığında kategori kataloğa eklenir veya mevcut kategori yeniden etkinleştirilir.'
                      : 'Stüdyonun görebileceği açık bir red gerekçesi yaz.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 500,
                  maxLines: 4,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: approve
                        ? 'İnceleme notu (isteğe bağlı)'
                        : 'Red gerekçesi',
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
                onPressed: canSubmit
                    ? () => Navigator.of(
                        dialogContext,
                      ).pop(controller.text.trim())
                    : null,
                child: Text(approve ? 'Onayla' : 'Reddet'),
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

class _BacklineCategoryRequestStatusPill extends StatelessWidget {
  const _BacklineCategoryRequestStatusPill({required this.status});

  final AdminBacklineCategoryRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AdminBacklineCategoryRequestStatus.pending => AppColors.coralAlt,
      AdminBacklineCategoryRequestStatus.approved => AppColors.spotifyGreen,
      AdminBacklineCategoryRequestStatus.rejected => Colors.redAccent,
      AdminBacklineCategoryRequestStatus.withdrawn => Colors.grey,
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

class _EmptyBacklineCategoryRequests extends StatelessWidget {
  const _EmptyBacklineCategoryRequests();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              'Bu filtrede kategori talebi yok.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRequestLoadError extends StatelessWidget {
  const _CategoryRequestLoadError({
    required this.message,
    required this.onRetry,
  });

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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cleanText,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAdminDateTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
