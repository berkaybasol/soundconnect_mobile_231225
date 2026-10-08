import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/waveform_stub.dart';

void main() {
  for (final width in [80, 160, 520]) {
    testWidgets('waveform stays inside and reaches the end of ${width}px', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 320, child: WaveformStub(progress: .4)),
            ),
          ),
        ),
      );
      final waveformPaint = find.descendant(
        of: find.byType(WaveformStub),
        matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter != null,
        ),
      );
      expect(waveformPaint, findsOneWidget);
      final painter = tester.widget<CustomPaint>(waveformPaint).painter!;

      await tester.runAsync(() async {
        const padding = 32;
        const height = 44;
        final imageWidth = width + padding * 2;
        const imageHeight = height + padding * 2;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..translate(padding.toDouble(), padding.toDouble());

        // Paint without a clip so drawing beyond the allotted waveform area
        // stays observable instead of being hidden by a screenshot boundary.
        painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
        final picture = recorder.endRecording();
        final image = await picture.toImage(imageWidth, imageHeight);
        try {
          final pixels = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(pixels, isNotNull);
          var paintedPixels = 0;
          var outsidePixels = 0;
          var endPixels = 0;
          for (var y = 0; y < imageHeight; y++) {
            for (var x = 0; x < imageWidth; x++) {
              final alpha = pixels!.getUint8((y * imageWidth + x) * 4 + 3);
              if (alpha == 0) continue;
              paintedPixels++;
              final inside =
                  x >= padding &&
                  x < padding + width &&
                  y >= padding &&
                  y < padding + height;
              if (!inside) {
                outsidePixels++;
              } else if (x >= padding + width - 4) {
                endPixels++;
              }
            }
          }
          expect(paintedPixels, greaterThan(0));
          expect(
            outsidePixels,
            0,
            reason: 'Waveform bars must not overlap adjacent player controls.',
          );
          expect(
            endPixels,
            greaterThan(0),
            reason:
                'A wide player must not leave an empty tail after its bars.',
          );
        } finally {
          image.dispose();
          picture.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    });
  }
}
