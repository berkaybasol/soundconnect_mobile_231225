import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../overthinking/domain/overthinking_repository.dart';
import 'overthinking_share_data.dart';
import 'overthinking_share_service.dart';
import 'overthinking_share_sheet.dart';

final _activeOverthinkingShares = Expando<bool>('overthinking-external-share');

/// Prepares an external story from a fresh source, then hands off only the PNG
/// the user reviewed, after revalidating that the source is still available.
Future<void> shareOverthinkingPost(
  BuildContext context, {
  required String postId,
  AuthSessionManager? sessions,
  AuthSession? expectedSession,
  OverthinkingRepository? repository,
  OverthinkingShareService? shareService,
  bool Function()? isValid,
  Listenable? validityChanges,
}) async {
  final manager = sessions ?? _registered<AuthSessionManager>();
  final captured = expectedSession ?? manager?.session;
  final id = postId.trim();
  bool valid() =>
      context.mounted &&
      manager != null &&
      captured != null &&
      identical(manager.session, captured) &&
      captured.isAuthenticated &&
      captured.isActive &&
      !captured.requiresListenerProfileChoice &&
      captured.userId?.trim().isNotEmpty == true &&
      (isValid?.call() ?? true);
  bool current() => valid() && ModalRoute.of(context)?.isCurrent == true;
  if (id.isEmpty || !current() || _activeOverthinkingShares[context] == true) {
    return;
  }

  _activeOverthinkingShares[context] = true;
  final posts = repository ?? _registered<OverthinkingRepository>();
  final exporter =
      shareService ??
      _registered<OverthinkingShareService>() ??
      PlatformOverthinkingShareService();
  Future<OverthinkingShareData?> read() async {
    if (!current() || posts == null) return null;
    final result = await posts.getDetail(postId: id);
    if (!current()) return null;
    final post = result.data;
    if (!result.isSuccess || post == null || post.id.trim() != id) return null;
    return OverthinkingShareData.fromPost(post);
  }

  try {
    final data = await read();
    if (!context.mounted || !current()) return;
    if (data == null) {
      _notice(
        context,
        'Bu yazı artık paylaşılamıyor. Profilini yenileyebilirsin.',
      );
      return;
    }
    final prepared = await exporter.prepare(context, data);
    if (!context.mounted || !current()) return;
    if (!prepared.data.matches(data)) throw StateError('Share source changed.');
    final target = await showOverthinkingShareSheet(
      context,
      prepared,
      validityChanges: Listenable.merge([manager, validityChanges]),
      isValid: valid,
    );
    if (!context.mounted || target == null || !current()) return;
    final latest = await read();
    if (!context.mounted || !current()) return;
    if (latest == null || !prepared.data.matches(latest)) {
      _notice(
        context,
        'Yazı değişmiş veya kaldırılmış. Yeniden paylaşmayı deneyebilirsin.',
      );
      return;
    }
    await exporter.share(context, prepared, target, isValid: valid);
  } catch (_) {
    if (context.mounted && current()) {
      _notice(
        context,
        'Paylaşım hazırlanamadı. Lütfen tekrar dene.',
        error: true,
      );
    }
  } finally {
    _activeOverthinkingShares[context] = false;
  }
}

T? _registered<T extends Object>() =>
    serviceLocator.isRegistered<T>() ? serviceLocator<T>() : null;

void _notice(BuildContext context, String message, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: error ? AppSnackBarTone.error : AppSnackBarTone.info,
        content: Text(message),
      ),
    );
