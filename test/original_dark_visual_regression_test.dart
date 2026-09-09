import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/login_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/forgot_password_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_listing_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/theme/collab_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_owner_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_ghost_profile_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_border_action_button.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/profile_brand_title.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/profile_management_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/soundconnect_date_picker.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/waveform_stub.dart';

import 'support/auth_widget_test_support.dart';
import 'support/collab_test_support.dart';

// Preserve the original Koyu surfaces. Listener/ghost baselines also capture
// their intentional alignment with the shared musician/venue profile design.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutterPackage = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final flutterRoot = configFile.absolute.uri.resolve(
      flutterPackage['rootUri'] as String,
    );
    final fontDirectory = Directory.fromUri(
      flutterRoot,
    ).uri.resolve('../../bin/cache/artifacts/material_fonts/');
    final loader = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      final bytes = await File.fromUri(
        fontDirectory.resolve('roboto-$weight.ttf'),
      ).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    // Replace flutter_test's box-only fallback for explicitly styled labels.
    final fallback = FontLoader('Ahem');
    fallback.addFont(
      File.fromUri(
        fontDirectory.resolve('roboto-regular.ttf'),
      ).readAsBytes().then(ByteData.sublistView),
    );
    await fallback.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      File(
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then(ByteData.sublistView),
    );
    await icons.load();
  });
  tearDown(() async {
    await serviceLocator.reset();
  });

  for (final screen in [
    'login',
    'forgot',
    'listener',
    'ghost',
    'collab',
    'controls',
    'sheet',
    'calendar',
  ]) {
    testWidgets('koyu $screen visual regression', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = AppTheme.navy;
      final auth = createAuthCubit(RecordingAuthRepository());
      addTearDown(auth.close);
      final detail = CollabListingDetailCubit(
        FakeCollabDetailRepository(listing: collabListingFixture()),
      );
      addTearDown(detail.close);
      final boundary = GlobalKey();
      late BuildContext pageContext;
      final Widget page = switch (screen) {
        'login' => const LoginScreen(),
        'forgot' => const ForgotPasswordScreen(),
        'listener' => ListenerProfileTheme(
          inheritAppTheme: true,
          child: Scaffold(
            appBar: AppBar(title: const ProfileBrandTitle()),
            body: ListenerProfileOwnerContent(
              profile: const ListenerProfile(
                id: 'theme-fixture',
                userId: 'theme-fixture',
                username: 'deniz',
                bio: 'Yeni sesler, yeni sahneler.',
                profilePictureUrl: null,
                followerCount: 24,
                followingCount: 68,
              ),
              onEditProfile: () {},
              onEditAvatar: () {},
              onEditPlaylists: () {},
              onPlaylistTap: (_) {},
              onPreviewAction: (_) {},
            ),
          ),
        ),
        'ghost' => ListenerProfileTheme(
          inheritAppTheme: true,
          child: Scaffold(
            appBar: AppBar(title: const ProfileBrandTitle()),
            body: ListenerGhostProfileContent(
              username: 'deniz',
              profilePictureUrl: null,
              owner: true,
              busy: false,
              onRefresh: () async {},
              onEditAvatar: () {},
              onSwitchToStandard: () {},
            ),
          ),
        ),
        'collab' => CollabThemeScope(
          child: CollabListingDetailScreen(
            listingId: 'listing-1',
            detailCubit: detail,
            showBottomNavigation: false,
          ),
        ),
        _ => Builder(
          builder: (context) {
            pageContext = context;
            return const _Controls();
          },
        ),
      };
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: page,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Asset decodes run outside fake time and must finish before a golden.
      await tester.runAsync(() async {
        for (final asset in [
          'assets/logo.png',
          'assets/Logoyanyana.png',
          'assets/fish.png',
          'assets/google.png',
          'assets/ghost (1).png',
          'assets/headphone2.png',
        ]) {
          await precacheImage(AssetImage(asset), boundary.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      if (screen == 'sheet') {
        showProfileManagementSheet<String>(
          pageContext,
          title: 'Profil yönetimi',
          options: const [
            ProfileManagementSheetOption(
              value: 'profile',
              icon: Icons.person_outline,
              label: 'Profil bilgileri',
            ),
            ProfileManagementSheetOption(
              value: 'media',
              icon: Icons.graphic_eq,
              label: 'Medya yönetimi',
            ),
          ],
        );
        await tester.pumpAndSettle();
      }
      if (screen == 'calendar') {
        showSoundConnectDatePicker(
          context: pageContext,
          initialDate: DateTime(2030, 9, 15),
          firstDate: DateTime(2030, 9),
          lastDate: DateTime(2030, 12, 31),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final evidence = Platform.environment['ORIGINAL_DARK_EVIDENCE_DIR'];
      if (evidence != null) {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final picture = await render.toImage(pixelRatio: 1);
          final bytes = (await picture.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await Directory(evidence).create(recursive: true);
          await File(
            '$evidence/koyu-$screen.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          picture.dispose();
        });
      }

      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/original_dark/koyu-$screen.png'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}

class _Controls extends StatelessWidget {
  const _Controls();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const ProfileBrandTitle()),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: 0,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Akış'),
        BottomNavigationBarItem(icon: Icon(Icons.graphic_eq), label: 'Sesler'),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Sana ait bir sahne',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Formlar, medya ve etkileşim durumları',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Kullanıcı adı',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        const TextField(
          decoration: InputDecoration(
            labelText: 'E-posta',
            errorText: 'Geçerli bir e-posta gir.',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              // Chip's explicit component style does not inherit textTheme's
              // font family in flutter_test. Keep this font override in the
              // capture fixture so production typography remains untouched.
              label: const Text('Rock', style: TextStyle(fontFamily: 'Roboto')),
              selected: true,
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Caz', style: TextStyle(fontFamily: 'Roboto')),
              onSelected: (_) {},
            ),
            const FilterChip(
              label: Text('Pasif', style: TextStyle(fontFamily: 'Roboto')),
              onSelected: null,
            ),
          ],
        ),
        Row(
          children: [
            Switch(value: true, onChanged: (_) {}),
            Switch(value: false, onChanged: (_) {}),
            const Switch(value: false, onChanged: null),
            Checkbox(value: true, onChanged: (_) {}),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SoundConnect Sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                WaveformStub(onPlay: () {}, progress: .4),
                const SizedBox(height: 12),
                GradientBorderActionButton(
                  icon: Icons.add,
                  label: 'Ses ekle',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GradientOutlineButton(label: 'Devam et', onPressed: () {}),
        const SizedBox(height: 10),
        const GradientBorderActionButton(
          icon: Icons.lock_outline,
          label: 'Kullanılamıyor',
          onPressed: null,
        ),
      ],
    ),
  );
}
