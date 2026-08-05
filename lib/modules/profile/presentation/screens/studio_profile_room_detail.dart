part of 'studio_profile_screen.dart';

enum _StudioPublicRoomSlotState {
  available,
  occupied,
  reservedByMe,
  pendingByMe,
  past,
}

class _StudioRoomDetailScreen extends StatefulWidget {
  final _StudioRoomItem room;
  final String studioProfileId;
  final bool canReserve;
  final List<_StudioRoomItem> ownerRooms;
  final DateTime? initialDate;
  final String? initialReservationId;

  const _StudioRoomDetailScreen({
    required this.room,
    required this.studioProfileId,
    required this.canReserve,
    this.ownerRooms = const [],
    this.initialDate,
    this.initialReservationId,
  });

  @override
  State<_StudioRoomDetailScreen> createState() =>
      _StudioRoomDetailScreenState();
}

class _StudioRoomDetailScreenState extends State<_StudioRoomDetailScreen> {
  final StudioRoomRepository _repository =
      serviceLocator<StudioRoomRepository>();
  final PageController _pageController = PageController();
  final PageController _ownerRoomPageController = PageController();
  late DateTime _selectedDate;
  late DateTime _selectedOwnerOverviewDate;
  late DateTime _ownerDateWindowStart;
  StudioBookingCalendarPolicy? _bookingPolicy;
  int _activePhoto = 0;
  String? _selectedTime;
  int _durationHours = 1;
  late int _selectedRoomIndex;
  StudioRoomAvailability? _publicAvailability;
  List<StudioReservation> _customerReservations = const [];
  List<StudioReservation> _scheduleReservations = const [];
  List<StudioOccupancy> _scheduleOccupancies = const [];
  bool _calendarLoading = true;
  bool _calendarMutationInFlight = false;
  String? _calendarError;
  int _calendarLoadGeneration = 0;
  String? _pendingReservationRequestId;
  String? _pendingReservationPayloadKey;
  bool _reservationSubmitting = false;
  final Map<String, String> _manualBlockRequestIds = {};
  bool _initialReservationSheetHandled = false;

  static const _times = <String>[
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
  ];

  _StudioRoomItem get _room => widget.ownerRooms.isEmpty
      ? widget.room
      : widget.ownerRooms[_selectedRoomIndex];

  List<_StudioRoomItem> get _managedRooms =>
      widget.ownerRooms.isEmpty ? [widget.room] : widget.ownerRooms;

  List<String> get _photos => _room.photoUrls.take(10).toList();

  DateTime get _studioToday =>
      _bookingPolicy?.todayLocalDate ?? _room.todayLocalDate;

  DateTime get _latestBookableDate =>
      _bookingPolicy?.latestBookableLocalDate ??
      studioAddCivilDays(_studioToday, 365);

  DateTime? get _studioClockNow {
    final current = _bookingPolicy?.currentLocalDateTime;
    if (current == null) return null;
    return DateTime.utc(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedRoomIndex = 0;
    final today = _dateOnly(widget.room.todayLocalDate);
    final requestedDate = widget.initialDate == null
        ? today
        : _dateOnly(widget.initialDate!);
    final initialDate = requestedDate.isBefore(today) ? today : requestedDate;
    _selectedDate = initialDate;
    _selectedOwnerOverviewDate = initialDate;
    _ownerDateWindowStart = initialDate;
    _loadCalendarData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ownerRoomPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _StudioRoomDetailHeader(
              title: widget.ownerRooms.isNotEmpty
                  ? 'Rezervasyon Yönetimi'
                  : _room.name,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.canReserve) ...[
                      _buildOwnerReservationOverview(),
                    ],
                    if (widget.canReserve) ...[
                      _buildGallery(),
                      const SizedBox(height: 18),
                      _buildIdentity(),
                      const SizedBox(height: 14),
                      _buildFeatures(),
                      const SizedBox(height: 16),
                    ],
                    if (!widget.canReserve) ...[const SizedBox(height: 16)],
                    _buildAvailability(),
                    const SizedBox(height: 16),
                    if (widget.canReserve) _buildReservationSummary(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setState(VoidCallback callback) => setState(callback);

  static String? _reservationPhoneError(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Telefon numarası zorunludur.';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11 || !digits.startsWith('0')) {
      return 'Numara 0 ile başlayan 11 rakam olmalıdır.';
    }
    return null;
  }

  static String _phonePayloadKey(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');

  static String _apiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static int _localHour(String? value, DateTime fallback) {
    final normalized = value?.trim() ?? '';
    if (normalized.length >= 2) {
      final parsed = int.tryParse(normalized.substring(0, 2));
      if (parsed != null) return parsed;
    }
    return fallback.toLocal().hour;
  }

  static String _localDateKey(String? value, DateTime fallback) {
    final normalized = value?.trim() ?? '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
      return normalized;
    }
    return _apiDate(fallback.toLocal());
  }

  static String _reservationDateKey(StudioReservation reservation) =>
      _localDateKey(reservation.localDate, reservation.startsAt);

  static String _occupancyDateKey(StudioOccupancy occupancy) =>
      _localDateKey(occupancy.localDate, occupancy.startsAt);

  static String _intervalDateKey(StudioUnavailableInterval interval) =>
      _localDateKey(interval.localDate, interval.startsAt);

  static int _occupancyStartHour(StudioOccupancy occupancy) =>
      _localHour(occupancy.localStartTime, occupancy.startsAt);

  static int _occupancyEndHour(StudioOccupancy occupancy) =>
      _localHour(occupancy.localEndTime, occupancy.endsAt);

  static int _intervalStartHour(StudioUnavailableInterval interval) =>
      _localHour(interval.localStartTime, interval.startsAt);

  static int _intervalEndHour(StudioUnavailableInterval interval) =>
      _localHour(interval.localEndTime, interval.endsAt);

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _formatDate(DateTime date) {
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
}
