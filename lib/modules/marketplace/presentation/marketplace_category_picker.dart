import 'package:flutter/material.dart';

import '../domain/marketplace_models.dart';
import 'marketplace_access_gate.dart';

/// A cancelled picker returns null; an explicit filter reset returns ''.
/// Listing editors only receive a product type, never a top-level group.
Future<String?> showMarketplaceCategoryPicker(
  BuildContext context, {
  required List<MarketplaceCategory> categories,
  String? selectedId,
  String? initialRootId,
  bool leafOnly = false,
  bool startAtRoot = false,
}) {
  if (!marketplaceCanAct(context) ||
      ModalRoute.of(context)?.isCurrent == false) {
    return Future.value();
  }
  return marketplaceSheet<String>(
    context,
    (_) => MarketplaceCategoryPicker(
      categories: categories,
      selectedId: selectedId,
      initialRootId: initialRootId,
      leafOnly: leafOnly,
      startAtRoot: startAtRoot,
    ),
  );
}

String? marketplaceCategoryLabel(
  List<MarketplaceCategory> categories,
  String? id,
) {
  if (id == null || id.isEmpty) return null;
  for (final root in categories) {
    if (root.id == id) return root.name;
    for (final child in root.children) {
      if (child.id == id) return '${root.name} › ${child.name}';
    }
  }
  return null;
}

class MarketplaceCategoryPicker extends StatefulWidget {
  const MarketplaceCategoryPicker({
    required this.categories,
    this.selectedId,
    this.initialRootId,
    this.leafOnly = false,
    this.startAtRoot = false,
    super.key,
  });

  final List<MarketplaceCategory> categories;
  final String? selectedId;
  final String? initialRootId;
  final bool leafOnly;

  /// Opens the group list while retaining the current selection highlight.
  final bool startAtRoot;

  @override
  State<MarketplaceCategoryPicker> createState() =>
      _MarketplaceCategoryPickerState();
}

class _MarketplaceCategoryPickerState extends State<MarketplaceCategoryPicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  MarketplaceCategory? _root;
  bool _closing = false;

  bool get _canAct =>
      mounted &&
      !_closing &&
      marketplaceCanAct(context) &&
      ModalRoute.of(context)?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    if (widget.startAtRoot) return;
    _root = widget.categories
        .where(
          (root) => widget.initialRootId != null
              ? root.id == widget.initialRootId
              : root.id == widget.selectedId ||
                    root.children.any((leaf) => leaf.id == widget.selectedId),
        )
        .firstOrNull;
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _enter(MarketplaceCategory root) {
    if (!_canAct) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _root = root;
      _search.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back() {
    if (!_canAct) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _root = null;
      _search.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _finish(String? id) {
    if (!_canAct) return;
    if (id != null &&
        widget.leafOnly &&
        !widget.categories.any(
          (root) => root.children.any((leaf) => leaf.id == id),
        )) {
      return;
    }
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          marketplaceCanAct(context) &&
          ModalRoute.of(context)?.isCurrent != false) {
        Navigator.of(context).pop(id);
      }
    });
  }

  static String _fold(String value) => value
      .trim()
      .replaceAll('İ', 'i')
      .toLowerCase()
      .replaceAll('\u0307', '')
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _fold(_search.text);
    final root = _root;
    final rows = <Widget>[];
    if (query.isEmpty) {
      if (root == null) {
        if (!widget.leafOnly) {
          rows.add(
            _row(
              key: const Key('marketplace-category-all'),
              title: 'Tüm kategoriler',
              icon: Icons.apps_rounded,
              selected: widget.selectedId == null || widget.selectedId!.isEmpty,
              onTap: () => _finish(''),
            ),
          );
        }
        for (final category in widget.categories) {
          rows.add(_groupRow(category));
        }
      } else {
        if (!widget.leafOnly) {
          rows.add(
            _row(
              key: const Key('marketplace-category-branch-all'),
              title: 'Tüm ${root.name} ilanları',
              icon: Icons.grid_view_rounded,
              selected: widget.selectedId == root.id,
              onTap: () => _finish(root.id),
            ),
          );
        }
        for (final leaf in root.children) {
          rows.add(_leafRow(leaf));
        }
      }
    } else {
      for (final category in root == null ? widget.categories : [root]) {
        if (root == null && _fold(category.name).contains(query)) {
          rows.add(_groupRow(category));
        }
        for (final leaf in category.children) {
          if (_fold(leaf.name).contains(query)) {
            rows.add(_leafRow(leaf, parentName: category.name));
          }
        }
      }
    }

    return PopScope<String>(
      canPop: root == null || _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && root != null) _back();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: CustomScrollView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              root?.name ?? 'Kategori seç',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.4,
                                height: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('marketplace-category-close'),
                            tooltip: 'Kapat',
                            onPressed: () => _finish(null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: root == null
                          ? Padding(
                              padding: const EdgeInsets.only(
                                top: 6,
                                bottom: 16,
                              ),
                              child: Text(
                                'Önce ana kategoriyi, sonra ürün türünü seç.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            )
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: const Key('marketplace-category-back'),
                                onPressed: _back,
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 17,
                                ),
                                label: const Text('Ana kategoriler'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        key: const Key('marketplace-category-search'),
                        controller: _search,
                        onChanged: (_) {
                          if (_canAct) setState(() {});
                        },
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: root == null
                              ? 'Kategori veya ürün türü ara'
                              : 'Bu kategoride ara',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 21,
                          ),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Aramayı temizle',
                                  onPressed: () {
                                    if (_canAct) setState(_search.clear);
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              if (rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        query.isEmpty
                            ? 'Bu kategoride henüz ürün türü yok.'
                            : 'Eşleşen kategori bulunamadı.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => rows[index],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupRow(MarketplaceCategory root) {
    final selectedLeaf = root.children
        .where((leaf) => leaf.id == widget.selectedId)
        .firstOrNull;
    return _row(
      key: ValueKey('marketplace-category-${root.id}'),
      title: root.name,
      subtitle: selectedLeaf?.name ?? '${root.children.length} ürün türü',
      icon: _icon(root.code),
      branch: true,
      selected: widget.selectedId == root.id || selectedLeaf != null,
      onTap: () => _enter(root),
    );
  }

  Widget _leafRow(MarketplaceCategory leaf, {String? parentName}) => _row(
    key: ValueKey('marketplace-category-${leaf.id}'),
    title: leaf.name,
    subtitle: parentName,
    selected: widget.selectedId == leaf.id,
    onTap: () => _finish(leaf.id),
  );

  Widget _row({
    required Key key,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    IconData? icon,
    bool selected = false,
    bool branch = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.surfaceContainerHigh : colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? colors.primary.withValues(alpha: .65)
              : colors.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: key,
        selected: selected,
        selectedColor: colors.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: icon == null
            ? null
            : Icon(icon, color: colors.onSurfaceVariant, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
        trailing: Icon(
          branch
              ? Icons.chevron_right_rounded
              : selected
              ? Icons.check_rounded
              : Icons.radio_button_unchecked_rounded,
          size: branch ? 22 : 19,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }

  static IconData _icon(String code) => switch (code.toUpperCase()) {
    'KEYBOARDS' => Icons.piano_outlined,
    'MICROPHONES' => Icons.mic_none_rounded,
    'RECORDING' => Icons.graphic_eq_rounded,
    'DJ' => Icons.album_outlined,
    'AMPS_EFFECTS' || 'LIVE_SOUND' => Icons.speaker_group_outlined,
    'LIGHTING_STAGE' => Icons.light_mode_outlined,
    'ACCESSORIES' => Icons.cable_rounded,
    _ => Icons.music_note_outlined,
  };
}
