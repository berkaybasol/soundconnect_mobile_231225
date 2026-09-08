import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/event_discovery_date_policy.dart';

void main() {
  test('Istanbul today crosses midnight at 21:00 UTC', () {
    expect(
      EventDiscoveryDatePolicy.today(DateTime.utc(2026, 9, 7, 20, 59, 59)),
      DateTime(2026, 9, 7),
    );
    expect(
      EventDiscoveryDatePolicy.today(DateTime.utc(2026, 9, 7, 21)),
      DateTime(2026, 9, 8),
    );
  });

  test('an instant with a foreign timezone still uses Istanbul day', () {
    expect(
      EventDiscoveryDatePolicy.today(
        DateTime.parse('2026-09-07T17:00:00-04:00'),
      ),
      DateTime(2026, 9, 8),
    );
    expect(
      EventDiscoveryDatePolicy.today(
        DateTime.parse('2026-09-08T04:00:00+09:00'),
      ),
      DateTime(2026, 9, 7),
    );
  });

  test('Istanbul midnight handles month and year rollover', () {
    expect(
      EventDiscoveryDatePolicy.today(DateTime.utc(2026, 12, 31, 21)),
      DateTime(2027, 1, 1),
    );
    expect(
      EventDiscoveryDatePolicy.today(DateTime.utc(2028, 2, 28, 21)),
      DateTime(2028, 2, 29),
    );
  });

  for (final today in [
    DateTime(2026, 9, 7),
    DateTime(2026, 12, 28),
    DateTime(2028, 2, 27),
    DateTime(2026, 3, 27),
    DateTime(2026, 10, 23),
  ]) {
    test('exactly seven calendar dates are selectable from $today', () {
      for (var day = -2; day <= 9; day++) {
        final date = DateTime(today.year, today.month, today.day + day, 23, 59);
        expect(
          EventDiscoveryDatePolicy.contains(date, today),
          day >= 0 && day <= 6,
          reason: 'day offset $day',
        );
      }
    });
  }

  test('normalizing chosen date does not reinterpret it as an instant', () {
    final date = DateTime.utc(2026, 9, 7, 23, 30);
    expect(EventDiscoveryDatePolicy.normalizeDate(date), DateTime(2026, 9, 7));
    expect(EventDiscoveryDatePolicy.apiDate(date), '2026-09-07');
  });

  test('Turkish labels are available without locale initialization', () {
    final tomorrow = DateTime(2026, 9, 8);
    expect(EventDiscoveryDatePolicy.shortDate(tomorrow), '8 Eyl');
    expect(EventDiscoveryDatePolicy.longDate(tomorrow), '8 Eylül');
    expect(EventDiscoveryDatePolicy.weekday(tomorrow), 'Salı');
    expect(EventDiscoveryDatePolicy.weekday(DateTime(2026, 9, 7)), 'Pazartesi');
    expect(EventDiscoveryDatePolicy.weekday(DateTime(2026, 9, 9)), 'Çarşamba');
    expect(EventDiscoveryDatePolicy.weekday(DateTime(2026, 9, 10)), 'Perşembe');
    expect(EventDiscoveryDatePolicy.weekday(DateTime(2026, 9, 11)), 'Cuma');
    expect(
      EventDiscoveryDatePolicy.weekday(DateTime(2026, 9, 12)),
      'Cumartesi',
    );
    expect(EventDiscoveryDatePolicy.weekday(DateTime(2026, 9, 13)), 'Pazar');
  });

  test('all Turkish months and API padding are correct', () {
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
    for (var month = 1; month <= 12; month++) {
      expect(
        EventDiscoveryDatePolicy.longDate(DateTime(2026, month, 1)),
        '1 ${months[month - 1]}',
      );
    }
    expect(
      EventDiscoveryDatePolicy.apiDate(DateTime(2026, 1, 2)),
      '2026-01-02',
    );
  });
}
