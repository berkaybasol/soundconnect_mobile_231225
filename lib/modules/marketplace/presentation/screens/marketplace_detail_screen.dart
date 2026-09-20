part of 'marketplace_screen.dart';

class _MarketplaceDetail extends StatefulWidget {
  const _MarketplaceDetail({
    required this.repository,
    required this.locationRepository,
    required this.listingId,
  });
  final MarketplaceRepository repository;
  final LocationRepository locationRepository;
  final String listingId;
  @override
  State<_MarketplaceDetail> createState() => _MarketplaceDetailState();
}

class _MarketplaceDetailState extends State<_MarketplaceDetail> {
  MarketplaceListing? _listing;
  String? _error;
  bool _loading = true, _busy = false, _saved = false, _confirming = false;
  int _loadEpoch = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!marketplaceCanAct(context)) return;
    if (_busy) return;
    final epoch = ++_loadEpoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.repository.getListing(widget.listingId);
    if (!mounted || !marketplaceCanAct(context) || epoch != _loadEpoch) return;
    setState(() {
      _loading = false;
      _listing = result.data;
      _saved = result.data?.saved ?? false;
      _error = result.error?.message;
    });
  }

  Future<void> _edit() async {
    if (!marketplaceCanAct(context)) return;
    if (_busy || _loading) return;
    final listing = _listing;
    if (listing == null) return;
    await Navigator.of(context).push<void>(
      marketplaceRoute(
        context,
        (_) => _MarketplaceEditor(
          repository: widget.repository,
          locationRepository: widget.locationRepository,
          listing: listing,
        ),
      ),
    );
    if (mounted && marketplaceCanAct(context)) unawaited(_load());
  }

  Future<void> _save() async {
    if (!marketplaceCanAct(context)) return;
    if (_busy || _loading) return;
    setState(() => _busy = true);
    final result = await widget.repository.setSaved(widget.listingId, !_saved);
    if (!mounted || !marketplaceCanAct(context)) return;
    setState(() {
      _busy = false;
      if (result.isSuccess) _saved = !_saved;
    });
    if (!result.isSuccess) {
      _message(context, result.error?.message ?? 'İlan kaydedilemedi.');
    }
  }

  Future<void> _transition(
    String action,
    String title,
    String explanation,
  ) async {
    if (!marketplaceCanAct(context)) return;
    final listing = _listing;
    if (listing == null || _busy || _loading) return;
    setState(() {
      _busy = true;
      _confirming = true;
    });
    final yes = await marketplaceDialog<bool>(
      context,
      (context) => AlertDialog(
        title: Text(title),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => _popMarketplaceRoute(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => _popMarketplaceRoute(context, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (!mounted || !marketplaceCanAct(context)) return;
    setState(() => _confirming = false);
    if (yes != true) {
      setState(() => _busy = false);
      return;
    }
    if (action == 'delete') {
      final result = await widget.repository.deleteDraft(
        listing.id,
        expectedVersion: listing.version,
      );
      if (!mounted || !marketplaceCanAct(context)) return;
      if (result.isSuccess) {
        _popMarketplaceRoute(context);
        return;
      }
      setState(() => _busy = false);
      _message(context, result.error?.message ?? 'Taslak silinemedi.');
    } else {
      final result = await widget.repository.transition(
        listing.id,
        action,
        expectedVersion: listing.version,
      );
      if (!mounted || !marketplaceCanAct(context)) return;
      setState(() {
        _busy = false;
        if (result.isSuccess) _listing = result.data;
      });
      if (!result.isSuccess) {
        _message(
          context,
          result.error?.message ??
              'İşlem tamamlanamadı. Güncel ilanı yenileyip tekrar dene.',
        );
      }
    }
  }

  Future<void> _report() async {
    if (!marketplaceCanAct(context)) return;
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      final sent = await marketplaceSheet<bool>(
        context,
        (_) => _MarketplaceReportForm(
          repository: widget.repository,
          listingId: widget.listingId,
        ),
      );
      if (mounted && marketplaceCanAct(context) && sent == true) {
        _message(context, 'Şikâyetin inceleme için alındı.');
      }
    } finally {
      if (mounted && marketplaceCanAct(context)) setState(() => _busy = false);
    }
  }

  void _profile(MarketplaceSeller seller) {
    if (!marketplaceCanAct(context)) return;
    final route = switch (seller.profileType) {
      'STUDIO' => AppRoutes.studioPublicProfile,
      'VENUE' => AppRoutes.venuePublicProfile,
      _ => AppRoutes.musicianPublicProfile,
    };
    Navigator.of(context).pushNamed(
      route,
      arguments: seller.profileType == 'VENUE'
          ? VenuePublicProfileArgs(venueId: seller.profileId)
          : PublicProfileArgs(profileId: seller.profileId),
    );
  }

  void _contact(MarketplaceSeller seller) {
    if (!marketplaceCanAct(context)) return;
    Navigator.of(context).pushNamed(
      AppRoutes.dmChat,
      arguments: DmChatScreenArgs(
        otherUserId: seller.userId,
        otherUsername: seller.displayName,
        otherUserProfilePicture: seller.avatarUrl,
        otherMusicianProfileId: seller.profileType == 'MUSICIAN'
            ? seller.profileId
            : null,
        currentUserId: marketplaceSessionFor(context)?.userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final listing = _listing;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'İlan detayı',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _busy || _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
          if (listing != null && !listing.isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton.filledTonal(
                tooltip: _saved ? 'Kayıttan çıkar' : 'İlanı kaydet',
                onPressed: _busy ? null : _save,
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerHigh,
                ),
                icon: Icon(
                  _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _saved ? AppColors.accentText : scheme.onSurface,
                  size: 21,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : listing == null
          ? _MarketplaceError(
              message: _error ?? 'Bu ilan artık görüntülenemiyor.',
              retry: _load,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                    children: [
                      _gallery(context, listing),
                      const SizedBox(height: 24),
                      if (listing.category != null) ...[
                        Text(
                          listing.category!.rootName.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.accentText,
                            fontSize: 10.5,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                      ],
                      Text(
                        listing.displayTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (listing.condition != null)
                            _tag(listing.condition!.label),
                          _tag(listing.status.label),
                        ],
                      ),
                      if (listing.locationLabel.isNotEmpty) ...[
                        const SizedBox(height: 13),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                listing.locationLabel,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      _pricePanel(context, listing),
                      const SizedBox(height: 16),
                      _MarketplaceDetailPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _MarketplaceDetailHeading(
                              icon: Icons.tune_rounded,
                              title: 'Ürün bilgileri',
                            ),
                            const SizedBox(height: 13),
                            if (listing.category != null)
                              _detailLine('Kategori', listing.category!.name),
                            if (listing.brand?.isNotEmpty == true)
                              _detailLine('Marka', listing.brand!),
                            if (listing.model?.isNotEmpty == true)
                              _detailLine('Model', listing.model!),
                            if (listing.deliveryMethod != null)
                              _detailLine(
                                'Teslim',
                                listing.deliveryMethod!.label,
                              ),
                            if (listing.category == null &&
                                listing.brand?.isNotEmpty != true &&
                                listing.model?.isNotEmpty != true &&
                                listing.deliveryMethod == null)
                              Text(
                                'Ürün bilgileri henüz eklenmedi.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MarketplaceDetailPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _MarketplaceDetailHeading(
                              icon: Icons.notes_rounded,
                              title: 'Açıklama',
                            ),
                            const SizedBox(height: 14),
                            SelectableText(
                              listing.description.isEmpty
                                  ? 'Açıklama henüz eklenmedi.'
                                  : listing.description,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 14,
                                height: 1.65,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MarketplaceDetailSeller(
                        seller: listing.seller,
                        onTap: () => _profile(listing.seller),
                      ),
                      const SizedBox(height: 20),
                      if (!listing.isOwner &&
                          listing.status == MarketplaceStatus.published) ...[
                        _MarketplaceDetailPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GradientOutlineButton(
                                label: 'Satıcıya yaz',
                                leading: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 19,
                                ),
                                onPressed: () => _contact(listing.seller),
                                backgroundColor: scheme.surfaceContainerLow,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Ödeme ve teslimatı satıcıyla görüşerek kararlaştırırsın. SoundConnect bu işlemleri gerçekleştirmez.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: _report,
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.onSurfaceVariant,
                            ),
                            icon: const Icon(Icons.flag_outlined, size: 16),
                            label: const Text('İlanı şikâyet et'),
                          ),
                        ),
                      ],
                      if (listing.isOwner) _ownerActions(context, listing),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _gallery(BuildContext context, MarketplaceListing listing) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      height: (width * .84).clamp(225, 430).toDouble(),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: listing.photoIds.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 29,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Fotoğraflar burada görünecek',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            )
          : PageView.builder(
              itemCount: listing.photoIds.length,
              itemBuilder: (context, index) => Stack(
                fit: StackFit.expand,
                children: [
                  MarketplacePhoto(
                    assetId: listing.photoIds[index],
                    fit: BoxFit.contain,
                    preferOriginal: true,
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library_outlined,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${index + 1} / ${listing.photoIds.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (listing.photoIds.length > 1)
                    Positioned(
                      bottom: 14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .48),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              listing.photoIds.length,
                              (dot) => Container(
                                width: dot == index ? 18 : 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: dot == index
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: .45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _pricePanel(BuildContext context, MarketplaceListing listing) {
    final scheme = Theme.of(context).colorScheme;
    return GradientOutline(
      radius: 20,
      strokeWidth: .8,
      colors: AppColors.decorativeGradient
          .map((color) => color.withValues(alpha: .38))
          .toList(),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'İLAN FİYATI',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.sell_outlined,
                  color: AppColors.accentText,
                  size: 17,
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _price(listing.priceMinor),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 32,
                  height: 1.12,
                  letterSpacing: -.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (listing.negotiable) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    color: AppColors.accentText,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Pazarlığa açık',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ownerActions(
    BuildContext context,
    MarketplaceListing listing,
  ) => _MarketplaceDetailPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MarketplaceDetailHeading(
          icon: Icons.dashboard_customize_outlined,
          title: 'İlan yönetimi',
        ),
        const SizedBox(height: 18),
        if (listing.canEdit)
          GradientOutlineButton(
            label: listing.status == MarketplaceStatus.draft
                ? 'Taslağı düzenle'
                : 'İlanı düzenle',
            leading: const Icon(Icons.edit_outlined, size: 18),
            onPressed: _busy ? null : _edit,
          ),
        if (listing.status == MarketplaceStatus.published) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _transition(
                    'sold',
                    'Satıldı olarak işaretle?',
                    'İlan pazardan kaldırılır. Bu, senin satış beyanındır.',
                  ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Satıldı olarak işaretle'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _transition(
                    'withdraw',
                    'İlan yayından kaldırılsın mı?',
                    'İlanını daha sonra düzenleyip yeniden yayınlayabilirsin.',
                  ),
            child: const Text('Yayından kaldır'),
          ),
        ],
        if (listing.status == MarketplaceStatus.draft)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => _transition(
                      'delete',
                      'Taslak silinsin mi?',
                      'Bu taslak ve eklediğin fotoğraflar kaldırılır.',
                    ),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              child: const Text('Taslağı sil'),
            ),
          ),
        if (listing.status == MarketplaceStatus.withdrawn)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Yeniden yayınlamak için ilanı düzenle ve önizle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        if (listing.status == MarketplaceStatus.sold ||
            listing.status == MarketplaceStatus.moderated)
          Text(
            listing.status == MarketplaceStatus.sold
                ? 'Bu ilan satıldı olarak işaretlendi ve pazarda görünmüyor.'
                : 'Bu ilan inceleme sonucunda yayından kaldırıldı.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
        if (_busy && !_confirming)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
      ],
    ),
  );

  Widget _detailLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MarketplaceDetailPanel extends StatelessWidget {
  const _MarketplaceDetailPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class _MarketplaceDetailHeading extends StatelessWidget {
  const _MarketplaceDetailHeading({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.accentText),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    ],
  );
}

class _MarketplaceDetailSeller extends StatelessWidget {
  const _MarketplaceDetailSeller({required this.seller, required this.onTap});
  final MarketplaceSeller seller;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = seller.displayName.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final avatarUrl = seller.avatarUrl?.trim();
    Widget fallback(BuildContext _) => ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
    );
    return _MarketplaceDetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'İLAN SAHİBİ',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 9.5,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    key: const Key('marketplace-seller-avatar'),
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(1.4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.decorativeGradient,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: avatarUrl?.isNotEmpty == true
                          ? AppCachedNetworkImage(
                              imageUrl: avatarUrl,
                              width: 50,
                              height: 50,
                              cacheWidth: 150,
                              cacheHeight: 150,
                              placeholderBuilder: fallback,
                              errorBuilder: fallback,
                            )
                          : fallback(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seller.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          seller.profileLabel,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceReportForm extends StatefulWidget {
  const _MarketplaceReportForm({
    required this.repository,
    required this.listingId,
  });
  final MarketplaceRepository repository;
  final String listingId;
  @override
  State<_MarketplaceReportForm> createState() => _MarketplaceReportFormState();
}

class _MarketplaceReportFormState extends State<_MarketplaceReportForm> {
  static const reasons = {
    'SCAM': 'Dolandırıcılık şüphesi',
    'MISLEADING': 'Yanıltıcı bilgi',
    'PROHIBITED': 'Uygun olmayan ürün',
    'SPAM': 'Spam / tekrarlanan ilan',
    'OTHER': 'Diğer',
  };
  final _description = TextEditingController();
  String? _requestId;
  ({String reason, String description})? _requestPayload;
  String _reason = 'SCAM';
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!marketplaceCanAct(context)) return;
    if (_busy) return;
    if (_reason == 'OTHER' && _description.text.trim().length < 5) {
      setState(() => _error = 'Şikâyet nedenini kısaca açıkla.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final payload = (reason: _reason, description: _description.text.trim());
    // Retry the same operation with its original key. Edited report content
    // is a different operation; reusing its key would conflict on the server.
    if (_requestPayload != payload) {
      _requestPayload = payload;
      _requestId = const Uuid().v4();
    }
    final result = await widget.repository.report(
      widget.listingId,
      reason: payload.reason,
      description: payload.description,
      clientRequestId: _requestId!,
    );
    if (!mounted || !marketplaceCanAct(context)) return;
    if (result.isSuccess) {
      _popMarketplaceRoute(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.error?.message ?? 'Şikâyet gönderilemedi.';
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'İlanı şikâyet et',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İncelememizi istediğin konuyu seç.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 20),
          for (final reason in reasons.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _reason == reason.key
                        ? AppColors.accentText.withValues(alpha: .6)
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: Text(
                    reason.value,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  leading: Icon(
                    _reason == reason.key
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: _reason == reason.key
                        ? AppColors.accentText
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onTap: _busy
                      ? null
                      : () => setState(() => _reason = reason.key),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: _decoration(
              'Açıklama${_reason == 'OTHER' ? '' : ' (isteğe bağlı)'}',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          GradientOutlineButton(
            label: 'Şikâyeti gönder',
            onPressed: _busy ? null : _send,
            loading: _busy,
          ),
        ],
      ),
    ),
  );
}
