import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  onScreenshot: (name, bytes, [args]) async {
    final directory = Directory(
      '../.local-verification/design-preview/screenshots',
    );
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    return true;
  },
  responseDataCallback: (data) => writeResponseData(
    data == null ? null : ({...data}..remove('screenshots')),
    destinationDirectory: '../.local-verification/design-preview',
    testOutputFilename: 'device-report',
  ),
);
