import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/admin_user_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/admin_analytics_report.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/admin_statistics_screen.dart';
import 'admin_user_directory_test.dart' show admin, tap;
import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

Map<String, dynamic> snapshot(String month) => {
  'month': month,
  'profileType': 'ALL',
  'asOf': '2026-11-26T12:05:00Z',
  'coverageStart': '2026-11-26',
  'live': {'asOf': '2026-11-25T21:02:00Z', 'members': 12, 'guests': 5},
  'membership': {
    'newAccounts': 19,
    'deletedAccounts': 2,
    'totalAccounts': 117,
    'change': 17,
    'pending': 3,
    'byRole': {'LISTENER': 77, 'MUSICIAN': 20, 'VENUE': 12, 'STUDIO': 8},
    'pendingByRole': {'VENUE': 1, 'STUDIO': 2},
  },
  'usage': <String, dynamic>{
    'mau': 13,
    'guestMau': 2,
    'avgDau': 2.5,
    'minutesPerActiveDay': 2.5,
    'totalMilliseconds': 750000,
    'previousActive': 5,
    'returned': 2,
    'returnRate': 0.4,
    'daily': [
      {'day': '$month-01', 'users': 2},
      {'day': '$month-02', 'users': 3},
    ],
    'hours': [
      {'hour': 21, 'users': 1.4},
    ],
    'weekdays': [
      {'weekday': 2, 'users': 1.5},
    ],
    'sections': [
      {'section': 'tables', 'visitors': 3, 'milliseconds': 600000},
    ],
    'dailySections': [
      {
        'day': '$month-01',
        'section': 'tables',
        'visitors': 1,
        'milliseconds': 120000,
      },
    ],
  },
  'firstWeek': {
    'eligible': 5,
    'acted': 2,
    'overEightMinutes': 1,
    'actions': {'table_join_requested': 2},
  },
  'peaks': {
    'members': {'count': 8, 'at': '2026-11-01T10:15:00Z'},
    'guests': {'count': 6, 'at': '2026-11-02T11:25:00Z'},
    'samples': 189,
  },
  'issues': [],
};

void main() {
  test(
    'legacy peaks keep their GA4 source after the live counter switches',
    () {
      final data = snapshot('2026-11');
      final legacy = AdminAnalyticsReport.read(data, '2026-11', null);
      expect(legacy.liveSource, AnalyticsReportSource.ga4);
      expect(legacy.peakSource, AnalyticsReportSource.ga4);
      data['liveSource'] = 'SOUNDCONNECT';
      data['peakSource'] = 'GA4';
      final previousMonth = AdminAnalyticsReport.read(data, '2026-11', null);
      expect(previousMonth.liveSource, AnalyticsReportSource.soundConnect);
      expect(previousMonth.peakSource, AnalyticsReportSource.ga4);
      data['peakSource'] = 'unexpected';
      expect(
        () => AdminAnalyticsReport.read(data, '2026-11', null),
        throwsFormatException,
      );
    },
  );

  test(
    'unknown source period and profile cannot be painted as the requested report',
    () {
      final data = snapshot('2026-11');
      expect(
        () => AdminAnalyticsReport.read(data, '2026-10', null),
        throwsFormatException,
      );
      data['profileType'] = 'STUDIO';
      expect(
        () => AdminAnalyticsReport.read(data, '2026-11', null),
        throwsFormatException,
      );
      data['profileType'] = 'ALL';
      data['usage']['daily'] = [
        {'day': '2026-10-31', 'users': 20},
      ];
      expect(
        () => AdminAnalyticsReport.read(data, '2026-11', null),
        throwsFormatException,
      );
      data['usage']['daily'] = [];
      data['usage']['previousActive'] = null;
      data['usage']['returned'] = null;
      data['usage']['returnRate'] = null;
      expect(
        AdminAnalyticsReport.read(data, '2026-11', null).usage?.previousActive,
        isNull,
      );
    },
  );

  testWidgets(
    'approved report shows live window, drilldowns, month and day controls and removes values on server revocation',
    (tester) async {
      final sessions = AudienceTestSessions(admin());
      var denied = false;
      final api = RecordingApiClient((r) {
        if (denied) {
          throw ApiException(const AppError(code: '403', message: 'no'));
        }
        if (r.path.endsWith('/analytics-preferences')) {
          return {
            'granted': 63,
            'denied': 37,
            'undecided': 17,
            'asOf': '2026-11-26T12:05:00Z',
          };
        }
        final month = r.query!['month'] as String;
        return snapshot(month)
          ..['liveSource'] = 'SOUNDCONNECT'
          ..['peakSource'] = 'SOUNDCONNECT'
          ..['peakCoverageStart'] = '$month-01T09:10:00Z';
      });
      await tester.pumpWidget(
        MaterialApp(
          home: AdminStatisticsScreen(
            repository: AdminUserDirectoryRepository(api, sessions),
            sessions: sessions,
            entry: sessions.session,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('SoundConnect · 25 Kasım 2026 23:57–26 Kasım 2026 00:02 TSİ'),
        findsOneWidget,
      );
      expect(find.text('2,5 ort.'), findsOneWidget);
      final month = api.requests.first.query!['month'] as String;
      final monthMenu = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      monthMenu.onChanged!('other');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .firstDate,
        DateTime(2000),
      );
      await tap(tester, find.text('Vazgeç'));
      await tap(tester, find.byType(DropdownButton<String>));
      final earlier = DateTime.parse('$month-01');
      final previousMonth = DateTime.utc(earlier.year, earlier.month - 1);
      const names = [
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
      await tap(
        tester,
        find
            .text('${names[previousMonth.month - 1]} ${previousMonth.year}')
            .last,
      );
      expect(api.lastRequest.query?['month'], reportMonth(previousMonth));
      await tap(tester, find.text('Bölümlerde geçirilen süre'));
      await tap(tester, find.text('Ayın tamamı'));
      await tap(tester, find.text('1 ${names[previousMonth.month - 1]}').last);
      expect(find.text('Masalar'), findsOneWidget);
      final table = find.byType(Table);
      expect(
        find.descendant(of: table, matching: find.text('2')),
        findsNWidgets(2),
      );
      await tap(tester, find.text('Bölümlerde geçirilen süre'));
      await tap(tester, find.text('İlk hafta ve geri dönüş'));
      expect(find.text('Masa isteği gönderme'), findsOneWidget);
      expect(find.text('%40 · 2/5'), findsOneWidget);
      expect(find.text('%40'), findsOneWidget);
      await tap(tester, find.text('Ayın beş dakikalık zirvesi'));
      expect(find.text('Ölçüm kaynağı · SoundConnect'), findsOneWidget);
      expect(
        find.textContaining('Bu kaynakla ölçüm başlangıcı'),
        findsOneWidget,
      );
      expect(find.textContaining('13:10–13:15 TSİ'), findsOneWidget);
      expect(find.textContaining('14:20–14:25 TSİ'), findsOneWidget);
      denied = true;
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('Yenile'));
      expect(find.text('Yönetim yetkisi gerekli.'), findsOneWidget);
      expect(find.text('2,5 ort.'), findsNothing);
    },
  );
}
