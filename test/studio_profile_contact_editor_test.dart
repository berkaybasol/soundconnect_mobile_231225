import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';

void main() {
  testWidgets('contact editor canonicalizes safe phone and website values', (
    tester,
  ) async {
    StudioProfileContactDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioProfileContactEditorSheet(
            profile: _profile,
            onSave: (draft) async {
              submitted = draft;
              return 'Testte açık kal';
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('studio-contact-phone')),
      '+90 (555) 111-22-33',
    );
    await tester.enterText(
      find.byKey(const Key('studio-contact-website')),
      'studio.example.com',
    );
    await tester.tap(find.byKey(const Key('studio-contact-save')));
    await tester.pumpAndSettle();

    expect(submitted?.phone, '05551112233');
    expect(submitted?.website, 'https://studio.example.com');
    expect(find.byKey(const Key('studio-contact-error')), findsOneWidget);
  });

  testWidgets('conflict error keeps the editor and user draft open', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioProfileContactEditorSheet(
            profile: _profile,
            onSave: (_) async {
              calls++;
              return 'Profil başka bir oturumda değişti. Güncel verileri aldık.';
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('studio-contact-name')),
      'Taslak Stüdyo',
    );
    await tester.tap(find.byKey(const Key('studio-contact-save')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byType(StudioProfileContactEditorSheet), findsOneWidget);
    expect(find.text('Taslak Stüdyo'), findsOneWidget);
    expect(find.textContaining('başka bir oturumda'), findsOneWidget);
  });

  testWidgets('invalid dial strings never reach the repository callback', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioProfileContactEditorSheet(
            profile: _profile,
            onSave: (_) async {
              calls++;
              return null;
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('studio-contact-phone')),
      '555;postd=1234',
    );
    await tester.tap(find.byKey(const Key('studio-contact-save')));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Geçerli bir telefon numarası gir.'), findsOneWidget);
  });
}

const _profile = StudioProfile(
  id: 'studio-1',
  userId: 'user-1',
  name: 'Studio',
  description: null,
  profilePictureMediaId: null,
  profilePictureUrl: null,
  address: 'Kadıköy',
  phone: '05551112233',
  website: 'https://studio.example.com',
  facilities: [],
  instagramUrl: null,
  youtubeUrl: null,
  timeZone: 'Europe/Istanbul',
  version: 1,
  spotifyTrackIds: [],
  spotifyTracks: [],
  activeRoomCount: 1,
  backlineUnitCount: 0,
);
