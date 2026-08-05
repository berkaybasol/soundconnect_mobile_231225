part of 'studio_profile_screen.dart';

class _BacklineInventoryFilterOption<T> {
  final T value;
  final String label;

  const _BacklineInventoryFilterOption({
    required this.value,
    required this.label,
  });
}

class _StudioOwnerBacklineErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StudioOwnerBacklineErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ownerManagementCardBorderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0xFFE47B86),
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB8C0CC), height: 1.35),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

class _StudioOwnerBacklinePagination extends StatelessWidget {
  final int pageIndex;
  final int totalPages;
  final bool enabled;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _StudioOwnerBacklinePagination({
    required this.pageIndex,
    required this.totalPages,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ownerManagementCardBorderColor),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Önceki sayfa',
            onPressed: enabled ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              '${pageIndex + 1} / $totalPages',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB8C0CC),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sonraki sayfa',
            onPressed: enabled ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
