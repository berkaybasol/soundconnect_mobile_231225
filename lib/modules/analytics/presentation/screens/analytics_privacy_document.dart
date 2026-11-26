import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum AnalyticsPrivacyDocument {
  notice('Analitik aydınlatma metni', 'ANALITIK_AYDINLATMA_TASLAGI.md'),
  consent('Analitik açık rıza metni', 'ANALITIK_ACIK_RIZA_TASLAGI.md'),
  general('Genel KVKK aydınlatma metni', 'KVKK_AYDINLATMA_TASLAGI.md');

  const AnalyticsPrivacyDocument(this.label, this.filename);
  final String label;
  final String filename;

  void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PrivacyDocumentScreen(document: this),
      ),
    );
  }
}

class _PrivacyDocumentScreen extends StatefulWidget {
  const _PrivacyDocumentScreen({required this.document});
  final AnalyticsPrivacyDocument document;

  @override
  State<_PrivacyDocumentScreen> createState() => _PrivacyDocumentScreenState();
}

class _PrivacyDocumentScreenState extends State<_PrivacyDocumentScreen> {
  final _generalLink = TapGestureRecognizer();
  late Future<String> _text;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text = DefaultAssetBundle.of(
      context,
    ).loadString('assets/privacy/${widget.document.filename}');
    _generalLink.onTap = () => AnalyticsPrivacyDocument.general.open(context);
  }

  @override
  void dispose() {
    _generalLink.dispose();
    super.dispose();
  }

  Widget _paragraph(String source) {
    final theme = Theme.of(context);
    if (source.startsWith('#')) {
      final title = source.startsWith('# ');
      return Semantics(
        header: true,
        child: Text(
          source.substring(title ? 2 : 3),
          style: title
              ? theme.textTheme.headlineSmall
              : theme.textTheme.titleMedium,
        ),
      );
    }
    final text = source.replaceAll(RegExp(r'^- ', multiLine: true), '• ');
    final inline = RegExp(
      r'\*\*(.+?)\*\*|\[([^\]]+)\]\(KVKK_AYDINLATMA_TASLAGI\.md\)',
    );
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in inline.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(start, match.start)));
      final bold = match.group(1);
      spans.add(
        bold != null
            ? TextSpan(
                text: bold,
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
            : TextSpan(
                text: match.group(2),
                style: const TextStyle(decoration: TextDecoration.underline),
                recognizer: _generalLink,
              ),
      );
      start = match.end;
    }
    spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(
      TextSpan(children: spans),
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik ve KVKK')),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _text,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Belge açılamadı.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final blocks = snapshot.requireData.trim().split(
              RegExp(r'\r?\n\s*\n'),
            );
            return SelectionArea(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                itemCount: blocks.length,
                itemBuilder: (_, index) =>
                    _paragraph(blocks[index].replaceAll('\r', '')),
                separatorBuilder: (_, _) => const SizedBox(height: 14),
              ),
            );
          },
        ),
      ),
    );
  }
}
