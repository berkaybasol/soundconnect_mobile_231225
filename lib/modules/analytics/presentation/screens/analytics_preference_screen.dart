import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../data/analytics_consent_controller.dart';
import 'analytics_privacy_document.dart';

const analyticsPreferenceTitle = 'Kullanım istatistikleri';
const analyticsPrivacyTitle = 'Gizlilik ve analitik tercihi';

Future<bool> saveAnalyticsPreference(
  BuildContext context,
  AnalyticsConsentController controller,
  int subject,
  bool allow,
) async {
  if (controller.busy || subject != controller.subjectRevision) return false;
  try {
    await controller.choose(allow, expectedSubject: subject);
    return subject == controller.subjectRevision;
  } catch (_) {
    if (context.mounted && subject == controller.subjectRevision) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          content: const Text('Tercihin kaydedilemedi. Lütfen tekrar dene.'),
          tone: AppSnackBarTone.error,
        ),
      );
    }
    return false;
  }
}

class AnalyticsPreferenceScreen extends StatelessWidget {
  const AnalyticsPreferenceScreen({
    super.key,
    required this.controller,
    required this.subject,
    required this.member,
    this.editing = false,
  });

  final AnalyticsConsentController controller;
  final int subject;
  final bool member;
  final bool editing;

  static void open(
    BuildContext context,
    AnalyticsConsentController controller,
  ) {
    AnalyticsPreferenceScreen(
      controller: controller,
      subject: controller.subjectRevision,
      member: controller.isMember,
    )._push(context);
  }

  void _push(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppSurfaceThemeScope(child: this),
      ),
    );
  }

  Future<void> _choose(BuildContext context, bool allow) async {
    final saved = await saveAnalyticsPreference(
      context,
      controller,
      subject,
      allow,
    );
    if (saved && context.mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(analyticsPrivacyTitle),
        actions: [CloseButton(onPressed: () => Navigator.of(context).pop())],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final current = controller.subjectRevision == subject;
            final choice = controller.choice;
            final showSaved =
                !editing &&
                current &&
                controller.error == null &&
                choice != ConsentChoice.undecided;
            final granted = choice == ConsentChoice.granted;
            final status = !current
                ? 'Oturum değişti.'
                : controller.error ??
                      switch (controller.choice) {
                        ConsentChoice.granted => 'Analitik açık',
                        ConsentChoice.denied =>
                          'Analitik kapalı · İzin verilmedi',
                        ConsentChoice.undecided =>
                          'Analitik kapalı · Henüz seçim yapılmadı',
                      };
            final enabled = current && !controller.busy;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.decorativeGradient,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  showSaved
                      ? (granted
                            ? 'Kullanım istatistiklerine izin verdiniz.'
                            : 'Kullanım istatistiklerine izin vermediniz.')
                      : 'SoundConnect’i birlikte geliştirelim',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showSaved) ...[
                  const SizedBox(height: 12),
                  Text(
                    granted
                        ? 'İstatistik ölçümü açık. İzninizi istediğiniz zaman geri alabilirsiniz.'
                        : 'İstatistik ölçümü kapalı. Tercihinizi istediğiniz zaman değiştirebilirsiniz.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  GradientOutlineButton(
                    label: 'Tercihimi değiştir',
                    onPressed: enabled
                        ? () => AnalyticsPreferenceScreen(
                            controller: controller,
                            subject: subject,
                            member: member,
                            editing: true,
                          )._push(context)
                        : null,
                  ),
                  const SizedBox(height: 26),
                ] else ...[
                  const SizedBox(height: 15),
                  const Text(
                    'SoundConnect’in son beş dakikadaki ziyaretleri saymasına ve Google Analytics ile aylık kullanım istatistikleri hazırlamamıza izin verebilirsiniz. Özel mesajlarınızın içeriği Google Analytics’e gönderilmez.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bu izin isteğe bağlıdır. Reddetseniz de SoundConnect’i kullanmaya devam edebilirsiniz.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                ],
                const Divider(height: 1),
                for (final document in AnalyticsPrivacyDocument.values) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(document.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => document.open(context),
                  ),
                  const Divider(height: 1),
                ],
                const SizedBox(height: 14),
                if (!showSaved)
                  Semantics(
                    liveRegion: true,
                    child: Text(status, style: theme.textTheme.labelMedium),
                  ),
                if (current && controller.error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: controller.busy ? null : controller.refresh,
                      child: const Text('Tekrar dene'),
                    ),
                  ),
              ],
            );
            if (showSaved) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                children: [content],
              );
            }
            final actions = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GradientOutlineButton(
                        label: 'İzin veriyorum',
                        horizontalPadding: 6,
                        maxLines: null,
                        onPressed: enabled
                            ? () => _choose(context, true)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: GradientOutlineButton(
                        label: 'İzin vermiyorum',
                        horizontalPadding: 6,
                        maxLines: null,
                        onPressed: enabled
                            ? () => _choose(context, false)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  member
                      ? 'Tercihinizi daha sonra Ayarlar’dan değiştirebilirsiniz.'
                      : 'Tercihinizi daha sonra Keşfet’teki “Gizlilik ve analitik tercihi” bağlantısından değiştirebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                const padding = EdgeInsets.fromLTRB(20, 18, 20, 12);
                if (constraints.maxHeight < 400 ||
                    MediaQuery.textScalerOf(context).scale(14) > 24) {
                  return ListView(
                    padding: padding,
                    children: [content, const SizedBox(height: 24), actions],
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView(padding: padding, children: [content]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                      child: actions,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
