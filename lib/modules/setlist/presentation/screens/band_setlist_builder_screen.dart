import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:io';

import '../../../../shared/theme/app_colors.dart';
import '../../../profile/domain/entities/band_profile.dart';

class BandSetlistBuilderScreen extends StatefulWidget {
  final BandProfile bandProfile;

  const BandSetlistBuilderScreen({super.key, required this.bandProfile});

  @override
  State<BandSetlistBuilderScreen> createState() =>
      _BandSetlistBuilderScreenState();
}

class _BandSetlistBuilderScreenState extends State<BandSetlistBuilderScreen> {
  final TextEditingController _setlistNameController = TextEditingController();
  final List<_TimelineItem> _items = <_TimelineItem>[_SongItem()];
  int _selectedIndex = 0;
  _PreviewTheme _previewTheme = _PreviewTheme.soft;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _setlistNameController.text = '${widget.bandProfile.name} Setlist';
    _setlistNameController.addListener(_refresh);
    _items.first.attach(_refresh);
  }

  @override
  void dispose() {
    _setlistNameController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _addSong() {
    final song = _SongItem()..attach(_refresh);
    setState(() {
      _items.add(song);
      _selectedIndex = _items.length - 1;
    });
  }

  void _addSet() {
    final nextSetNo = _items.whereType<_SetItem>().length + 1;
    final setItem = _SetItem(nextSetNo)..attach(_refresh);
    setState(() {
      _items.add(setItem);
      _selectedIndex = _items.length - 1;
    });
  }

  void _removeSelected() {
    if (_items.length == 1) return;
    final removed = _items.removeAt(_selectedIndex);
    removed.dispose();
    setState(() {
      if (_selectedIndex >= _items.length) {
        _selectedIndex = _items.length - 1;
      }
    });
  }

  Future<void> _pickTone(_SongItem song) async {
    var value = song.tone;
    final result = await showModalBottomSheet<_ToneValue>(
      context: context,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Ton Seçimi',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _TonePickerField<_ToneNote>(
                    label: '1) Nota',
                    value: value.note,
                    items: _ToneNote.values,
                    itemLabel: (v) => v.label,
                    onChanged: (v) {
                      if (v == null) return;
                      setSheetState(() {
                        value = value.copyWith(note: v, original: false);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _TonePickerField<_ToneAccidental>(
                    label: '2) Diyez / Bemol',
                    value: value.accidental,
                    items: _ToneAccidental.values,
                    itemLabel: (v) => v.label,
                    onChanged: (v) {
                      if (v == null) return;
                      setSheetState(() {
                        value = value.copyWith(accidental: v, original: false);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _TonePickerField<_ToneQuality>(
                    label: '3) Major / Minor',
                    value: value.quality,
                    items: _ToneQuality.values,
                    itemLabel: (v) => v.label,
                    onChanged: (v) {
                      if (v == null) return;
                      setSheetState(() {
                        value = value.copyWith(quality: v, original: false);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(_ToneValue.original()),
                      child: const Text('Orijinal Ton'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(value),
                    child: const Text('Uygula'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == null) return;
    song.tone = result;
    _refresh();
  }

  int _songNoAt(int index) {
    var no = 0;
    for (var i = 0; i <= index; i++) {
      if (_items[i] is _SongItem) no++;
    }
    return no;
  }

  Future<void> _savePreviewImage() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      final title = _setlistNameController.text.trim().isEmpty
          ? 'Setlist Adı'
          : _setlistNameController.text.trim();
      final controller = ScreenshotController();
      final screenSize = MediaQuery.of(context).size;
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;

      final bytes = await controller.captureFromWidget(
        Material(
          color: AppColors.navBlueDeep,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: SizedBox(
                width: screenSize.width - 24,
                height: screenSize.height - 26,
                child: _CodeEditorPreview(
                  title: title,
                  items: _items,
                  theme: _previewTheme,
                  fullscreenMode: true,
                ),
              ),
            ),
          ),
        ),
        context: context,
        pixelRatio: pixelRatio,
      );

      final tempDir = await getTemporaryDirectory();
      final safeName = title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      final filename =
          '${safeName.isEmpty ? 'setlist' : safeName}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'image/png')],
          subject: '$title Görsel',
          text: '$title setlist görseli',
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gorsel olusturma sirasinda hata olustu.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  void _openFullPreview(String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Canlı Önizleme')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: _CodeEditorPreview(
                title: title,
                items: _items,
                theme: _previewTheme,
                fullscreenMode: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _setlistNameController.text.trim().isEmpty
        ? 'Setlist Adı'
        : _setlistNameController.text.trim();
    final selected = _items[_selectedIndex];
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setlist Oluştur'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isExportingPdf ? null : _savePreviewImage,
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: Text(
                _isExportingPdf ? 'Hazırlanıyor' : 'Fotoğrafı Kaydet',
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            children: [
              TextField(
                controller: _setlistNameController,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  labelText: 'Setlist Adı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final tile = item is _SongItem
                                ? _SongSlotTile(
                                    index: _songNoAt(idx) - 1,
                                    selected: idx == _selectedIndex,
                                    onTap: () =>
                                        setState(() => _selectedIndex = idx),
                                  )
                                : _SetMarkerTile(
                                    selected: idx == _selectedIndex,
                                    onTap: () =>
                                        setState(() => _selectedIndex = idx),
                                  );
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: tile,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    _AddMiniTile(icon: Icons.add, onTap: _addSong),
                    const SizedBox(width: 8),
                    _AddMiniTile(label: '|', opacity: 0.45, onTap: _addSet),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (selected is _SongItem)
                _SelectedSongEditor(
                  rowNo: _songNoAt(_selectedIndex),
                  row: selected,
                  canRemove: _items.length > 1,
                  onRemove: _removeSelected,
                  onPickTone: () => _pickTone(selected),
                )
              else
                _SelectedSetEditor(
                  setItem: selected as _SetItem,
                  canRemove: _items.length > 1,
                  onRemove: _removeSelected,
                ),
              if (!isKeyboardOpen) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: _CodeEditorPreview(
                    title: title,
                    items: _items,
                    theme: _previewTheme,
                    onThemeSelected: (value) =>
                        setState(() => _previewTheme = value),
                    onFullscreen: () => _openFullPreview(title),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
