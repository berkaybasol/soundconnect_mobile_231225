import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../data/table_group_report_repository.dart';
import '../../domain/table_group_report.dart';

Future<void> showTableGroupReportSheet(
  BuildContext context, {
  required TableGroupReportRepository repository,
  required ApiRequestContext actor,
  required String tableId,
  required TableGroupReportKind kind,
  required String evidenceLabel,
  required String evidenceText,
  required String evidenceContext,
  String? messageId,
  String? senderUsername,
  Future<Result<void>> Function()? blockSender,
  Widget Function(BuildContext, Widget)? wrapContent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) {
      final content = _ReportSheet(
        repository: repository,
        actor: actor,
        tableId: tableId,
        kind: kind,
        evidenceLabel: evidenceLabel,
        evidenceText: evidenceText,
        evidenceContext: evidenceContext,
        messageId: messageId,
        senderUsername: senderUsername,
        blockSender: blockSender,
      );
      return wrapContent?.call(context, content) ?? content;
    },
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.repository,
    required this.actor,
    required this.tableId,
    required this.kind,
    required this.evidenceLabel,
    required this.evidenceText,
    required this.evidenceContext,
    this.messageId,
    this.senderUsername,
    this.blockSender,
  });
  final TableGroupReportRepository repository;
  final ApiRequestContext actor;
  final String tableId;
  final TableGroupReportKind kind;
  final String evidenceLabel;
  final String evidenceText;
  final String evidenceContext;
  final String? messageId;
  final String? senderUsername;
  final Future<Result<void>> Function()? blockSender;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _text = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _requestId = const Uuid().v4();
  TableGroupReportReason? _reason;
  bool _sending = false;
  bool _submitted = false;
  bool _unavailable = false;
  bool _received = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending ||
        _received ||
        _unavailable ||
        !widget.repository.isCurrent(widget.actor)) {
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_reason == null) {
      setState(() => _error = 'Bir bildirim nedeni seç.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _submitted = true;
      _error = null;
    });
    final result = await widget.repository.report(
      actor: widget.actor,
      tableId: widget.tableId,
      requestId: _requestId,
      kind: widget.kind,
      reason: _reason!,
      description: _text.text,
      messageId: widget.messageId,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _received = result.isSuccess;
      final error = result.error;
      if (error != null) {
        // A lost response can follow a committed report. Keep that request
        // unchanged for retry. The server may reject editable input before commit.
        if (error.code == '4000' || error.code == '400') _submitted = false;
        _unavailable = const {'9105', '9135', '9134'}.contains(error.code);
        _error = switch (error.code) {
          '9105' || '9135' => 'Bu kayıt için bildirim artık gönderilemiyor.',
          '9134' => 'Bu bildirim daha önce farklı bilgilerle gönderilmiş.',
          _ => error.message,
        };
      }
    });
  }

  Future<void> _blockSender() async {
    final block = widget.blockSender;
    if (_sending ||
        !_received ||
        block == null ||
        !widget.repository.isCurrent(widget.actor)) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await block();
    if (!mounted) return;
    if (result.isSuccess && widget.repository.isCurrent(widget.actor)) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _sending = false;
      _error = result.error?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final incident = widget.kind == TableGroupReportKind.incident;
    final title = switch (widget.kind) {
      TableGroupReportKind.listing => 'Masayı bildir',
      TableGroupReportKind.message => 'Mesajı bildir',
      TableGroupReportKind.incident => 'Bir olay bildir',
    };
    return ListenableBuilder(
      listenable: widget.repository.sessions,
      builder: (context, _) {
        final current = widget.repository.isCurrent(widget.actor);
        return PopScope(
          canPop: !_sending || !current,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                18 + MediaQuery.viewInsetsOf(context).bottom,
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
                              : _received
                              ? 'Bildirimin alındı'
                              : title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        icon: const Icon(Icons.close),
                        onPressed: _sending && current
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  if (!current)
                    Text(TableGroupReportRepository.sessionChanged.message)
                  else if (_received) ...[
                    const SizedBox(height: 12),
                    const Icon(Icons.check_circle_outline, size: 38),
                    const SizedBox(height: 12),
                    Text(switch (widget.kind) {
                      TableGroupReportKind.message =>
                        'Yönetici bildirdiğin mesajı inceleyecek.',
                      TableGroupReportKind.listing =>
                        'Yönetici bildirdiğin ilanı inceleyecek.',
                      TableGroupReportKind.incident =>
                        'Yönetici anlattığın olayı inceleyecek.',
                    }, textAlign: TextAlign.center),
                    if (widget.kind == TableGroupReportKind.message &&
                        widget.blockSender != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.senderUsername == null
                            ? 'Mesajı yazan kişiyi engellemek ister misin?'
                            : '@${widget.senderUsername} kullanıcısını engellemek ister misin?',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: _sending ? null : _blockSender,
                        child: const Text('Engelle'),
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(color: colors.error),
                          textAlign: TextAlign.center,
                        ),
                    ],
                    const SizedBox(height: 18),
                    GradientOutlineButton(
                      label: 'Tamam',
                      strokeWidth: 0.9,
                      onPressed: _sending ? null : () => Navigator.pop(context),
                    ),
                  ] else
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              border: Border(
                                left: BorderSide(
                                  color: colors.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.evidenceLabel,
                                  style: theme.textTheme.labelLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(widget.evidenceText),
                                if (widget.evidenceContext.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.evidenceContext,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bildirim nedeni',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          _reasonOptions(colors),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _text,
                            readOnly: _submitted,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 500,
                            decoration: InputDecoration(
                              labelText: incident
                                  ? 'Ne yaşandı? (zorunlu)'
                                  : 'Açıklama (isteğe bağlı)',
                              hintText: incident
                                  ? 'Olayı kendi sözlerinle anlat.'
                                  : null,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final description = (value ?? '').trim();
                              if (incident && description.isEmpty) {
                                return 'Yaşadığın olayı anlat.';
                              }
                              if (description.runes.length > 500) {
                                return 'En fazla 500 karakter yazabilirsin.';
                              }
                              return null;
                            },
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: colors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(switch (widget.kind) {
                                  TableGroupReportKind.message =>
                                    'Sohbetten yalnızca bu mesaj incelemeye eklenir. Kimliğin masa üyeleriyle paylaşılmaz.',
                                  TableGroupReportKind.listing =>
                                    'İlan ve açıklaman yöneticiye gider. Kimliğin masa sahibiyle paylaşılmaz.',
                                  TableGroupReportKind.incident =>
                                    'Masa bilgisi ve anlatımın yöneticiye gider. Kimliğin masa üyeleriyle paylaşılmaz.',
                                }, style: theme.textTheme.bodySmall),
                              ),
                            ],
                          ),
                          if (_error case final String error)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  error,
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          GradientOutlineButton(
                            onPressed: _sending || _unavailable ? null : _send,
                            leading: const Icon(Icons.send_outlined, size: 18),
                            loading: _sending,
                            strokeWidth: 0.9,
                            horizontalPadding: 16,
                            maxLines: null,
                            label: _unavailable
                                ? 'Gönderilemiyor'
                                : _submitted && !_sending
                                ? 'Tekrar dene'
                                : 'Bildirimi gönder',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _reasonOptions(ColorScheme colors) => LayoutBuilder(
    builder: (context, constraints) {
      final singleColumn =
          MediaQuery.textScalerOf(context).scale(14) > 20 ||
          constraints.maxWidth < 260;
      final width = singleColumn
          ? constraints.maxWidth
          : (constraints.maxWidth - 8) / 2;
      return RadioGroup<TableGroupReportReason>(
        groupValue: _reason,
        onChanged: (reason) {
          if (_submitted) return;
          setState(() {
            _reason = reason;
            _error = null;
          });
        },
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final reason in widget.kind.reasons)
              SizedBox(
                width: width,
                child: GradientOutline(
                  strokeWidth: 0.9,
                  radius: 10,
                  colors: _submitted
                      ? [colors.outlineVariant, colors.outlineVariant]
                      : null,
                  child: Material(
                    color: reason == _reason
                        ? Color.alphaBlend(
                            colors.primary.withValues(alpha: 0.10),
                            colors.surfaceContainerHighest,
                          )
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    child: RadioListTile<TableGroupReportReason>(
                      value: reason,
                      enabled: !_submitted,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      title: Text(reason.label),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
