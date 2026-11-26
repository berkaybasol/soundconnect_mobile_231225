import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../data/analytics_consent_controller.dart';
import '../screens/analytics_preference_screen.dart';

class GuestAnalyticsPreferenceEntry extends StatelessWidget {
  const GuestAnalyticsPreferenceEntry({super.key});

  @override
  Widget build(BuildContext context) {
    if (!serviceLocator.isRegistered<AnalyticsConsentController>()) {
      return const SizedBox.shrink();
    }
    final controller = serviceLocator<AnalyticsConsentController>();
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isMember || !controller.canChooseForSubject) {
          return const SizedBox.shrink();
        }
        void open() => AnalyticsPreferenceScreen.open(context, controller);
        if (controller.choice != ConsentChoice.undecided ||
            controller.error != null) {
          return TextButton(
            onPressed: open,
            child: Text(
              analyticsPrivacyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.underline,
              ),
            ),
          );
        }
        final subject = controller.subjectRevision;
        Future<bool> choose(bool allow) =>
            saveAnalyticsPreference(context, controller, subject, allow);
        final decisionStyle = TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          minimumSize: const Size(0, 39),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: theme.textTheme.labelMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        );
        return Container(
          key: const Key('analytics-preference-card'),
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.fromLTRB(9, 0, 9, 2),
          decoration: BoxDecoration(
            color: appCardSurface(
              context,
              darkenBackground: true,
            ).withValues(alpha: .40),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: .60),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 44,
                          vertical: 4,
                        ),
                        child: Center(
                          child: Text(
                            'Kullanım istatistiklerine izin ver',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 19 / 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        tooltip: 'Kapat ve izin verme',
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        onPressed: controller.busy ? null : () => choose(false),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                spacing: 8,
                children: [
                  for (final allow in [true, false])
                    Expanded(
                      child: GradientOutline(
                        radius: 12,
                        strokeWidth: 1,
                        child: TextButton(
                          style: decisionStyle,
                          onPressed: controller.busy
                              ? null
                              : () => choose(allow),
                          child: Text(allow ? 'Evet' : 'Hayır'),
                        ),
                      ),
                    ),
                ],
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  minimumSize: const Size(0, 31),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: open,
                child: const Text(
                  'Detaylar',
                  style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MemberAnalyticsPreferenceTile extends StatelessWidget {
  const MemberAnalyticsPreferenceTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (!serviceLocator.isRegistered<AnalyticsConsentController>()) {
      return const SizedBox.shrink();
    }
    final controller = serviceLocator<AnalyticsConsentController>();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isMember || !controller.canChooseForSubject) {
          return const SizedBox.shrink();
        }
        final subject = controller.subjectRevision;
        return ListTile(
          key: const Key('account-settings-analytics-preference'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Semantics(
            hint: 'Ayrıntıları ve izin seçeneklerini açar.',
            child: const Text(analyticsPreferenceTitle),
          ),
          subtitle: controller.error == null ? null : Text(controller.error!),
          onTap: () => AnalyticsPreferenceScreen.open(context, controller),
          trailing: Semantics(
            label: analyticsPreferenceTitle,
            child: _MemberAnalyticsSwitch(
              value: controller.choice == ConsentChoice.granted,
              onChanged: controller.busy
                  ? null
                  : (value) => saveAnalyticsPreference(
                      context,
                      controller,
                      subject,
                      value,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _MemberAnalyticsSwitch extends StatelessWidget {
  const _MemberAnalyticsSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final offFill = dark ? const Color(0xFF101824) : scheme.surfaceContainer;
    final onFill = dark ? const Color(0xFF1A1525) : scheme.primaryContainer;
    final offBorder = dark ? const Color(0xFF47546B) : scheme.outline;
    final offThumb = dark ? const Color(0xFFA4AFC2) : scheme.onSurfaceVariant;
    final onThumb = dark ? const Color(0xFFF4E6F5) : scheme.onPrimaryContainer;

    return Opacity(
      opacity: onChanged == null ? 0.55 : 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GradientOutline(
            radius: 14,
            strokeWidth: 1.5,
            colors: value ? null : [offBorder, offBorder],
            child: Container(
              width: 48,
              height: 28,
              decoration: ShapeDecoration(
                color: value ? onFill : offFill,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          // Keep the native switch's drag, keyboard, focus and accessibility.
          Switch(
            value: value,
            onChanged: onChanged,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            trackColor: const WidgetStatePropertyAll(Colors.transparent),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            activeThumbColor: onFill,
            inactiveThumbColor: offFill,
            thumbIcon: WidgetStateProperty.resolveWith(
              (states) => Icon(
                Icons.circle,
                size: 22,
                color: states.contains(WidgetState.selected)
                    ? onThumb
                    : offThumb,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
