part of 'venue_weekly_calendar_editor_screen.dart';

extension _VenueEventDraftSheetStateUiHelpers on _VenueEventDraftSheetState {
  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _fieldFrame({required Widget child, required bool active}) {
    return Container(
      padding: EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              )
            : null,
        border: active
            ? null
            : Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16.8),
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
      padding: EdgeInsets.symmetric(vertical: 6),
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GradientOutlinePainter(borderRadius: 14, strokeWidth: 1.4),
          child: SizedBox.expand(),
        ),
      ),
    );
  }

  String _formatTimeValue(TimeOfDay time) {
    final hourLabel = time.hour == 0
        ? '24'
        : time.hour.toString().padLeft(2, '0');
    final minuteLabel = time.minute.toString().padLeft(2, '0');
    return '$hourLabel.$minuteLabel';
  }

  Widget _timeField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(label),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.navBlueDeep.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _gradientIcon(icon, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
