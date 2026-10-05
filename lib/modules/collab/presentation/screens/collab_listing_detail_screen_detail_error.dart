part of 'collab_listing_detail_screen.dart';

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _detailsController = TextEditingController();
  CollabReportReason _reason = CollabReportReason.misleading;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'İlanı şikayet et',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Bildirim nedenini seç ve gerekliyse kısa bir açıklama ekle.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            ...CollabReportReason.values.map(
              (reason) => RadioListTile<CollabReportReason>(
                value: reason,
                groupValue: _reason,
                title: Text(_reportReasonLabel(reason)),
                onChanged: (value) {
                  if (value != null) setState(() => _reason = value);
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: _reason == CollabReportReason.other
                    ? 'Açıklama zorunlu'
                    : 'Açıklama (isteğe bağlı)',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                final input = CollabReportInput(
                  reason: _reason,
                  details: _detailsController.text.trim(),
                );
                if (!input.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    appSnackBar(
                      context,
                      tone: AppSnackBarTone.warning,
                      content: const Text(
                        'Diğer nedeni için açıklama yazmalısın.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(input);
              },
              child: const Text('Bildirimi Gönder'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _supportsFee(CollabListing listing) =>
    listing.cadence == CollabCadence.extra ||
    (listing.cadence == CollabCadence.regular &&
        listing.publisher.profileType == CollabProfileKind.venue);

String _wantedSummary(CollabListing listing) {
  final base = listing.wantedType.wantedLabel;
  final specialty = listing.specialtyLabel;
  return listing.wantedType == CollabProfileKind.musician && specialty != null
      ? '$base: $specialty'
      : base;
}

String _dateTimeText(DateTime? value) {
  if (value == null) return 'Tarih belirtilmemiş';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} · '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _feeText(CollabListing listing) {
  final minor = listing.feeAmountMinor;
  if (minor == null) return 'Ücret belirtilmemiş';
  final major = minor ~/ 100;
  final fraction = minor.remainder(100).abs();
  final grouped = major.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final amount = fraction == 0
      ? grouped
      : '$grouped,${fraction.toString().padLeft(2, '0')}';
  return listing.currency == 'TRY'
      ? '₺$amount'
      : '$amount ${listing.currency ?? ''}'.trim();
}

String _statusLabel(CollabListingStatus status) => switch (status) {
  CollabListingStatus.draft => 'Taslak',
  CollabListingStatus.open => 'Açık',
  CollabListingStatus.closed => 'İlan Kapandı',
  CollabListingStatus.expired => 'İlanın Süresi Doldu',
};

String _reportReasonLabel(CollabReportReason reason) => switch (reason) {
  CollabReportReason.spam => 'Spam veya tekrar eden ilan',
  CollabReportReason.inappropriate => 'Uygunsuz içerik',
  CollabReportReason.misleading => 'Yanıltıcı veya hatalı ilan',
  CollabReportReason.other => 'Diğer',
};
