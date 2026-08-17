import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/di/service_locator.dart';
import '../domain/dm_user_profile_resolver.dart';
import '../domain/entities/dm_profile_target.dart';
import 'screens/dm_chat_screen.dart';

const String _defaultDmContactName = 'SoundConnect kullanıcısı';

Future<void> openBandRepresentativeConversation(
  BuildContext context, {
  required String bandName,
  required String contactUserId,
  required String contactUsername,
  DmUserProfileResolver? profileResolver,
}) async {
  final normalizedUserId = contactUserId.trim();
  if (normalizedUserId.isEmpty) return;

  final normalizedUsername = _normalizeUsername(contactUsername);
  final confirmed = await _confirmBandConversation(
    context,
    bandName: bandName,
    contactUsername: normalizedUsername,
  );
  if (!context.mounted || !confirmed) return;

  final musicianTarget = await _resolveMusicianTarget(
    contactUserId: normalizedUserId,
    contactUsername: normalizedUsername,
    profileResolver: profileResolver,
  );
  if (!context.mounted) return;

  Navigator.of(context).pushNamed(
    AppRoutes.dmChat,
    arguments: DmChatScreenArgs(
      otherUserId: normalizedUserId,
      otherUsername: normalizedUsername.isEmpty
          ? _defaultDmContactName
          : normalizedUsername,
      otherUserProfilePicture: _nonBlank(musicianTarget?.imageUrl),
      otherMusicianProfileId: _nonBlank(musicianTarget?.id),
    ),
  );
}

Future<bool> _confirmBandConversation(
  BuildContext context, {
  required String bandName,
  required String contactUsername,
}) async {
  final normalizedBandName = bandName.trim();
  final contactLead = normalizedBandName.isEmpty
      ? 'Bu grubun'
      : '$normalizedBandName grubunun';
  final contactSentence = contactUsername.isEmpty
      ? '$contactLead mesajlarını grup yetkilisi yanıtlıyor.'
      : '$contactLead mesajlarını @$contactUsername yanıtlıyor.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Grup yetkilisiyle mesajlaş'),
      content: Text('$contactSentence Sohbete geçmek ister misin?'),
      actions: [
        TextButton(
          key: const ValueKey<String>('band-representative-dm-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey<String>('band-representative-dm-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sohbete git'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<DmProfileTarget?> _resolveMusicianTarget({
  required String contactUserId,
  required String contactUsername,
  required DmUserProfileResolver? profileResolver,
}) async {
  try {
    final targets =
        await (profileResolver ?? serviceLocator<DmUserProfileResolver>())
            .resolveByUserId(
              userId: contactUserId,
              usernameHint: contactUsername.isEmpty ? null : contactUsername,
            );
    for (final target in targets) {
      if (target.type == DmProfileTargetType.musician &&
          target.id.trim().isNotEmpty) {
        return target;
      }
    }
  } catch (_) {
    // Messaging still works as a user-pair DM when profile enrichment fails.
  }
  return null;
}

String _normalizeUsername(String value) =>
    value.trim().replaceFirst(RegExp(r'^@+'), '');

String? _nonBlank(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
