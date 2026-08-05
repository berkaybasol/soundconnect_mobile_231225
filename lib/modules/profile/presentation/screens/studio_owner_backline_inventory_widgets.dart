part of 'studio_profile_screen.dart';

class _BacklineInventorySummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color accent;

  const _BacklineInventorySummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = const Color(0xFFD4D9E2),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ownerManagementCardBorderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF979FAA),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineInventoryFilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BacklineInventoryFilterButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BacklineOutlineChoice(
      icon: icon,
      label: label,
      selected: active,
      onTap: onTap,
    );
  }
}

class _BacklineInventoryManagementCard extends StatefulWidget {
  final _StudioBacklineInventoryItem item;
  final VoidCallback onManage;

  const _BacklineInventoryManagementCard({
    super.key,
    required this.item,
    required this.onManage,
  });

  @override
  State<_BacklineInventoryManagementCard> createState() =>
      _BacklineInventoryManagementCardState();
}

class _BacklineInventoryManagementCardState
    extends State<_BacklineInventoryManagementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final available = item.available;
    final busy = item.reserved;
    final maintenance = item.maintenance;
    final status = _statusFor(
      item,
      available: available,
      maintenance: maintenance,
    );
    return Container(
      decoration: BoxDecoration(
        color: _ownerManagementCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ownerManagementCardBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, _expanded ? 12 : 14, 12, 14),
              child: Row(
                crossAxisAlignment: _expanded
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  if (_expanded) ...[
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: _ownerManagementInsetColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _ownerManagementInsetBorderColor,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.photoUrls.isNotEmpty
                          ? AppCachedNetworkImage(
                              imageUrl: item.photoUrls.first,
                              fit: BoxFit.cover,
                              cacheProfile: AppImageCacheProfile.compact,
                              cacheWidth: 174,
                              cacheHeight: 174,
                              errorBuilder: (_) => Icon(
                                item.icon,
                                color: _roomFormIconColor,
                                size: 29,
                              ),
                            )
                          : Icon(
                              item.icon,
                              color: _roomFormIconColor,
                              size: 29,
                            ),
                    ),
                    const SizedBox(width: 11),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (_expanded) ...[
                              const SizedBox(width: 7),
                              _BacklineInventoryStatusPill(
                                label: status.$1,
                                color: status.$2,
                              ),
                            ],
                          ],
                        ),
                        if (_expanded) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFAAB1BC),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF7F8793),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF929BA8),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _BacklineInventoryCountCell(
                              label: 'Toplam',
                              value: item.total,
                            ),
                            const SizedBox(width: 7),
                            _BacklineInventoryCountCell(
                              label: 'Müsait',
                              value: available,
                              accent: const Color(0xFF62C98B),
                            ),
                            const SizedBox(width: 7),
                            _BacklineInventoryCountCell(
                              label: 'Dolu',
                              value: busy,
                              accent: const Color(0xFFF0C75E),
                            ),
                            const SizedBox(width: 7),
                            _BacklineInventoryCountCell(
                              label: 'Bakımda',
                              value: maintenance,
                              accent: const Color(0xFFE47B86),
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        _StudioActionButton(
                          icon: Icons.tune_rounded,
                          label: 'Ekipmanı Yönet',
                          outlined: true,
                          onTap: widget.onManage,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  static (String, Color) _statusFor(
    _StudioBacklineInventoryItem item, {
    required int available,
    required int maintenance,
  }) {
    if (maintenance == item.total) {
      return ('Bakımda', const Color(0xFFE47B86));
    }
    if (available == item.total) {
      return ('Müsait', const Color(0xFF62C98B));
    }
    if (available > 0) {
      return ('Kısmen Müsait', const Color(0xFFF0C75E));
    }
    return ('Dolu', const Color(0xFFC9A0E8));
  }
}

class _BacklineInventoryCountCell extends StatelessWidget {
  final String label;
  final int value;
  final Color accent;

  const _BacklineInventoryCountCell({
    required this.label,
    required this.value,
    this.accent = const Color(0xFFD4D9E2),
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _ownerManagementInsetColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ownerManagementInsetBorderColor),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF858D98),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BacklineInventoryStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _BacklineInventoryStatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BacklineInventoryEmptyState extends StatelessWidget {
  const _BacklineInventoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ownerManagementInsetBorderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: Color(0xFF89919D), size: 34),
          SizedBox(height: 10),
          Text(
            'Eşleşen ekipman bulunamadı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Arama metnini veya filtreleri değiştirerek tekrar dene.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF929AA6), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
