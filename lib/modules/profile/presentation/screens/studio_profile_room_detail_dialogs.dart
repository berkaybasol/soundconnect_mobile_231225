part of 'studio_profile_screen.dart';

class _StudioReservationConfirmDialog extends StatefulWidget {
  const _StudioReservationConfirmDialog({
    required this.roomName,
    required this.dateLabel,
    required this.startTime,
    required this.durationHours,
  });

  final String roomName;
  final String dateLabel;
  final String startTime;
  final int durationHours;

  @override
  State<_StudioReservationConfirmDialog> createState() =>
      _StudioReservationConfirmDialogState();
}

class _StudioReservationConfirmDialogState
    extends State<_StudioReservationConfirmDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: '0')
      ..selection = const TextSelection.collapsed(offset: 1);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_phoneController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AlertDialog(
        backgroundColor: const Color(0xFF101722),
        title: const Text('Rezervasyonu Onayla'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.roomName}\n${widget.dateLabel} • '
                '${widget.startTime}\n${widget.durationHours} saat',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.done,
                inputFormatters: const [_TurkishMobilePhoneFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Telefon numarası',
                  hintText: '0 534 576 27 72',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: _StudioRoomDetailScreenState._reservationPhoneError,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Text(
                'Stüdyo bu numarayı yalnızca rezervasyonunuz için görebilir.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              const Text(
                'Ödeme yöntemi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const _StudioReservationPaymentOption(
                icon: Icons.payments_outlined,
                title: 'Elden ödeme yapacağım',
                subtitle: 'Ödeme stüdyo ile doğrudan gerçekleştirilir.',
                selected: true,
              ),
              const SizedBox(height: 8),
              const _StudioReservationPaymentOption(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Online ödeme yapacağım',
                subtitle: 'Ödeme uygulama üzerinden gerçekleştirilir.',
                comingSoon: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Rezervasyon Oluştur'),
          ),
        ],
      ),
    );
  }
}

class _StudioReservationPaymentOption extends StatelessWidget {
  const _StudioReservationPaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFFFF7F87)
        : const Color(0xFF2A3547);
    return Opacity(
      opacity: comingSoon ? 0.68 : 1,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1520),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: _roomFormIconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (comingSoon) ...[
                        const SizedBox(width: 7),
                        const _StudioComingSoonBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF98A2B1),
                      fontSize: 9.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? const Color(0xFFFF7F87)
                  : const Color(0xFF667184),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _TurkishMobilePhoneFormatter extends TextInputFormatter {
  const _TurkishMobilePhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (newValue.text.trimLeft().startsWith('+90') && digits.startsWith('90')) {
      digits = '0${digits.substring(2)}';
    } else if (digits.isEmpty) {
      digits = '0';
    } else if (!digits.startsWith('0')) {
      digits = '0$digits';
    }
    if (digits.length > 11) digits = digits.substring(0, 11);
    final formatted = _formatReservationPhone(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatReservationPhone(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('90')) {
    digits = '0${digits.substring(2)}';
  }
  if (digits.length != 11 || !digits.startsWith('0')) {
    return value.trim();
  }
  return '${digits.substring(0, 1)} '
      '${digits.substring(1, 4)} '
      '${digits.substring(4, 7)} '
      '${digits.substring(7, 9)} '
      '${digits.substring(9, 11)}';
}

class _StudioRoomDetailHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _StudioRoomDetailHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Geri',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _StudioRoomPhotoPlaceholder extends StatelessWidget {
  final _StudioRoomItem room;

  const _StudioRoomPhotoPlaceholder({required this.room});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: room.gradient,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -28,
            bottom: -36,
            child: Icon(
              room.icon,
              size: 180,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Icon(room.icon, color: Colors.white, size: 58),
          const Positioned(
            right: 12,
            bottom: 10,
            child: Text(
              'Fotoğraf yakında',
              style: TextStyle(
                color: Color(0xFFCDD3DE),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomDetailCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _StudioRoomDetailCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(color: Color(0xFF8E98A7), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StudioRoomDetailMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StudioRoomDetailMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StudioSocialGradientIcon(icon, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD5DBE5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioRoomDateSelector extends StatelessWidget {
  final DateTime date;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _StudioRoomDateSelector({
    required this.date,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CalendarArrowButton(
          icon: Icons.arrow_back,
          onTap: canGoBack ? onPrevious : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPick,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF0A101A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF263244)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFFF06C86),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _StudioRoomDetailScreenState._formatDate(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _CalendarArrowButton(
          icon: Icons.arrow_forward,
          onTap: canGoForward ? onNext : null,
        ),
      ],
    );
  }
}

class _StudioManualBusyRange {
  final String id;
  final int startIndex;
  final int endIndex;
  final int version;

  const _StudioManualBusyRange({
    required this.id,
    required this.startIndex,
    required this.endIndex,
    required this.version,
  });

  factory _StudioManualBusyRange.fromDomain(StudioOccupancy occupancy) {
    return _StudioManualBusyRange(
      id: occupancy.id,
      startIndex:
          _StudioRoomDetailScreenState._occupancyStartHour(occupancy) - 9,
      endIndex: _StudioRoomDetailScreenState._occupancyEndHour(occupancy) - 9,
      version: occupancy.version,
    );
  }

  int get durationHours => endIndex - startIndex;

  bool contains(int index) => index >= startIndex && index < endIndex;
}

String _manualHourLabel(int index) =>
    '${(9 + index).toString().padLeft(2, '0')}:00';

class _StudioOwnerReservation {
  final String id;
  final String userId;
  final String? phoneNumber;
  final String userName;
  final String avatarUrl;
  final int startIndex;
  final int durationHours;
  final StudioReservationStatus status;
  final DateTime startsAt;
  final DateTime? evaluatedAt;
  final bool completed;
  final int version;
  final int? totalPriceMinor;
  final String? currency;

  const _StudioOwnerReservation({
    required this.id,
    required this.userId,
    required this.phoneNumber,
    required this.userName,
    required this.avatarUrl,
    required this.startIndex,
    required this.durationHours,
    required this.status,
    required this.startsAt,
    required this.evaluatedAt,
    required this.completed,
    required this.version,
    required this.totalPriceMinor,
    required this.currency,
  });

  factory _StudioOwnerReservation.fromDomain(
    StudioReservation reservation, {
    required DateTime? evaluatedAt,
  }) {
    final startHour = _StudioRoomDetailScreenState._localHour(
      reservation.localStartTime,
      reservation.startsAt,
    );
    final endHour = _StudioRoomDetailScreenState._localHour(
      reservation.localEndTime,
      reservation.endsAt,
    );
    return _StudioOwnerReservation(
      id: reservation.id,
      userId: reservation.requesterId ?? '',
      phoneNumber: reservation.requesterPhone == null
          ? null
          : _formatReservationPhone(reservation.requesterPhone!),
      userName: reservation.requesterUsername ?? 'SoundConnect Kullanıcısı',
      avatarUrl: reservation.requesterAvatarUrl ?? '',
      startIndex: startHour - 9,
      durationHours: endHour - startHour,
      status: reservation.status,
      startsAt: _localWallClockStart(reservation),
      evaluatedAt: evaluatedAt,
      completed: reservation.completed,
      version: reservation.version,
      totalPriceMinor: reservation.totalPriceMinor,
      currency: reservation.currency,
    );
  }

  bool get approved => status.isConfirmed;

  StudioReservationOwnerCapabilities get capabilities =>
      StudioReservationOwnerCapabilities.evaluate(
        status: status,
        startsAt: startsAt,
        completed: completed,
        now: evaluatedAt,
      );

  String get statusLabel {
    if (completed) return 'Tamamlandı';
    final now = evaluatedAt;
    if (now == null) {
      return status.isConfirmed ? 'Onaylı' : 'Onay Bekliyor';
    }
    if (!startsAt.isAfter(now)) {
      return status.isConfirmed ? 'Devam Ediyor' : 'Süresi Geçti';
    }
    return status.isConfirmed ? 'Onaylı' : 'Onay Bekliyor';
  }

  static DateTime _localWallClockStart(StudioReservation reservation) {
    final date = DateTime.tryParse(reservation.localDate ?? '');
    final time = reservation.localStartTime?.trim() ?? '';
    final parts = time.split(':');
    final hour = parts.isEmpty ? null : int.tryParse(parts[0]);
    final minute = parts.length < 2 ? null : int.tryParse(parts[1]);
    if (date == null || hour == null || minute == null) {
      return reservation.startsAt.toUtc();
    }
    return DateTime.utc(date.year, date.month, date.day, hour, minute);
  }

  String? get totalPriceLabel {
    final minor = totalPriceMinor;
    if (minor == null) return null;
    final whole = minor ~/ 100;
    final fraction = minor.remainder(100);
    final grouped = whole.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final amount = fraction == 0
        ? grouped
        : '$grouped,${fraction.toString().padLeft(2, '0')}';
    return currency == 'TRY' || currency == null
        ? '₺$amount'
        : '$amount $currency';
  }
}

const _studioReservationApprovedColor = Color(0xFF49C98A);
const _studioReservationPendingColor = Color(0xFFB58A4E);
const _studioManualBusyColor = Color(0xFFB96873);
