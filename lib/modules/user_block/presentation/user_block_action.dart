import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/di/service_locator.dart';
import '../../../shared/widgets/gradient_outline_button.dart';
import '../../content_report/data/content_report_repository.dart';
import '../../content_report/presentation/content_report_action.dart';
import '../data/user_block_repository.dart';

Future<bool> confirmBlockUser(
  BuildContext context, {
  required String userId,
  required String username,
}) => _confirm(context, userId, username, block: true);

Future<bool> confirmUnblockUser(
  BuildContext context, {
  required String userId,
  required String username,
}) => _confirm(context, userId, username, block: false);

Future<bool> _confirm(
  BuildContext context,
  String id,
  String name, {
  required bool block,
}) async {
  final sessions = serviceLocator<AuthSessionManager>();
  final session = sessions.session;
  if (!session.isActive ||
      !session.isAuthenticated ||
      session.userId == id ||
      id.trim().isEmpty) {
    return false;
  }
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BlockDialog(
          id: id,
          name: name,
          block: block,
          sessions: sessions,
          expected: session,
          repository: serviceLocator<UserBlockRepository>(),
        ),
      ) ??
      false;
}

class _BlockDialog extends StatefulWidget {
  const _BlockDialog({
    required this.id,
    required this.name,
    required this.block,
    required this.sessions,
    required this.expected,
    required this.repository,
  });
  final String id;
  final String name;
  final bool block;
  final AuthSessionManager sessions;
  final AuthSession expected;
  final UserBlockRepository repository;
  @override
  State<_BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<_BlockDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !identical(widget.expected, widget.sessions.session)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = widget.block
        ? await widget.repository.block(widget.id)
        : await widget.repository.unblock(widget.id);
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (result.isSuccess &&
        identical(widget.sessions.session, widget.expected)) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.error?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name.trim().isEmpty ? 'Bu hesap' : widget.name.trim();
    return ListenableBuilder(
      listenable: widget.sessions,
      builder: (context, _) {
        final current = identical(widget.sessions.session, widget.expected);
        return PopScope(
          canPop: !_busy || !current,
          child: AlertDialog(
            scrollable: true,
            title: Text(
              !current
                  ? 'Oturum değişti'
                  : widget.block
                  ? '$name engellensin mi?'
                  : '$name için engel kaldırılsın mı?',
            ),
            content: Text(
              !current
                  ? 'Bu pencereyi kapatabilirsin.'
                  : _error ??
                        (widget.block
                            ? 'Birbirinizin profilini ve kişisel paylaşımlarını göremez, birbirinize mesaj gönderemezsiniz. Mevcut takipleriniz kaldırılır.'
                            : 'Daha önceki takipleriniz otomatik olarak geri gelmez.'),
            ),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (current) ...[
                    GradientOutlineButton(
                      label: widget.block ? 'Engelle' : 'Engeli kaldır',
                      onPressed: _submit,
                      loading: _busy,
                      strokeWidth: 0.9,
                      horizontalPadding: 16,
                      maxLines: null,
                    ),
                    const SizedBox(height: 4),
                  ],
                  TextButton(
                    onPressed: !_busy || !current
                        ? () => Navigator.of(context).pop(false)
                        : null,
                    child: Text(current ? 'Vazgeç' : 'Kapat'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class UserBlockProfileMenu extends StatelessWidget {
  const UserBlockProfileMenu({
    super.key,
    required this.userId,
    required this.name,
    this.reportKind,
    this.reportProfileId,
  });
  final String userId;
  final String name;
  final ContentReportKind? reportKind;
  final String? reportProfileId;
  @override
  Widget build(BuildContext context) {
    if (!serviceLocator.isRegistered<AuthSessionManager>() ||
        !serviceLocator.isRegistered<UserBlockRepository>()) {
      return const SizedBox.shrink();
    }
    final sessions = serviceLocator<AuthSessionManager>();
    return ListenableBuilder(
      listenable: sessions,
      builder: (context, _) {
        final session = sessions.session;
        if (!session.isActive ||
            !session.isAuthenticated ||
            session.userId == null ||
            session.userId == userId ||
            userId.trim().isEmpty) {
          return const SizedBox.shrink();
        }
        final reports =
            reportKind != null &&
            serviceLocator.isRegistered<ContentReportRepository>() &&
            ContentReportRepository.canReport(session);
        return PopupMenuButton<String>(
          key: ValueKey((
            reportKind,
            userId,
            reportProfileId,
            sessions.credentialRevision,
          )),
          tooltip: 'Profil seçenekleri',
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            if (!identical(sessions.session, session)) return;
            if (action == 'report' && reports) {
              unawaited(
                showContentReportForm(
                  context,
                  kind: reportKind!,
                  targetId: userId,
                  label: 'Profili bildir',
                  preview: name,
                  expected: session,
                  profileId: reportProfileId,
                ),
              );
            } else if (action == 'block') {
              unawaited(
                confirmBlockUser(context, userId: userId, username: name),
              );
            }
          },
          itemBuilder: (_) => [
            if (reports)
              const PopupMenuItem(
                value: 'report',
                child: Text('Profili bildir'),
              ),
            const PopupMenuItem(value: 'block', child: Text('Engelle')),
          ],
        );
      },
    );
  }
}

/// Discards an open profile when the same account blocks it from another route.
class BlockAwarePublicProfile extends StatefulWidget {
  const BlockAwarePublicProfile({
    super.key,
    required this.userId,
    required this.child,
  });
  final String userId;
  final Widget child;
  @override
  State<BlockAwarePublicProfile> createState() =>
      _BlockAwarePublicProfileState();
}

class _BlockAwarePublicProfileState extends State<BlockAwarePublicProfile> {
  StreamSubscription<UserBlockChange>? _changes;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    if (serviceLocator.isRegistered<UserBlockRepository>()) {
      _changes = serviceLocator<UserBlockRepository>().changes.listen((event) {
        if (event.userId == widget.userId &&
            event.status.interactionBlocked &&
            event.actorId ==
                serviceLocator<AuthSessionManager>().session.userId) {
          setState(() => _unavailable = true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(BlockAwarePublicProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _unavailable = false;
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _unavailable
      ? Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Bu profil kullanılamıyor.')),
        )
      : widget.child;
}
