import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_table_group_draft_composer.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/table_group_profile_draft.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';

/// Opt-in real-widget exports for visual QA, using the actual shared composer
/// and its controls. Only the network response and authenticated user are fake.
void main() {
  final outputPath = Platform.environment['LISTENER_TABLE_COMPOSER_RENDER_DIR'];
  testWidgets(
    'render the actual table draft composer at normal and accessible widths',
    (tester) async {
      await tester.runAsync(() async {
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final loader = FontLoader('Roboto');
        for (final font in [
          'roboto-regular.ttf',
          'roboto-medium.ttf',
          'roboto-bold.ttf',
          'roboto-black.ttf',
        ]) {
          loader.addFont(
            File('$fonts/$font').readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });

      final sessions = AudienceTestSessions(audienceSession(user: 'berna'));
      final shares = _Shares();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        shares.signal.dispose();
        sessions.dispose();
      });
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final width in [390.0, 320.0]) {
        final capture = GlobalKey();
        final composer = GlobalKey<ListenerTableGroupDraftComposerState>();
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.navy.copyWith(
              textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.6 : 1)),
              child: child!,
            ),
            home: ListenerProfileTheme(
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: capture,
                    child: ListenerTableGroupDraftComposer(
                      key: composer,
                      draft: TableGroupProfileDraftArgs(
                        tableGroupId: 'table',
                        expectedSession: sessions.session,
                      ),
                      profile: const ListenerProfile(
                        id: 'profile',
                        userId: 'berna',
                        username: 'berna',
                        bio: null,
                        profilePictureUrl: null,
                        followerCount: 0,
                        followingCount: 0,
                        visibilityChoiceCompleted: true,
                        profileContentVisible: true,
                        profileContentEditable: true,
                      ),
                      sessions: sessions,
                      repository: shares,
                      onFinished: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(composer.currentState!.readyForReveal, isTrue);
        final publish = find.byKey(
          const Key('listener-table-group-draft-publish'),
        );
        expect(
          tester.widget<GradientOutlineButton>(publish).onPressed,
          isNotNull,
        );
        expect(find.text('Açıklama (isteğe bağlı)'), findsOneWidget);
        expect(find.text('Bu masa için birkaç söz ekle…'), findsOneWidget);

        for (final filled in [false, true]) {
          if (filled) {
            await tester.enterText(
              find.byKey(const Key('listener-table-group-draft-note')),
              'Bu akşam müzikten konuşmak için bir araya geliyoruz. Bekleriz!',
            );
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final pixels =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(outputPath!).create(recursive: true);
            await File(
              '$outputPath/composer-${filled ? 'note' : 'empty'}-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
      }
    },
    skip: outputPath == null,
  );
}

class _Shares extends Fake implements TableGroupProfileShareRepository {
  final signal = ValueNotifier(0);

  @override
  ValueNotifier<int> get changes => signal;

  @override
  Future<Result<TableGroupProfileShareState>> getState({
    required String tableGroupId,
    required AuthSession expectedSession,
  }) async => Result.success(
    TableGroupProfileShareState(
      tableGroupId: tableGroupId,
      shareId: null,
      publishedOnProfile: false,
      note: null,
      publishedAt: null,
      canPublish: true,
      tableGroup: TableGroupProfileShareSource(
        id: tableGroupId,
        description: 'Müzikten konuşmak için buluşalım.',
        venueName: null,
        cityName: 'Ankara',
        districtName: 'Çankaya',
        meetingAt: DateTime.now().add(const Duration(minutes: 30)),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        status: 'ACTIVE',
        maxPersonCount: 4,
        acceptedCount: 2,
      ),
    ),
  );
}
