import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:io';

import '../../../../shared/theme/app_colors.dart';
import '../../../profile/domain/entities/band_profile.dart';
part 'band_setlist_builder_models.dart';
part 'band_setlist_builder_widgets.dart';

class BandSetlistBuilderScreen extends StatefulWidget {
  final BandProfile? bandProfile;
  final String? initialTitle;

  BandSetlistBuilderScreen({super.key, this.bandProfile, this.initialTitle});

  @override
  State<BandSetlistBuilderScreen> createState() =>
      _BandSetlistBuilderScreenState();
}

class _SetlistExportPage {
  final List<_TimelineItem> items;
  final int songNumberOffset;

  _SetlistExportPage({required this.items, required this.songNumberOffset});
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
    final initialTitle = widget.initialTitle?.trim();
    final bandName = widget.bandProfile?.name.trim();
    _setlistNameController.text = initialTitle?.isNotEmpty == true
        ? initialTitle!
        : bandName?.isNotEmpty == true
        ? '$bandName Setlist'
        : 'Setlist';
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ton Seçimi',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
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
                  SizedBox(height: 8),
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
                  SizedBox(height: 8),
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
                  SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(_ToneValue.original()),
                      child: Text('Orijinal Ton'),
                    ),
                  ),
                  SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(value),
                    child: Text('Uygula'),
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

  int get _songCount => _items.whereType<_SongItem>().length;

  int get _exportImageCount => _buildExportPages().length;

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
      final exportPages = _buildExportPages();
      final tempDir = await getTemporaryDirectory();
      final safeName = title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      final baseName = safeName.isEmpty ? 'setlist' : safeName;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final files = <XFile>[];
      if (!mounted) return;

      for (var pageIndex = 0; pageIndex < exportPages.length; pageIndex++) {
        if (!mounted) return;
        final page = exportPages[pageIndex];
        final pageTitle = exportPages.length == 1
            ? title
            : '$title (${pageIndex + 1}/${exportPages.length})';
        final bytes = await controller.captureFromWidget(
          Material(
            color: AppColors.navBlueDeep,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: SizedBox(
                  width: screenSize.width - 24,
                  height: screenSize.height - 26,
                  child: _CodeEditorPreview(
                    title: pageTitle,
                    items: page.items,
                    theme: _previewTheme,
                    fullscreenMode: true,
                    exportCompact: true,
                    songNumberOffset: page.songNumberOffset,
                  ),
                ),
              ),
            ),
          ),
          context: context,
          pixelRatio: pixelRatio,
        );
        final partSuffix = exportPages.length == 1 ? '' : '_${pageIndex + 1}';
        final file = File(
          '${tempDir.path}/${baseName}_$timestamp$partSuffix.png',
        );
        await file.writeAsBytes(bytes, flush: true);
        files.add(XFile(file.path, mimeType: 'image/png'));
      }

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: files,
          subject: '$title Görsel',
          text: exportPages.length == 1
              ? '$title setlist görseli'
              : '$title setlist görselleri',
          sharePositionOrigin: Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gorsel olusturma sirasinda hata olustu.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  List<_SetlistExportPage> _buildExportPages() {
    final maxSongsPerImage = _previewTheme == _PreviewTheme.cod ? 32 : 10;
    final pages = <_SetlistExportPage>[];
    var current = <_TimelineItem>[];
    var currentSongCount = 0;
    var totalSongsBeforePage = 0;

    void flush() {
      if (current.isEmpty) return;
      pages.add(
        _SetlistExportPage(
          items: List<_TimelineItem>.of(current),
          songNumberOffset: totalSongsBeforePage,
        ),
      );
      totalSongsBeforePage += currentSongCount;
      current = <_TimelineItem>[];
      currentSongCount = 0;
    }

    for (final item in _items) {
      if (item is _SongItem && currentSongCount >= maxSongsPerImage) {
        flush();
      }
      if (item is _SetItem &&
          current.isNotEmpty &&
          currentSongCount >= maxSongsPerImage) {
        flush();
      }

      current.add(item);
      if (item is _SongItem) {
        currentSongCount += 1;
      }
    }
    flush();

    return pages.isEmpty
        ? <_SetlistExportPage>[
            _SetlistExportPage(items: _items, songNumberOffset: 0),
          ]
        : pages;
  }

  void _openFullPreview(String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Canlı Önizleme')),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
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
        title: Text('Setlist Oluştur'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isExportingPdf ? null : _savePreviewImage,
              icon: _isExportingPdf
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.image_outlined),
              label: Text(
                _isExportingPdf ? 'Hazırlanıyor' : 'Fotoğrafı Kaydet',
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            children: [
              TextField(
                controller: _setlistNameController,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  labelText: 'Setlist Adı',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    '$_songCount şarkı · $_exportImageCount fotoğraf',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
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
                              padding: EdgeInsets.only(right: 8),
                              child: tile,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    _AddMiniTile(icon: Icons.add, onTap: _addSong),
                    SizedBox(width: 8),
                    _AddMiniTile(label: '|', opacity: 0.45, onTap: _addSet),
                  ],
                ),
              ),
              SizedBox(height: 10),
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
                SizedBox(height: 12),
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
