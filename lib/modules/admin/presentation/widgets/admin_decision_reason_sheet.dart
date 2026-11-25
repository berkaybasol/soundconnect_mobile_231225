import 'package:flutter/material.dart';

import '../../domain/admin_decision_reason.dart';
import 'application_review_widgets.dart';
import 'admin_visual_theme.dart';

class AdminDecisionReasonSheet extends StatefulWidget {
  const AdminDecisionReasonSheet({
    super.key,
    required this.heading,
    required this.title,
    required this.impact,
    this.submitLabel = 'Kararı kaydet',
    this.helper = '5–500 karakter',
    this.destructive = false,
    this.checkBeforeSubmit,
  });
  final String heading;
  final String impact;
  final String submitLabel;
  final String helper;
  final bool destructive;
  final String title;
  final Future<String?> Function()? checkBeforeSubmit;

  @override
  State<AdminDecisionReasonSheet> createState() =>
      _AdminDecisionReasonSheetState();
}

class _AdminDecisionReasonSheetState extends State<AdminDecisionReasonSheet> {
  final _form = GlobalKey<FormState>();
  String _note = '';
  bool _closed = false;
  bool _checking = false;
  String? _submitError;

  void _close(String? value) {
    if (_closed || ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.of(context).pop(value);
  }

  Future<void> _submit() async {
    if (_closed || _checking || !_form.currentState!.validate()) return;
    final note = _note.trim();
    final check = widget.checkBeforeSubmit;
    if (check != null) {
      setState(() {
        _checking = true;
        _submitError = null;
      });
      final error = await check();
      if (!mounted || _closed) return;
      setState(() {
        _checking = false;
        _submitError = error;
      });
      if (error != null) return;
    }
    _close(note);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.heading,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(widget.impact),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: _checking,
                minLines: 2,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Karar gerekçesi',
                  helperText: widget.helper,
                  counterText: '',
                ),
                onChanged: (value) => _note = value,
                validator: (value) => isValidAdminDecisionReason(value ?? '')
                    ? null
                    : '5–500 karakterlik bir gerekçe yaz.',
              ),
              const SizedBox(height: 16),
              if (_submitError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _submitError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ApplicationReviewButtons(
                secondary: TextButton(
                  onPressed: () => _close(null),
                  child: const Text('Vazgeç'),
                ),
                primary: widget.destructive
                    ? FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                        ),
                        onPressed: _checking ? null : _submit,
                        child: Text(widget.submitLabel),
                      )
                    : AdminBrandButton(
                        label: widget.submitLabel,
                        icon: Icons.check,
                        onPressed: _checking ? null : _submit,
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
