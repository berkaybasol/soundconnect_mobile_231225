import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_listing.dart';

/// A 9:16, self-contained listing poster. It deliberately uses no network
/// images so rendering remains deterministic while offline or on a slow link.
class CollabShareCard extends StatelessWidget {
  const CollabShareCard({
    required this.listing,
    this.publisherAvatar,
    super.key,
  });

  final CollabListing listing;
  final ImageProvider? publisherAvatar;

  @override
  Widget build(BuildContext context) {
    final specialty = listing.specialtyLabel ?? listing.wantedType.label;
    return SizedBox(
      key: const ValueKey('collab-share-card'),
      width: 360,
      height: 640,
      child: Material(
        color: const Color(0xFF030713),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.75, -0.65),
              radius: 1.45,
              colors: [Color(0xFF51205C), Color(0xFF111225), Color(0xFF030713)],
              stops: [0, 0.48, 1],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandRow(),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.socialGradient),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x553D174A),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xF20A101B),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Publisher(
                          listing: listing,
                          avatarImage: publisherAvatar,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          listing.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          listing.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFB8C0D0),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _MetaRow(
                          icon: Icons.search_rounded,
                          text: _wantedSummary(listing, specialty),
                        ),
                        const SizedBox(height: 9),
                        _MetaRow(
                          icon: Icons.location_on_outlined,
                          text: listing.city.name,
                        ),
                        if (listing.cadence == CollabCadence.extra &&
                            listing.scheduledAt != null) ...[
                          const SizedBox(height: 9),
                          _MetaRow(
                            icon: Icons.calendar_month_outlined,
                            text: _dateText(listing.scheduledAt!),
                          ),
                        ],
                        if (listing.genres.isNotEmpty) ...[
                          const SizedBox(height: 17),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: listing.genres
                                .take(3)
                                .map((genre) => _GenreChip(label: genre))
                                .toList(growable: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                const Row(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SoundConnect Collab’da keşfet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 212,
    height: 54,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: 212,
          height: 45,
          child: Image.asset(
            'assets/Logoyanyana.png',
            fit: BoxFit.fitWidth,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
        const Positioned(
          left: 45,
          top: 33,
          child: Text(
            'COLLAB',
            style: TextStyle(
              color: Color(0xFFB8C0D0),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Publisher extends StatelessWidget {
  const _Publisher({required this.listing, this.avatarImage});

  final CollabListing listing;
  final ImageProvider? avatarImage;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFB85CFF),
        foregroundImage: avatarImage,
        onForegroundImageError: avatarImage == null ? null : (_, _) {},
        child: Text(
          listing.publisher.initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listing.publisher.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              listing.publisher.profileType.label,
              style: const TextStyle(color: Color(0xFF9EA8B7), fontSize: 10.5),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFFE67AAE), size: 17),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFEFF2F8),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF171F2D),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0xFF303B4C)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFDCE1EA),
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String _wantedSummary(CollabListing listing, String specialty) =>
    listing.wantedType == CollabProfileKind.musician
    ? '$specialty arıyor'
    : '${listing.wantedType.label} arıyor';

String _dateText(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} · '
      '${two(local.hour)}:${two(local.minute)}';
}
