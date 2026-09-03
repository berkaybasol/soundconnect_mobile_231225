import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/listener_profile_choice_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';

void main() {
  Widget app(
    _ChoiceRepository repository, {
    Size? size,
    TextScaler textScaler = TextScaler.noScaling,
    ListenerProfileChoiceCompletion? choiceCompletion,
    ListenerProfileChoiceLogout? logout,
  }) {
    final screen = ListenerProfileChoiceScreen(
      cubitFactory: () => ListenerProfileCubit(repository),
      choiceCompletion: choiceCompletion ?? () async => true,
      logout: logout ?? () async {},
    );
    final materialApp = MaterialApp(
      routes: <String, WidgetBuilder>{
        AppRoutes.listenerProfile: (_) =>
            const Scaffold(body: Text('listener-profile-target')),
        AppRoutes.login: (_) => const Scaffold(body: Text('login-target')),
      },
      home: screen,
    );
    if (size == null && textScaler == TextScaler.noScaling) {
      return materialApp;
    }
    return MediaQuery(
      data: MediaQueryData(
        size: size ?? const Size(420, 800),
      ).copyWith(textScaler: textScaler),
      child: materialApp,
    );
  }

  testWidgets('shows two premium profile choices with their icons and copy', (
    tester,
  ) async {
    final repository = _ChoiceRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Hayalet Profil'), findsOneWidget);
    expect(find.text('Sosyal Profil'), findsOneWidget);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    expect(find.text('Profilini seç'), findsNothing);
    expect(find.text('SoundConnect’te nasıl görünmek istersin?'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    expect(find.bySemanticsLabel('Hayalet profil simgesi'), findsOneWidget);
    expect(find.bySemanticsLabel('SoundConnect amblemi'), findsOneWidget);
    expect(find.byKey(const Key('listener-choice-ghost-icon')), findsOneWidget);
    expect(
      find.byKey(const Key('listener-choice-social-icon')),
      findsOneWidget,
    );
    expect(find.text('Standart SoundConnect deneyimi.'), findsOneWidget);
    expect(
      find.text(
        'SoundConnect’in bütün özelliklerinden faydalanabilirsin ancak profil '
        'içeriğin saklı kalır ve bu moddayken yeni profil içeriği kaydedilmez.',
      ),
      findsOneWidget,
    );
    const visibilityCopy = 'Seçimin profil görünürlüğünü belirler.';
    expect(find.text(visibilityCopy), findsOneWidget);
    final lockRect = tester.getRect(find.byIcon(Icons.lock_outline_rounded));
    final visibilityCopyRect = tester.getRect(find.text(visibilityCopy));
    expect(lockRect.center.dy, closeTo(visibilityCopyRect.center.dy, 0.5));
    expect(visibilityCopyRect.left - lockRect.right, closeTo(7, 0.5));
    expect(
      find.textContaining('Ayarlar’dan değiştirebilirsin'),
      findsOneWidget,
    );
    expect(find.textContaining('Standart Profil'), findsNothing);
    expect(repository.loadCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'social choice is first and cards keep an extended golden proportion',
    (tester) async {
      tester.view.physicalSize = const Size(420, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _ChoiceRepository();
      await tester.pumpWidget(app(repository));
      await tester.pumpAndSettle();

      final social = find.byKey(const Key('listener-choice-social'));
      final ghost = find.byKey(const Key('listener-choice-ghost'));
      final socialRect = tester.getRect(social);
      final ghostRect = tester.getRect(ghost);
      final contentTop = tester
          .getRect(find.textContaining('Sana uygun profil deneyimini seç'))
          .top;
      final contentBottom = tester
          .getRect(find.text('Seçimin profil görünürlüğünü belirler.'))
          .bottom;

      expect(socialRect.left, lessThan(ghostRect.left));
      expect(socialRect.height / socialRect.width, closeTo(2.618, 0.02));
      expect(ghostRect.height, socialRect.height);
      expect(contentTop, closeTo(860 - contentBottom, 1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in <({Key key, ListenerVisibilityMode mode})>[
    (
      key: const Key('listener-choice-ghost'),
      mode: ListenerVisibilityMode.ghost,
    ),
    (
      key: const Key('listener-choice-social'),
      mode: ListenerVisibilityMode.standard,
    ),
  ]) {
    testWidgets('${scenario.mode.name} choice is persisted before navigation', (
      tester,
    ) async {
      final repository = _ChoiceRepository();
      await tester.pumpWidget(app(repository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(scenario.key));
      await tester.tap(find.byKey(scenario.key));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.lastRequest?.visibilityMode, scenario.mode);
      expect(repository.lastRequest?.expectedVersion, 7);
      expect(find.text('listener-profile-target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('locks both choices while the visibility request is in flight', (
    tester,
  ) async {
    final repository = _ChoiceRepository();
    final pending = Completer<Result<ListenerProfile>>();
    repository.updateCompleter = pending;
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listener-choice-ghost')));
    await tester.tap(find.byKey(const Key('listener-choice-social')));
    await tester.pump();

    expect(repository.updateCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(
      Result.success(_profile(ListenerVisibilityMode.ghost, true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('listener-profile-target'), findsOneWidget);
  });

  testWidgets('failed mutation stays on the chooser and can be retried', (
    tester,
  ) async {
    final repository = _ChoiceRepository(
      updateResult: const Result.failure(AppError(code: '429', message: '')),
    );
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listener-choice-ghost')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('çok sık değiştirdin'), findsOneWidget);
    expect(find.text('listener-profile-target'), findsNothing);

    repository.updateResult = Result.success(
      _profile(ListenerVisibilityMode.ghost, true),
    );
    await tester.tap(find.byKey(const Key('listener-choice-ghost')));
    await tester.pumpAndSettle();
    expect(repository.updateCalls, 2);
    expect(find.text('listener-profile-target'), findsOneWidget);
  });

  testWidgets('two-column design remains usable at 320px and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ChoiceRepository();
    await tester.pumpWidget(
      app(
        repository,
        size: const Size(320, 700),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('listener-choice-ghost')), findsOneWidget);
    expect(find.byKey(const Key('listener-choice-social')), findsOneWidget);
    final socialRect = tester.getRect(
      find.byKey(const Key('listener-choice-social')),
    );
    final ghostRect = tester.getRect(
      find.byKey(const Key('listener-choice-ghost')),
    );
    expect(socialRect.left, lessThan(ghostRect.left));
    expect(socialRect.height, ghostRect.height);

    await tester.ensureVisible(find.text('Sosyal Profil'));
    await tester.tap(find.text('Sosyal Profil'));
    await tester.pumpAndSettle();

    expect(
      repository.lastRequest?.visibilityMode,
      ListenerVisibilityMode.standard,
    );
    expect(find.text('listener-profile-target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure offers a retry without exposing the choices', (
    tester,
  ) async {
    final repository = _ChoiceRepository(
      loadResult: const Result.failure(
        AppError(code: 'network', message: 'Bağlantı kurulamadı.'),
      ),
    );
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.text('Hayalet Profil'), findsNothing);

    repository.loadResult = Result.success(_profile());
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(repository.loadCalls, 2);
    expect(find.text('Hayalet Profil'), findsOneWidget);
  });

  testWidgets('account switch remains available when profile loading fails', (
    tester,
  ) async {
    final repository = _ChoiceRepository(
      loadResult: const Result.failure(
        AppError(code: 'network', message: 'Bağlantı kurulamadı.'),
      ),
    );
    var logoutCalls = 0;
    await tester.pumpWidget(
      app(
        repository,
        logout: () async {
          logoutCalls += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listener-choice-account-switch')));
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
    expect(find.text('login-target'), findsOneWidget);
  });

  testWidgets('partial mutation success reloads and unlocks the chooser', (
    tester,
  ) async {
    final repository = _ChoiceRepository();
    final pending = Completer<Result<ListenerProfile>>();
    final reload = Completer<Result<ListenerProfile>>();
    repository.updateCompleter = pending;
    repository.reloadCompleter = reload;
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listener-choice-ghost')));
    await tester.pump();
    pending.complete(
      Result.success(_profile(ListenerVisibilityMode.standard, false)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('listener-choice-social')));
    expect(repository.updateCalls, 1);

    reload.complete(Result.success(_profile()));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.textContaining('sunucuda doğrulanamadı'), findsOneWidget);

    repository.updateCompleter = null;
    repository.reloadCompleter = null;
    await tester.tap(find.byKey(const Key('listener-choice-social')));
    await tester.pumpAndSettle();
    expect(repository.updateCalls, 2);
    expect(find.text('listener-profile-target'), findsOneWidget);
  });

  testWidgets(
    'recovers a server-completed choice without asking the user again',
    (tester) async {
      final repository = _ChoiceRepository(
        loadResult: Result.success(
          _profile(ListenerVisibilityMode.standard, true),
        ),
      );
      var completionCalls = 0;

      await tester.pumpWidget(
        app(
          repository,
          choiceCompletion: () async {
            completionCalls += 1;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(completionCalls, 1);
      expect(repository.updateCalls, 0);
      expect(find.text('listener-profile-target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

ListenerProfile _profile([
  ListenerVisibilityMode mode = ListenerVisibilityMode.standard,
  bool visibilityChoiceCompleted = false,
]) {
  final ghost = mode == ListenerVisibilityMode.ghost;
  final restricted = ghost || !visibilityChoiceCompleted;
  return ListenerProfile(
    id: 'profile-1',
    userId: 'user-1',
    username: 'berna',
    bio: restricted ? null : 'bio',
    profilePictureUrl: null,
    followerCount: restricted ? null : 0,
    followingCount: restricted ? null : 0,
    visibilityMode: mode,
    version: 7,
    profileContentVisible: !restricted,
    profileContentEditable: !restricted,
    canReceiveFollowers: !restricted,
    visibilityChoiceCompleted: visibilityChoiceCompleted,
  );
}

class _ChoiceRepository extends ListenerProfileRepository {
  _ChoiceRepository({
    Result<ListenerProfile>? loadResult,
    Result<ListenerProfile>? updateResult,
  }) : loadResult = loadResult ?? Result.success(_profile()),
       updateResult = updateResult ?? Result.success(_profile());

  Result<ListenerProfile> loadResult;
  Result<ListenerProfile> updateResult;
  Completer<Result<ListenerProfile>>? updateCompleter;
  Completer<Result<ListenerProfile>>? reloadCompleter;
  int loadCalls = 0;
  int updateCalls = 0;
  ListenerVisibilityUpdateRequest? lastRequest;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    loadCalls += 1;
    final completer = reloadCompleter;
    if (loadCalls > 1 && completer != null) {
      return completer.future;
    }
    return loadResult;
  }

  @override
  Future<Result<ListenerProfile>> updateVisibility(
    ListenerVisibilityUpdateRequest request,
  ) async {
    updateCalls += 1;
    lastRequest = request;
    final completer = updateCompleter;
    if (completer != null) return completer.future;
    if (!updateResult.isSuccess) return updateResult;
    return Result.success(_profile(request.visibilityMode, true));
  }
}
