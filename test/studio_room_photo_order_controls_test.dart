import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_room_photo_order_controls.dart';

void main() {
  testWidgets('photo order controls expose only valid moves', (tester) async {
    final moves = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioRoomPhotoOrderControls(
            index: 0,
            itemCount: 3,
            onMoveTo: moves.add,
          ),
        ),
      ),
    );

    final previous = tester.widget<IconButton>(
      find.byKey(const Key('studio-room-photo-move-previous')),
    );
    final next = tester.widget<IconButton>(
      find.byKey(const Key('studio-room-photo-move-next')),
    );
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('studio-room-photo-move-next')));
    expect(moves, [1]);
  });

  testWidgets('photo order controls stay hidden for a single photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudioRoomPhotoOrderControls(
          index: 0,
          itemCount: 1,
          onMoveTo: (_) {},
        ),
      ),
    );

    expect(
      find.byKey(const Key('studio-room-photo-move-previous')),
      findsNothing,
    );
    expect(find.byKey(const Key('studio-room-photo-move-next')), findsNothing);
  });
}
