import 'package:flutter/material.dart';

import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../domain/entities/table_group_profile_share.dart';
import '../../domain/table_group_expiry_policy.dart';
import 'table_group_overview_style.dart';

const _shareBorder = Color(0xFF202B3A);
const _shareMuted = Color(0xFFA8B2C2);

/// Public table information shared by profile publications and feed cards.
/// Navigation and engagement remain the responsibility of the hosting card.
class TableGroupSharePreview extends StatelessWidget {
  const TableGroupSharePreview({
    super.key,
    required this.table,
    this.now,
    this.openAction,
    this.compact = false,
  });

  final TableGroupProfileShareSource table;
  final DateTime? now;
  final Widget? openAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final instant = now ?? DateTime.now();
    final active = table.isActiveAt(instant);
    final awaitingFinalSnapshot = table.needsFinalSnapshotAt(instant);
    final endedLabel = active
        ? null
        : table.status == 'CANCELLED'
        ? 'Bu masa kapatıldı'
        : 'Bu masanın süresi doldu';
    final location = [table.districtName, table.cityName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final description = table.description?.trim() ?? '';
    final venue = table.venueName?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            description.isEmpty ? 'Birlikte bir masada' : description,
            maxLines: compact ? 4 : 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 23 : 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              height: 1.22,
            ),
          ),
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 7),
          _TableDetail(icon: Icons.location_on_outlined, text: location),
        ],
        SizedBox(height: compact ? 14 : 17),
        _TableInformation(
          table: table,
          venue: venue.isEmpty
              ? TableGroupOverviewStyle.unspecifiedVenueLabel
              : venue,
          instant: instant,
          awaitingFinalSnapshot: awaitingFinalSnapshot,
          endedLabel: endedLabel,
          openAction: openAction,
        ),
      ],
    );
  }
}

class _TableInformation extends StatelessWidget {
  const _TableInformation({
    required this.table,
    required this.venue,
    required this.instant,
    required this.awaitingFinalSnapshot,
    required this.endedLabel,
    required this.openAction,
  });

  final TableGroupProfileShareSource table;
  final String venue;
  final DateTime instant;
  final bool awaitingFinalSnapshot;
  final String? endedLabel;
  final Widget? openAction;

  @override
  Widget build(BuildContext context) {
    final meeting = formatTableGroupMeetingAt(table.meetingAt, now: instant);
    final separator = meeting.lastIndexOf(' ');
    final venueField = _TableInformationField(
      icon: Icons.storefront_outlined,
      value: venue,
      semanticLabel: 'Mekân, $venue',
    );
    final timeField = _TableInformationField(
      icon: Icons.access_time_rounded,
      label: separator < 0
          ? 'BULUŞMA'
          : meeting.substring(0, separator).toUpperCase(),
      value: separator < 0 ? meeting : meeting.substring(separator + 1),
      semanticLabel: table.meetingAt == null
          ? 'Buluşma saati belirtilmemiş'
          : 'Buluşma, $meeting',
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF151D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _shareBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
                // Preserve readable metadata at narrow widths and large text.
                // The actual inset width matters more than the device width.
                if (constraints.maxWidth < 224 * scale) {
                  return Column(
                    children: [
                      venueField,
                      const SizedBox(height: 16),
                      timeField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: venueField),
                    const SizedBox(
                      height: 28,
                      child: VerticalDivider(
                        color: _shareBorder,
                        width: 1,
                        thickness: 1,
                      ),
                    ),
                    Expanded(child: timeField),
                  ],
                );
              },
            ),
          ),
          const Divider(color: _shareBorder, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 44,
                      maxWidth: constraints.maxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: awaitingFinalSnapshot
                          ? const Text(
                              'Katılımcı bilgisi güncelleniyor…',
                              style: TextStyle(
                                color: _shareMuted,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            )
                          : _TableCapacity(table: table),
                    ),
                  ),
                  if (openAction != null) openAction!,
                ],
              ),
            ),
          ),
          if (endedLabel != null) ...[
            const Divider(color: _shareBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _TableDetail(
                icon: table.status == 'CANCELLED'
                    ? Icons.event_busy_outlined
                    : Icons.history_rounded,
                text: endedLabel!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableInformationField extends StatelessWidget {
  const _TableInformationField({
    required this.icon,
    this.label,
    required this.value,
    required this.semanticLabel,
  });
  final IconData icon;
  final String? label;
  final String value;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            BrandGradientIcon(icon, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null) ...[
                    Text(
                      label!,
                      style: const TextStyle(
                        color: _shareMuted,
                        fontSize: 11,
                        letterSpacing: .3,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    value,
                    style: const TextStyle(
                      color: _shareMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TableCapacity extends StatelessWidget {
  const _TableCapacity({required this.table});
  final TableGroupProfileShareSource table;

  @override
  Widget build(BuildContext context) {
    final count = '${table.acceptedCount}/${table.maxPersonCount} kişi';
    // Glyphs are decorative; the numeric label remains the authoritative count.
    final seats = table.maxPersonCount.clamp(0, 6);
    return Semantics(
      label: count,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < seats; index++) ...[
                  Icon(
                    index < table.acceptedCount
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded,
                    size: 16,
                    color: index < table.acceptedCount
                        ? TableGroupOverviewStyle.brandGradient[1]
                        : const Color(0xFF8252A8),
                  ),
                  if (index + 1 < seats) const SizedBox(width: 3),
                ],
              ],
            ),
            Text(
              count,
              style: const TextStyle(
                color: _shareMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableDetail extends StatelessWidget {
  const _TableDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(child: Icon(icon, size: 16, color: _shareMuted)),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: _shareMuted, fontSize: 12, height: 1.4),
        ),
      ),
    ],
  );
}
