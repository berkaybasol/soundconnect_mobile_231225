import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/simulation/local_simulation_config.dart';

typedef LocalSimulationPersonaSelected =
    FutureOr<void> Function(
      LocalSimulationPersona persona,
      String commonPassword,
    );

/// Developer-only login shortcut. The caller decides whether it is reachable;
/// [enabled] is still checked here so a disabled launcher remains inert.
class LocalSimulationPersonaLauncher extends StatelessWidget {
  const LocalSimulationPersonaLauncher({
    super.key,
    required this.enabled,
    required this.isBusy,
    required this.personas,
    required this.configuredPassword,
    required this.onSelected,
  });

  final bool enabled;
  final bool isBusy;
  final List<LocalSimulationPersona> personas;
  final String configuredPassword;
  final LocalSimulationPersonaSelected onSelected;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !enabled) return const SizedBox.shrink();
    return IconButton(
      key: const Key('local-simulation-persona-launcher'),
      tooltip: 'Yerel simülasyon kişisi',
      onPressed: isBusy || personas.isEmpty ? null : () => _open(context),
      icon: const Icon(Icons.science_outlined),
    );
  }

  Future<void> _open(BuildContext context) async {
    if (!kDebugMode || !enabled) return;
    final persona = await showModalBottomSheet<LocalSimulationPersona>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              'Müzisyen akışı gözlemcisi',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Aynı simülasyon dünyasını üç farklı başlangıçtan incele.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final item in personas)
              ListTile(
                key: Key('local-simulation-persona-${item.key}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(_iconFor(item.state)),
                title: Text(item.displayName),
                subtitle: Text('@${item.username} · ${item.description}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(sheetContext).pop(item),
              ),
          ],
        ),
      ),
    );
    if (persona == null || !context.mounted) return;

    var password = configuredPassword;
    if (password.trim().isEmpty) {
      final entered = await _requestPassword(context);
      if (entered == null || !context.mounted) return;
      password = entered;
    }
    await onSelected(persona, password);
  }

  Future<String?> _requestPassword(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => const _SimulationPasswordDialog(),
    );
  }
}

class _SimulationPasswordDialog extends StatefulWidget {
  const _SimulationPasswordDialog();

  @override
  State<_SimulationPasswordDialog> createState() =>
      _SimulationPasswordDialogState();
}

class _SimulationPasswordDialogState extends State<_SimulationPasswordDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Simülasyon şifresi'),
      content: TextField(
        key: const Key('local-simulation-password'),
        controller: _controller,
        autofocus: true,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'Ortak şifre',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Giriş yap')),
      ],
    );
  }

  void _submit() {
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _error = 'Şifre boş olamaz');
      return;
    }
    Navigator.of(context).pop(password);
  }
}

IconData _iconFor(LocalSimulationObserverState state) => switch (state) {
  LocalSimulationObserverState.complete => Icons.verified_outlined,
  LocalSimulationObserverState.incomplete => Icons.rule_folder_outlined,
  LocalSimulationObserverState.coldStart => Icons.ac_unit_rounded,
};
