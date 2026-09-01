part of 'table_group_list_screen.dart';

class _TableGroupListCard extends StatelessWidget {
  final TableGroup group;
  final VoidCallback onOpenDetail;
  final String meetingTimeText;

  _TableGroupListCard({
    required this.group,
    required this.onOpenDetail,
    required this.meetingTimeText,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedVenue = group.venueName?.trim();
    final venue = normalizedVenue?.isNotEmpty == true
        ? normalizedVenue!
        : TableGroupOverviewStyle.unspecifiedVenueLabel;
    final description = group.description?.trim();
    final title = description?.isNotEmpty == true
        ? description!
        : 'Masa buluşması';
    final username = _resolveUsername(group);
    final avatarUrl = _validUrlOrNull(group.ownerProfileImageUrl);
    final initials = _initialsFrom(username);
    final acceptedCount = (group.acceptedCount < 1 ? 1 : group.acceptedCount)
        .clamp(0, group.maxPersonCount);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactLayout =
        MediaQuery.sizeOf(context).width >= 360 && textScale <= 1.4;
    final topRowHeight = textScale > 1.8
        ? 86.0
        : compactLayout
        ? 60.0
        : 68.0;
    final avatarSize = compactLayout ? 58.0 : 68.0;
    final metadataLeft = compactLayout ? 72.0 : 82.0;
    final locationText = _tableGroupLocationLabel(group);
    final detailSemanticsLabel = <String>[
      title,
      'Mekân $venue',
      locationText,
      '$acceptedCount/${group.maxPersonCount} kişi',
      meetingTimeText == '--:--'
          ? 'Buluşma saati belirtilmemiş'
          : 'Buluşma saati $meetingTimeText',
      'Detayları aç',
    ].join('. ');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compactLayout ? 4 : 6),
      child: Semantics(
        key: ValueKey<String>('table_group_open_detail-${group.id}'),
        container: true,
        button: true,
        label: detailSemanticsLabel,
        onTap: onOpenDetail,
        child: ExcludeSemantics(
          child: Container(
            key: ValueKey<String>('table_group_card-${group.id}'),
            decoration: BoxDecoration(
              gradient: TableGroupOverviewStyle.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TableGroupOverviewStyle.cardBorder),
              boxShadow: TableGroupOverviewStyle.cardShadows,
            ),
            child: Material(
              key: ValueKey<String>('table_group_card_surface-${group.id}'),
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpenDetail,
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(12),
                splashColor: AppColors.gradientC.withValues(alpha: 0.10),
                highlightColor: AppColors.gradientC.withValues(alpha: 0.06),
                child: Column(
                  key: ValueKey<String>('table_group_metadata-${group.id}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        17,
                        compactLayout ? 12 : 18,
                        6,
                        0,
                      ),
                      child: SizedBox(
                        height: topRowHeight,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final metadataRight =
                                (constraints.maxWidth - metadataLeft - 227)
                                    .clamp(28.0, 60.0);
                            return Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _OwnerAvatar(
                                    groupId: group.id,
                                    imageUrl: avatarUrl,
                                    initials: initials,
                                    size: avatarSize,
                                  ),
                                ),
                                Positioned(
                                  left: metadataLeft,
                                  right: metadataRight,
                                  top: 0,
                                  bottom: 0,
                                  child: Transform.translate(
                                    offset: Offset(0, compactLayout ? 1 : 4),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _TableGroupDescriptionTitle(
                                            groupId: group.id,
                                            description: title,
                                          ),
                                          const SizedBox(height: 2),
                                          _TableGroupLocationLine(group: group),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: compactLayout ? -4 : -8,
                                  right: 0,
                                  child: _TableGroupDetailAffordance(
                                    groupId: group.id,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        9,
                        compactLayout ? 6 : 14,
                        9,
                        compactLayout ? 5 : 7,
                      ),
                      child: _TableGroupStatsStrip(
                        group: group,
                        venue: venue,
                        meetingTimeText: meetingTimeText,
                        acceptedCount: acceptedCount,
                        compactLayout: compactLayout,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveUsername(TableGroup group) {
    final fromBackend = group.ownerUsername?.trim();
    if (fromBackend != null && fromBackend.isNotEmpty) return fromBackend;
    final owner = group.ownerId.trim();
    if (owner.isEmpty) return 'Kullanici';
    return owner.length <= 8 ? owner : owner.substring(0, 8);
  }

  String _initialsFrom(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final first = words.first;
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.toUpperCase();
    }
    return (words.first[0] + words[1][0]).toUpperCase();
  }

  String? _validUrlOrNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty) {
      return null;
    }
    return text;
  }
}

class _TableGroupDescriptionTitle extends StatelessWidget {
  const _TableGroupDescriptionTitle({
    required this.groupId,
    required this.description,
  });

  final String groupId;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Text(
      description,
      key: ValueKey<String>('table_group_description_title-$groupId'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: TableGroupOverviewStyle.primaryText,
        fontSize: 18.5,
        height: 1.18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _TableGroupDetailAffordance extends StatelessWidget {
  const _TableGroupDetailAffordance({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey<String>('table_group_detail_affordance-$groupId'),
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          'Detay',
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: TableGroupOverviewStyle.bodyMuted,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 2),
        Icon(
          Icons.chevron_right_rounded,
          size: 22,
          color: TableGroupOverviewStyle.bodyMuted,
        ),
      ],
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({
    required this.groupId,
    required this.imageUrl,
    required this.initials,
    required this.size,
  });

  final String groupId;
  final String? imageUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageSize = size - 3;
    return Container(
      key: ValueKey<String>('table_group_owner_avatar-$groupId'),
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7A45), Color(0xFF8B2CFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B2CFF).withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: AppCachedNetworkImage(
          key: ValueKey<String>('table_group_owner_image-$groupId'),
          imageUrl: imageUrl,
          width: imageSize,
          height: imageSize,
          cacheWidth: (imageSize * 3).round(),
          cacheHeight: (imageSize * 3).round(),
          placeholderBuilder: (context) => _fallback(),
          errorBuilder: (context) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      key: ValueKey<String>('table_group_owner_fallback-$groupId'),
      color: const Color(0xFF070B13),
      child: Center(
        child: Text(
          initials,
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size < 60 ? 16 : 18,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _TableGroupStatsStrip extends StatelessWidget {
  const _TableGroupStatsStrip({
    required this.group,
    required this.venue,
    required this.meetingTimeText,
    required this.acceptedCount,
    required this.compactLayout,
  });

  final TableGroup group;
  final String venue;
  final String meetingTimeText;
  final int acceptedCount;
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('table_group_stats_strip-${group.id}'),
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compactLayout ? 6 : 10,
      ),
      decoration: BoxDecoration(
        gradient: TableGroupOverviewStyle.insetGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TableGroupOverviewStyle.insetBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedLayout =
              constraints.maxWidth < 255 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.8;
          final venueAndTime = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _TableGroupVenueLine(groupId: group.id, venue: venue),
              ),
              const _TableGroupStatDivider(),
              _TableGroupMeetingTime(groupId: group.id, text: meetingTimeText),
            ],
          );
          final participantSlots = _TableGroupParticipantSlots(
            groupId: group.id,
            acceptedCount: acceptedCount,
            maxPersonCount: group.maxPersonCount,
          );
          final capacityText = _TableGroupCapacity(
            groupId: group.id,
            text: '$acceptedCount/${group.maxPersonCount} kişi',
          );

          if (useStackedLayout) {
            return Column(
              key: ValueKey<String>('table_group_stats_stacked-${group.id}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                venueAndTime,
                const SizedBox(height: 10),
                Row(
                  children: [
                    participantSlots,
                    const SizedBox(width: 9),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: capacityText,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            key: ValueKey<String>('table_group_stats_inline-${group.id}'),
            children: [
              Expanded(
                flex: 3,
                child: _TableGroupVenueLine(groupId: group.id, venue: venue),
              ),
              const _TableGroupStatDivider(),
              _TableGroupMeetingTime(groupId: group.id, text: meetingTimeText),
              const _TableGroupStatDivider(),
              Expanded(
                flex: 5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      participantSlots,
                      const SizedBox(width: 9),
                      capacityText,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TableGroupStatDivider extends StatelessWidget {
  const _TableGroupStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 23,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: TableGroupOverviewStyle.divider,
    );
  }
}

class _TableGroupVenueLine extends StatelessWidget {
  const _TableGroupVenueLine({required this.groupId, required this.venue});

  final String groupId;
  final String venue;

  @override
  Widget build(BuildContext context) {
    final isUnspecified =
        venue == TableGroupOverviewStyle.unspecifiedVenueLabel;
    final venueText = Text(
      venue,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: TableGroupOverviewStyle.bodyMuted,
        fontSize: 13.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 110),
      child: Row(
        key: ValueKey<String>('table_group_venue_line-$groupId'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandGradientIcon(Icons.storefront_outlined, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: isUnspecified
                ? FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: venueText,
                  )
                : venueText,
          ),
        ],
      ),
    );
  }
}

class _TableGroupLocationLine extends StatelessWidget {
  const _TableGroupLocationLine({required this.group});

  final TableGroup group;

  @override
  Widget build(BuildContext context) {
    final label = _tableGroupLocationLabel(group);
    return Row(
      key: ValueKey<String>('table_group_location-${group.id}'),
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 18,
          color: TableGroupOverviewStyle.bodyMuted,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TableGroupOverviewStyle.bodyMuted,
              fontSize: 13.5,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TableGroupMeetingTime extends StatelessWidget {
  const _TableGroupMeetingTime({required this.groupId, required this.text});

  final String groupId;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey<String>('table_group_meeting_time-$groupId'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandGradientIcon(Icons.schedule_rounded, size: 19),
        const SizedBox(width: 7),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: TableGroupOverviewStyle.bodyMuted,
            fontSize: 13.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TableGroupCapacity extends StatelessWidget {
  const _TableGroupCapacity({required this.groupId, required this.text});

  final String groupId;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: ValueKey<String>('table_group_capacity-$groupId'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: TableGroupOverviewStyle.bodyMuted,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _TableGroupParticipantSlots extends StatelessWidget {
  final String groupId;
  final int acceptedCount;
  final int maxPersonCount;

  const _TableGroupParticipantSlots({
    required this.groupId,
    required this.acceptedCount,
    required this.maxPersonCount,
  });

  @override
  Widget build(BuildContext context) {
    final safeCapacity = maxPersonCount.clamp(0, 6);
    final safeAccepted = acceptedCount.clamp(0, safeCapacity);
    return Row(
      key: ValueKey<String>('table_group_participant_slots-$groupId'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < safeCapacity; index++) ...[
          BrandGradientIcon(
            index < safeAccepted
                ? Icons.person_rounded
                : Icons.person_outline_rounded,
            key: ValueKey<String>(
              index < safeAccepted
                  ? 'table_group_filled_slot-$groupId-$index'
                  : 'table_group_empty_slot-$groupId-$index',
            ),
            size: 19,
          ),
          if (index != safeCapacity - 1) const SizedBox(width: 1),
        ],
      ],
    );
  }
}

String _tableGroupLocationLabel(TableGroup group) {
  final district = group.district?.name.trim();
  final city = group.city.name.trim();
  if (district != null && district.isNotEmpty && city.isNotEmpty) {
    return '$district · $city';
  }
  if (district != null && district.isNotEmpty) return district;
  return city.isEmpty ? 'Konum belirtilmedi' : city;
}

class _CreateTableFab extends StatefulWidget {
  final Future<void> Function() onTap;
  final ValueChanged<Offset> onDragDelta;

  _CreateTableFab({required this.onTap, required this.onDragDelta});

  @override
  State<_CreateTableFab> createState() => _CreateTableFabState();
}

class _CreateTableFabState extends State<_CreateTableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1150),
    );
    _scale = Tween<double>(
      begin: 0.98,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('table_group_create_fab'),
      onTap: widget.onTap,
      onPanUpdate: (details) => widget.onDragDelta(details.delta),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 145,
              height: 50,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 12),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pureBlack.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Masa oluşturmak\niçin buraya tıklayın',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient.last.withValues(alpha: 0.42),
                    blurRadius: 16,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(
                Icons.groups_2_rounded,
                color: AppColors.white,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
