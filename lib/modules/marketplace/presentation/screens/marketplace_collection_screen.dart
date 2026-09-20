part of 'marketplace_screen.dart';

class _MarketplaceCollectionScreen extends StatefulWidget {
  const _MarketplaceCollectionScreen({
    required this.repository,
    required this.locationRepository,
    required this.collection,
  });
  final MarketplaceRepository repository;
  final LocationRepository locationRepository;
  final MarketplaceCollection collection;
  @override
  State<_MarketplaceCollectionScreen> createState() =>
      _MarketplaceCollectionScreenState();
}

class _MarketplaceCollectionScreenState
    extends State<_MarketplaceCollectionScreen> {
  late final _browse = MarketplaceBrowseController(
    widget.repository,
    collection: widget.collection,
    canAct: () => marketplaceCanAct(context),
  );
  bool get _mine => widget.collection == MarketplaceCollection.mine;
  @override
  void initState() {
    super.initState();
    unawaited(_browse.refresh());
  }

  @override
  void dispose() {
    _browse.dispose();
    super.dispose();
  }

  Future<void> _open(String id) async {
    if (!marketplaceCanAct(context)) return;
    await Navigator.of(context).push<void>(
      marketplaceRoute(
        context,
        (_) => _MarketplaceDetail(
          repository: widget.repository,
          locationRepository: widget.locationRepository,
          listingId: id,
        ),
      ),
    );
    if (mounted && marketplaceCanAct(context)) unawaited(_browse.refresh());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: Text(
        _mine ? 'İlanlarım' : 'Kaydettiklerim',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    body: AnimatedBuilder(
      animation: _browse,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _browse.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                child: _MarketplaceCollectionHeader(mine: _mine),
              ),
            ),
            if (_mine)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MarketplaceCollectionFilter(
                          label: 'Tümü',
                          selected: _browse.status == null,
                          onTap: () {
                            _browse.status = null;
                            unawaited(_browse.refresh());
                          },
                        ),
                        for (final status in MarketplaceStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _MarketplaceCollectionFilter(
                              label: status.label,
                              selected: _browse.status == status,
                              onTap: () {
                                _browse.status = status;
                                unawaited(_browse.refresh());
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _mine
                            ? (_browse.status?.label ?? 'Tüm ilanların')
                            : 'Kaydedilen ilanlar',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!_browse.loading)
                      Text(
                        '${_browse.totalElements} ilan',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ..._listingSlivers(
              context,
              _browse,
              onOpen: _open,
              empty: _mine
                  ? 'Bu bölümde henüz ilanın yok.'
                  : 'Kaydettiğin yayındaki ilanlar burada görünür.',
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    ),
  );
}

class _MarketplaceCollectionHeader extends StatelessWidget {
  const _MarketplaceCollectionHeader({required this.mine});
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentText.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accentText.withValues(alpha: .2),
                  ),
                ),
                child: Icon(
                  mine
                      ? Icons.inventory_2_outlined
                      : Icons.bookmark_border_rounded,
                  size: 19,
                  color: AppColors.accentText,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'EKİPMAN PAZARI',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 9.5,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            mine ? 'İlanlarını yönet' : 'Aklındaki ekipmanlar',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 23,
              letterSpacing: -.6,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            mine
                ? 'Taslaklarını tamamla, yayındaki ilanlarını düzenle.'
                : 'Kaydettiğin yayındaki ilanları buradan takip et.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceCollectionFilter extends StatelessWidget {
  const _MarketplaceCollectionFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: AppColors.decorativeGradient)
              : null,
          color: selected ? null : scheme.outlineVariant,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Material(
          color: selected
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
