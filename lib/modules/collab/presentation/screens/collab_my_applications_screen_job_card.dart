part of 'collab_my_applications_screen.dart';

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.other,
    required this.busy,
    required this.otherConfirmed,
    required this.onProfile,
    required this.onMessage,
    required this.onDetail,
    required this.onConfirm,
    required this.onReview,
  });

  final CollabJob job;
  final CollabActor other;
  final bool busy;
  final bool otherConfirmed;
  final VoidCallback onProfile;
  final VoidCallback? onMessage;
  final VoidCallback onDetail;
  final VoidCallback? onConfirm;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirmationText = job.isCompleted
        ? 'İki taraf da işi tamamladı.'
        : job.confirmedByMe
        ? 'Sen onayladın · Karşı taraf bekleniyor.'
        : otherConfirmed
        ? 'Karşı taraf onayladı · Senin onayın bekleniyor.'
        : 'Tamamlanması için iki tarafın da onayı gerekir.';
    return CollabGradientFrame(
      highlighted: !job.isCompleted,
      radius: 19,
      strokeWidth: job.isCompleted ? 1 : 1.25,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollabActorHeader(
            actor: other,
            onTap: onProfile,
            trailing: CollabJobStatusPill(status: job.status),
          ),
          const SizedBox(height: 12),
          Text(
            job.listing.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  job.isCompleted
                      ? Icons.verified_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: job.isCompleted
                      ? AppColors.spotifyGreen
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    confirmationText,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          CollabActionsWrap(
            actions: [
              CollabCardAction(
                label: 'İlan detayı',
                icon: Icons.open_in_new_rounded,
                onPressed: busy ? null : onDetail,
              ),
              CollabCardAction(
                label: 'Mesaj',
                icon: Icons.chat_bubble_outline_rounded,
                tone: CollabCardActionTone.brand,
                onPressed: busy ? null : onMessage,
              ),
              if (onConfirm != null)
                CollabCardAction(
                  label: 'İşi tamamladım',
                  icon: Icons.task_alt_rounded,
                  tone: CollabCardActionTone.success,
                  busy: busy,
                  onPressed: busy ? null : onConfirm,
                ),
              if (job.isCompleted)
                CollabCardAction(
                  label: job.reviewedByMe
                      ? 'Değerlendirildi'
                      : 'Puanla ve yorumla',
                  icon: job.reviewedByMe
                      ? Icons.star_rounded
                      : Icons.star_outline,
                  tone: CollabCardActionTone.success,
                  busy: busy,
                  onPressed: busy ? null : onReview,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet();

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Collab deneyimini değerlendir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '$_rating üzerinden 5 yıldız',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = value),
                  tooltip: '$value yıldız',
                  iconSize: 34,
                  color: AppColors.socialOrange,
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Yorum (isteğe bağlı)',
              hintText: 'Birlikte çalışma deneyimini paylaş...',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CollabOutlineAction(
              key: const ValueKey<String>('collab-review-submit'),
              onPressed: () {
                final comment = _commentController.text.trim();
                Navigator.of(context).pop(
                  CollabReviewInput(
                    rating: _rating,
                    comment: comment.isEmpty ? null : comment,
                  ),
                );
              },
              icon: Icons.star_rounded,
              label: 'Değerlendirmeyi gönder',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message ?? 'Veriler yüklenemedi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}
