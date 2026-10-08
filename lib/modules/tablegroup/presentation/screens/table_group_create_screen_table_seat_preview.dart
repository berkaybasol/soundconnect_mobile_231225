part of 'table_group_create_screen.dart';

class _TableSeatPreview extends StatelessWidget {
  final List<_SeatGender> seatGenders;
  final int totalSeats;

  _TableSeatPreview({required this.seatGenders, required this.totalSeats});

  List<Color> _seatGradient() {
    return AppColors.decorativeGradient;
  }

  IconData _seatIcon(_SeatGender gender) {
    return switch (gender) {
      _SeatGender.me => Icons.bookmark_rounded,
      _SeatGender.female => Icons.female_rounded,
      _SeatGender.male => Icons.male_rounded,
      _SeatGender.other => Icons.all_inclusive_rounded,
    };
  }

  double _seatIconSize(_SeatGender gender) {
    return switch (gender) {
      _SeatGender.me => 18,
      _SeatGender.female => 24,
      _SeatGender.male => 24,
      _SeatGender.other => 19,
    };
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SizedBox(
      height: 194,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(constraints.maxWidth / 2, 102);
          final rx = constraints.maxWidth * 0.39;
          final ry = 56.0;
          final seats = <Widget>[
            Positioned(
              left: center.dx - 113,
              top: center.dy - 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(42),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFCFBFF), Color(0xFFF2EEF9)],
                  ),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.45),
                    width: 1.0,
                  ),
                ),
                child: SizedBox(
                  width: 226,
                  height: 122,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 10,
                        child: Container(
                          width: 52,
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: AppColors.pureBlack.withValues(alpha: 0.10),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        child: Container(
                          width: 12,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Color(0xFFF0EDF7),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.8),
                              width: 0.8,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 170,
                        height: 86,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: AppColors.decorativeGradient
                                .map((color) => color.withValues(alpha: 0.32))
                                .toList(),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(1.4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32.6),
                            child: Container(
                              color: AppColors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: 0.72,
                        child: Image.asset(
                          'assets/logotransparent.png',
                          width: 132,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];

          for (int i = 0; i < seatGenders.length; i++) {
            final angle = -1.570796 + (6.283185 * i / seatGenders.length);
            final seatCenter = Offset(
              center.dx + rx * cos(angle),
              center.dy + ry * sin(angle),
            );
            final inwardShadowOffset = Offset(
              -cos(angle) * 1.6,
              -sin(angle) * 1.6,
            );
            final isMe = i == 0;
            final seatGradient = _seatGradient();
            seats.add(
              Positioned(
                left: seatCenter.dx - 18,
                top: seatCenter.dy - 18,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: GradientOutline(
                    enabled: AppColors.isLight,
                    radius: 999,
                    child: Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: AppColors.isLight
                          ? BoxDecoration(
                              color: AppColors.navBlue,
                              shape: BoxShape.circle,
                            )
                          : BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: seatGradient,
                              ),
                              border: Border.all(
                                color: AppColors.white.withValues(alpha: 0.96),
                                width: 1.7,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.pureBlack.withValues(
                                    alpha: 0.20,
                                  ),
                                  blurRadius: 4.8,
                                  offset: inwardShadowOffset,
                                ),
                              ],
                            ),
                      child: isMe
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.bookmark_rounded,
                                    size: 18,
                                    color: AppColors.decorativeForeground
                                        .withValues(alpha: 0.98),
                                  ),
                                  Positioned(
                                    top: 5.5,
                                    child: Icon(
                                      Icons.star_rounded,
                                      size: 8,
                                      color: AppColors.decorativeForeground
                                          .withValues(alpha: 0.98),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Icon(
                              _seatIcon(seatGenders[i]),
                              size: _seatIconSize(seatGenders[i]),
                              color: AppColors.decorativeForeground.withValues(
                                alpha: 0.98,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(children: seats);
        },
      ),
    );
  }
}

class _PremiumVenueToggle extends StatelessWidget {
  final Key controlKey;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _PremiumVenueToggle({
    required this.controlKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    final accent = AppColors.brandGradient.last;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      toggled: value,
      label: 'Belirli bir mekâna mı gidiyorsunuz?',
      value: value ? 'Açık' : 'Kapalı',
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.55,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: controlKey,
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? () => onChanged!(!value) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: (AppColors.isOriginalDark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : AppColors.inputFill),
                  border: Border.all(
                    color: value
                        ? accent.withValues(alpha: 0.82)
                        : (AppColors.isOriginalDark
                              ? Theme.of(context).colorScheme.outline
                              : AppColors.border),
                    width: value ? 1.2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.decorativeGradient,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.surface,
                        ),
                        child: Icon(
                          value
                              ? Icons.location_on_rounded
                              : Icons.location_on_outlined,
                          color: colorScheme.onSurface,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Belirli bir mekâna mı gidiyorsunuz?',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            value
                                ? 'Mekânını aşağıdaki alandan seç'
                                : 'Dilersen buluşma mekânını ekle',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GradientOutline(
                      enabled: AppColors.isLight,
                      radius: 999,
                      colors: value && enabled
                          ? AppColors.decorativeGradient
                          : [AppColors.border, AppColors.border],
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 56,
                        height: 34,
                        padding: const EdgeInsets.all(3),
                        decoration: AppColors.isLight
                            ? BoxDecoration(
                                color: AppColors.navBlue,
                                borderRadius: BorderRadius.circular(999),
                              )
                            : BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: value
                                    ? LinearGradient(
                                        colors: AppColors.decorativeGradient,
                                      )
                                    : null,
                                color: value
                                    ? null
                                    : (AppColors.isOriginalDark
                                          ? Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                          : AppColors.inputFill),
                                border: Border.all(
                                  color: value
                                      ? AppColors.white.withValues(alpha: 0.18)
                                      : (AppColors.isOriginalDark
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.outline
                                            : AppColors.border),
                                ),
                              ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: value
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.pureBlack.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DescriptionCounter extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionCounter({required this.controller});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final length = TableGroupCreateRequest.descriptionCodePointLength(
          value.text,
        );
        final limit = TableGroupCreateRequest.maxDescriptionLength;
        return Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            label: '$length / $limit karakter',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '$length/$limit',
                  key: const Key('table_group_description_counter'),
                  style: TextStyle(
                    color: length > limit
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;

  _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _GradientFocusFrame extends StatelessWidget {
  final bool isFocused;
  final Widget child;

  _GradientFocusFrame({required this.isFocused, required this.child});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: isFocused
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.decorativeGradient,
              )
            : LinearGradient(
                colors: [
                  (AppColors.isOriginalDark
                      ? Theme.of(context).colorScheme.outline
                      : AppColors.border),
                  (AppColors.isOriginalDark
                      ? Theme.of(context).colorScheme.outline
                      : AppColors.border),
                ],
              ),
      ),
      child: child,
    );
  }
}

class _PremiumAgeRangeSlider extends StatelessWidget {
  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<RangeValues>? onChanged;

  _PremiumAgeRangeSlider({
    required this.values,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final startPercent = ((values.start - min) / (max - min)).clamp(0.0, 1.0);
    final endPercent = ((values.end - min) / (max - min)).clamp(0.0, 1.0);

    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth - 24;
          final activeLeft = 12 + (trackWidth * startPercent);
          final activeRight = 12 + (trackWidth * endPercent);

          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                right: 12,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.95),
                  ),
                ),
              ),
              Positioned(
                left: activeLeft,
                width: (activeRight - activeLeft) < 8
                    ? 8
                    : (activeRight - activeLeft),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: AppColors.decorativeGradient,
                    ),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 0.01,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: AppColors.white,
                  overlayColor: Color(0xFFC15CE0).withValues(alpha: 0.16),
                  rangeThumbShape: RoundRangeSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                  rangeValueIndicatorShape:
                      PaddleRangeSliderValueIndicatorShape(),
                  valueIndicatorColor: AppColors.isLight
                      ? AppColors.actionGradient.last
                      : AppColors.brandGradient.last,
                  valueIndicatorTextStyle: TextStyle(
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: RangeSlider(
                  values: values,
                  min: min,
                  max: max,
                  divisions: divisions,
                  labels: RangeLabels(
                    values.start.round().toString(),
                    values.end.round().toString(),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GenderSeatMiniControl extends StatelessWidget {
  final String keyPrefix;
  final IconData icon;
  final int count;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  _GenderSeatMiniControl({
    required this.keyPrefix,
    required this.icon,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  List<Color> _seatGradient() {
    return AppColors.decorativeGradient;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      children: [
        GradientOutline(
          enabled: AppColors.isLight,
          radius: 999,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: AppColors.isLight
                ? BoxDecoration(
                    color: AppColors.navBlue,
                    shape: BoxShape.circle,
                  )
                : BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _seatGradient(),
                    ),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.95),
                      width: 1.2,
                    ),
                  ),
            child: Icon(
              icon,
              size: 24,
              color:
                  (AppColors.isLight ? AppColors.textPrimary : AppColors.white)
                      .withValues(alpha: 0.98),
            ),
          ),
        ),
        SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: Key('table_group_seat_$keyPrefix-remove'),
              borderRadius: BorderRadius.circular(999),
              onTap: onRemove,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.remove,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              width: 20,
              child: Text(
                count.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            InkWell(
              key: Key('table_group_seat_$keyPrefix-add'),
              borderRadius: BorderRadius.circular(999),
              onTap: onAdd,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
