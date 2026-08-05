part of 'studio_profile_screen.dart';

class _StudioManualEndTimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StudioManualEndTimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _studioManualBusyColor.withValues(alpha: 0.14)
              : const Color(0xFF0A101A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _studioManualBusyColor : const Color(0xFF263244),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFFFB5BD) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StudioReservationActionSheet extends StatelessWidget {
  final _StudioOwnerReservation reservation;
  final String roomName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onShowDetails;
  final Future<DmProfileTarget?> profileTarget;
  final ValueChanged<DmProfileTarget> onShowProfile;
  final VoidCallback onSendMessage;
  final VoidCallback onCancel;

  const _StudioReservationActionSheet({
    required this.reservation,
    required this.roomName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.onApprove,
    required this.onReject,
    required this.onShowDetails,
    required this.profileTarget,
    required this.onShowProfile,
    required this.onSendMessage,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final capabilities = reservation.capabilities;
    final statusColor = capabilities.hasMutation
        ? reservation.approved
              ? _studioReservationApprovedColor
              : _studioReservationPendingColor
        : const Color(0xFF9EA8B7);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0xFF2A3546))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF465267),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _StudioReservationGuestHeader(
              reservation: reservation,
              roomName: roomName,
              startTime: startTime,
              endTime: endTime,
              statusLabel: reservation.statusLabel,
              statusColor: statusColor,
              profileTarget: profileTarget,
              onShowProfile: (target) =>
                  _closeThen(context, () => onShowProfile(target)),
            ),
            const SizedBox(height: 18),
            if (capabilities.canApprove) ...[
              _StudioReservationSheetAction(
                icon: Icons.check_circle_outline_rounded,
                label: 'Rezervasyonu Onayla',
                color: _studioReservationApprovedColor,
                emphasized: true,
                onTap: () => _closeThen(context, onApprove),
              ),
              const SizedBox(height: 8),
            ],
            _StudioReservationSheetAction(
              icon: Icons.receipt_long_outlined,
              label: 'Rezervasyon Bilgileri',
              onTap: () => _closeThen(context, onShowDetails),
            ),
            const SizedBox(height: 8),
            _StudioReservationSheetAction(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Kullanıcıya Mesaj Gönder',
              onTap: () => _closeThen(context, onSendMessage),
            ),
            if (capabilities.canReject ||
                (reservation.approved && capabilities.canCancel)) ...[
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF263244), height: 1),
              const SizedBox(height: 14),
              if (capabilities.canReject)
                _StudioReservationSheetAction(
                  icon: Icons.cancel_outlined,
                  label: 'Talebi Reddet',
                  color: const Color(0xFFFF7373),
                  onTap: () => _closeThen(context, onReject),
                )
              else
                _StudioReservationSheetAction(
                  icon: Icons.event_busy_outlined,
                  label: 'Rezervasyonu İptal Et',
                  color: const Color(0xFFFF7373),
                  onTap: () => _closeThen(context, onCancel),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _closeThen(BuildContext context, VoidCallback callback) {
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero, callback);
  }
}

class _StudioReservationGuestHeader extends StatelessWidget {
  const _StudioReservationGuestHeader({
    required this.reservation,
    required this.roomName,
    required this.startTime,
    required this.endTime,
    required this.statusLabel,
    required this.statusColor,
    required this.profileTarget,
    required this.onShowProfile,
  });

  final _StudioOwnerReservation reservation;
  final String roomName;
  final String startTime;
  final String endTime;
  final String statusLabel;
  final Color statusColor;
  final Future<DmProfileTarget?> profileTarget;
  final ValueChanged<DmProfileTarget> onShowProfile;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DmProfileTarget?>(
      future: profileTarget,
      builder: (context, snapshot) {
        final target = snapshot.data;
        final onProfileTap = target == null
            ? null
            : () => onShowProfile(target);
        return Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: _StudioReservationAvatar(
                reservation: reservation,
                onTap: onProfileTap,
                avatarUrlOverride: target?.imageUrl,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$roomName • $startTime–$endTime',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFA2ACBA),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withValues(alpha: 0.45)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudioReservationSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;
  final VoidCallback onTap;

  const _StudioReservationSheetAction({
    required this.icon,
    required this.label,
    this.color = const Color(0xFFD7DCE5),
    this.emphasized = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? color.withValues(alpha: 0.10)
          : const Color(0xFF101A28),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: emphasized
                  ? color.withValues(alpha: 0.42)
                  : const Color(0xFF263244),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioReservationDetailsDialog extends StatelessWidget {
  final _StudioOwnerReservation reservation;
  final String roomName;
  final DateTime date;
  final String startTime;
  final String endTime;

  const _StudioReservationDetailsDialog({
    required this.reservation,
    required this.roomName,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF101722),
      title: const Text('Rezervasyon Bilgileri'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StudioReservationDetailRow(
            label: 'Kullanıcı',
            value: reservation.userName,
          ),
          if (reservation.phoneNumber != null)
            _StudioReservationDetailRow(
              label: 'Telefon',
              value: reservation.phoneNumber!,
            ),
          _StudioReservationDetailRow(label: 'Oda', value: roomName),
          _StudioReservationDetailRow(
            label: 'Tarih',
            value: _studioReservationDateLabel(date),
          ),
          _StudioReservationDetailRow(
            label: 'Saat',
            value: '$startTime–$endTime',
          ),
          _StudioReservationDetailRow(
            label: 'Süre',
            value: '${reservation.durationHours} saat',
          ),
          if (reservation.totalPriceLabel != null)
            _StudioReservationDetailRow(
              label: 'Toplam',
              value: reservation.totalPriceLabel!,
            ),
          _StudioReservationDetailRow(
            label: 'Durum',
            value: reservation.statusLabel,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _StudioReservationDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _StudioReservationDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF8F99A9), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _studioReservationDateLabel(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _StudioRoomDurationChip extends StatelessWidget {
  final int hours;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _StudioRoomDurationChip({
    required this.hours,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2A172A)
              : enabled
              ? const Color(0xFF0A101A)
              : const Color(0xFF090D14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.socialPink
                : enabled
                ? const Color(0xFF263244)
                : const Color(0xFF1A2230),
          ),
        ),
        child: Text(
          '$hours sa',
          style: TextStyle(
            color: selected
                ? const Color(0xFFFF9AAE)
                : enabled
                ? Colors.white
                : const Color(0xFF596271),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StudioRoomReservationRow extends StatelessWidget {
  final String label;
  final String value;

  const _StudioRoomReservationRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8E98A7), fontSize: 12),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudioRoomReserveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _StudioRoomReserveButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: enabled ? null : const Color(0xFF252B35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton.icon(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.event_available_outlined, size: 19),
        label: const Text(
          'Rezervasyon Oluştur',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _StudioRoomSwipeCue extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _StudioRoomSwipeCue({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 40),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        icon,
        size: 23,
        color: const Color(0xFFAEB7C5),
        shadows: const [Shadow(color: Color(0xCC05080D), blurRadius: 7)],
      ),
    );
  }
}

class _StudioOwnerRoomSummaryCard extends StatelessWidget {
  final _StudioRoomItem room;
  final int reservationCount;
  final int occupiedHours;

  const _StudioOwnerRoomSummaryCard({
    required this.room,
    required this.reservationCount,
    required this.occupiedHours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1622),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: room.gradient),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(room.icon, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (room.type.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        room.type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9EA8B7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StudioOwnerRoomMetric(
                  value: '$reservationCount',
                  label: 'Rezervasyon',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StudioOwnerRoomMetric(
                  value: '$occupiedHours saat',
                  label: 'Dolu Süre',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudioOwnerRoomMetric extends StatelessWidget {
  final String value;
  final String label;

  const _StudioOwnerRoomMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF090F18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8F99A9), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _StudioOwnerReservationDateCard extends StatelessWidget {
  final DateTime date;
  final int reservationCount;
  final bool selected;
  final VoidCallback onTap;

  const _StudioOwnerReservationDateCard({
    required this.date,
    required this.reservationCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF17202D) : const Color(0xFF0D141F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFFF8A8A) : const Color(0xFF263244),
          ),
        ),
        child: Column(
          children: [
            Text(
              _ownerOverviewWeekday(date.weekday),
              style: const TextStyle(color: Color(0xFF9EA8B7), fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              date.day.toString(),
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFD5DBE5),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reservationCount == 0 ? 'Boş' : '$reservationCount kayıt',
              style: TextStyle(
                color: reservationCount == 0
                    ? const Color(0xFF7F8998)
                    : const Color(0xFF67D6A1),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameRoomOverviewDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _ownerOverviewWeekday(int weekday) =>
    const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][weekday - 1];
