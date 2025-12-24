import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool centerContent;
  final AlignmentGeometry centerAlignment;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.centerContent = false,
    this.centerAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: centerContent
                    ? Align(alignment: centerAlignment, child: child)
                    : child,
              ),
            );
          },
        ),
      ),
    );
  }
}
