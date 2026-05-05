import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool centerContent;
  final AlignmentGeometry centerAlignment;
  final bool scrollable;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.centerContent = false,
    this.centerAlignment = Alignment.center,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: centerContent
                  ? Align(alignment: centerAlignment, child: child)
                  : child,
            );

            if (!scrollable) {
              return Padding(padding: const EdgeInsets.all(16), child: content);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: content,
            );
          },
        ),
      ),
    );
  }
}
