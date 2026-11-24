import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/utils/turkish_date_label.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../notification/domain/entities/studio_reservation_notification_target.dart';
import '../../notification/presentation/notification_target_read.dart';
import '../../profile/presentation/navigation/studio_navigation.dart';
import '../../profile/presentation/screens/studio_listener_info_screen.dart';
import '../domain/entities/studio_reservation.dart';
import '../domain/studio_room_repository.dart';

class CustomerReservationsScreen extends StatelessWidget {
  const CustomerReservationsScreen({
    super.key,
    this.target,
    this.reservationId,
  });

  final StudioReservationNotificationTarget? target;
  final String? reservationId;

  @override
  Widget build(BuildContext context) => StudioListenerAccessGate(
    builder: (_) => _CustomerReservations(
      key: ValueKey(target?.reservationId ?? reservationId),
      repository: serviceLocator<StudioRoomRepository>(),
      reservationId: target?.reservationId ?? reservationId,
      target: target,
    ),
  );
}

class _CustomerReservations extends StatefulWidget {
  const _CustomerReservations({
    super.key,
    required this.repository,
    this.reservationId,
    this.target,
  });
  final StudioRoomRepository repository;
  final String? reservationId;
  final StudioReservationNotificationTarget? target;

  @override
  State<_CustomerReservations> createState() => _CustomerReservationsState();
}

class _CustomerReservationsState extends State<_CustomerReservations> {
  List<StudioReservation> _rows = const [];
  int _page = 0;
  int _generation = 0;
  bool _hasNext = false, _loading = true, _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  Future<void> _load(int page) async {
    final generation = ++_generation;
    setState(() {
      _page = page;
      _loading = true;
      _error = null;
    });
    final id = widget.reservationId;
    if (id != null) {
      final result = await widget.repository.getCustomerReservation(id);
      if (!mounted || generation != _generation) return;
      final row = result.data;
      final target = widget.target;
      final match =
          row != null &&
          row.id == id &&
          (target == null ||
              (row.roomId == target.roomId &&
                  row.studioProfileId == target.studioProfileId &&
                  row.localDate == target.localDate &&
                  row.startsAt.isAtSameMomentAs(target.startsAt) &&
                  row.endsAt.isAtSameMomentAs(target.endsAt)));
      setState(() {
        _loading = false;
        _rows = match ? [row] : [];
        if (!match) {
          _error = result.error?.message ?? 'Rezervasyon getirilemedi.';
        }
      });
      return;
    }
    final result = await widget.repository.listCustomerReservations(page: page);
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _error = result.error?.message;
      _rows = result.data?.items ?? [];
      _hasNext = result.data?.hasNext ?? false;
    });
  }

  Future<void> _cancel(StudioReservation row) async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    final confirmed = await showStudioDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Rezervasyon iptal edilsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      final result = await widget.repository.cancelCustomerReservation(
        reservationId: row.id,
        expectedVersion: row.version,
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: Text(
              result.error?.message ?? 'Rezervasyon iptal edilemedi.',
            ),
          ),
        );
      }
      await _load(_page);
    }
    if (mounted) setState(() => _cancelling = false);
  }

  Widget _card(StudioReservation row) {
    final date = DateTime.tryParse(row.localDate ?? '');
    final status = switch (row.status) {
      StudioReservationStatus.pendingApproval => 'Onay bekliyor',
      StudioReservationStatus.confirmed =>
        row.completed ? 'Tamamlandı' : 'Onaylandı',
      StudioReservationStatus.cancelledByCustomer => 'İptal ettin',
      StudioReservationStatus.cancelledByStudio => 'Stüdyo iptal etti',
      StudioReservationStatus.rejectedByStudio => 'Reddedildi',
      StudioReservationStatus.expired => 'Süresi doldu',
    };
    final period = [
      row.localStartTime?.substring(0, 5),
      row.localEndTime?.substring(0, 5),
    ].whereType<String>().join('–');
    final tile = Card(
      child: ListTile(
        title: Text(row.roomName ?? 'Stüdyo rezervasyonu'),
        subtitle: Text(
          [
            if (date != null) turkishDateLabel(date),
            if (period.isNotEmpty) period,
            status,
          ].join(' · '),
        ),
        trailing:
            !row.completed &&
                !row.status.isTerminal &&
                row.startsAt.isAfter(DateTime.now())
            ? TextButton(
                onPressed: _cancelling ? null : () => _cancel(row),
                child: const Text('İptal et'),
              )
            : null,
      ),
    );
    final target = widget.target;
    return target == null
        ? tile
        : NotificationTargetReady(
            contentIdentity: target,
            requireVisibleBounds: true,
            child: tile,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.reservationId == null
              ? 'Stüdyo rezervasyonlarım'
              : 'Stüdyo rezervasyonum',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: () => _load(_page),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_rows.isEmpty)
                  const Text('Henüz stüdyo rezervasyonun yok.'),
                ..._rows.map(_card),
                if (_page > 0 || _hasNext)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _page == 0 || _cancelling
                            ? null
                            : () => _load(_page - 1),
                        child: const Text('Önceki'),
                      ),
                      TextButton(
                        onPressed: !_hasNext || _cancelling
                            ? null
                            : () => _load(_page + 1),
                        child: const Text('Sonraki'),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
