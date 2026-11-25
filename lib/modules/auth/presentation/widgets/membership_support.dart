import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/widgets/app_snack_bar.dart';

const membershipSupportEmail = 'destek@soundconnect.com.tr';

Uri membershipSupportWhatsApp(String message) =>
    Uri.https('wa.me', '/905378581093', {'text': message});

Future<void> openMembershipSupport(
  BuildContext context,
  Uri uri,
  String failureMessage,
) async {
  if (ModalRoute.of(context)?.isCurrent == false) return;
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // A missing handler and a failed platform launch use the same recovery.
  }
  if (!opened &&
      context.mounted &&
      ModalRoute.of(context)?.isCurrent != false) {
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: AppSnackBarTone.error,
        content: Text(failureMessage),
      ),
    );
  }
}
