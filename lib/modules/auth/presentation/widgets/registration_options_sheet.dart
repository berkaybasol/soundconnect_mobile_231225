import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';

// Weak navigator keys keep separate navigation stacks independent without
// retaining disposed navigators. The lock covers the sheet and registration.
final _registrationInProgress = Expando<bool>();

Future<void> openRegistrationOptions(BuildContext context) async {
  if (!context.mounted) return;
  final sourceRoute = ModalRoute.of(context);
  if (sourceRoute?.isCurrent != true) return;
  final navigator = Navigator.of(context);
  if (_registrationInProgress[navigator] == true) return;

  _registrationInProgress[navigator] = true;
  try {
    final continueWithEmail = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.navBlueDeep,
      barrierColor: Colors.black.withValues(alpha: .65),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: AppColors.border, width: .8),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => const _RegistrationOptionsSheet(),
    );
    // Never navigate from a disposed sheet context or a page replaced while
    // the options were open. Dismissal is not a registration choice.
    if (continueWithEmail == true &&
        context.mounted &&
        navigator.mounted &&
        sourceRoute?.isCurrent == true) {
      await navigator.pushNamed(AppRoutes.register);
    }
  } finally {
    _registrationInProgress[navigator] = false;
  }
}

class _RegistrationOptionsSheet extends StatefulWidget {
  const _RegistrationOptionsSheet();

  @override
  State<_RegistrationOptionsSheet> createState() =>
      _RegistrationOptionsSheetState();
}

class _RegistrationOptionsSheetState extends State<_RegistrationOptionsSheet> {
  bool _finished = false;

  void _finish([bool? continueWithEmail]) {
    if (!mounted || _finished || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _finished = true;
    Navigator.of(context).pop(continueWithEmail);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      key: const Key('registration-options-sheet'),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Üye ol',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: _finish,
                icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('registration-google-unavailable'),
            onPressed: null,
            style: OutlinedButton.styleFrom(
              disabledForegroundColor: AppColors.textMuted,
              backgroundColor: AppColors.inputFill,
              side: BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              minimumSize: const Size(0, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Image.asset(
                    'assets/google.png',
                    width: 21,
                    height: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Google ile devam et',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navBlueSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Yakında',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // A wrapping label keeps the normal registration action readable at
          // large accessibility text sizes, without changing shared buttons.
          Semantics(
            button: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.brandGradient),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(.8),
                child: Material(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(17.2),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('registration-email-continue'),
                    onTap: () => _finish(true),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 58.4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const BrandGradientIcon.social(
                              Icons.mail_outline_rounded,
                              size: 21,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'E-posta ile devam et',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
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
            ),
          ),
        ],
      ),
    ),
  );
}
