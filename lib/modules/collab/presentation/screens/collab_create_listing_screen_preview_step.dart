part of 'collab_create_listing_screen.dart';

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.listing,
    required this.publisherName,
    required this.genres,
    required this.description,
    required this.submitting,
    required this.editingOpenListing,
    required this.fieldsLocked,
    required this.onPublish,
    required this.onSaveDraft,
    super.key,
  });

  final CollabDiscoveryListing listing;
  final String publisherName;
  final List<String> genres;
  final String description;
  final bool submitting;
  final bool editingOpenListing;
  final bool fieldsLocked;
  final VoidCallback onPublish;
  final VoidCallback onSaveDraft;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Önizleme',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'İlanının nasıl görüneceğini son kez kontrol et.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          CollabListingCard(
            listing: listing,
            saved: false,
            onTap: () {},
            onSave: () {},
            interactive: false,
            showSave: false,
          ),
          const SizedBox(height: 13),
          CollabGradientFrame(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            child: Column(
              children: [
                _PreviewRow(
                  icon: Icons.person_outline_rounded,
                  label: 'İlan Veren',
                  value: publisherName,
                ),
                _PreviewRow(
                  icon: Icons.library_music_outlined,
                  label: 'Tarz',
                  value: genres.isEmpty ? 'Belirtilmemiş' : genres.join(', '),
                ),
                _PreviewRow(
                  icon: Icons.notes_rounded,
                  label: 'Açıklama',
                  value: description,
                  multiLine: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _ComingSoonCard(
            title: 'Öne Çıkar',
            description: 'İlanını daha fazla Backstage profiline ulaştır.',
            icon: Icons.rocket_launch_outlined,
          ),
          const SizedBox(height: 14),
          if (fieldsLocked) ...[
            const _EditorNotice(
              message: 'Bu ilan başvuru aldığı için değişiklik kaydedilemez.',
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 12),
          ],
          CollabPrimaryAction(
            key: const ValueKey('collab-create-publish'),
            label: editingOpenListing ? 'Değişiklikleri Kaydet' : 'Yayınla',
            icon: editingOpenListing
                ? Icons.save_outlined
                : Icons.send_outlined,
            busy: submitting,
            onPressed: submitting || fieldsLocked ? null : onPublish,
          ),
          if (!editingOpenListing) ...[
            const SizedBox(height: 9),
            CollabOutlineAction(
              key: const ValueKey('collab-create-save-draft'),
              label: 'Taslak Kaydet',
              icon: Icons.description_outlined,
              onPressed: submitting ? null : onSaveDraft,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool multiLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: multiLine
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: multiLine ? 4 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.socialPurple.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: AppColors.socialPurple.withValues(alpha: 0.48),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.socialPurple, size: 29),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CollabStatusPill(label: 'Yakında', color: AppColors.socialPurple),
          ],
        ),
      ),
    );
  }
}

String _longDate(DateTime date) {
  const months = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _timeLabel(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
