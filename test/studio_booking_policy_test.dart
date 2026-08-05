import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_reservation.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_booking_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_civil_date.dart';

void main() {
  group('StudioBookingCalendarPolicy', () {
    final policy = StudioBookingCalendarPolicy(
      todayLocalDate: DateTime(2026, 7, 24),
      currentLocalTime: '10:30:15.123456',
      latestBookableLocalDateTime: DateTime(2027, 7, 24, 10, 30, 15, 123, 456),
    );

    test('uses the server-authored studio day instead of the device day', () {
      expect(policy.containsDate(DateTime(2026, 7, 23)), isFalse);
      expect(policy.containsDate(DateTime(2026, 7, 24)), isTrue);
      expect(policy.shiftDate(DateTime(2026, 7, 24), -1), isNull);
    });

    test('enforces current and latest local start boundaries', () {
      expect(policy.canStartAt(DateTime(2026, 7, 24), 10), isFalse);
      expect(policy.canStartAt(DateTime(2026, 7, 24), 11), isTrue);
      expect(policy.canStartAt(DateTime(2027, 7, 24), 10), isTrue);
      expect(policy.canStartAt(DateTime(2027, 7, 24), 11), isFalse);
      expect(policy.shiftDate(DateTime(2027, 7, 24), 1), isNull);
    });
  });

  group('StudioReservationOwnerCapabilities', () {
    final now = DateTime.utc(2026, 7, 24, 10);

    test('allows decision actions only for a future pending request', () {
      final capabilities = StudioReservationOwnerCapabilities.evaluate(
        status: StudioReservationStatus.pendingApproval,
        startsAt: DateTime.utc(2026, 7, 24, 11),
        completed: false,
        now: now,
      );

      expect(capabilities.canApprove, isTrue);
      expect(capabilities.canReject, isTrue);
      expect(capabilities.canCancel, isTrue);
    });

    test('allows cancellation for a future confirmed reservation', () {
      final capabilities = StudioReservationOwnerCapabilities.evaluate(
        status: StudioReservationStatus.confirmed,
        startsAt: DateTime.utc(2026, 7, 24, 11),
        completed: false,
        now: now,
      );

      expect(capabilities.canApprove, isFalse);
      expect(capabilities.canReject, isFalse);
      expect(capabilities.canCancel, isTrue);
    });

    test('suppresses every mutation once the reservation starts', () {
      for (final status in [
        StudioReservationStatus.pendingApproval,
        StudioReservationStatus.confirmed,
      ]) {
        final capabilities = StudioReservationOwnerCapabilities.evaluate(
          status: status,
          startsAt: now,
          completed: false,
          now: now,
        );
        expect(capabilities.hasMutation, isFalse);
      }
    });

    test('fails closed when the authoritative Studio clock is unavailable', () {
      final capabilities = StudioReservationOwnerCapabilities.evaluate(
        status: StudioReservationStatus.pendingApproval,
        startsAt: DateTime.utc(2035, 1, 1),
        completed: false,
        now: null,
      );

      expect(capabilities.hasMutation, isFalse);
    });
  });

  group('Studio calendar reference date', () {
    test('requires a server date for remote or editable calendars', () {
      final fallback = DateTime(2035, 5, 6);

      expect(
        studioCalendarReferenceDate(
          serverDate: null,
          editable: true,
          hasRemoteRepository: false,
          presentationFallback: fallback,
        ),
        isNull,
      );
      expect(
        studioCalendarReferenceDate(
          serverDate: null,
          editable: false,
          hasRemoteRepository: true,
          presentationFallback: fallback,
        ),
        isNull,
      );
    });

    test('allows device fallback only for a local read-only fixture', () {
      final fallback = DateTime(2035, 5, 6, 22, 15);

      expect(
        studioCalendarReferenceDate(
          serverDate: null,
          editable: false,
          hasRemoteRepository: false,
          presentationFallback: fallback,
        ),
        DateTime(2035, 5, 6),
      );
    });
  });
}
