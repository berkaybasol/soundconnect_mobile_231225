import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_invite_decision_screen.dart';

void main() {
  test('existing invitation uses group wording without rewriting names', () {
    const args = BandInviteDecisionScreenArgs(
      bandId: 'band',
      title: ' Sahbaz seni banda davet etti ',
      message: ' bugrasahin tarafından band daveti aldın. ',
    );
    expect(args.displayTitle, 'Sahbaz seni gruba davet etti');
    expect(args.displayMessage, 'bugrasahin tarafından davet aldın.');
  });

  test('new invitation wording remains unchanged', () {
    const args = BandInviteDecisionScreenArgs(
      bandId: 'band',
      title: 'Sahbaz seni gruba davet etti',
      message: 'bugrasahin tarafından davet aldın.',
    );
    expect(args.displayTitle, args.title);
    expect(args.displayMessage, args.message);
  });

  test('custom copy and names are not globally replaced', () {
    const args = BandInviteDecisionScreenArgs(
      bandId: 'band',
      title: 'banda seni banda davet etti',
      message: 'band daveti aldın adlı kullanıcıdan özel mesaj',
    );
    expect(args.displayTitle, 'banda seni gruba davet etti');
    expect(args.displayMessage, args.message);
  });

  test('missing copy remains empty for the screen fallback', () {
    const args = BandInviteDecisionScreenArgs(bandId: 'band');
    expect(args.displayTitle, isEmpty);
    expect(args.displayMessage, isEmpty);
  });
}
