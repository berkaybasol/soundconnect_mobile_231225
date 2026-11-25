import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../data/admin_venue_suggestion_repository.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_read_only_list.dart';

class AdminVenueSuggestionsScreen extends StatelessWidget {
  const AdminVenueSuggestionsScreen({
    super.key,
    required this.repository,
    required this.sessions,
    required this.initialSession,
    this.frame,
  });

  final AdminVenueSuggestionRepository repository;
  final AuthSessionManager sessions;
  final AuthSession initialSession;
  final AdminSubpageFrame? frame;

  @override
  Widget build(BuildContext context) => AdminReadOnlyList<AdminVenueSuggestion>(
    repository: repository,
    sessions: sessions,
    initialSession: initialSession,
    frame: frame,
    title: 'Önerilen mekânlar',
    itemLabel: 'mekân önerisi',
    countLabel: 'öneri',
    rowBuilder: (suggestion) => _SuggestionRow(suggestion: suggestion),
  );
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion});
  final AdminVenueSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.venueName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${suggestion.cityName} / ${suggestion.districtName}',
                  style: secondary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Canlı müzik: ${suggestion.liveMusic.label}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
