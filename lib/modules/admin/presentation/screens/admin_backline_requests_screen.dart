import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/utils/turkish_date_label.dart';
import '../../../studio/domain/entities/backline_catalog.dart';
import '../../data/admin_backline_request_repository.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_read_only_list.dart';

class AdminBacklineRequestsScreen extends StatelessWidget {
  const AdminBacklineRequestsScreen({
    super.key,
    required this.repository,
    required this.sessions,
    required this.initialSession,
    this.frame,
  });

  final AdminBacklineRequestRepository repository;
  final AuthSessionManager sessions;
  final AuthSession initialSession;
  final AdminSubpageFrame? frame;

  @override
  Widget build(BuildContext context) =>
      AdminReadOnlyList<BacklineCategoryRequest>(
        repository: repository,
        sessions: sessions,
        initialSession: initialSession,
        frame: frame,
        title: 'Backline kategori talepleri',
        itemLabel: 'kategori talebi',
        countLabel: 'talep',
        rowKey: (item) => ValueKey(item.id),
        rowBuilder: (item) => _RequestRow(request: item),
      );
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});
  final BacklineCategoryRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final isRoot = request.type == BacklineCategoryRequestType.rootCategory;
    final parent = request.parentCategoryName;
    final note = request.requesterNote;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                isRoot ? Icons.folder_outlined : Icons.account_tree_outlined,
                size: 16,
                color: colors.primary,
              ),
              Text(
                isRoot ? 'Ana kategori' : 'Alt kategori',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (request.status != BacklineCategoryRequestStatus.pending)
                Text(request.status.label, style: secondary),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            request.requestedName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              Text(
                request.studioName ?? 'Stüdyo adı belirtilmemiş',
                style: secondary,
              ),
              Text(
                turkishDateLabel(request.createdAt.toLocal()),
                style: secondary,
              ),
            ],
          ),
          if (parent != null) ...[
            const SizedBox(height: 8),
            Text('Üst kategori: $parent'),
          ],
          if (request.proposedChildren.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Önerilen alt kategoriler: ${request.proposedChildren.map((child) => child.name).join(', ')}',
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
