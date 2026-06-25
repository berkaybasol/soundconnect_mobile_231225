part of 'band_setlist_builder_screen.dart';

class _SongSlotTile extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;

  _SongSlotTile({
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
              ? LinearGradient(colors: AppColors.brandGradient)
              : null,
          color: selected
              ? null
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: selected
                ? AppColors.white
                : Theme.of(context).colorScheme.onSurface,
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

  _SetMarkerTile({required this.selected, required this.onTap});

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
              ? LinearGradient(colors: AppColors.brandGradient)
              : null,
          color: selected
              ? null
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          '|',
          style: TextStyle(
            color: selected
                ? AppColors.white
                : Theme.of(context).colorScheme.onSurface,
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

  _AddMiniTile({
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
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: icon != null
              ? Icon(icon, size: 16)
              : Text(
                  label ?? '+',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
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

  _SelectedSetEditor({
    required this.setItem,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Set',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                icon: Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          TextField(
            controller: setItem.titleController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
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

  _SelectedSongEditor({
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
          gradient: LinearGradient(colors: AppColors.brandGradient),
        ),
        child: Container(
          margin: EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10.8),
          ),
          child: child,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border.all(color: Theme.of(context).dividerColor),
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Text(
                  '$rowNo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.coralLight,
                  ),
                ),
              ),
              SizedBox(width: 8),
              _InlineActionHint(symbol: '+', label: 'Şarkı'),
              SizedBox(width: 6),
              _InlineActionHint(symbol: '|', label: 'Set'),
              Spacer(),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                icon: Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          SizedBox(height: 6),
          shell(
            TextField(
              controller: row.artistController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Sanatçı Adı',
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(height: 8),
          shell(
            TextField(
              controller: row.songController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Şarkı Adı',
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(height: 8),
          shell(
            InkWell(
              borderRadius: BorderRadius.circular(10.8),
              onTap: onPickTone,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.tone.display,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down),
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

  _InlineActionHint({required this.symbol, required this.label});

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
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(
            symbol,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  _TonePickerField({
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
      dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
  final bool exportCompact;
  final int songNumberOffset;

  _CodeEditorPreview({
    required this.title,
    required this.items,
    required this.theme,
    this.onThemeSelected,
    this.onFullscreen,
    this.fullscreenMode = false,
    this.exportCompact = false,
    this.songNumberOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _PreviewPalette.fromTheme(theme);
    final logoAlignment = fullscreenMode
        ? Alignment.center
        : Alignment.centerLeft;
    final lines = <String>['SETLIST "$title"'];
    final blockRows = <Widget>[];
    var songNo = songNumberOffset;
    final logoHeight = exportCompact
        ? (theme == _PreviewTheme.cod ? 58.0 : 98.0)
        : 98.0;
    final logoScale = exportCompact
        ? (theme == _PreviewTheme.cod ? 1.0 : 1.65)
        : 1.95;
    final rowBottomMargin = exportCompact ? 6.0 : 10.0;
    final songRowPadding = exportCompact
        ? EdgeInsets.fromLTRB(9, 7, 9, 7)
        : EdgeInsets.fromLTRB(10, 10, 10, 10);
    final setRowPadding = exportCompact
        ? EdgeInsets.fromLTRB(10, 7, 10, 7)
        : EdgeInsets.fromLTRB(12, 10, 12, 10);
    final titlePadding = exportCompact
        ? EdgeInsets.fromLTRB(10, 7, 10, 7)
        : EdgeInsets.fromLTRB(10, 9, 10, 9);
    for (final item in items) {
      if (item is _SetItem) {
        final setTitle = item.titleController.text.trim().isEmpty
            ? 'SET'
            : item.titleController.text.trim();
        lines.add('--- $setTitle ---');
        if (theme != _PreviewTheme.cod) {
          blockRows.add(
            Container(
              margin: EdgeInsets.only(bottom: rowBottomMargin),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: AppColors.brandGradient),
              ),
              child: Container(
                margin: EdgeInsets.all(1.2),
                padding: setRowPadding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.8),
                  color: palette.card,
                ),
                child: Row(
                  children: [
                    Icon(Icons.segment, size: 16, color: AppColors.coral),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        setTitle,
                        style: TextStyle(
                          color: palette.content,
                          fontWeight: FontWeight.w800,
                          fontSize: exportCompact ? 12 : null,
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
            margin: EdgeInsets.only(bottom: rowBottomMargin),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Padding(
              padding: songRowPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(colors: AppColors.brandGradient),
                    ),
                    child: Text(
                      '$songNo',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          songName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.content,
                            fontWeight: FontWeight.w800,
                            fontSize: exportCompact ? 13 : null,
                          ),
                        ),
                        SizedBox(height: exportCompact ? 1 : 2),
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: exportCompact ? 10.5 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: palette.chip,
                    ),
                    child: Text(
                      song.tone.display,
                      style: TextStyle(
                        color: palette.content,
                        fontSize: exportCompact ? 10 : 11,
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
      padding: EdgeInsets.all(12),
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
                child: _buildPreviewHeader(
                  logoAlignment,
                  logoHeight,
                  logoScale,
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
                  ],
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                SizedBox(width: 8),
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
          if (!fullscreenMode) SizedBox(height: 8) else SizedBox(height: 6),
          if (theme == _PreviewTheme.cod)
            ...lines.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
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
              margin: EdgeInsets.only(bottom: rowBottomMargin),
              padding: titlePadding,
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
                  fontSize: exportCompact ? 13 : null,
                ),
              ),
            ),
            ...blockRows,
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewHeader(
    Alignment logoAlignment,
    double logoHeight,
    double logoScale,
  ) {
    if (exportCompact && theme == _PreviewTheme.cod) {
      return SizedBox(
        height: logoHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            r'''
  ____                       _  ____                            _
 / ___|  ___  _   _ _ __ __| |/ ___|___  _ __  _ __   ___  ___| |_
 \___ \ / _ \| | | | '__/ _` | |   / _ \| '_ \| '_ \ / _ \/ __| __|
  ___) | (_) | |_| | | | (_| | |__| (_) | | | | | | |  __/ (__| |_
 |____/ \___/ \__,_|_|  \__,_|\____\___/|_| |_|_| |_|\___|\___|\__|
''',
            maxLines: 6,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: AppColors.coralLight,
              fontFamily: 'monospace',
              fontSize: 5.4,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
      );
    }

    if (exportCompact) {
      return SizedBox(
        height: logoHeight,
        child: ClipRect(
          child: Align(
            alignment: logoAlignment,
            child: Transform.scale(
              scale: logoScale,
              alignment: logoAlignment,
              child: Image.asset(
                'assets/logotransparent.png',
                height: logoHeight,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: logoHeight,
      child: ClipRect(
        child: Align(
          alignment: logoAlignment,
          child: Transform.scale(
            scale: logoScale,
            alignment: logoAlignment,
            child: Image.asset(
              'assets/logotransparent.png',
              height: logoHeight,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
