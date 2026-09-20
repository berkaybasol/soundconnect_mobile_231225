import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../marketplace/presentation/marketplace_photo.dart';
import '../../data/marketplace_report_admin_repository.dart';
import '../../domain/marketplace_report_admin.dart';

class MarketplaceReportAdminScreen extends StatefulWidget {
  const MarketplaceReportAdminScreen({
    super.key,
    required this.repository,
    required this.sessions,
  });
  final MarketplaceReportAdminRepository repository;
  final AuthSessionManager sessions;
  @override
  State<MarketplaceReportAdminScreen> createState() =>
      _MarketplaceReportAdminScreenState();
}

class _MarketplaceReportAdminScreenState
    extends State<MarketplaceReportAdminScreen> {
  late final AuthSession _entry;
  final List<MarketplaceAdminReport> _reports = [];
  String _status = 'OPEN';
  String? _error;
  bool _busy = false, _last = true, _revoked = false;
  int _page = 0, _epoch = 0;
  bool get _current =>
      !_revoked &&
      identical(_entry, widget.sessions.session) &&
      canManageMarketplaceReports(widget.sessions.session);

  @override
  void initState() {
    super.initState();
    _entry = widget.sessions.session;
    widget.sessions.addListener(_sessionChanged);
    unawaited(_load());
  }

  void _sessionChanged() {
    if (!identical(_entry, widget.sessions.session)) {
      _revoked = true;
      _epoch++;
      if (mounted) {
        setState(() {
          _reports.clear();
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _epoch++;
    widget.sessions.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!_current || _busy) return;
    final epoch = ++_epoch;
    final page = more ? _page + 1 : 0;
    setState(() {
      _busy = true;
      _error = null;
      if (!more) _reports.clear();
    });
    final result = await widget.repository.load(status: _status, page: page);
    if (!mounted || !_current || epoch != _epoch) return;
    setState(() {
      _busy = false;
      if (result.isSuccess) {
        _reports.addAll(result.data!.items);
        _page = page;
        _last = result.data!.last;
      } else {
        _error = result.error!.message;
      }
    });
  }

  Future<void> _review(MarketplaceAdminReport report) async {
    if (!_current || _busy) return;
    final decision = await showDialog<({bool remove, String note})>(
      context: context,
      builder: (_) => _ReviewDialog(sessions: widget.sessions, entry: _entry),
    );
    if (decision == null || !mounted || !_current) return;
    setState(() => _busy = true);
    final result = await widget.repository.review(
      report,
      removeListing: decision.remove,
      note: decision.note,
    );
    if (!mounted || !_current) return;
    setState(() => _busy = false);
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: Text(result.error!.message),
        ),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pazar şikâyetleri')),
    body: !_current
        ? const Center(child: Text('İnceleme yetkisi gerekli.'))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Bildirim durumu',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'OPEN',
                      child: Text('İnceleme bekliyor'),
                    ),
                    DropdownMenuItem(
                      value: 'ACTIONED',
                      child: Text('İlan kaldırıldı'),
                    ),
                    DropdownMenuItem(
                      value: 'DISMISSED',
                      child: Text('İşlem yapılmadan kapatıldı'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) {
                            _status = value;
                            unawaited(_load());
                          }
                        },
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                if (!_busy && _error == null && _reports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Bu durumda bildirim yok.')),
                  ),
                for (final report in _reports) _card(context, report),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!_busy && !_last && _reports.isNotEmpty)
                  OutlinedButton(
                    onPressed: () => _load(more: true),
                    child: const Text('Daha fazla'),
                  ),
              ],
            ),
          ),
  );

  Widget _card(BuildContext context, MarketplaceAdminReport report) {
    final listing = report.evidence;
    final money = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final reason =
        const {
          'SCAM': 'Dolandırıcılık şüphesi',
          'MISLEADING': 'Yanıltıcı ilan',
          'PROHIBITED': 'Uygun olmayan ürün',
          'SPAM': 'Spam',
          'OTHER': 'Diğer',
        }[report.reason] ??
        report.reason;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listing.displayTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '$reason · ${DateFormat('dd.MM.yyyy HH:mm').format(report.reportedAt.toLocal())}',
            ),
            if (report.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(report.description),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Bildirim anındaki ilan'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${listing.seller.displayName} · @${listing.seller.username}',
                      ),
                      Text(
                        [
                              listing.condition?.label,
                              if (listing.priceMinor != null)
                                money.format(listing.priceMinor! / 100),
                              listing.locationLabel,
                            ]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                      ),
                      if (listing.category != null)
                        Text(
                          '${listing.category!.rootName} / ${listing.category!.name}',
                        ),
                      const SizedBox(height: 8),
                      Text(listing.description),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in listing.photoIds)
                            SizedBox(
                              width: 144,
                              height: 144,
                              child: InkWell(
                                onTap: () => _openPhoto(id),
                                child: MarketplacePhoto(
                                  assetId: id,
                                  moderatorMode: true,
                                  sessions: widget.sessions,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
            if (report.resolutionNote?.isNotEmpty == true)
              Text('Karar notu: ${report.resolutionNote}'),
            if (report.status == 'OPEN')
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _busy ? null : () => _review(report),
                  child: const Text('İncele ve karar ver'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhoto(String id) async {
    if (!_current) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: widget.sessions,
        builder: (context, _) => Dialog(
          child: AspectRatio(
            aspectRatio: .8,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _current
                      ? InteractiveViewer(
                          maxScale: 5,
                          child: MarketplacePhoto(
                            assetId: id,
                            moderatorMode: true,
                            sessions: widget.sessions,
                            fit: BoxFit.contain,
                            preferOriginal: true,
                          ),
                        )
                      : const Center(child: Icon(Icons.lock_outline)),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
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

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.sessions, required this.entry});
  final AuthSessionManager sessions;
  final AuthSession entry;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _note = TextEditingController();
  bool _remove = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.sessions,
    builder: (context, _) {
      final allowed =
          identical(widget.entry, widget.sessions.session) &&
          canManageMarketplaceReports(widget.sessions.session);
      return AlertDialog(
        title: const Text('Bildirim kararı'),
        content: !allowed
            ? const Text('Oturumun değişti. İnceleme sayfasını yeniden aç.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('İlanı yayından kaldır'),
                      subtitle: const Text(
                        'Kapalıysa bildirim işlem yapılmadan kapatılır.',
                      ),
                      value: _remove,
                      onChanged: (v) => setState(() => _remove = v),
                    ),
                    TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Karar gerekçesi',
                        helperText: 'En az 5 karakter',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          if (allowed)
            FilledButton(
              onPressed: _note.text.trim().length < 5
                  ? null
                  : () => Navigator.pop(context, (
                      remove: _remove,
                      note: _note.text.trim(),
                    )),
              child: const Text('Kararı kaydet'),
            ),
        ],
      );
    },
  );
}
