import 'package:flutter/material.dart';

class CollabSearchableOptionSheet<T> extends StatefulWidget {
  const CollabSearchableOptionSheet({
    required this.title,
    required this.options,
    required this.labelFor,
    required this.onSelected,
    this.selected,
    super.key,
  });

  final String title;
  final List<T> options;
  final String Function(T option) labelFor;
  final ValueChanged<T> onSelected;
  final T? selected;

  @override
  State<CollabSearchableOptionSheet<T>> createState() =>
      _CollabSearchableOptionSheetState<T>();
}

class _CollabSearchableOptionSheetState<T>
    extends State<CollabSearchableOptionSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleOptions = normalizedQuery.isEmpty
        ? widget.options
        : widget.options
              .where(
                (option) => widget
                    .labelFor(option)
                    .toLowerCase()
                    .contains(normalizedQuery),
              )
              .toList(growable: false);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('collab-specialty-search'),
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Enstrüman, rol veya ekipman ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: visibleOptions.isEmpty
                  ? const Center(child: Text('Eşleşen seçenek bulunamadı.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: visibleOptions.length,
                      itemBuilder: (context, index) {
                        final option = visibleOptions[index];
                        final isSelected = option == widget.selected;
                        return ListTile(
                          title: Text(widget.labelFor(option)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded)
                              : null,
                          onTap: () => widget.onSelected(option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
