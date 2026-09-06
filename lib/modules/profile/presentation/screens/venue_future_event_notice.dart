import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../domain/entities/venue_event_item.dart';

class VenueFutureEventNotice extends StatelessWidget {
  const VenueFutureEventNotice({super.key, required this.eventDate});
  final DateTime eventDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = venueEventProfileVisibleFrom(eventDate);
    const months = [
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
    final label = '${date.day} ${months[date.month - 1]} ${date.year}';
    return Container(
      key: const Key('venue-future-event-notice'),
      padding: const EdgeInsets.all(.8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(13.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: BrandGradientIcon(
                  Icons.event_available_outlined,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bu etkinlik Gelecek Etkinlikler’e eklenecek. '
                  'Mekan profilindeki haftalık takvimde $label tarihinden itibaren görünecek.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
