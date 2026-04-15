part of 'band_setlist_builder_screen.dart';

enum _PreviewTheme { cod, soft, dark }

extension on _PreviewTheme {
  String get label => name;
}

class _PreviewPalette {
  final Color background;
  final Color border;
  final Color header;
  final Color content;
  final Color lineNumber;
  final Color card;
  final Color muted;
  final Color chip;

  const _PreviewPalette({
    required this.background,
    required this.border,
    required this.header,
    required this.content,
    required this.lineNumber,
    required this.card,
    required this.muted,
    required this.chip,
  });

  factory _PreviewPalette.fromTheme(_PreviewTheme theme) {
    switch (theme) {
      case _PreviewTheme.cod:
        return const _PreviewPalette(
          background: Color(0xFF0F1117),
          border: AppColors.border,
          header: Color(0xFFA6ACC5),
          content: Color(0xFFD7DBE8),
          lineNumber: Color(0xFF6B7285),
          card: Color(0xFF1A1F2B),
          muted: Color(0xFF93A0BD),
          chip: Color(0xFF262E3E),
        );
      case _PreviewTheme.soft:
        return const _PreviewPalette(
          background: Color(0xFFF7F9FC),
          border: Color(0xFFDCE3EF),
          header: Color(0xFF51607C),
          content: Color(0xFF273246),
          lineNumber: Color(0xFF90A0BA),
          card: Color(0xFFFFFFFF),
          muted: Color(0xFF66748F),
          chip: Color(0xFFE9EEF8),
        );
      case _PreviewTheme.dark:
        return const _PreviewPalette(
          background: Color(0xFF090B10),
          border: Color(0xFF1D2230),
          header: Color(0xFF8EA4D8),
          content: Color(0xFFE4ECFF),
          lineNumber: Color(0xFF5E6F92),
          card: Color(0xFF121722),
          muted: Color(0xFF8A98B6),
          chip: Color(0xFF20293A),
        );
    }
  }
}

abstract class _TimelineItem {
  void attach(VoidCallback listener);
  void dispose();
}

class _SetItem extends _TimelineItem {
  final TextEditingController titleController;

  _SetItem(int no) : titleController = TextEditingController(text: 'SET $no');

  @override
  void attach(VoidCallback listener) {
    titleController.addListener(listener);
  }

  @override
  void dispose() {
    titleController.dispose();
  }
}

class _SongItem extends _TimelineItem {
  final TextEditingController artistController = TextEditingController();
  final TextEditingController songController = TextEditingController();
  _ToneValue tone = _ToneValue.original();
  VoidCallback? _listener;

  @override
  void attach(VoidCallback listener) {
    _listener = listener;
    artistController.addListener(listener);
    songController.addListener(listener);
  }

  @override
  void dispose() {
    if (_listener != null) {
      artistController.removeListener(_listener!);
      songController.removeListener(_listener!);
    }
    artistController.dispose();
    songController.dispose();
  }
}

enum _ToneNote { a, b, c, d, e, f, g }

extension on _ToneNote {
  String get label => name.toUpperCase();
}

enum _ToneQuality { major, minor }

extension on _ToneQuality {
  String get label => this == _ToneQuality.major ? 'Major' : 'Minor';
}

enum _ToneAccidental { natural, sharp, flat }

extension on _ToneAccidental {
  String get label {
    switch (this) {
      case _ToneAccidental.natural:
        return 'Doğal';
      case _ToneAccidental.sharp:
        return 'Diyez (#)';
      case _ToneAccidental.flat:
        return 'Bemol (♭)';
    }
  }
}

class _ToneValue {
  final _ToneNote note;
  final _ToneQuality quality;
  final _ToneAccidental accidental;
  final bool original;

  const _ToneValue({
    required this.note,
    required this.quality,
    required this.accidental,
    this.original = false,
  });

  factory _ToneValue.original() {
    return const _ToneValue(
      note: _ToneNote.c,
      quality: _ToneQuality.major,
      accidental: _ToneAccidental.natural,
      original: true,
    );
  }

  _ToneValue copyWith({
    _ToneNote? note,
    _ToneQuality? quality,
    _ToneAccidental? accidental,
    bool? original,
  }) {
    return _ToneValue(
      note: note ?? this.note,
      quality: quality ?? this.quality,
      accidental: accidental ?? this.accidental,
      original: original ?? this.original,
    );
  }

  String get display {
    if (original) return 'Original';
    final accidentalLabel = switch (accidental) {
      _ToneAccidental.natural => '',
      _ToneAccidental.sharp => '#',
      _ToneAccidental.flat => '♭',
    };
    final qualityLabel = quality == _ToneQuality.major ? 'Maj' : 'Min';
    return '${note.label}$accidentalLabel $qualityLabel';
  }
}
