part of 'studio_profile_screen.dart';

extension _StudioRoomDetailData on _StudioRoomDetailScreenState {
  Future<void> _loadCalendarData({bool showLoading = true}) async {
    final generation = ++_calendarLoadGeneration;
    if (showLoading && mounted) {
      _setState(() {
        _calendarLoading = true;
        _calendarError = null;
      });
    }
    if (widget.canReserve) {
      final availabilityFuture = _repository.getPublicAvailability(
        studioProfileId: widget.studioProfileId,
        roomId: _room.id,
        from: _selectedDate,
        to: _selectedDate,
      );
      final reservationsFuture = _repository
          .listCustomerReservationsForRoomDate(
            roomId: _room.id,
            date: _selectedDate,
          );
      final result = await availabilityFuture;
      final reservationsResult = await reservationsFuture;
      if (!mounted || generation != _calendarLoadGeneration) return;
      if (!result.isSuccess ||
          result.data == null ||
          !reservationsResult.isSuccess ||
          reservationsResult.data == null) {
        _setState(() {
          _calendarLoading = false;
          _calendarError =
              result.error?.message ??
              reservationsResult.error?.message ??
              'Oda müsaitliği getirilemedi.';
        });
        return;
      }
      final customerReservations = <StudioReservation>[
        ...reservationsResult.data!.items,
      ];
      var reservationsPage = reservationsResult.data!;
      const maximumCustomerReservationPages = 20;
      while (reservationsPage.hasNext &&
          reservationsPage.pageIndex + 1 < maximumCustomerReservationPages) {
        final nextResult = await _repository
            .listCustomerReservationsForRoomDate(
              roomId: _room.id,
              date: _selectedDate,
              page: reservationsPage.pageIndex + 1,
            );
        if (!mounted || generation != _calendarLoadGeneration) return;
        final nextPage = nextResult.data;
        if (!nextResult.isSuccess || nextPage == null) {
          _setState(() {
            _calendarLoading = false;
            _calendarError =
                nextResult.error?.message ?? 'Rezervasyonların getirilemedi.';
          });
          return;
        }
        customerReservations.addAll(nextPage.items);
        reservationsPage = nextPage;
      }
      if (reservationsPage.hasNext) {
        _setState(() {
          _calendarLoading = false;
          _calendarError =
              'Bu gün için görüntülenemeyecek kadar çok rezervasyon kaydı var.';
        });
        return;
      }
      _setState(() {
        final availability = result.data!;
        _publicAvailability = availability;
        _customerReservations = List.unmodifiable(customerReservations);
        _bookingPolicy = StudioBookingCalendarPolicy(
          todayLocalDate: availability.todayLocalDate,
          currentLocalTime: availability.currentLocalTime,
          latestBookableLocalDateTime: availability.latestBookableLocalDateTime,
        );
        _calendarLoading = false;
        _calendarError = null;
      });
      return;
    }

    final from = _ownerDateWindowStart;
    final candidateTo = studioAddCivilDays(from, 4);
    final to = candidateTo.isAfter(_latestBookableDate)
        ? _latestBookableDate
        : candidateTo;
    final reservations = <StudioReservation>[];
    List<StudioOccupancy> occupancies = const [];
    StudioBookingCalendarPolicy? bookingPolicy;
    var pageIndex = 0;
    const maximumPagesPerLoad = 20;
    while (pageIndex < maximumPagesPerLoad) {
      final result = await _repository.getOwnerSchedule(
        roomId: _room.id,
        from: from,
        to: to,
        page: pageIndex,
        size: 100,
      );
      if (!mounted || generation != _calendarLoadGeneration) return;
      final schedule = result.data;
      if (!result.isSuccess || schedule == null) {
        _setState(() {
          _calendarLoading = false;
          _calendarError =
              result.error?.message ?? 'Rezervasyon takvimi getirilemedi.';
        });
        return;
      }
      reservations.addAll(schedule.reservations.items);
      occupancies = schedule.occupancies;
      bookingPolicy ??= StudioBookingCalendarPolicy(
        todayLocalDate: schedule.todayLocalDate,
        currentLocalTime: schedule.currentLocalTime,
        latestBookableLocalDateTime: schedule.latestBookableLocalDateTime,
      );
      if (!schedule.reservations.hasNext) break;
      pageIndex++;
    }
    if (!mounted || generation != _calendarLoadGeneration) return;
    if (pageIndex >= maximumPagesPerLoad) {
      _setState(() {
        _calendarLoading = false;
        _calendarError =
            'Bu tarih aralığında görüntülenemeyecek kadar çok talep var.';
      });
      return;
    }
    _setState(() {
      _scheduleReservations = List.unmodifiable(reservations);
      _scheduleOccupancies = List.unmodifiable(occupancies);
      _bookingPolicy = bookingPolicy;
      _calendarLoading = false;
      _calendarError = null;
    });
    _openInitialReservationSheetIfPossible();
  }

  void _openInitialReservationSheetIfPossible() {
    if (_initialReservationSheetHandled || !mounted) return;
    final reservationId = widget.initialReservationId?.trim() ?? '';
    if (reservationId.isEmpty) {
      _initialReservationSheetHandled = true;
      return;
    }
    StudioReservation? domainReservation;
    for (final reservation in _scheduleReservations) {
      if (reservation.id == reservationId) {
        domainReservation = reservation;
        break;
      }
    }
    if (domainReservation == null) return;
    _initialReservationSheetHandled = true;
    final reservation = _StudioOwnerReservation.fromDomain(
      domainReservation,
      evaluatedAt: _studioClockNow,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showOwnerReservationActions(reservation);
    });
  }

  void _showCalendarError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearPendingReservationRequest() {
    _pendingReservationPayloadKey = null;
    _pendingReservationRequestId = null;
  }
}
