import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/di/service_locator.dart';
import '../../../shared/widgets/gradient_outline_button.dart';
import '../data/content_report_repository.dart';
import '../domain/content_report.dart';

export '../domain/content_report.dart' show ContentReportKind;

class ContentReportMenu extends StatelessWidget {
  const ContentReportMenu({
    super.key,
    required this.kind,
    required this.targetId,
    required this.label,
    this.preview,
    this.ownerId,
    this.enabled = true,
    this.isCurrent,
  });

  final ContentReportKind kind;
  final String targetId, label;
  final String? preview, ownerId;
  final bool enabled;
  final bool Function()? isCurrent;

  @override
  Widget build(BuildContext context) {
    if (targetId.isEmpty ||
        !serviceLocator.isRegistered<ContentReportRepository>()) {
      return const SizedBox.shrink();
    }
    final repository = serviceLocator<ContentReportRepository>();
    return ListenableBuilder(
      listenable: repository.sessions,
      builder: (context, _) {
        final session = repository.sessions.session;
        final revision = repository.sessions.credentialRevision;
        if (!ContentReportRepository.canReport(session) ||
            ownerId == session.userId) {
          return const SizedBox.shrink();
        }
        return PopupMenuButton<String>(
          key: ValueKey((kind, targetId, revision)),
          tooltip: kind == ContentReportKind.comment
              ? 'Yorum seçenekleri'
              : 'Paylaşım seçenekleri',
          enabled: enabled,
          onSelected: (_) {
            if (!(isCurrent?.call() ?? true) ||
                !repository.current(session, revision)) {
              return;
            }
            showContentReportForm(
              context,
              kind: kind,
              targetId: targetId,
              label: label,
              preview: preview,
              expected: session,
            );
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'report', child: Text(label)),
          ],
        );
      },
    );
  }
}

Future<void> showContentReportForm(
  BuildContext context, {
  required ContentReportKind kind,
  required String targetId,
  required String label,
  required AuthSession expected,
  String? profileId,
  String? preview,
}) async {
  if (!context.mounted ||
      ModalRoute.of(context)?.isCurrent != true ||
      !serviceLocator.isRegistered<ContentReportRepository>()) {
    return;
  }
  final repository = serviceLocator<ContentReportRepository>();
  final revision = repository.sessions.credentialRevision;
  if (!repository.current(expected, revision)) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _ContentReportForm(
      repository: repository,
      expected: expected,
      revision: revision,
      kind: kind,
      targetId: targetId,
      title: label,
      preview: preview,
      profileId: profileId,
    ),
  );
}

class _ContentReportForm extends StatefulWidget {
  const _ContentReportForm({
    required this.repository,
    required this.expected,
    required this.revision,
    required this.kind,
    required this.targetId,
    required this.title,
    this.preview,
    this.profileId,
  });

  final ContentReportRepository repository;
  final AuthSession expected;
  final int revision;
  final ContentReportKind kind;
  final String targetId, title;
  final String? preview, profileId;

  @override
  State<_ContentReportForm> createState() => _ContentReportFormState();
}

class _ContentReportFormState extends State<_ContentReportForm> {
  final _description = TextEditingController();
  final _requestId = const Uuid().v4();
  ContentReportReason? _reason;
  bool _pending = false,
      _sent = false,
      _attempted = false,
      _unavailable = false;
  String? _error;

  bool get _current =>
      widget.repository.current(widget.expected, widget.revision);

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending || _sent || _unavailable || !_current) return;
    final reason = _reason;
    if (reason == null || _description.text.trim().runes.length > 500) {
      setState(
        () => _error = reason == null
            ? 'Bir bildirim nedeni seç.'
            : 'Açıklama en fazla 500 karakter olabilir.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      // Preserve the submission and its id if a committed response is lost.
      _attempted = true;
      _error = null;
    });
    final result = await widget.repository.submit(
      expected: widget.expected,
      revision: widget.revision,
      requestId: _requestId,
      kind: widget.kind,
      targetId: widget.targetId,
      profileId: widget.profileId,
      reason: reason,
      description: _description.text,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _sent = result.isSuccess;
      _unavailable = result.error?.code == '9140';
      if (!_sent) {
        _error = result.error?.code == '9143'
            ? 'Kısa sürede çok sayıda bildirim gönderdin. Bir süre sonra tekrar deneyebilirsin.'
            : 'Bildirimin gönderildiği doğrulanamadı. Tekrar deneyebilirsin.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.repository.sessions,
      builder: (context, _) {
        final current = _current;
        return PopScope(
          canPop: !_pending || !current,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          !current
                              ? 'Oturum değişti'
                              : _sent
                              ? 'Bildirimin alındı'
                              : widget.title,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        icon: const Icon(Icons.close),
                        onPressed: current && _pending
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  if (current && _unavailable)
                    const Text('Bu içerik için bildirim alınamıyor.'),
                  if (current && !_sent && !_unavailable) ...[
                    if (widget.preview?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          widget.preview!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    DropdownButtonFormField<ContentReportReason>(
                      decoration: const InputDecoration(
                        labelText: 'Bildirim nedeni',
                      ),
                      isExpanded: true,
                      items: [
                        for (final reason in ContentReportReason.values)
                          DropdownMenuItem(
                            value: reason,
                            child: Text(reason.label),
                          ),
                      ],
                      onChanged: _attempted
                          ? null
                          : (value) => setState(() {
                              _reason = value;
                              _error = null;
                            }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _description,
                      readOnly: _attempted,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama (isteğe bağlı)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error case final String error)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    const SizedBox(height: 8),
                    GradientOutlineButton(
                      label: _attempted && !_pending
                          ? 'Tekrar dene'
                          : 'Bildirimi gönder',
                      onPressed: _pending ? null : _submit,
                      loading: _pending,
                      strokeWidth: 0.9,
                      leading: const Icon(Icons.send_outlined, size: 18),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
