part of 'profile_common_widgets.dart';

class EditableBioSection extends StatefulWidget {
  final String? bio;
  final bool editable;
  final Future<void> Function(String)? onSave;
  final String emptyText;
  final String addLabel;
  final String hintText;

  EditableBioSection({
    super.key,
    required this.bio,
    required this.editable,
    required this.onSave,
    this.emptyText = 'Henüz bir açıklama eklenmedi.',
    this.addLabel = 'Profiline birkaç cümle ekle',
    this.hintText = 'Kendinden biraz bahset...',
  });

  @override
  State<EditableBioSection> createState() => _EditableBioSectionState();
}

class _EditableBioSectionState extends State<EditableBioSection> {
  bool _isEditing = false;
  bool _saving = false;
  String _draft = '';

  @override
  void didUpdateWidget(covariant EditableBioSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.bio != widget.bio) {
      _draft = widget.bio?.trim() ?? '';
    }
  }

  Future<void> _handleSave() async {
    if (widget.onSave == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave!(_draft);
      if (!mounted) return;
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBio = widget.bio?.trim().isNotEmpty == true;
    final resolvedBio = hasBio ? widget.bio!.trim() : '';

    if (!widget.editable) {
      return Text(
        hasBio ? resolvedBio : widget.emptyText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.6,
        ),
      );
    }

    if (!_isEditing) {
      if (!hasBio) {
        return TextButton(
          onPressed: () {
            setState(() {
              _draft = '';
              _isEditing = true;
            });
          },
          child: Text(widget.addLabel),
        );
      }

      return Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 4, right: 20),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                resolvedBio,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _draft = widget.bio?.trim() ?? '';
                  _isEditing = true;
                });
              },
              child: Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.edit,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        TextFormField(
          initialValue: _draft,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.coralAlt),
            ),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          onChanged: (value) => _draft = value,
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _isEditing = false),
              child: Text('İptal'),
            ),
            SizedBox(width: 10),
            GradientOutlineButton(
              onPressed: _saving ? null : _handleSave,
              loading: _saving,
              label: _saving ? 'Kaydediliyor...' : 'Kaydet',
            ),
          ],
        ),
      ],
    );
  }
}
