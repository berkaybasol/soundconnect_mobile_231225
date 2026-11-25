import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/table_report_admin_repository.dart';
import '../../domain/admin_decision_reason.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_visual_theme.dart';
import '../widgets/application_review_widgets.dart';

typedef TableReviewInput = ({TableReportDecision decision, String note});

class TableReportDecisionScreen extends StatefulWidget {
  const TableReportDecisionScreen({
    super.key,
    required this.report,
    required this.access,
    this.frame,
  });
  final TableAdminReport report;
  final ValueListenable<bool> access;
  final AdminSubpageFrame? frame;
  @override
  State<TableReportDecisionScreen> createState() =>
      _TableReportDecisionScreenState();
}

class _TableReportDecisionScreenState extends State<TableReportDecisionScreen> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  TableReportDecision _decision = TableReportDecision.dismiss;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext themedContext) async {
    if (!widget.access.value ||
        ModalRoute.of(context)?.isCurrent != true ||
        !_form.currentState!.validate()) {
      return;
    }
    final decision = _decision;
    final note = _note.text.trim();
    if (decision.removesContent) {
      final isTable = decision == TableReportDecision.removeTable;
      final accepted = await showDialog<bool>(
        context: themedContext,
        builder: (context) => ValueListenableBuilder<bool>(
          valueListenable: widget.access,
          builder: (context, allowed, _) => AlertDialog(
            title: Text(
              allowed
                  ? isTable
                        ? 'Masa yayından kaldırılsın mı?'
                        : 'Mesaj kaldırılsın mı?'
                  : 'Yetki değişti',
            ),
            content: allowed
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTable
                              ? 'Masa kapanacak. Sohbet ve oyun sona erecek, bekleyen başvurular kaldırılacak. Profil kartlarındaki masa açıklaması gizlenecek. Masa sahibi ve üyeler, bildirenin kimliği paylaşılmadan bilgilendirilecek.'
                              : 'Bu mesaj masa sohbetinden kaldırılacak. Bildirilen içerik şikâyet kaydında kalacak.',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Karar gerekçesi',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(note),
                      ],
                    ),
                  )
                : Text(TableReportAdminRepository.accessError.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              if (allowed)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    isTable
                        ? 'Masayı kaldır ve kararı kaydet'
                        : 'Mesajı kaldır ve kararı kaydet',
                  ),
                ),
            ],
          ),
        ),
      );
      if (accepted != true ||
          !mounted ||
          !widget.access.value ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
    }
    Navigator.of(
      context,
    ).pop<TableReviewInput>((decision: decision, note: note));
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.access,
    builder: (context, allowed, _) => ApplicationPageFrame(
      title: 'Şikâyeti sonuçlandır',
      backLabel: 'Şikâyet ayrıntısı',
      frame: widget.frame,
      child: allowed
          ? Builder(
              builder: (context) => Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  children: [
                    if (widget.frame != null)
                      Text(
                        'Şikâyeti sonuçlandır',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    Text(widget.report.title),
                    const SizedBox(height: 16),
                    RadioGroup<TableReportDecision>(
                      groupValue: _decision,
                      onChanged: (d) {
                        if (d != null) setState(() => _decision = d);
                      },
                      child: ApplicationSurface(
                        rows: [
                          for (final d in TableReportDecision.values.where(
                            widget.report.allows,
                          ))
                            RadioListTile<TableReportDecision>(
                              value: d,
                              title: Text(d.label),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Karar gerekçesi',
                        alignLabelWithHint: true,
                      ),
                      validator: (s) => isValidAdminDecisionReason(s ?? '')
                          ? null
                          : '5–500 karakterlik bir gerekçe yaz.',
                    ),
                    const SizedBox(height: 12),
                    AdminBrandButton(
                      label: _decision.removesContent
                          ? 'Devam et'
                          : 'Kararı kaydet',
                      icon: Icons.check,
                      onPressed: () => _submit(context),
                    ),
                  ],
                ),
              ),
            )
          : Center(child: Text(TableReportAdminRepository.accessError.message)),
    ),
  );
}
