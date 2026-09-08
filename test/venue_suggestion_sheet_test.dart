import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event/domain/venue_suggestion_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event/presentation/screens/venue_suggestion_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';

const _ankara = City(id: 'a', name: 'Ankara');
const _istanbul = City(id: 'i', name: 'İstanbul');
const _cankaya = District(id: 'c', name: 'Çankaya', cityId: 'a');
const _kadikoy = District(id: 'k', name: 'Kadıköy', cityId: 'i');
const _failure = Result<void>.failure(
  AppError(code: 'network', message: 'Yeniden dene.'),
);

void main() {
  testWidgets(
    'valid authoritative prefill is used without external contact fields',
    (tester) async {
      await _open(tester);
      expect(find.text('Ankara'), findsOneWidget);
      expect(find.text('Çankaya'), findsOneWidget);
      expect(find.text('Mekan adı'), findsOneWidget);
      expect(find.textContaining('Instagram'), findsNothing);
      expect(find.textContaining('Giriş'), findsNothing);
      expect(find.text('Evet'), findsOneWidget);
      expect(find.text('Hayır'), findsOneWidget);
      expect(find.text('Bilmiyorum'), findsOneWidget);
    },
  );

  testWidgets('forged city and district prefill is never selected', (
    tester,
  ) async {
    await _open(
      tester,
      city: const City(id: 'wrong', name: 'Yanlış'),
      district: _kadikoy,
    );
    expect(find.text('Yanlış'), findsNothing);
    expect(find.text('Kadıköy'), findsNothing);
    expect(find.text('İl seç'), findsOneWidget);
  });

  testWidgets('district belonging to another city is not prefilled', (
    tester,
  ) async {
    await _open(tester, district: _kadikoy);
    expect(find.text('Ankara'), findsOneWidget);
    expect(find.text('Kadıköy'), findsNothing);
    expect(find.text('İlçe seç'), findsOneWidget);
  });

  testWidgets(
    'empty form requires name city district and explicit music answer',
    (tester) async {
      final repo = _Repo();
      await _open(tester, repo: repo, city: null, district: null);
      await _tap(tester, find.byKey(const ValueKey('proposal-submit')));
      expect(find.text('Mekan adı 2–100 karakter olmalı.'), findsOneWidget);
      expect(find.text('İl seçmelisin.'), findsOneWidget);
      expect(find.text('İlçe seçmelisin.'), findsOneWidget);
      expect(find.text('Bir seçenek işaretlemelisin.'), findsOneWidget);
      expect(repo.requests, isEmpty);
    },
  );

  for (final answer in ['Evet', 'Hayır', 'Bilmiyorum']) {
    testWidgets('valid $answer submits once and returns true', (tester) async {
      final repo = _Repo();
      bool? returned;
      await _open(tester, repo: repo, onResult: (value) => returned = value);
      await _fill(tester, answer: answer);
      await _tap(tester, find.byKey(const ValueKey('proposal-submit')));
      expect(repo.requests, hasLength(1));
      expect(repo.requests.single.venueName, 'Şehir Sahnesi');
      expect(repo.requests.single.cityId, 'a');
      expect(repo.requests.single.districtId, 'c');
      expect(returned, isTrue);
      expect(find.text('Mekan öner'), findsNothing);
    });
  }

  testWidgets(
    'pending submit blocks double taps fields close back and drag dismissal',
    (tester) async {
      final pending = Completer<Result<void>>();
      final repo = _Repo()..handler = () => pending.future;
      await _open(tester, repo: repo);
      await _fill(tester);
      final submit = find.byKey(const ValueKey('proposal-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      expect(repo.requests, hasLength(1));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('proposal-venue-name')),
            )
            .enabled,
        isFalse,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Mekan öner'), findsOneWidget);
      await tester.ensureVisible(find.text('Mekan öner'));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Kapat',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.drag(find.text('Mekan öner'), const Offset(0, 350));
      await tester.pump();
      expect(find.text('Mekan öner'), findsOneWidget);
      pending.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(find.text('Mekan öner'), findsNothing);
    },
  );

  testWidgets(
    'retry retains entered data and request id, changed payload gets new id',
    (tester) async {
      final repo = _Repo()..handler = () async => _failure;
      await _open(tester, repo: repo);
      await _fill(tester);
      await _tap(tester, find.byKey(const ValueKey('proposal-submit')));
      expect(find.text('Yeniden dene.'), findsOneWidget);
      expect(find.text('Şehir Sahnesi'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('proposal-submit')));
      expect(repo.requests[0].requestId, repo.requests[1].requestId);
      await tester.ensureVisible(
        find.byKey(const ValueKey('proposal-venue-name')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('proposal-venue-name')),
        'Başka mekan',
      );
      await _tap(tester, find.byKey(const ValueKey('proposal-submit')));
      expect(repo.requests[2].requestId, isNot(repo.requests[1].requestId));
    },
  );

  testWidgets('unexpected repository exception preserves form for retry', (
    tester,
  ) async {
    final repo = _Repo()..handler = () => throw StateError('offline');
    await _open(tester, repo: repo);
    await _fill(tester);
    await _tap(tester, find.byKey(const ValueKey('proposal-submit')));
    expect(find.textContaining('Gönderim doğrulanamadı'), findsOneWidget);
    expect(find.text('Şehir Sahnesi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location errors retry without losing name', (tester) async {
    final locations = _Locations()..failCities = true;
    await _open(tester, locations: locations);
    await tester.enterText(
      find.byKey(const ValueKey('proposal-venue-name')),
      'Şehir Sahnesi',
    );
    expect(
      find.text('İller yüklenemedi. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    locations.failCities = false;
    await _tap(tester, find.text('Tekrar dene'));
    expect(find.text('Ankara'), findsOneWidget);
    expect(find.text('Çankaya'), findsOneWidget);
    expect(find.text('Şehir Sahnesi'), findsOneWidget);
  });

  testWidgets(
    'old city district response cannot replace current city choices',
    (tester) async {
      final pending = Completer<Result<List<District>>>();
      final locations = _Locations()
        ..districtHandler = (id) => id == 'a'
            ? pending.future
            : Future.value(const Result.success([_kadikoy]));
      await _open(tester, locations: locations, settle: false);
      await _tap(
        tester,
        find.byKey(const ValueKey('proposal-city')),
        settle: false,
      );
      await _tap(tester, find.text('İstanbul'));
      pending.complete(const Result.success([_cankaya]));
      await tester.pumpAndSettle();
      expect(find.text('İstanbul'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('proposal-district')));
      expect(find.text('Kadıköy'), findsOneWidget);
      expect(find.text('Çankaya'), findsNothing);
    },
  );

  testWidgets('cancel returns null without sending', (tester) async {
    final repo = _Repo();
    var completed = false;
    await _open(
      tester,
      repo: repo,
      onResult: (result) {
        expect(result, isNull);
        completed = true;
      },
    );
    await _tap(tester, find.text('Vazgeç'));
    expect(completed, isTrue);
    expect(repo.requests, isEmpty);
  });

  testWidgets(
    '320 width and 200 percent text remain scrollable with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester, textScale: 2);
      await tester.ensureVisible(
        find.byKey(const ValueKey('proposal-venue-name')),
      );
      await tester.tap(find.byKey(const ValueKey('proposal-venue-name')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('proposal-submit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('proposal-submit')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  _Locations? locations,
  _Repo? repo,
  City? city = _ankara,
  District? district = _cankaya,
  double textScale = 1,
  ValueChanged<bool?>? onResult,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
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
              final result = await showVenueSuggestionSheet(
                context,
                locationRepository: locations ?? _Locations(),
                repository: repo ?? _Repo(),
                initialCity: city,
                initialDistrict: district,
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _fill(WidgetTester tester, {String answer = 'Evet'}) async {
  await tester.ensureVisible(find.byKey(const ValueKey('proposal-venue-name')));
  await tester.enterText(
    find.byKey(const ValueKey('proposal-venue-name')),
    'Şehir Sahnesi',
  );
  await _tap(tester, find.text(answer));
}

class _Locations extends Fake implements LocationRepository {
  bool failCities = false;
  Future<Result<List<District>>> Function(String)? districtHandler;
  @override
  Future<Result<List<City>>> getCities() async => failCities
      ? const Result.failure(AppError(code: 'network', message: 'offline'))
      : const Result.success([_ankara, _istanbul]);
  @override
  Future<Result<List<District>>> getDistricts(String id) =>
      districtHandler?.call(id) ??
      Future.value(Result.success(id == 'a' ? [_cankaya] : [_kadikoy]));
}

typedef _Request = ({
  String requestId,
  String venueName,
  String cityId,
  String districtId,
  VenueSuggestionLiveMusic liveMusic,
});

class _Repo extends Fake implements VenueSuggestionRepository {
  final requests = <_Request>[];
  Future<Result<void>> Function()? handler;
  @override
  Future<Result<void>> submit({
    required String requestId,
    required String venueName,
    required String cityId,
    required String districtId,
    required VenueSuggestionLiveMusic liveMusic,
  }) {
    requests.add((
      requestId: requestId,
      venueName: venueName,
      cityId: cityId,
      districtId: districtId,
      liveMusic: liveMusic,
    ));
    return handler?.call() ?? Future.value(const Result.success(null));
  }
}
