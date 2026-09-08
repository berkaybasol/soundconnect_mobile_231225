import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_pending_invitation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_management_panel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_member_caption.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  late _Bands bands;
  late _SessionManager session;
  setUp(() async {
    await serviceLocator.reset();
    bands = _Bands();
    session = _SessionManager();
    serviceLocator
      ..registerSingleton<BandRepository>(bands)
      ..registerSingleton<MusicianProfileRepository>(_Musicians())
      ..registerSingleton<AuthSessionManager>(session);
  });
  tearDown(serviceLocator.reset);

  testWidgets(
    'active founder can edit self and active members, not pending members',
    (tester) async {
      bands.profile = _profile(
        members: [
          _member('founder', role: 'FOUNDER'),
          _member('member'),
          _member('pending', status: 'PENDING'),
        ],
      );
      await _mount(tester, bands);
      expect(find.byKey(const Key('edit-member-title-founder')), findsNothing);
      expect(find.byKey(const Key('edit-member-title-member')), findsNothing);
      await _openOptions(tester, 'founder');
      expect(
        find.byKey(const Key('edit-member-title-founder')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('remove-member-founder')), findsNothing);
      await _dismissOptions(tester, 'founder');
      await _openOptions(tester, 'member');
      expect(find.byKey(const Key('edit-member-title-member')), findsOneWidget);
      expect(find.byKey(const Key('remove-member-member')), findsOneWidget);
      await _dismissOptions(tester, 'member');
      expect(find.byKey(const Key('edit-member-title-pending')), findsNothing);
      expect(find.byKey(const Key('remove-member-pending')), findsNothing);
      expect(find.byKey(const Key('member-options-pending')), findsNothing);
      expect(find.byKey(const Key('band-member-pending')), findsNothing);
      expect(find.text('Kurucu'), findsOneWidget);
      expect(find.text('Üye'), findsNothing);
      expect(find.text('Menajer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewer in [
    'member',
    'outsider',
    'inactive',
    'guest',
    'wrong-role',
  ]) {
    testWidgets('$viewer never sees title editing actions', (tester) async {
      session.value = viewer == 'guest'
          ? const AuthSession.guest()
          : _session(
              userId: viewer == 'inactive' || viewer == 'wrong-role'
                  ? 'founder'
                  : viewer,
              status: viewer == 'inactive' ? 'PENDING' : 'ACTIVE',
              role: viewer == 'wrong-role' ? 'ROLE_LISTENER' : 'ROLE_MUSICIAN',
            );
      await _mount(tester, bands);
      expect(find.byKey(const Key('edit-member-title-founder')), findsNothing);
      expect(find.byKey(const Key('edit-member-title-member')), findsNothing);
      expect(find.byKey(const Key('member-options-founder')), findsNothing);
      expect(find.byKey(const Key('member-options-member')), findsNothing);
      expect(bands.writes, isEmpty);
    });
  }

  testWidgets(
    'founder can save own display title without changing founder authority',
    (tester) async {
      await _mount(tester, bands);
      await _edit(tester, 'founder', 'Vokalist');
      await _save(tester);
      expect(bands.writes.single.userId, 'founder');
      expect(bands.writes.single.bandId, 'band');
      expect(bands.writes.single.expectedVersion, 3);
      expect(bands.writes.single.sessionKey, 'founder');
      expect(find.text('Vokalist'), findsOneWidget);
      expect(find.text('Kurucu'), findsOneWidget);
      expect(find.byKey(const Key('member-options-founder')), findsOneWidget);
      final caption = tester.widget<BandMemberCaption>(
        find.byWidgetPredicate(
          (widget) =>
              widget is BandMemberCaption && widget.member.userId == 'founder',
        ),
      );
      expect(caption.member.isFounder, isTrue);
      expect(caption.member.profileId, 'profile-founder');
      expect(caption.member.titleVersion, 4);
    },
  );

  testWidgets(
    'free-form title saves once with exact target and title version',
    (tester) async {
      await _mount(tester, bands);
      await _edit(tester, 'member', '  Davul  & Perküsyon  ');
      await _save(tester);
      expect(bands.writes, hasLength(1));
      expect(bands.writes.single.title, 'Davul  & Perküsyon');
      expect(bands.writes.single.userId, 'member');
      expect(find.text('Davul  & Perküsyon'), findsOneWidget);
      expect(find.text('Gruptaki rolü kaydedildi.'), findsOneWidget);
      expect(find.text('Üye'), findsNothing);
    },
  );

  testWidgets(
    'confirmed title response cannot overwrite roster profile identity',
    (tester) async {
      bands.onWrite = (_) async => const Result.success(
        BandMemberSummary(
          userId: 'member',
          profileId: null,
          username: 'Changed response username',
          profilePictureUrl: 'wrong-avatar',
          role: 'MEMBER',
          status: 'ACTIVE',
          memberTitle: 'Gitarist',
          titleVersion: 4,
        ),
      );
      await _mount(tester, bands);
      await _edit(tester, 'member', 'Gitarist');
      await _save(tester);
      final caption = tester.widget<BandMemberCaption>(
        find.byWidgetPredicate(
          (widget) =>
              widget is BandMemberCaption && widget.member.userId == 'member',
        ),
      );
      expect(caption.member.profileId, 'profile-member');
      expect(caption.member.username, 'aedrum');
      expect(caption.member.profilePictureUrl, isNull);
      expect(caption.member.memberTitle, 'Gitarist');
      expect(caption.member.titleVersion, 4);
      expect(caption.member.role, 'MEMBER');
    },
  );

  testWidgets('cancellation and unchanged title never send a mutation', (
    tester,
  ) async {
    bands.profile = _profile(
      members: [
        _member('founder', role: 'FOUNDER'),
        _member('member', title: 'Davulcu'),
      ],
    );
    await _mount(tester, bands);
    await _openEditor(tester, 'member');
    expect(_saveButton(tester).onPressed, isNull);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(bands.writes, isEmpty);
    expect(find.text('Davulcu'), findsOneWidget);
  });

  testWidgets('clear sends null and removes the generic member subtitle', (
    tester,
  ) async {
    bands.profile = _profile(
      members: [
        _member('founder', role: 'FOUNDER'),
        _member('member', title: 'Davulcu'),
      ],
    );
    await _mount(tester, bands);
    await _openEditor(tester, 'member');
    await tester.tap(find.byKey(const Key('band-member-title-clear')));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(bands.writes.single.title, isNull);
    expect(find.text('Davulcu'), findsNothing);
    expect(find.text('Üye'), findsNothing);
    expect(find.text('Gruptaki rolü kaldırıldı.'), findsOneWidget);
  });

  testWidgets('20 joined emoji count as 20 user-perceived characters', (
    tester,
  ) async {
    await _mount(tester, bands);
    await _edit(tester, 'member', List.filled(21, '👩‍👩‍👧‍👦').join());
    final input = tester.widget<TextField>(
      find.byKey(const Key('band-member-title-input')),
    );
    expect(input.controller!.text.characters.length, 20);
    expect(find.text('20/20'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);
    await _save(tester);
    expect(bands.writes.single.title!.characters.length, 20);
  });

  for (final invalid in [
    'Gitar\u202E',
    'a${List.filled(260, '\u0301').join()}',
  ]) {
    testWidgets(
      'invalid control or oversized raw input is not submitted ${invalid.length}',
      (tester) async {
        await _mount(tester, bands);
        await _edit(tester, 'member', invalid);
        expect(_saveButton(tester).onPressed, isNull);
        expect(bands.writes, isEmpty);
      },
    );
  }

  testWidgets(
    'single-line input removes pasted line breaks before submission',
    (tester) async {
      await _mount(tester, bands);
      await _edit(tester, 'member', 'Davul\nVokal');
      final input = tester.widget<TextField>(
        find.byKey(const Key('band-member-title-input')),
      );
      expect(input.controller!.text, 'DavulVokal');
      await _save(tester);
      expect(bands.writes.single.title, 'DavulVokal');
    },
  );

  testWidgets('session switch while editing cannot send a stale mutation', (
    tester,
  ) async {
    await _mount(tester, bands);
    await _edit(tester, 'member', 'Davulcu');
    session.change(_session(userId: 'other-user'));
    await tester.pump();
    await _save(tester);
    expect(bands.writes, isEmpty);
    expect(find.text('Davulcu'), findsNothing);
  });

  testWidgets(
    'pending write is single flight and never applies an optimistic title',
    (tester) async {
      final pending = Completer<Result<BandMemberSummary>>();
      bands.onWrite = (_) => pending.future;
      await _mount(tester, bands);
      final staleOpen = tester
          .widget<IconButton>(find.byKey(const Key('member-options-member')))
          .onPressed!;
      await _openOptions(tester, 'member');
      final staleSelection = tester
          .widget<InkWell>(find.byKey(const Key('edit-member-title-member')))
          .onTap!;
      staleSelection();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('band-member-title-input')),
        'Davulcu',
      );
      await tester.pumpAndSettle();
      final submit = _saveButton(tester).onPressed!;
      submit();
      submit();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(bands.writes, hasLength(1));
      expect(find.text('Davulcu'), findsNothing);
      staleOpen();
      staleSelection();
      await tester.pump();
      expect(find.byKey(const Key('band-member-title-dialog')), findsNothing);
      expect(find.byKey(const Key('edit-member-title-member')), findsNothing);
      pending.complete(
        Result.success(_member('member', title: 'Davulcu', version: 4)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Davulcu'), findsOneWidget);
      staleOpen();
      staleSelection();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('band-member-title-dialog')), findsNothing);
      expect(find.byKey(const Key('edit-member-title-member')), findsNothing);
      expect(bands.writes, hasLength(1));
    },
  );

  for (final bad in [
    'user',
    'role',
    'status',
    'version',
    'same-version-title',
  ]) {
    testWidgets(
      '$bad response reconciles the roster once without replaying mutation',
      (tester) async {
        bands.onWrite = (_) async {
          bands.profile = _profile(
            members: [
              _member('founder', role: 'FOUNDER'),
              _member('member', title: 'Sunucudaki unvan', version: 5),
            ],
          );
          return Result.success(
            _member(
              bad == 'user' ? 'stranger' : 'member',
              role: bad == 'role' ? 'FOUNDER' : 'MEMBER',
              status: bad == 'status' ? 'LEFT' : 'ACTIVE',
              title: 'Davulcu',
              version: bad == 'version'
                  ? 9
                  : bad == 'same-version-title'
                  ? 3
                  : 4,
            ),
          );
        };
        await _mount(tester, bands);
        await _edit(tester, 'member', 'Davulcu');
        await _save(tester);
        expect(bands.writes, hasLength(1));
        expect(bands.reads, 2);
        expect(find.text('Davulcu'), findsNothing);
        expect(find.text('Sunucudaki unvan'), findsOneWidget);
        expect(find.text('Kurucu'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'transport error refreshes authoritative state and permits a fresh edit',
    (tester) async {
      bands.onWrite = (_) async => throw StateError('Lost response');
      await _mount(tester, bands);
      await _edit(tester, 'member', 'Davulcu');
      await _save(tester);
      expect(bands.reads, 2);
      expect(bands.writes, hasLength(1));
      bands.onWrite = null;
      await _edit(tester, 'member', 'Gitarist');
      await _save(tester);
      expect(bands.writes, hasLength(2));
      expect(find.text('Gitarist'), findsOneWidget);
    },
  );

  testWidgets(
    'late reply after sign-out cannot merge titles into the old page',
    (tester) async {
      final pending = Completer<Result<BandMemberSummary>>();
      bands.onWrite = (_) => pending.future;
      await _mount(tester, bands);
      await _edit(tester, 'member', 'Davulcu');
      _saveButton(tester).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      session.change(const AuthSession.guest());
      pending.complete(
        Result.success(_member('member', title: 'Davulcu', version: 4)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Davulcu'), findsNothing);
      expect(find.byKey(const Key('edit-member-title-member')), findsNothing);
      expect(find.byKey(const Key('member-options-member')), findsNothing);
      expect(bands.writes, hasLength(1));
      expect(bands.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large-text editor remains scrollable above a phone keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mount(tester, bands, scale: 2);
    await _edit(tester, 'member', 'Davulcu');
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('band-member-title-save')));
    expect(tester.takeException(), isNull);
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  for (final lostResponse in [false, true]) {
    testWidgets(
      'settled write reconciles surviving parent after workspace disposal $lostResponse',
      (tester) async {
        final pending = Completer<Result<BandMemberSummary>>();
        bands.onWrite = (_) => pending.future;
        await _mount(tester, bands);
        final navigator = Navigator.of(
          tester.element(find.byKey(const Key('member-options-member'))),
        );
        await _edit(tester, 'member', 'Davulcu');
        _saveButton(tester).onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        navigator.pop();
        await tester.pumpAndSettle();
        bands.profile = _profile(
          members: [
            _member('founder', role: 'FOUNDER'),
            _member('member', title: 'Davulcu', version: 4),
          ],
        );
        if (lostResponse) {
          pending.completeError(StateError('Lost response'));
        } else {
          pending.complete(
            Result.success(_member('member', title: 'Davulcu', version: 4)),
          );
        }
        await tester.pumpAndSettle();
        expect(bands.reads, 2);
        expect(bands.writes, hasLength(1));
        await tester.ensureVisible(find.text('Üyeleri Yönet'));
        await tester.tap(find.text('Üyeleri Yönet'));
        await tester.pumpAndSettle();
        expect(find.text('Davulcu'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const Key('member-options-member')),
              )
              .onPressed,
          isNotNull,
        );
        expect(bands.reads, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('saved dialog callbacks are inert after dialog disposal', (
    tester,
  ) async {
    await _mount(tester, bands);
    await _edit(tester, 'member', 'Davulcu');
    final save = _saveButton(tester).onPressed!;
    final clear = tester
        .widget<IconButton>(find.byKey(const Key('band-member-title-clear')))
        .onPressed!;
    final cancel = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Vazgeç'))
        .onPressed!;
    cancel();
    await tester.pumpAndSettle();
    save();
    clear();
    cancel();
    await tester.pumpAndSettle();
    expect(bands.writes, isEmpty);
    expect(find.text('Üyeleri Yönet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'member options are single flight and block other roster actions',
    (tester) async {
      await _mount(tester, bands);
      final open = tester
          .widget<IconButton>(find.byKey(const Key('member-options-member')))
          .onPressed!;
      final refresh = tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.refresh_rounded),
          )
          .onPressed!;
      open();
      open();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const Key('edit-member-title-member')), findsOneWidget);
      expect(find.byKey(const Key('remove-member-member')), findsOneWidget);
      refresh();
      await tester.pump();
      expect(bands.reads, 1);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(
                const Key('member-options-founder'),
                skipOffstage: false,
              ),
            )
            .onPressed,
        isNull,
      );
      await _dismissOptions(tester, 'member');
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('member-options-member')))
            .onPressed,
        isNotNull,
      );
      expect(bands.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in <String, AuthSession>{
    'account': _session(userId: 'other-user'),
    'token': _session(token: 'replacement-token'),
    'status': _session(status: 'SUSPENDED'),
    'role': _session(role: 'ROLE_LISTENER'),
    'logout': const AuthSession.guest(),
  }.entries) {
    testWidgets('title menu selection after session ${change.key} is inert', (
      tester,
    ) async {
      await _mount(tester, bands);
      await _openOptions(tester, 'member');
      session.change(change.value);
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-member-title-member')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('band-member-title-dialog')), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(bands.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disposed menu selection cannot pop a newer editor route', (
    tester,
  ) async {
    await _mount(tester, bands);
    await _openOptions(tester, 'member');
    final staleSelect = tester
        .widget<InkWell>(find.byKey(const Key('edit-member-title-member')))
        .onTap!;
    await _dismissOptions(tester, 'member');
    await _openEditor(tester, 'founder');
    staleSelect();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('band-member-title-dialog')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(bands.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved menu callback is inert after workspace disposal', (
    tester,
  ) async {
    await _mount(tester, bands);
    final workspaceNavigator = Navigator.of(
      tester.element(find.byKey(const Key('member-options-member'))),
    );
    await _openOptions(tester, 'member');
    final staleSelect = tester
        .widget<InkWell>(find.byKey(const Key('edit-member-title-member')))
        .onTap!;
    await _dismissOptions(tester, 'member');
    workspaceNavigator.pop();
    await tester.pumpAndSettle();
    staleSelect();
    await tester.pumpAndSettle();
    expect(find.text('Band Yönetimi'), findsOneWidget);
    expect(find.byKey(const Key('band-member-title-dialog')), findsNothing);
    expect(bands.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final theme in ['navy', 'light', 'black']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('title cards and editor fit responsive $theme ${scale}x', (
        tester,
      ) async {
        bands.profile = _profile(
          members: [
            _member('founder', role: 'FOUNDER', title: 'Vokal ve Bas Gitar'),
            _member('member', title: 'Davul ve Perküsyon'),
          ],
        );
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _mount(tester, bands, theme: theme, scale: scale);
        expect(tester.takeException(), isNull);
        for (final id in ['founder', 'member']) {
          final identity = tester.getRect(
            find.byKey(Key('band-member-identity-$id')),
          );
          final copy = tester.getRect(
            find.byKey(Key('band-member-identity-copy-$id')),
          );
          final menu = tester.getRect(find.byKey(Key('member-options-$id')));
          expect(menu.width, greaterThanOrEqualTo(48));
          expect(menu.height, greaterThanOrEqualTo(48));
          expect(find.byKey(Key('band-member-actions-$id')), findsNothing);
          expect(
            copy.width,
            greaterThanOrEqualTo(scale == 2 ? 130 : 200),
            reason: 'One trailing action preserves readable identity width',
          );
          expect((menu.center.dy - identity.center.dy).abs(), lessThan(1));
          expect(menu.left, greaterThanOrEqualTo(identity.right));
          expect(find.byKey(Key('edit-member-title-$id')), findsNothing);
        }
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
        await _capturePreview(tester, 'roster-$theme-$scale');
        await _openOptions(tester, 'member');
        expect(
          find.byKey(const Key('edit-member-title-member')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('remove-member-member')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _capturePreview(tester, 'menu-$theme-$scale');
        await _dismissOptions(tester, 'member');
        await _openOptions(tester, 'founder');
        await tester.tap(find.byKey(const Key('edit-member-title-founder')));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byKey(const Key('band-member-title-save')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _capturePreview(tester, 'editor-$theme-$scale');
      });
    }
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Bands bands, {
  String theme = 'navy',
  double scale = 1,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('member-title-preview'),
      child: MaterialApp(
        theme: theme == 'light'
            ? AppTheme.light
            : theme == 'black'
            ? AppTheme.black
            : AppTheme.navy,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: BandManagementPanelScreen(profile: bands.profile),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Üyeleri Yönet'));
  await tester.tap(find.text('Üyeleri Yönet'));
  await tester.pumpAndSettle();
}

Future<void> _capturePreview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('MEMBER_TITLE_PREVIEW')) return;
  await tester.runAsync(() async {
    const fontRoot = String.fromEnvironment(
      'MEMBER_TITLE_PREVIEW_FLUTTER_ROOT',
    );
    for (final font in {
      'Roboto':
          '$fontRoot/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
      'MaterialIcons':
          '$fontRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
            font.key,
          )..addFont(File(font.value).readAsBytes().then(ByteData.sublistView)))
          .load();
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('member-title-preview')),
  );
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/band-member-title-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      picture.dispose();
    }
  });
}

Future<void> _edit(WidgetTester tester, String id, String title) async {
  await _openEditor(tester, id);
  await tester.enterText(
    find.byKey(const Key('band-member-title-input')),
    title,
  );
  await tester.pumpAndSettle();
}

Future<void> _openOptions(WidgetTester tester, String id) async {
  await tester.ensureVisible(find.byKey(Key('member-options-$id')));
  await tester.tap(find.byKey(Key('member-options-$id')));
  await tester.pumpAndSettle();
}

Future<void> _dismissOptions(WidgetTester tester, String id) async {
  final edit = find.byKey(Key('edit-member-title-$id'));
  final item = edit.evaluate().isNotEmpty
      ? edit
      : find.byKey(Key('remove-member-$id'));
  Navigator.of(tester.element(item)).pop();
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester, String id) async {
  await _openOptions(tester, id);
  await tester.tap(find.byKey(Key('edit-member-title-$id')));
  await tester.pumpAndSettle();
}

GradientOutlineButton _saveButton(WidgetTester tester) =>
    tester.widget<GradientOutlineButton>(
      find.byKey(const Key('band-member-title-save')),
    );

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('band-member-title-save')));
  await tester.tap(find.byKey(const Key('band-member-title-save')));
  await tester.pumpAndSettle();
}

BandMemberSummary _member(
  String id, {
  String role = 'MEMBER',
  String status = 'ACTIVE',
  String? title,
  int version = 3,
}) => BandMemberSummary(
  userId: id,
  profileId: 'profile-$id',
  username: id == 'founder' ? 'bugrasahin' : 'aedrum',
  profilePictureUrl: null,
  role: role,
  status: status,
  memberTitle: title,
  titleVersion: version,
);

BandProfile _profile({List<BandMemberSummary>? members}) => BandProfile(
  id: 'band',
  name: 'Şahbaz',
  description: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: const [],
  members: members ?? [_member('founder', role: 'FOUNDER'), _member('member')],
);

AuthSession _session({
  String userId = 'founder',
  String status = 'ACTIVE',
  String role = 'ROLE_MUSICIAN',
  String? token,
}) => AuthSession.authenticated(
  token: token ?? 'token-$userId',
  userId: userId,
  username: userId,
  accountStatus: status,
  roles: [role],
  permissions: const [],
  expiresAt: DateTime.utc(2040),
  isAdmin: false,
);

class _SessionManager extends Fake implements AuthSessionManager {
  AuthSession value = _session();
  final listeners = <VoidCallback>{};
  @override
  AuthSession get session => value;
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  void change(AuthSession next) {
    value = next;
    for (final listener in List.of(listeners)) {
      listener();
    }
  }
}

typedef _Write = ({
  String bandId,
  String userId,
  String? title,
  int expectedVersion,
  String sessionKey,
});

class _Bands extends Fake implements BandRepository {
  BandProfile profile = _profile();
  int reads = 0;
  final writes = <_Write>[];
  Future<Result<BandMemberSummary>> Function(_Write)? onWrite;
  @override
  Future<Result<BandProfile>> getBandById(String bandId) async {
    reads++;
    return Result.success(profile);
  }

  @override
  Future<Result<BandPendingInvitationPage>> getPendingInvitations({
    required String bandId,
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  }) async => Result.success(
    BandPendingInvitationPage(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      hasNext: false,
    ),
  );

  @override
  Future<Result<BandMemberSummary>> updateMemberTitle({
    required String bandId,
    required String userId,
    String? memberTitle,
    required int expectedTitleVersion,
    required String expectedSessionKey,
  }) async {
    final call = (
      bandId: bandId,
      userId: userId,
      title: memberTitle,
      expectedVersion: expectedTitleVersion,
      sessionKey: expectedSessionKey,
    );
    writes.add(call);
    if (onWrite != null) return onWrite!(call);
    final current = profile.members.singleWhere(
      (member) => member.userId == userId,
    );
    final updated = current.copyWithTitle(
      memberTitle: memberTitle,
      titleVersion: expectedTitleVersion + 1,
    );
    profile = _profile(
      members: profile.members
          .map((member) => member.userId == userId ? updated : member)
          .toList(),
    );
    return Result.success(updated);
  }
}

class _Musicians extends Fake implements MusicianProfileRepository {
  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async =>
      const Result.failure(AppError(code: 'missing', message: 'No photo'));
}
