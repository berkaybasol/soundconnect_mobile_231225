part of 'band_setlist_builder_screen.dart';

class _SongSlotTile extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _SongSlotTile({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: selected
              ? const LinearGradient(colors: AppColors.brandGradient)
              : null,
          color: selected ? null : AppColors.inputFill,
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SetMarkerTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _SetMarkerTile({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: selected
              ? const LinearGradient(colors: AppColors.brandGradient)
              : null,
          color: selected ? null : AppColors.inputFill,
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Text(
          '|',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _AddMiniTile extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final double opacity;
  final VoidCallback? onTap;

  const _AddMiniTile({
    this.icon,
    this.label,
    this.opacity = 0.55,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? opacity : 0.3,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppColors.inputFill,
            border: Border.all(color: AppColors.border),
          ),
          child: icon != null
              ? Icon(icon, size: 16)
              : Text(
                  label ?? '+',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SelectedSetEditor extends StatelessWidget {
  final _SetItem setItem;
  final bool canRemove;
  final VoidCallback onRemove;

  const _SelectedSetEditor({
    required this.setItem,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: AppColors.navBlueSoft,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Set',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          TextField(
            controller: setItem.titleController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Set Başlığı',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSongEditor extends StatelessWidget {
  final int rowNo;
  final _SongItem row;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onPickTone;

  const _SelectedSongEditor({
    required this.rowNo,
    required this.row,
    required this.canRemove,
    required this.onRemove,
    required this.onPickTone,
  });

  @override
  Widget build(BuildContext context) {
    Widget shell(Widget child) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(colors: AppColors.brandGradient),
        ),
        child: Container(
          margin: const EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(10.8),
          ),
          child: child,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: AppColors.navBlueSoft,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: AppColors.inputFill,
                ),
                child: Text(
                  '$rowNo',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.coralLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const _InlineActionHint(symbol: '+', label: 'Şarkı'),
              const SizedBox(width: 6),
              const _InlineActionHint(symbol: '|', label: 'Set'),
              const Spacer(),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          shell(
            TextField(
              controller: row.artistController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Sanatçı Adı',
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          shell(
            TextField(
              controller: row.songController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Şarkı Adı',
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          shell(
            InkWell(
              borderRadius: BorderRadius.circular(10.8),
              onTap: onPickTone,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.tone.display,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineActionHint extends StatelessWidget {
  final String symbol;
  final String label;

  const _InlineActionHint({required this.symbol, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            symbol,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TonePickerField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _TonePickerField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      menuMaxHeight: 300,
      dropdownColor: AppColors.navBlueSoft,
      borderRadius: BorderRadius.circular(12),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.inputFill,
      ),
    );
  }
}

class _CodeEditorPreview extends StatelessWidget {
  final String title;
  final List<_TimelineItem> items;
  final _PreviewTheme theme;
  final ValueChanged<_PreviewTheme>? onThemeSelected;
  final VoidCallback? onFullscreen;
  final bool fullscreenMode;

  const _CodeEditorPreview({
    required this.title,
    required this.items,
    required this.theme,
    this.onThemeSelected,
    this.onFullscreen,
    this.fullscreenMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _PreviewPalette.fromTheme(theme);
    final logoAlignment = fullscreenMode
        ? Alignment.center
        : Alignment.centerLeft;
    final lines = <String>['SETLIST "$title"'];
    final blockRows = <Widget>[];
    var songNo = 0;
    for (final item in items) {
      if (item is _SetItem) {
        final setTitle = item.titleController.text.trim().isEmpty
            ? 'SET'
            : item.titleController.text.trim();
        lines.add('--- $setTitle ---');
        if (theme != _PreviewTheme.cod) {
          blockRows.add(
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: AppColors.brandGradient),
              ),
              child: Container(
                margin: const EdgeInsets.all(1.2),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.8),
                  color: palette.card,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.segment, size: 16, color: AppColors.coral),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        setTitle,
                        style: TextStyle(
                          color: palette.content,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'SET',
                      style: TextStyle(
                        color: palette.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        continue;
      }
      final song = item as _SongItem;
      songNo += 1;
      final artist = song.artistController.text.trim().isEmpty
          ? '<sanatçı>'
          : song.artistController.text.trim();
      final songName = song.songController.text.trim().isEmpty
          ? '<şarkı>'
          : song.songController.text.trim();
      lines.add(
        '${songNo.toString().padLeft(2, '0')} | $artist -> $songName -> ${song.tone.display}',
      );
      if (theme != _PreviewTheme.cod) {
        blockRows.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: AppColors.brandGradient,
                      ),
                    ),
                    child: Text(
                      '$songNo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          songName,
                          style: TextStyle(
                            color: palette.content,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          artist,
                          style: TextStyle(
                            color: palette.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: palette.chip,
                    ),
                    child: Text(
                      song.tone.display,
                      style: TextStyle(
                        color: palette.content,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: palette.border),
      ),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 98,
                  child: ClipRect(
                    child: Align(
                      alignment: logoAlignment,
                      child: Transform.scale(
                        scale: 1.95,
                        alignment: logoAlignment,
                        child: Image.asset(
                          'assets/logotransparent.png',
                          height: 98,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!fullscreenMode && onThemeSelected != null)
                PopupMenuButton<_PreviewTheme>(
                  onSelected: onThemeSelected,
                  color: palette.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: palette.border),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _PreviewTheme.cod,
                      child: Text(
                        'cod',
                        style: TextStyle(color: palette.content),
                      ),
                    ),
                    PopupMenuItem(
                      value: _PreviewTheme.soft,
                      child: Text(
                        'soft',
                        style: TextStyle(color: palette.content),
                      ),
                    ),
                    PopupMenuItem(
                      value: _PreviewTheme.dark,
                      child: Text(
                        'dark',
                        style: TextStyle(color: palette.content),
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: palette.card,
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      'Tema: ${theme.label}',
                      style: TextStyle(
                        color: palette.content,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (!fullscreenMode && onThemeSelected != null)
                const SizedBox(width: 8),
              if (!fullscreenMode && onFullscreen != null)
                IconButton(
                  onPressed: onFullscreen,
                  tooltip: 'Tam ekran',
                  icon: Icon(
                    Icons.open_in_full,
                    size: 18,
                    color: palette.header,
                  ),
                ),
            ],
          ),
          if (!fullscreenMode)
            const SizedBox(height: 8)
          else
            const SizedBox(height: 6),
          if (theme == _PreviewTheme.cod)
            ...lines.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: palette.content,
                    ),
                    children: [
                      TextSpan(
                        text: '${(entry.key + 1).toString().padLeft(2, '0')}  ',
                        style: TextStyle(color: palette.lineNumber),
                      ),
                      TextSpan(text: entry.value),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: palette.content,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...blockRows,
          ],
        ],
      ),
    );
  }
}
