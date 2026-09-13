import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 2),
  writeResponseOnFailure: true,
  responseDataCallback: (data) => writeResponseData(
    data,
    destinationDirectory: 'tmp/announcements_20260913',
    testOutputFilename: 'phone_native_video_report',
  ),
);
