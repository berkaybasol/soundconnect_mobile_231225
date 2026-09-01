import 'package:flutter/material.dart';

/// Visual language shared by the public table list and detail overview.
///
/// These values intentionally stay local to TableGroup. The rest of the app
/// can keep following the selected application theme while this experience
/// retains the dark, low-contrast depth used by its reference design.
abstract final class TableGroupOverviewStyle {
  static const unspecifiedVenueLabel = 'Belirtilmemiş';

  static const pageBase = Color(0xFF07101D);
  static const pageDeep = Color(0xFF060D18);
  static const cardTop = Color(0xFF0D1725);
  static const cardBottom = Color(0xFF09121F);
  static const cardBorder = Color(0xFF26364B);
  static const insetTop = Color(0xFF07101B);
  static const insetBottom = Color(0xFF050B14);
  static const insetBorder = Color(0xFF1C2A3D);
  static const primaryText = Color(0xFFF5F2F4);
  static const warmHeading = Color(0xFFF4E5E6);
  static const headingMuted = Color(0xFFBAC7DC);
  static const bodyMuted = Color(0xFFA8B5C9);
  static const tertiaryText = Color(0xFF8795AA);
  static const divider = Color(0xFF223147);

  static const brandGradient = <Color>[
    Color(0xFFFF6A5F),
    Color(0xFFF45591),
    Color(0xFFC34CFF),
  ];

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[cardTop, cardBottom],
  );

  static const insetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[insetTop, insetBottom],
  );

  static const cardShadows = <BoxShadow>[
    BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 10)),
    BoxShadow(
      color: Color(0x122A6AA4),
      blurRadius: 28,
      spreadRadius: -6,
      offset: Offset(0, 8),
    ),
  ];
}

class TableGroupOverviewBackdrop extends StatelessWidget {
  const TableGroupOverviewBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                TableGroupOverviewStyle.pageBase,
                Color(0xFF07111F),
                TableGroupOverviewStyle.pageDeep,
              ],
              stops: <double>[0, 0.48, 1],
            ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.65, -0.72),
                radius: 1.05,
                colors: <Color>[Color(0x29183B61), Color(0x00060D18)],
                stops: <double>[0, 1],
              ),
            ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.95, 0.15),
                radius: 0.9,
                colors: <Color>[Color(0x18123151), Color(0x00060D18)],
                stops: <double>[0, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
