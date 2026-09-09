import 'package:flutter/material.dart';

class ListenerEventPostNoteEditor extends StatefulWidget {
  const ListenerEventPostNoteEditor({
    super.key,
    required this.note,
    required this.onSave,
  });

  final String? note;
  final Future<String?> Function(String note) onSave;

  @override
  State<ListenerEventPostNoteEditor> createState() =>
      _ListenerEventPostNoteEditorState();
}

class _ListenerEventPostNoteEditorState
    extends State<ListenerEventPostNoteEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.note ?? '',
  );
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    final note = _text.text.trim();
    if (note.runes.length > 500) {
      setState(() => _error = 'Açıklama en fazla 500 karakter olabilir.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onSave(note);
    } catch (_) {
      error = 'Açıklama kaydedilemedi. Tekrar deneyebilirsin.';
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
    if (error == null) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Açıklamayı düzenle'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: TextField(
            key: const Key('listener-post-note-input'),
            controller: _text,
            enabled: !_saving,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) {
                  // The API validates Unicode code points; Flutter's default
                  // counter treats a multi-code-point emoji as one character.
                  final length = _text.text.trim().runes.length;
                  return Text(
                    '$length / $maxLength',
                    style: length > maxLength!
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null,
                  );
                },
            decoration: InputDecoration(
              hintText: 'Etkinlik hakkında birkaç söz…',
              errorText: _error,
              errorMaxLines: 4,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          key: const Key('listener-post-note-save'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    ),
  );
}
