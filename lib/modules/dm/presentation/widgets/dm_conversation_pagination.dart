import 'package:flutter/material.dart';

import '../cubit/dm_conversations_state.dart';

/// An explicit, accessible continuation keeps older chats reachable even when
/// the first page is shorter than the screen or all its empty rows are filtered.
class DmConversationPagination extends StatelessWidget {
  const DmConversationPagination({
    super.key,
    required this.state,
    required this.onLoadMore,
    required this.onRefresh,
  });

  final DmConversationsState state;
  final VoidCallback onLoadMore;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore || state.status == DmConversationsStatus.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == DmConversationsStatus.failure) {
      return Column(
        children: [
          const Text('Konuşmalar yenilenemedi.'),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
          ),
        ],
      );
    }
    if (!state.hasNext) return const SizedBox.shrink();
    return Column(
      children: [
        if (state.loadMoreError != null)
          const Text('Eski konuşmalar yüklenemedi.'),
        TextButton.icon(
          onPressed: onLoadMore,
          icon: const Icon(Icons.expand_more),
          label: Text(
            state.loadMoreError == null
                ? 'Daha eski konuşmalar'
                : 'Tekrar dene',
          ),
        ),
      ],
    );
  }
}
