import 'dart:async';

enum UsageSection {
  tables,
  overthinking,
  marketplace,
  collab,
  discover,
  profiles,
  other,
}

enum TableView { list, preview, chat, create }

enum ViewedProfile { musician, band, venue, listener, studio }

typedef SectionView = ({
  UsageSection section,
  TableView? table,
  ViewedProfile? profile,
  bool? own,
  bool discoveryEvent,
});

SectionView sectionView(
  UsageSection section, {
  TableView? table,
  ViewedProfile? profile,
  bool? own,
  bool discoveryEvent = false,
}) => (
  section: section,
  table: table,
  profile: profile,
  own: own,
  discoveryEvent: discoveryEvent,
);

/// Only a confirmed, foreground measurement session owns an elapsed clock.
/// UTC labels the beginning of each sample; monotonic time measures its length.
class SectionClock {
  SectionClock(
    this.emit, {
    Duration Function()? elapsed,
    DateTime Function()? utcNow,
  }) : _elapsed = elapsed,
       _utcNow = utcNow ?? DateTime.now;

  final void Function(SectionView view, DateTime start, int milliseconds) emit;
  final Duration Function()? _elapsed;
  final Stopwatch _watch = Stopwatch();
  Duration get _now => _elapsed?.call() ?? _watch.elapsed;
  final DateTime Function() _utcNow;
  SectionView _view = sectionView(UsageSection.other);
  Duration? _start;
  late DateTime _startUtc;
  Timer? _timer;

  void begin() {
    if (_start != null) return;
    _watch.start();
    _start = _now;
    _startUtc = _utcNow().toUtc();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  void show(SectionView view) {
    if (_view == view) return;
    flush();
    _view = view;
  }

  void flush() {
    final start = _start;
    if (start == null) return;
    final now = _now;
    final milliseconds = (now - start).inMilliseconds;
    if (milliseconds <= 0) return;
    final from = _startUtc;
    _start = start + Duration(milliseconds: milliseconds);
    _startUtc = from.add(Duration(milliseconds: milliseconds));
    // A frozen process can miss lifecycle callbacks. Never count a long gap as
    // observed engagement; restart at the current confirmed foreground time.
    if (milliseconds > 120000) {
      _start = now;
      _startUtc = _utcNow().toUtc();
      return;
    }
    emit(_view, from, milliseconds);
  }

  void end({required bool sendLast}) {
    if (sendLast) flush();
    _timer?.cancel();
    _timer = null;
    _start = null;
    _watch.stop();
    _watch.reset();
  }
}
