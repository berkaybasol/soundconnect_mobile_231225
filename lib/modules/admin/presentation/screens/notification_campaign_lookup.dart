part of 'notification_campaign_screen.dart';

class _CampaignLookupDialog extends StatefulWidget {
  const _CampaignLookupDialog({
    required this.repository,
    required this.sessions,
    this.targetKind,
  });
  final NotificationCampaignRepository repository;
  final AuthSessionManager sessions;
  final String? targetKind;
  @override
  State<_CampaignLookupDialog> createState() => _CampaignLookupDialogState();
}

class _CampaignLookupDialogState extends State<_CampaignLookupDialog> {
  final _query = TextEditingController();
  late final AuthSession _session;
  List<CampaignLookup> _items = const [];
  String? _error;
  bool _busy = false, _searched = false, _revoked = false;
  int _revision = 0;
  bool get _current =>
      mounted &&
      !_revoked &&
      identical(_session, widget.sessions.session) &&
      canManageNotificationCampaigns(widget.sessions.session);
  @override
  void initState() {
    super.initState();
    _session = widget.sessions.session;
    widget.sessions.addListener(_changed);
  }

  void _changed() {
    if (!_current && mounted) {
      setState(() {
        _revoked = true;
        _items = const [];
        _busy = false;
        _error = null;
        _query.clear();
      });
    }
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_changed);
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_current || _busy) return;
    final query = _query.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'En az 2 karakter yaz.');
      return;
    }
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _error = null;
      _items = const [];
    });
    final result = await widget.repository.search(
      query,
      targetKind: widget.targetKind,
    );
    if (!_current || revision != _revision) return;
    setState(() {
      _busy = false;
      _searched = true;
      _items = result.data ?? const [];
      _error = result.error?.message;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    title: Text(
      widget.targetKind == null ? 'Kullanıcı seç' : 'Açılacak hedefi seç',
    ),
    content: SizedBox(
      width: 460,
      child: !_current
          ? const Text('Oturumun değişti. Sayfayı yeniden aç.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('campaign-lookup-query'),
                  controller: _query,
                  maxLength: 80,
                  enabled: _current,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText:
                        widget.targetKind == null ||
                            widget.targetKind == 'PROFILE'
                        ? 'Kullanıcı adı veya ad'
                        : 'Başlık',
                    suffixIcon: IconButton(
                      tooltip: 'Ara',
                      onPressed: _busy ? null : _search,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onChanged: (_) {
                    _revision++;
                    setState(() {
                      _busy = false;
                      _items = const [];
                      _searched = false;
                      _error = null;
                    });
                  },
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            _searched
                                ? 'Eşleşen sonuç yok.'
                                : 'En az 2 karakter yazıp ara. İlk 20 sonuç gösterilir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        )
                      // The repository limits lookup responses to 20 items.
                      // Let the dialog own scrolling: a nested viewport cannot
                      // provide the intrinsic dimensions AlertDialog needs.
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in _items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: CollabGradientFrame(
                                  radius: 16,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 5,
                                          ),
                                      title: Text(item.label),
                                      subtitle: item.subtitle == null
                                          ? null
                                          : Text(item.subtitle!),
                                      trailing: const Icon(
                                        Icons.add_circle_outline_rounded,
                                      ),
                                      onTap: () {
                                        if (_current) {
                                          Navigator.of(context).pop(item);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Vazgeç'),
      ),
    ],
  );
}
