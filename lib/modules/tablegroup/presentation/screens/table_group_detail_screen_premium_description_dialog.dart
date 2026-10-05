part of 'table_group_detail_screen.dart';

class _PremiumDescriptionDialog extends StatelessWidget {
  final String description;

  const _PremiumDescriptionDialog({required this.description});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final foreground = AppColors.isOriginalDark
        ? Theme.of(context).colorScheme.onSurface
        : AppColors.legacy(AppColors.white);
    final muted = AppColors.isOriginalDark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : AppColors.legacy(AppColors.white).withValues(alpha: 0.72);

    return Dialog(
      key: const Key('table_group_description_dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.decorativeGradient
                  .map((color) => color.withValues(alpha: 0.72))
                  .toList(growable: false),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: 0.52),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: (AppColors.isOriginalDark
                  ? Theme.of(context).colorScheme.surfaceContainer
                  : AppColors.navBlue),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppColors.decorativeGradient,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (AppColors.isOriginalDark
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh
                                : AppColors.navBlueSoft),
                          ),
                          child: Icon(
                            Icons.subject_rounded,
                            color: foreground,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masa hakkında',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Masa sahibinin buluşma notu',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (AppColors.isOriginalDark
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : AppColors.inputFill),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (AppColors.isOriginalDark
                            ? Theme.of(context).colorScheme.outline
                            : AppColors.border),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        description,
                        key: const Key('table_group_description_dialog_text'),
                        style: TextStyle(
                          color: foreground,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: AppColors.decorativeGradient,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: Material(
                        color: (AppColors.isOriginalDark
                            ? Theme.of(context).colorScheme.surfaceContainer
                            : AppColors.navBlue),
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          key: const Key('table_group_description_close'),
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(13),
                          child: SizedBox(
                            height: 48,
                            child: Center(
                              child: Text(
                                'Kapat',
                                style: TextStyle(
                                  color: foreground,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
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
    );
  }
}

class _PremiumConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const _PremiumConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final foreground = AppColors.isOriginalDark
        ? Theme.of(context).colorScheme.onSurface
        : AppColors.legacy(AppColors.white);
    final muted = AppColors.isOriginalDark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : AppColors.legacy(AppColors.white).withValues(alpha: 0.72);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxDialogHeight = screenHeight > 48
        ? screenHeight - 48
        : screenHeight;

    return Dialog(
      key: const Key('table_group_confirmation_dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: 390, maxHeight: maxDialogHeight),
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.decorativeGradient
                .map((color) => color.withValues(alpha: 0.76))
                .toList(growable: false),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.pureBlack.withValues(alpha: 0.56),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (AppColors.isOriginalDark
                ? Theme.of(context).colorScheme.surfaceContainer
                : AppColors.navBlue),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('table_group_confirmation_scroll'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: AppColors.decorativeGradient,
                                ),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (AppColors.isOriginalDark
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHigh
                                      : AppColors.navBlueSoft),
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: foreground,
                                  size: 23,
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (AppColors.isOriginalDark
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest
                                : AppColors.inputFill),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (AppColors.isOriginalDark
                                  ? Theme.of(context).colorScheme.outline
                                  : AppColors.border),
                            ),
                          ),
                          child: Text(
                            message,
                            style: TextStyle(
                              color: muted,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('table_group_confirmation_cancel'),
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: muted,
                          side: BorderSide(
                            color: (AppColors.isOriginalDark
                                ? Theme.of(context).colorScheme.outline
                                : AppColors.border),
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Vazgeç',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GradientOutline(
                        enabled: AppColors.isLight,
                        radius: 14,
                        child: DecoratedBox(
                          decoration: AppColors.isLight
                              ? BoxDecoration(
                                  color: AppColors.navBlue,
                                  borderRadius: BorderRadius.circular(14),
                                )
                              : BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: LinearGradient(
                                    colors: AppColors.actionGradient,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (AppColors.isLight
                                                  ? AppColors.avatarShadow
                                                  : AppColors
                                                        .brandGradient
                                                        .last)
                                              .withValues(
                                                alpha: AppColors.isLight
                                                    ? 0.12
                                                    : 0.22,
                                              ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              key: const Key(
                                'table_group_confirmation_confirm',
                              ),
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                foregroundColor: AppColors.onAccent,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                confirmLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinDialogSubmission {
  final String note;

  const _JoinDialogSubmission(this.note);
}

class _PremiumJoinDialog extends StatefulWidget {
  const _PremiumJoinDialog();

  @override
  State<_PremiumJoinDialog> createState() => _PremiumJoinDialogState();
}

class _PremiumJoinDialogState extends State<_PremiumJoinDialog> {
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _noteFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _cancel() => Navigator.of(context).pop();

  void _confirm() =>
      Navigator.of(context).pop(_JoinDialogSubmission(_noteController.text));

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final foreground = AppColors.isOriginalDark
        ? Theme.of(context).colorScheme.onSurface
        : AppColors.legacy(AppColors.white);
    final muted = AppColors.isOriginalDark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : AppColors.legacy(AppColors.white).withValues(alpha: 0.72);

    return Dialog(
      key: const Key('table_group_join_dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.decorativeGradient
                  .map((color) => color.withValues(alpha: 0.72))
                  .toList(growable: false),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: 0.52),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: (AppColors.isOriginalDark
                  ? Theme.of(context).colorScheme.surfaceContainer
                  : AppColors.navBlue),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppColors.decorativeGradient,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (AppColors.isOriginalDark
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh
                                : AppColors.navBlueSoft),
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: foreground,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Katılma isteği',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Masa sahibine kısa bir not bırakabilirsin.',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('table_group_join_owner_warning'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.decorativeGradient.first.withValues(
                            alpha: 0.18,
                          ),
                          AppColors.decorativeGradient.last.withValues(
                            alpha: 0.14,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: AppColors.coralLight.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.coralLight,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Aktif bir masan varsa bu istek onaylandığında '
                            'kapanır.',
                            style: TextStyle(
                              color: AppColors.legacy(
                                AppColors.white,
                              ).withValues(alpha: 0.94),
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Not',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (AppColors.isOriginalDark
                              ? Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest
                              : AppColors.inputFill),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (AppColors.isOriginalDark
                                ? Theme.of(context).colorScheme.outline
                                : AppColors.border),
                          ),
                        ),
                        child: Text(
                          'İsteğe bağlı',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: _noteFocusNode.hasFocus
                          ? LinearGradient(colors: AppColors.decorativeGradient)
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
                    child: TextField(
                      key: const Key('table_group_join_note_input'),
                      controller: _noteController,
                      focusNode: _noteFocusNode,
                      autofocus: true,
                      maxLength: 256,
                      minLines: 3,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: AppColors.coralLight,
                      style: TextStyle(color: foreground),
                      decoration: InputDecoration(
                        hintText: 'Kısa bir not yazabilirsin…',
                        hintStyle: TextStyle(color: muted, fontSize: 14),
                        counterText: '',
                        filled: true,
                        fillColor: (AppColors.isOriginalDark
                            ? Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest
                            : AppColors.inputFill),
                        contentPadding: const EdgeInsets.fromLTRB(
                          15,
                          14,
                          15,
                          14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _noteController,
                    builder: (context, value, _) => Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${value.text.characters.length}/256',
                        key: const Key('table_group_join_note_counter'),
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('table_group_join_cancel'),
                          onPressed: _cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: muted,
                            side: BorderSide(
                              color: (AppColors.isOriginalDark
                                  ? Theme.of(context).colorScheme.outline
                                  : AppColors.border),
                            ),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'İptal',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GradientOutline(
                          enabled: AppColors.isLight,
                          radius: 14,
                          child: DecoratedBox(
                            decoration: AppColors.isLight
                                ? BoxDecoration(
                                    color: AppColors.navBlue,
                                    borderRadius: BorderRadius.circular(14),
                                  )
                                : BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      colors: AppColors.actionGradient,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (AppColors.isLight
                                                    ? AppColors.avatarShadow
                                                    : AppColors
                                                          .brandGradient
                                                          .last)
                                                .withValues(
                                                  alpha: AppColors.isLight
                                                      ? 0.12
                                                      : 0.22,
                                                ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: const Key('table_group_join_confirm'),
                                onTap: _confirm,
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: Text(
                                      'Gönder',
                                      style: TextStyle(
                                        color: AppColors.onAccent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final List<Color> colors;

  _GradientOutlinePainter({
    required this.radius,
    required this.strokeWidth,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(colors: colors).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.colors != colors;
  }
}
