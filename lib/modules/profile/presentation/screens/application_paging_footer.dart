import 'package:flutter/material.dart';

class ApplicationPagingFooter extends StatelessWidget {
  const ApplicationPagingFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    this.error,
    this.onMore,
    this.onRetry,
  });
  final bool loading;
  final bool hasMore;
  final String? error;
  final VoidCallback? onMore;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (onRetry != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, textAlign: TextAlign.center),
            ),
          TextButton(onPressed: onRetry, child: const Text('Yeniden dene')),
        ],
      );
    }
    if (!hasMore) return const SizedBox.shrink();
    return TextButton(
      onPressed: onMore,
      child: const Text('Daha fazla göster'),
    );
  }
}
