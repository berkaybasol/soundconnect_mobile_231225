part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateUiHelpers on _VenueEventDraftSheetState {
  Widget _sectionCard({required Widget child}) => child;

  Widget _sectionLabel(String label, {IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            _gradientIcon(icon, size: 17),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldFrame({required Widget child, required bool active}) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: active
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        border: active
            ? null
            : Border.all(color: Theme.of(context).dividerColor),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.brandGradient[1].withValues(alpha: 0.12),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }

  Widget _gradientIcon(IconData icon, {double size = 20}) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: AppColors.white),
    );
  }

  Widget _pickerSelectionOverlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GradientOutlinePainter(borderRadius: 12, strokeWidth: 1.2),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  String _formatTimeValue(TimeOfDay time) {
    final hourLabel = time.hour.toString().padLeft(2, '0');
    final minuteLabel = time.minute.toString().padLeft(2, '0');
    return '$hourLabel:$minuteLabel';
  }

  Widget _selectionTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: _gradientIcon(icon, size: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: '$label saatini kaldır',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 17,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 19,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return _selectionTile(
      label: label,
      value: value,
      icon: icon,
      onTap: onTap,
      onClear: onClear,
    );
  }

  Widget _gradientActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 160),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(0.9),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppColors.brandGradient),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(9.2),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _gradientIcon(icon, size: 19),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
