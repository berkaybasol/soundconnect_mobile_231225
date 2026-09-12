import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/musician_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/musician_profile_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_public_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/backstage_palette.dart';

void main() {
  testWidgets(
    'musician page uses canonical neutral surfaces and brand accents',
    (tester) async {
      final base = AppTheme.navy;
      late ThemeData scoped;
      await tester.pumpWidget(
        MaterialApp(
          theme: base,
          home: MusicianProfileThemeScope(
            child: Builder(
              builder: (context) {
                scoped = Theme.of(context);
                return const Scaffold(body: SizedBox.expand());
              },
            ),
          ),
        ),
      );

      final colors = scoped.colorScheme;
      expect(colors.brightness, Brightness.dark);
      expect(colors.surface, BackstagePalette.canvas);
      expect(colors.surfaceDim, BackstagePalette.canvasTop);
      expect(colors.surfaceBright, BackstagePalette.surfaceRaised);
      expect(colors.surfaceContainerLowest, BackstagePalette.canvasTop);
      expect(colors.surfaceContainerLow, BackstagePalette.canvas);
      expect(colors.surfaceContainer, BackstagePalette.surface);
      expect(colors.surfaceContainerHigh, BackstagePalette.surfaceRaised);
      expect(colors.surfaceContainerHighest, BackstagePalette.input);
      expect(colors.onSurface, BackstagePalette.textPrimary);
      expect(colors.onSurfaceVariant, BackstagePalette.textMuted);
      expect(colors.outline, BackstagePalette.border);
      expect(colors.outlineVariant, BackstagePalette.divider);
      expect(scoped.scaffoldBackgroundColor, Colors.transparent);
      expect(scoped.cardTheme.color, BackstagePalette.surface);
      expect(scoped.canvasColor, BackstagePalette.surfaceRaised);
      expect(scoped.dividerColor, BackstagePalette.border);
      expect(scoped.inputDecorationTheme.fillColor, BackstagePalette.input);
      expect(scoped.popupMenuTheme.color, BackstagePalette.surfaceRaised);
      expect(
        scoped.dialogTheme.backgroundColor,
        BackstagePalette.surfaceRaised,
      );
      expect(
        scoped.bottomSheetTheme.modalBackgroundColor,
        BackstagePalette.surfaceRaised,
      );

      // A palette change must not redefine semantic colors or page behavior.
      expect(colors.primary, base.colorScheme.primary);
      expect(colors.secondary, base.colorScheme.secondary);
      expect(colors.error, base.colorScheme.error);
      expect(scoped.pageTransitionsTheme, base.pageTransitionsTheme);
      expect(scoped.visualDensity, base.visualDensity);
      expect(scoped.elevatedButtonTheme, base.elevatedButtonTheme);
      expect(scoped.appBarTheme.toolbarHeight, base.appBarTheme.toolbarHeight);
      expect(
        scoped.inputDecorationTheme.focusedBorder,
        base.inputDecorationTheme.focusedBorder,
      );
      expect(
        scoped.inputDecorationTheme.enabledBorder!.borderSide.color,
        BackstagePalette.border,
      );

      final backgrounds = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(MusicianProfileThemeScope),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient = backgrounds
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<LinearGradient>()
          .single;
      expect(gradient.colors, const [
        BackstagePalette.canvasTop,
        BackstagePalette.canvasMid,
        BackstagePalette.canvasTop,
      ]);
      expect(gradient.stops, const [0, 0.48, 1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile theme leaves siblings and navigation chrome unchanged', (
    tester,
  ) async {
    final base = AppTheme.navy;
    late ThemeData outside;
    late ThemeData inside;
    late ThemeData chrome;
    await tester.pumpWidget(
      MaterialApp(
        theme: base,
        home: Column(
          children: [
            Builder(
              builder: (context) {
                outside = Theme.of(context);
                return const SizedBox.shrink();
              },
            ),
            MusicianProfileThemeScope(
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      inside = Theme.of(context);
                      return const SizedBox.shrink();
                    },
                  ),
                  MusicianProfileChromeScope(
                    child: Builder(
                      builder: (context) {
                        chrome = Theme.of(context);
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    expect(outside.colorScheme, base.colorScheme);
    expect(outside.scaffoldBackgroundColor, base.scaffoldBackgroundColor);
    expect(chrome.colorScheme, outside.colorScheme);
    expect(chrome.scaffoldBackgroundColor, outside.scaffoldBackgroundColor);
    expect(chrome.bottomNavigationBarTheme, outside.bottomNavigationBarTheme);
    expect(chrome.navigationBarTheme, outside.navigationBarTheme);
    expect(chrome.iconTheme, outside.iconTheme);
    expect(inside.colorScheme.surface, BackstagePalette.canvas);
    expect(inside.colorScheme.surface, isNot(base.colorScheme.surface));
    expect(tester.takeException(), isNull);
  });

  for (final owner in [true, false]) {
    testWidgets(
      '${owner ? 'owner' : 'public'} route keeps loading and failure in the profile palette',
      (tester) async {
        await serviceLocator.reset();
        final profiles = _PendingProfileRepository();
        final sessions = _GuestSessions();
        serviceLocator
          ..registerSingleton<AuthSessionManager>(sessions)
          ..registerSingleton<ArtistVenueConnectionRepository>(
            _UnusedConnections(),
          )
          ..registerSingleton<LocationRepository>(_UnusedLocations())
          ..registerSingleton<VenueDirectoryRepository>(_UnusedVenues())
          ..registerFactory<MusicianProfileCubit>(
            () => MusicianProfileCubit(profiles),
          )
          ..registerFactory<FollowActionCubit>(
            () => FollowActionCubit(_UnusedFollowRepository()),
          );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await serviceLocator.reset();
          sessions.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              settings: const RouteSettings(
                arguments: PublicProfileArgs(profileId: 'musician-profile'),
              ),
              builder: (_) => owner
                  ? const MusicianProfileScreen()
                  : const MusicianPublicProfileScreen(),
            ),
          ),
        );

        expect(find.byType(MusicianProfileThemeScope), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          Theme.of(tester.element(find.byType(Scaffold))).colorScheme.surface,
          BackstagePalette.canvas,
        );
        expect(profiles.ownerReads, owner ? 1 : 0);
        expect(profiles.publicReads, owner ? 0 : 1);

        profiles.result.complete(
          const Result.failure(
            AppError(
              code: 'test_profile_unavailable',
              message: 'Profil okunamadı',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Profil okunamadı'), findsOneWidget);
        expect(
          Theme.of(
            tester.element(find.text('Profil okunamadı')),
          ).colorScheme.onSurface,
          BackstagePalette.textPrimary,
        );
        expect(find.byType(MusicianProfileThemeScope), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('removing the profile scope restores the original theme', (
    tester,
  ) async {
    final base = AppTheme.navy;
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    late ThemeData observed;
    await tester.pumpWidget(
      MaterialApp(
        theme: base,
        home: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (_, scoped, _) {
            final child = Builder(
              builder: (context) {
                observed = Theme.of(context);
                return const SizedBox.shrink();
              },
            );
            return scoped ? MusicianProfileThemeScope(child: child) : child;
          },
        ),
      ),
    );
    expect(observed.colorScheme.surface, BackstagePalette.canvas);
    enabled.value = false;
    await tester.pumpAndSettle();
    expect(observed.colorScheme, base.colorScheme);
    expect(observed.scaffoldBackgroundColor, base.scaffoldBackgroundColor);
    expect(observed.cardTheme, base.cardTheme);
    expect(observed.inputDecorationTheme, base.inputDecorationTheme);
    expect(tester.takeException(), isNull);
  });
}

class _GuestSessions extends Fake
    with ChangeNotifier
    implements AuthSessionManager {
  @override
  AuthSession get session => const AuthSession.guest();
}

class _PendingProfileRepository extends Fake
    implements MusicianProfileRepository {
  final result = Completer<Result<MusicianProfile>>();
  var ownerReads = 0;
  var publicReads = 0;

  @override
  Future<Result<MusicianProfile>> getMyProfile() {
    ownerReads++;
    return result.future;
  }

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) {
    publicReads++;
    return result.future;
  }
}

class _UnusedConnections extends Fake
    implements ArtistVenueConnectionRepository {}

class _UnusedLocations extends Fake implements LocationRepository {}

class _UnusedVenues extends Fake implements VenueDirectoryRepository {}

class _UnusedFollowRepository extends Fake implements FollowRepository {}
