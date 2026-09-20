import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';

Future<String?> showLocationPickerSheet(
  BuildContext context, {
  required String title,
  required Map<String, String> options,
  String? selected,
  String searchLabel = 'Ara',
  Key? searchKey,
  Key Function(String)? optionKeyFor,
  Widget Function(Widget child)? routeWrapper,
}) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
    return Future<String?>.value();
  }
  final snapshot = Map<String, String>.unmodifiable(options);
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.navBlueDeep,
    builder: (_) {
      final picker = _LocationPicker(
        title: title,
        options: snapshot,
        selected: selected,
        searchLabel: searchLabel,
        searchKey: searchKey,
        optionKeyFor: optionKeyFor,
      );
      return routeWrapper?.call(picker) ?? picker;
    },
  );
}

class _LocationPicker extends StatefulWidget {
  const _LocationPicker({
    required this.title,
    required this.options,
    required this.searchLabel,
    this.selected,
    this.searchKey,
    this.optionKeyFor,
  });

  final String title;
  final Map<String, String> options;
  final String? selected;
  final String searchLabel;
  final Key? searchKey;
  final Key Function(String)? optionKeyFor;

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  String _query = '';
  bool _closing = false;

  String _fold(String value) => value
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

  void _select(String id) {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
    _closing = true;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final query = _fold(_query);
    final options = widget.options.entries
        .where((item) => _fold(item.value).contains(query))
        .toList();
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final keyboardInset = math.min(
            MediaQuery.viewInsetsOf(context).bottom,
            constraints.maxHeight,
          );
          final height = math.min(
            MediaQuery.sizeOf(context).height * .65,
            math.max(0.0, constraints.maxHeight - keyboardInset),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: SizedBox(
              height: height,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                      child: TextField(
                        key: widget.searchKey,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: _searchDecoration(widget.searchLabel),
                      ),
                    ),
                  ),
                  if (options.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Text('Sonuç bulunamadı.'),
                      ),
                    ),
                  SliverList.builder(
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final item = options[index];
                      return ListTile(
                        key: widget.optionKeyFor?.call(item.key),
                        title: Text(item.value),
                        selected: item.key == widget.selected,
                        selectedColor: AppColors.isLight
                            ? AppColors.accentText
                            : null,
                        trailing: item.key == widget.selected
                            ? const BrandGradientIcon.social(
                                Icons.check_rounded,
                              )
                            : null,
                        onTap: () => _select(item.key),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

InputDecoration _searchDecoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: AppColors.inputFill,
  prefixIcon: const BrandGradientIcon.social(Icons.search_rounded),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: AppColors.textMuted),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
);
