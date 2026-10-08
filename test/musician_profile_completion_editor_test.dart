import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/policy/profile_feed_availability.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/entities/instrument.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/instrument_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/musician_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_social_support.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  late _SessionManager session;
  late _ProfileRepository profiles;

  setUp(() async {
    await serviceLocator.reset();
    session = _SessionManager();
    profiles = _ProfileRepository();
    serviceLocator
      ..registerSingleton<AuthSessionManager>(session)
      ..registerSingleton<MusicianProfileRepository>(profiles);
  });

  tearDown(() => serviceLocator.reset());

  test('completion task codes resolve to dedicated musician editors', () {
    expect(
      musicianProfileCompletionEditorForCode('INSTRUMENTS'),
      MusicianProfileCompletionEditor.instruments,
    );
    expect(
      musicianProfileCompletionEditorForCode('STAGE_NAME_AND_BIO'),
      MusicianProfileCompletionEditor.profileDetails,
    );
    expect(
      musicianProfileCompletionEditorForCode('BIO'),
      MusicianProfileCompletionEditor.profileDetails,
    );
    expect(
      musicianProfileCompletionEditorForCode('PROFILE_DETAILS'),
      MusicianProfileCompletionEditor.profileDetails,
    );
    expect(
      musicianProfileCompletionEditorForCode('PORTFOLIO'),
      MusicianProfileCompletionEditor.portfolio,
    );
    expect(
      musicianProfileCompletionEditorForCode('PROFILE_PHOTO_AND_SOCIAL_LINKS'),
      MusicianProfileCompletionEditor.photoAndSocialLinks,
    );
    expect(musicianProfileCompletionEditorForCode('UNKNOWN'), isNull);
  });

  testWidgets(
    'management offers profile completion only when profile feeds are enabled',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      await _mountManagementLauncher(tester);
      expect(
        find.text('Profil Tamamlama'),
        ProfileFeedAvailability.enabled ? findsOneWidget : findsNothing,
      );
      expect(find.text('Biyografi'), findsNothing);
      expect(find.text('Akış Tercihleri'), findsNothing);
      expect(find.text('Enstrümanlarım'), findsNothing);

      if (!ProfileFeedAvailability.enabled) {
        expect(find.text('Bandlerim'), findsOneWidget);
        expect(find.text('Setlist Oluşturucu'), findsOneWidget);
        expect(find.text('Mekan Bağlantıları'), findsOneWidget);
        expect(find.text('Etkinlik Yönetimi'), findsOneWidget);
        expect(find.byType(MusicianProfileCompletionScreen), findsNothing);
        expect(tester.takeException(), isNull);
        return;
      }

      await tester.tap(find.text('Profil Tamamlama'));
      await tester.pumpAndSettle();
      expect(find.byType(MusicianProfileCompletionScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Akış Tercihleri'), findsOneWidget);
      expect(find.text('Enstrümanlarım'), findsOneWidget);
      expect(find.text('Biyografi'), findsNothing);
      expect(find.byKey(_saveCompletion), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MusicianManagementPanelScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(profiles.requests, isEmpty);
      expect(preferences.cityUpdates, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completion saves only the changed city and stays on the combined page',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      await _mountCompletionPage(tester);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-1'),
      );
      await _tapCompletionControl(tester, _saveCompletion);

      expect(preferences.cityUpdates, [('city-1', 3)]);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(MusicianProfileCompletionScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(profiles.requests, isEmpty);
      await _tapCompletionControl(tester, _saveCompletion);
      expect(preferences.cityUpdates, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  if (ProfileFeedAvailability.enabled) {
    testWidgets(
      'completion instrument save refreshes the profile owner when the page is left',
      (tester) async {
        final preferences = _registerCompletionRepositories(profiles);
        var panelReturns = 0;
        await _mountManagementLauncher(
          tester,
          onReturned: () => panelReturns++,
        );
        await tester.tap(find.text('Profil Tamamlama'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('musician-instrument-i-guitar')),
              )
              .value,
          isTrue,
        );
        await _tapCompletionControl(
          tester,
          const Key('musician-instrument-i-bass'),
        );
        expect(
          find.byKey(const Key('musician-completion-selected-i-bass')),
          findsOneWidget,
        );
        await _tapCompletionControl(tester, _saveCompletion);

        expect(profiles.requests.single.instrumentIds, ['i-bass', 'i-guitar']);
        expect(profiles.expectedSessionKeys, ['owner-1']);
        expect(preferences.cityUpdates, isEmpty);
        expect(find.byType(MusicianProfileCompletionScreen), findsOneWidget);
        expect(panelReturns, 0);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(MusicianManagementPanelScreen), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Profil ekranı'), findsOneWidget);
        expect(panelReturns, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an account switch prevents saving drafts from the combined page',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      await _mountCompletionPage(tester);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-1'),
      );
      await _tapCompletionControl(
        tester,
        const Key('musician-instrument-i-bass'),
      );
      session.changeUser('other');
      await tester.pumpAndSettle();
      if (find.byKey(_saveCompletion).evaluate().isNotEmpty) {
        await _tapCompletionControl(tester, _saveCompletion);
      }

      expect(find.byType(BottomSheet), findsNothing);
      expect(profiles.requests, isEmpty);
      expect(preferences.cityUpdates, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unchanged completion and reverted selections perform no writes',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      await _mountCompletionPage(tester);
      await _tapCompletionControl(tester, _saveCompletion);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-1'),
      );
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-clear'),
      );
      await _tapCompletionControl(
        tester,
        const Key('musician-instrument-i-bass'),
      );
      await _tapCompletionControl(
        tester,
        const Key('musician-instrument-i-bass'),
      );
      await _tapCompletionControl(tester, _saveCompletion);

      expect(preferences.cityUpdates, isEmpty);
      expect(profiles.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a partial save retains the failed draft and retries only instruments',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      profiles.response = const Result.failure(
        AppError(code: 'NETWORK', message: 'Enstrümanlar kaydedilemedi.'),
      );
      await _mountCompletionPage(tester);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-1'),
      );
      await _tapCompletionControl(
        tester,
        const Key('musician-instrument-i-bass'),
      );
      await _tapCompletionControl(tester, _saveCompletion);

      expect(preferences.cityUpdates, [('city-1', 3)]);
      expect(profiles.requests, hasLength(1));
      expect(profiles.requests.single.instrumentIds, ['i-bass', 'i-guitar']);
      expect(
        find.byKey(const Key('musician-completion-selected-i-bass')),
        findsOneWidget,
      );
      expect(find.byType(MusicianProfileCompletionScreen), findsOneWidget);
      profiles.response = null;
      await _tapCompletionControl(tester, _saveCompletion);

      expect(preferences.cityUpdates, hasLength(1));
      expect(profiles.requests, hasLength(2));
      expect(profiles.requests.last.instrumentIds, ['i-bass', 'i-guitar']);
      await _tapCompletionControl(tester, _saveCompletion);
      expect(preferences.cityUpdates, hasLength(1));
      expect(profiles.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed city save preserves both drafts and retries before instruments',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      preferences.cityResponse = const Result.failure(
        AppError(code: 'NETWORK', message: 'Şehir tercihi kaydedilemedi.'),
      );
      final calls = <String>[];
      preferences.onCityUpdate = () => calls.add('city');
      profiles.onRequest = () => calls.add('instruments');
      await _mountCompletionPage(tester);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-1'),
      );
      await _tapCompletionControl(
        tester,
        const Key('musician-instrument-i-bass'),
      );
      await _tapCompletionControl(tester, _saveCompletion);

      expect(calls, ['city']);
      expect(preferences.cityUpdates, [('city-1', 3)]);
      expect(preferences.current.opportunityCity, isNull);
      expect(profiles.requests, isEmpty);
      expect(
        find.descendant(
          of: find.byKey(_cityCompletionField),
          matching: find.text('İstanbul'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('musician-completion-selected-i-bass')),
        findsOneWidget,
      );

      preferences.cityResponse = null;
      await _tapCompletionControl(tester, _saveCompletion);

      expect(calls, ['city', 'city', 'instruments']);
      expect(preferences.cityUpdates, [('city-1', 3), ('city-1', 3)]);
      expect(profiles.requests.single.instrumentIds, ['i-bass', 'i-guitar']);
      expect(find.byType(MusicianProfileCompletionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'both sections save from one button in city then instrument order',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      final calls = <String>[];
      preferences.onCityUpdate = () => calls.add('city');
      profiles.onRequest = () => calls.add('instruments');
      await _mountCompletionPage(tester);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-1'),
      );
      await _tapCompletionControl(
        tester,
        const Key('musician-instrument-i-bass'),
      );
      await _tapCompletionControl(tester, _saveCompletion);

      expect(calls, ['city', 'instruments']);
      expect(preferences.cityUpdates, [('city-1', 3)]);
      expect(profiles.requests.single.instrumentIds, ['i-bass', 'i-guitar']);
      expect(find.byType(MusicianProfileCompletionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clearing an existing opportunity city persists the empty preference',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      preferences.setCity('city-1');
      await _mountCompletionPage(tester);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-clear'),
      );
      await _tapCompletionControl(tester, _saveCompletion);

      expect(preferences.cityUpdates, [(null, 3)]);
      expect(preferences.current.opportunityCity, isNull);
      expect(profiles.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dirty back can continue editing or discard without saving', (
    tester,
  ) async {
    final preferences = _registerCompletionRepositories(profiles);
    bool? returned;
    await _mountCompletionPage(
      tester,
      onReturned: (changed) => returned = changed,
    );
    await _tapCompletionControl(
      tester,
      const Key('musician-completion-city-city-1'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Değişiklikleri bırak'), findsOneWidget);
    await tester.tap(find.text('Düzenlemeye devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(MusicianProfileCompletionScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değişiklikleri bırak'));
    await tester.pumpAndSettle();

    expect(find.byType(MusicianProfileCompletionScreen), findsNothing);
    expect(returned, isFalse);
    expect(preferences.cityUpdates, isEmpty);
    expect(profiles.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account switch during city save prevents the pending instrument write',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      final cityResult = Completer<Result<MusicianFeedPreferences>>();
      preferences.pendingCityResult = cityResult.future;
      await _mountCompletionPage(tester);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-1'),
      );
      await _tapCompletionControl(
        tester,
        const Key('musician-instrument-i-bass'),
      );
      await tester.ensureVisible(find.byKey(_saveCompletion));
      await tester.tap(find.byKey(_saveCompletion));
      await tester.pump();
      expect(preferences.cityUpdates, [('city-1', 3)]);
      session.changeUser('other');
      preferences.setCity('city-1');
      cityResult.complete(Result.success(preferences.current));
      await tester.pumpAndSettle();

      expect(profiles.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dismissing the city picker leaves the form and stored preferences unchanged',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      await _mountCompletionPage(tester);
      expect(find.byKey(_cityCompletionSearch), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      await _tapCompletionControl(tester, _cityCompletionField);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.enterText(find.byKey(_cityCompletionSearch), 'Ankara');
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(_cityCompletionField),
          matching: find.text('Şehir seç'),
        ),
        findsOneWidget,
      );
      await _tapCompletionControl(tester, _saveCompletion);
      expect(preferences.cityUpdates, isEmpty);
      expect(profiles.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'city picker marks the current city and reselecting it performs no write',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      preferences.setCity('city-1');
      await _mountCompletionPage(tester);
      await _tapCompletionControl(tester, _cityCompletionField);
      await tester.enterText(find.byKey(_cityCompletionSearch), 'istanbul');
      await tester.pumpAndSettle();
      final selectedCity = find.byKey(
        const Key('musician-completion-city-city-1'),
      );
      expect(tester.widget<ListTile>(selectedCity).selected, isTrue);
      expect(tester.widget<ListTile>(selectedCity).trailing, isNotNull);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-1'),
      );

      expect(find.byType(BottomSheet), findsNothing);
      await _tapCompletionControl(tester, _saveCompletion);
      expect(preferences.cityUpdates, isEmpty);
      expect(profiles.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'city picker exposes the full catalogue and selection only changes the draft',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      await _mountCompletionPage(tester);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-8'),
      );

      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(_cityCompletionField),
          matching: find.text('Şanlıurfa'),
        ),
        findsOneWidget,
      );
      expect(preferences.cityUpdates, isEmpty);
      expect(preferences.current.opportunityCity, isNull);
      await _tapCompletionControl(tester, _saveCompletion);
      expect(preferences.cityUpdates, [('city-8', 3)]);
      expect(preferences.current.opportunityCity?.name, 'Şanlıurfa');
      expect(profiles.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'city picker recovers from an empty search and accepts Turkish city names',
    (tester) async {
      final preferences = _registerCompletionRepositories(profiles);
      await _mountCompletionPage(tester);
      await _tapCompletionControl(tester, _cityCompletionField);
      await tester.enterText(
        find.byKey(_cityCompletionSearch),
        'olmayan-şehir',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(ListTile),
        ),
        findsNothing,
      );
      await tester.enterText(find.byKey(_cityCompletionSearch), 'İZMİR');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('musician-completion-city-city-7')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('musician-completion-city-city-1')),
        findsNothing,
      );
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-7'),
      );
      expect(
        find.descendant(
          of: find.byKey(_cityCompletionField),
          matching: find.text('İzmir'),
        ),
        findsOneWidget,
      );
      expect(preferences.cityUpdates, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'combined controls remain usable with large text and an open keyboard',
    (tester) async {
      tester.view
        ..physicalSize = const Size(320, 720)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      _registerCompletionRepositories(profiles);
      await _mountCompletionPage(tester, textScale: 1.7);
      await _tapCompletionControl(tester, _cityCompletionField);
      final citySearch = find.byKey(
        const Key('musician-completion-city-search'),
      );
      await tester.ensureVisible(citySearch);
      await tester.enterText(citySearch, 'İstan');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tapCompletionControl(
        tester,
        const Key('musician-completion-city-city-1'),
      );
      final instrumentSearch = find.byKey(
        const Key('musician-completion-instrument-search'),
      );
      await tester.ensureVisible(instrumentSearch);
      await tester.enterText(instrumentSearch, 'Bas');
      await tester.pumpAndSettle();
      await _tapCompletionControl(
        tester,
        const Key('musician-instrument-i-bass'),
      );
      expect(
        find.byKey(const Key('musician-completion-selected-i-bass')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await _tapCompletionControl(tester, _saveCompletion);
      expect(profiles.requests.single.instrumentIds, ['i-bass', 'i-guitar']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('portfolio completion opens the actual track upload editor', (
    tester,
  ) async {
    await _mountVoidEditorLauncher(
      tester,
      open: (context) =>
          showMusicianPortfolioCompletionEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.text('SoundConnect üzerinden şarkı ekle'), findsOneWidget);
    expect(find.text('Ses dosyası seç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo and social completion opens its photo action', (
    tester,
  ) async {
    var photoEdits = 0;
    await _mountVoidEditorLauncher(
      tester,
      open: (context) => showMusicianPhotoAndSocialLinksCompletionEditor(
        context,
        profile: _profile,
        onEditPhoto: () async => photoEdits += 1,
        onEditSocialLink: (_) async {},
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('musician-photo-social-completion-editor')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('musician-completion-edit-photo')));
    await tester.pumpAndSettle();

    expect(photoEdits, 1);
    expect(find.text('Fotoğraf ve bağlantılar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo and social completion opens the selected link editor', (
    tester,
  ) async {
    ProfileSocialPlatform? editedPlatform;
    await _mountVoidEditorLauncher(
      tester,
      open: (context) => showMusicianPhotoAndSocialLinksCompletionEditor(
        context,
        profile: _profile,
        onEditPhoto: () async {},
        onEditSocialLink: (platform) async => editedPlatform = platform,
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('musician-completion-edit-social-instagram')),
    );
    await tester.pumpAndSettle();

    expect(editedPlatform, ProfileSocialPlatform.instagram);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile details completion updates only the biography', (
    tester,
  ) async {
    await _mountEditorLauncher(
      tester,
      open: (context) =>
          showMusicianProfileDetailsEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsOneWidget);
    expect(find.text('Eski Sahne Adı'), findsNothing);
    expect(find.text('Sahne adı'), findsNothing);
    await tester.enterText(fields, '  Yeni biyografi  ');
    await tester.tap(
      find.widgetWithText(GradientOutlineButton, 'Biyografiyi kaydet'),
    );
    await tester.pumpAndSettle();

    expect(profiles.expectedSessionKeys, ['owner-1']);
    expect(profiles.requests, hasLength(1));
    expect(profiles.requests.single.toJson(), {
      'description': 'Yeni biyografi',
    });
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile details completion rejects an empty biography', (
    tester,
  ) async {
    await _mountEditorLauncher(
      tester,
      open: (context) =>
          showMusicianProfileDetailsEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(
      find.widgetWithText(GradientOutlineButton, 'Biyografiyi kaydet'),
    );
    await tester.pump();

    expect(find.text('Biyografi boş bırakılamaz.'), findsOneWidget);
    expect(profiles.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an account switch prevents a stale completion write', (
    tester,
  ) async {
    await _mountEditorLauncher(
      tester,
      open: (context) =>
          showMusicianProfileDetailsEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    session.current = _authenticated('other');
    await tester.tap(
      find.widgetWithText(GradientOutlineButton, 'Biyografiyi kaydet'),
    );
    await tester.pump();

    expect(profiles.requests, isEmpty);
    expect(find.text('Oturum değişti. Lütfen yeniden dene.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mismatched profile response cannot claim completion success', (
    tester,
  ) async {
    profiles.response = const Result.success(_otherProfile);
    await _mountEditorLauncher(
      tester,
      open: (context) =>
          showMusicianProfileDetailsEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(GradientOutlineButton, 'Biyografiyi kaydet'),
    );
    await tester.pumpAndSettle();

    expect(profiles.requests, hasLength(1));
    expect(
      find.text('Profil kimliği doğrulanamadı. Lütfen yeniden dene.'),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instrument completion starts from canonical preferences', (
    tester,
  ) async {
    serviceLocator
      ..registerSingleton<InstrumentRepository>(_Instruments())
      ..registerSingleton<MusicianFeedPreferencesRepository>(_Preferences());
    await _mountEditorLauncher(
      tester,
      open: (context) =>
          showMusicianInstrumentEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('musician-instrument-i-guitar')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('musician-instrument-i-bass')));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(GradientOutlineButton, 'Enstrümanları kaydet'),
    );
    await tester.pumpAndSettle();

    expect(profiles.expectedSessionKeys, ['owner-1']);
    expect(profiles.requests.single.instrumentIds, ['i-bass', 'i-guitar']);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _saveCompletion = Key('musician-profile-completion-save');
const _cityCompletionField = Key('musician-completion-city-field');
const _cityCompletionSearch = Key('musician-completion-city-search');

_Preferences _registerCompletionRepositories(_ProfileRepository profiles) {
  final preferences = _Preferences();
  profiles.onInstrumentsSaved = preferences.setInstruments;
  serviceLocator
    ..registerSingleton<MusicianFeedPreferencesRepository>(preferences)
    ..registerSingleton<LocationRepository>(_Locations())
    ..registerSingleton<InstrumentRepository>(_Instruments());
  return preferences;
}

Future<void> _tapCompletionControl(WidgetTester tester, Key key) async {
  final control = find.byKey(key);
  final isCityOption =
      key is ValueKey<String> &&
      key.value.startsWith('musician-completion-city-city-');
  if (isCityOption && find.byType(BottomSheet).evaluate().isEmpty) {
    await _tapCompletionControl(tester, _cityCompletionField);
  }
  if (isCityOption && control.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      control,
      180,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> _mountCompletionPage(
  WidgetTester tester, {
  ValueChanged<bool?>? onReturned,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) =>
                      const MusicianProfileCompletionScreen(profile: _profile),
                ),
              );
              onReturned?.call(changed);
            },
            child: const Text('Tamamlamayı aç'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Tamamlamayı aç'));
  await tester.pumpAndSettle();
}

Future<void> _mountManagementLauncher(
  WidgetTester tester, {
  VoidCallback? onReturned,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: Scaffold(
        appBar: AppBar(title: const Text('Profil ekranı')),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const MusicianManagementPanelScreen(
                    musicianProfile: _profile,
                  ),
                ),
              );
              onReturned?.call();
            },
            child: const Text('Yönetimi aç'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Yönetimi aç'));
  await tester.pumpAndSettle();
}

Future<void> _mountEditorLauncher(
  WidgetTester tester, {
  required Future<bool> Function(BuildContext context) open,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(open(context)),
            child: const Text('Aç'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _mountVoidEditorLauncher(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) open,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(open(context)),
            child: const Text('Aç'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AuthSession _authenticated(String userId) => AuthSession.authenticated(
  token: 'token-$userId',
  userId: userId,
  username: userId,
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_MUSICIAN'],
  permissions: const [],
  expiresAt: DateTime(2100),
  isAdmin: false,
);

const _profile = MusicianProfile(
  id: 'profile-1',
  userId: 'owner-1',
  username: 'owner',
  stageName: 'Eski Sahne Adı',
  bio: 'Eski biyografi',
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: ['Gitar'],
  activeVenues: [],
  bands: [],
);

const _otherProfile = MusicianProfile(
  id: 'other-profile',
  userId: 'other',
  username: 'other',
  stageName: 'Başka profil',
  bio: null,
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: [],
  activeVenues: [],
  bands: [],
);

class _SessionManager extends Fake
    with ChangeNotifier
    implements AuthSessionManager {
  AuthSession current = _authenticated('owner-1');

  @override
  AuthSession get session => current;

  void changeUser(String userId) {
    current = _authenticated(userId);
    notifyListeners();
  }
}

class _ProfileRepository extends Fake implements MusicianProfileRepository {
  final requests = <MusicianProfileSaveRequest>[];
  final expectedSessionKeys = <String?>[];
  Result<MusicianProfile>? response;
  VoidCallback? onRequest;
  ValueChanged<List<String>>? onInstrumentsSaved;

  @override
  Future<Result<MusicianProfile>> updateMyProfile(
    MusicianProfileSaveRequest request, {
    String? expectedSessionKey,
  }) async {
    requests.add(request);
    expectedSessionKeys.add(expectedSessionKey);
    onRequest?.call();
    if (response case final response?) return response;
    final instrumentIds = request.instrumentIds;
    if (instrumentIds != null) onInstrumentsSaved?.call(instrumentIds);
    return Result.success(
      MusicianProfile(
        id: _profile.id,
        userId: _profile.userId,
        username: _profile.username,
        stageName: _profile.stageName,
        bio: request.description ?? _profile.bio,
        profilePicture: _profile.profilePicture,
        instagramUrl: _profile.instagramUrl,
        youtubeUrl: _profile.youtubeUrl,
        soundcloudUrl: _profile.soundcloudUrl,
        spotifyEmbedUrl: _profile.spotifyEmbedUrl,
        spotifyArtistId: _profile.spotifyArtistId,
        spotifyTrackIds: _profile.spotifyTrackIds,
        spotifyTracks: _profile.spotifyTracks,
        instruments: instrumentIds == null
            ? _profile.instruments
            : instrumentIds.map(_instrumentName).toList(growable: false),
        activeVenues: _profile.activeVenues,
        bands: _profile.bands,
      ),
    );
  }
}

class _Instruments extends Fake implements InstrumentRepository {
  @override
  Future<Result<List<Instrument>>> getAll() async => const Result.success([
    Instrument(id: 'i-guitar', name: 'Gitar'),
    Instrument(id: 'i-bass', name: 'Bas Gitar'),
  ]);
}

class _Preferences extends Fake implements MusicianFeedPreferencesRepository {
  final cityUpdates = <(String?, int)>[];
  VoidCallback? onCityUpdate;
  Future<Result<MusicianFeedPreferences>>? pendingCityResult;
  Result<MusicianFeedPreferences>? cityResponse;
  MusicianFeedPreferences current = const MusicianFeedPreferences(
    contractVersion: 1,
    version: 3,
    opportunityCity: null,
    instruments: [
      MusicianFeedPreferenceInstrument(id: 'i-guitar', name: 'Gitar'),
    ],
  );

  @override
  Future<Result<MusicianFeedPreferences>> get() async =>
      Result.success(current);

  void setCity(String? cityId, {int? version}) {
    current = MusicianFeedPreferences(
      contractVersion: current.contractVersion,
      version: version ?? current.version,
      opportunityCity: cityId == null
          ? null
          : MusicianFeedPreferenceCity(
              id: cityId,
              name: _cities.singleWhere((city) => city.id == cityId).name,
            ),
      instruments: current.instruments,
    );
  }

  void setInstruments(List<String> ids) {
    current = MusicianFeedPreferences(
      contractVersion: current.contractVersion,
      version: current.version + 1,
      opportunityCity: current.opportunityCity,
      instruments: ids
          .map(
            (id) => MusicianFeedPreferenceInstrument(
              id: id,
              name: _instrumentName(id),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<Result<MusicianFeedPreferences>> updateOpportunityCity({
    required String? cityId,
    required int expectedVersion,
  }) async {
    cityUpdates.add((cityId, expectedVersion));
    onCityUpdate?.call();
    if (pendingCityResult case final result?) return result;
    if (cityResponse case final response?) return response;
    setCity(cityId, version: expectedVersion + 1);
    return Result.success(current);
  }
}

String _instrumentName(String id) => switch (id) {
  'i-guitar' => 'Gitar',
  'i-bass' => 'Bas Gitar',
  _ => throw StateError('Unknown fixture instrument: $id'),
};

class _Locations extends Fake implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async => const Result.success(_cities);
}

const _cities = [
  City(id: 'city-1', name: 'İstanbul'),
  City(id: 'city-2', name: 'Adana'),
  City(id: 'city-3', name: 'Ankara'),
  City(id: 'city-4', name: 'Antalya'),
  City(id: 'city-5', name: 'Bursa'),
  City(id: 'city-6', name: 'Eskişehir'),
  City(id: 'city-7', name: 'İzmir'),
  City(id: 'city-8', name: 'Şanlıurfa'),
];
