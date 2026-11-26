import 'package:flutter/foundation.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_consent_controller.dart';

class TestAnalyticsConsent extends ChangeNotifier
    implements AnalyticsConsentController {
  @override
  ConsentChoice choice = ConsentChoice.undecided;
  @override
  bool isMember = false;
  @override
  int subjectRevision = 0;
  @override
  bool get busy => false;
  @override
  bool get canChooseForSubject => true;
  @override
  String? get error => null;
  final decisions = <bool>[];

  @override
  Future<void> choose(bool allow, {int? expectedSubject}) async {
    if (expectedSubject != subjectRevision) throw StateError('Changed actor');
    decisions.add(allow);
    choice = allow ? ConsentChoice.granted : ConsentChoice.denied;
    notifyListeners();
  }

  void changeMember() {
    isMember = true;
    subjectRevision++;
    choice = ConsentChoice.undecided;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
