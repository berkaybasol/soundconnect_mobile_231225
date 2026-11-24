import 'package:flutter/material.dart';

import '../../domain/pending_application.dart';
import 'admin_panel_frame.dart';
import 'admin_visual_theme.dart';

class ApplicationPageFrame extends StatelessWidget {
  const ApplicationPageFrame({
    super.key,
    required this.title,
    required this.backLabel,
    required this.frame,
    required this.child,
    this.onRefresh,
    this.refreshTooltip = 'Listeyi yenile',
  });
  final String title;
  final String backLabel;
  final AdminSubpageFrame? frame;
  final Widget child;
  final VoidCallback? onRefresh;
  final String refreshTooltip;

  @override
  Widget build(BuildContext context) {
    final refresh = onRefresh == null
        ? null
        : IconButton(
            tooltip: refreshTooltip,
            icon: const Icon(Icons.refresh, size: 21),
            onPressed: onRefresh,
          );
    final panel = frame;
    if (panel == null) {
      return AdminThemeScope(
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [if (refresh != null) refresh],
          ),
          body: SafeArea(top: false, child: child),
        ),
      );
    }
    return panel(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: Text(backLabel),
                    ),
                  ),
                ),
                if (refresh != null) refresh,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class ApplicationSurface extends StatelessWidget {
  const ApplicationSurface({super.key, required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    elevation: 0,
    child: Column(
      children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) const Divider(height: 1, thickness: 1),
          row,
        ],
      ],
    ),
  );
}

class ApplicationReviewHeader extends StatelessWidget {
  const ApplicationReviewHeader({super.key, required this.item});
  final PendingApplication item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = switch (item.status) {
      ApplicationReviewStatus.pending =>
        dark ? const Color(0xffffd29b) : const Color(0xff755116),
      ApplicationReviewStatus.approved =>
        dark ? const Color(0xffb1e5d4) : const Color(0xff276147),
      ApplicationReviewStatus.rejected =>
        dark ? const Color(0xffffc4be) : const Color(0xff8a3440),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            color: color.withValues(alpha: .12),
            shape: StadiumBorder(
              side: BorderSide(color: color.withValues(alpha: .28)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.status.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            item.businessName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.9,
            ),
          ),
        ),
        if (item.location.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.location,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ApplicationInfoLine extends StatelessWidget {
  const ApplicationInfoLine(this.icon, this.label, this.value, {super.key});
  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value?.trim().isNotEmpty == true ? value! : 'Belirtilmemiş',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ApplicationReviewButtons extends StatelessWidget {
  const ApplicationReviewButtons({
    super.key,
    required this.secondary,
    required this.primary,
  });
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    final emphasis = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: primary,
    );
    if (MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(16) > 20) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [secondary, const SizedBox(height: 8), emphasis],
      );
    }
    return Row(
      children: [
        Expanded(child: secondary),
        const SizedBox(width: 10),
        Expanded(child: emphasis),
      ],
    );
  }
}

class ApplicationDecisionSheet extends StatefulWidget {
  const ApplicationDecisionSheet({
    super.key,
    required this.item,
    required this.kind,
    required this.approve,
    required this.initialReason,
  });
  final PendingApplication item;
  final ApplicationKind kind;
  final bool approve;
  final String initialReason;

  @override
  State<ApplicationDecisionSheet> createState() =>
      _ApplicationDecisionSheetState();
}

class _ApplicationDecisionSheetState extends State<ApplicationDecisionSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _reason = TextEditingController(
    text: widget.initialReason,
  );
  bool _closed = false;

  void _close(String? answer) {
    if (_closed || ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.pop(context, answer);
  }

  void _submit() {
    if (widget.approve || _form.currentState!.validate()) {
      _close(widget.approve ? '' : _reason.text.trim());
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approve = widget.approve;
    final label = approve ? 'Başvuruyu onayla' : 'Başvuruyu reddet';
    final icon = approve ? Icons.check : Icons.close;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    label,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.item.businessName,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                if (approve)
                  Text(
                    'Onayladığında başvuru sahibi ${widget.kind.label.toLowerCase()} profilini kullanmaya başlayabilir.',
                  )
                else ...[
                  TextFormField(
                    controller: _reason,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: maxApplicationRejectionLength,
                    decoration: const InputDecoration(
                      labelText: 'Ret gerekçesi',
                      hintText: 'Başvuruyu neden reddediyorsun?',
                    ),
                    validator: (value) =>
                        applicationRejectionError(value ?? ''),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Başvuru sahibi bu açıklamayı görecek.'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                ApplicationReviewButtons(
                  secondary: TextButton(
                    onPressed: () => _close(null),
                    child: const Text('Vazgeç'),
                  ),
                  primary: AdminBrandButton(
                    label: label,
                    icon: icon,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
