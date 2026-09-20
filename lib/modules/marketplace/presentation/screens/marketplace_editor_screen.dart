part of 'marketplace_screen.dart';

class _MarketplaceEditor extends StatefulWidget {
  const _MarketplaceEditor({
    required this.repository,
    required this.locationRepository,
    this.listing,
  });
  final MarketplaceRepository repository;
  final LocationRepository locationRepository;
  final MarketplaceListing? listing;
  @override
  State<_MarketplaceEditor> createState() => _MarketplaceEditorState();
}

class _MarketplaceEditorState extends State<_MarketplaceEditor> {
  final _title = TextEditingController(),
      _description = TextEditingController(),
      _brand = TextEditingController(),
      _model = TextEditingController(),
      _price = TextEditingController();
  final _createRequestId = const Uuid().v4();
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  MarketplaceListing? _draft;
  List<MarketplaceCategory> _categories = const [];
  List<City> _cities = const [];
  List<District> _districts = const [];
  List<String> _photos = [];
  Set<String> _serverPhotoIds = {};
  String? _categoryId, _cityId, _districtId;
  MarketplaceCondition? _condition;
  MarketplaceDelivery? _delivery;
  bool _negotiable = false,
      _busy = false,
      _previewOpen = false,
      _dirty = false,
      _allowPop = false,
      _catalogLoading = true,
      _districtLoading = false,
      _validatePublication = false;
  String? _catalogError, _districtError, _saveError, _progressLabel;
  double? _progress;
  int _districtEpoch = 0;
  DraftMediaCleanupCoordinator? _cleanup;
  ProfileUploadCancellation? _uploadCancellation;
  late final _uploads = serviceLocator<ProfileMediaUploadRepository>();
  @override
  void initState() {
    super.initState();
    if (widget.listing != null) _bind(widget.listing!);
    unawaited(_loadCatalogs());
    if (_cityId != null) unawaited(_loadDistricts(_cityId!));
  }

  void _bind(MarketplaceListing listing) {
    _draft = listing;
    _title.text = listing.title;
    _description.text = listing.description;
    _brand.text = listing.brand ?? '';
    _model.text = listing.model ?? '';
    _price.text = marketplacePriceInput(listing.priceMinor);
    _categoryId = listing.category?.id;
    _cityId = listing.city?.id;
    _districtId = listing.district?.id;
    _condition = listing.condition;
    _delivery = listing.deliveryMethod;
    _negotiable = listing.negotiable;
    _photos = List.of(listing.photoIds);
    _serverPhotoIds = listing.photoIds.toSet();
    _dirty = false;
    _cleanup ??= DraftMediaCleanupCoordinator(
      repository: _uploads,
      ownerType: 'MARKETPLACE',
      ownerId: listing.id,
    );
  }

  Future<void> _loadCatalogs() async {
    if (!marketplaceCanAct(context)) return;
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    final values = await Future.wait([
      widget.repository.getCategories(),
      widget.locationRepository.getCities(),
    ]);
    if (!mounted || !marketplaceCanAct(context)) return;
    setState(() {
      _catalogLoading = false;
      if (values[0].isSuccess && values[1].isSuccess) {
        _categories = values[0].data! as List<MarketplaceCategory>;
        _cities = values[1].data! as List<City>;
      } else {
        _catalogError =
            values[0].error?.message ??
            values[1].error?.message ??
            'Seçenekler yüklenemedi.';
      }
    });
  }

  Future<void> _loadDistricts(String cityId) async {
    if (!marketplaceCanAct(context)) return;
    final epoch = ++_districtEpoch;
    setState(() {
      _districtLoading = true;
      _districtError = null;
      _districts = const [];
    });
    final result = await widget.locationRepository.getDistricts(cityId);
    if (!mounted ||
        !marketplaceCanAct(context) ||
        epoch != _districtEpoch ||
        cityId != _cityId) {
      return;
    }
    setState(() {
      _districtLoading = false;
      _districts = result.data ?? const [];
      _districtError = result.error?.message;
    });
  }

  @override
  void dispose() {
    _uploadCancellation?.cancel();
    for (final controller in [_title, _description, _brand, _model, _price]) {
      controller.dispose();
    }
    if (_cleanup != null) unawaited(_cleanup!.close());
    super.dispose();
  }

  void _changed([String? _]) {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _exit() {
    setState(() {
      _allowPop = true;
      _dirty = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && marketplaceCanAct(context)) _popMarketplaceRoute(context);
    });
  }

  Future<void> _leave() async {
    if (!marketplaceCanAct(context)) return;
    if (_busy) return;
    if (!_dirty) {
      _exit();
      return;
    }
    final leave = await marketplaceDialog<bool>(
      context,
      (context) => AlertDialog(
        title: const Text('Kaydedilmeyen değişiklikler bırakılsın mı?'),
        content: const Text(
          'Kaydedilmemiş değişikliklerin bırakılır. Son kaydettiğin ilan veya taslak korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => _popMarketplaceRoute(context, false),
            child: const Text('Düzenlemeye devam et'),
          ),
          TextButton(
            onPressed: () => _popMarketplaceRoute(context, true),
            child: const Text('Değişiklikleri bırak'),
          ),
        ],
      ),
    );
    if (mounted && marketplaceCanAct(context) && leave == true) _exit();
  }

  Future<bool> _ensureDraft() async {
    if (!marketplaceCanAct(context)) return false;
    if (_draft != null) return true;
    final result = await widget.repository.createDraft(_createRequestId);
    if (!mounted || !marketplaceCanAct(context)) return false;
    if (!result.isSuccess || result.data == null) {
      setState(
        () => _saveError = result.error?.message ?? 'Taslak oluşturulamadı.',
      );
      return false;
    }
    _draft = result.data;
    _cleanup = DraftMediaCleanupCoordinator(
      repository: _uploads,
      ownerType: 'MARKETPLACE',
      ownerId: _draft!.id,
    );
    return true;
  }

  Future<void> _addPhotos() async {
    if (!marketplaceCanAct(context)) return;
    if (_busy || _photos.length >= 8) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 88,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (!mounted || !marketplaceCanAct(context) || picked.isEmpty) return;
      final remaining = 8 - _photos.length;
      if (picked.length > remaining) {
        _message(
          context,
          'En fazla 8 fotoğraf ekleyebilirsin. İlk $remaining fotoğraf alınacak.',
        );
      }
      if (!await _ensureDraft() || !mounted || !marketplaceCanAct(context)) {
        return;
      }
      final selected = picked.take(remaining).toList();
      for (var index = 0; index < selected.length; index++) {
        final file = selected[index];
        final size = await file.length();
        if (!mounted || !marketplaceCanAct(context)) return;
        if (size <= 0 || size > 10 * 1024 * 1024) {
          _message(context, 'Her fotoğraf 10 MB veya daha küçük olmalı.');
          continue;
        }
        final suffix = file.name.split('.').last.toLowerCase();
        final mime = switch (suffix) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => null,
        };
        if (mime == null) {
          _message(context, 'JPG, PNG veya WebP fotoğraf seç.');
          continue;
        }
        setState(() {
          _progressLabel =
              'Fotoğraf yükleniyor (${index + 1}/${selected.length})';
          _progress = 0;
        });
        final cancellation = ProfileUploadCancellation();
        _uploadCancellation = cancellation;
        final result = await _uploads.uploadAsset(
          source: ProfileUploadSource(sizeBytes: size, openRead: file.openRead),
          ownerType: 'MARKETPLACE',
          ownerId: _draft!.id,
          mediaKind: 'IMAGE',
          mimeType: mime,
          originalFileName: file.name,
          visibility: 'PRIVATE',
          contentAudience: 'BACKSTAGE',
          attachmentIntent: const ProfileUploadAttachmentIntent.draft(),
          cancellation: cancellation,
          onProgress: (sent, total) {
            if (mounted && marketplaceCanAct(context)) {
              setState(() => _progress = total > 0 ? sent / total : null);
            }
          },
          onStageChanged: (stage) {
            if (mounted &&
                marketplaceCanAct(context) &&
                stage == ProfileUploadStage.verifying) {
              setState(() {
                _progressLabel = 'Fotoğraf hazırlanıyor…';
                _progress = null;
              });
            }
          },
        );
        _uploadCancellation = null;
        final media = result.data;
        if (!mounted || !marketplaceCanAct(context)) {
          if (media != null) _uploads.releaseDraftCleanupLeases([media.uuid]);
          return;
        }
        if (media != null) {
          final cleanup = _cleanup!;
          final tracked = await cleanup.trackUploaded(media.uuid);
          if (!mounted || !marketplaceCanAct(context)) {
            await cleanup.discard(media.uuid);
            return;
          }
          if (tracked.isSuccess) {
            setState(() {
              _photos.add(media.uuid);
              _dirty = true;
            });
          } else {
            _message(context, tracked.error?.message ?? 'Fotoğraf eklenemedi.');
          }
        } else if (mounted && marketplaceCanAct(context)) {
          _message(context, result.error?.message ?? 'Fotoğraf yüklenemedi.');
        }
        if (!mounted || !marketplaceCanAct(context)) return;
      }
    } catch (_) {
      if (mounted && marketplaceCanAct(context)) {
        _message(context, 'Fotoğraf seçilemedi veya yüklenemedi. Tekrar dene.');
      }
    } finally {
      if (mounted && marketplaceCanAct(context)) {
        setState(() {
          _busy = false;
          _progressLabel = null;
          _progress = null;
        });
      }
    }
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return _validatePublication ? 'Fiyat gir.' : null;
    final minor = parseMarketplacePriceMinor(text);
    if (minor == null || minor <= 0 || minor > 100000000000) {
      return '0 ile 1 milyar TL arasında geçerli bir fiyat gir.';
    }
    return null;
  }

  bool _valid(bool publication) {
    setState(() => _validatePublication = publication);
    final textValid = _formKey.currentState?.validate() ?? false;
    if (!publication) return textValid;
    final leaf = _categories
        .expand((root) => root.children)
        .any((leaf) => leaf.id == _categoryId);
    final extraValid =
        leaf &&
        _condition != null &&
        _cityId != null &&
        _districtId != null &&
        _delivery != null &&
        _photos.isNotEmpty;
    if (!extraValid) {
      setState(
        () => _saveError =
            'Kategori, durum, konum, teslim tercihi ve en az bir fotoğraf ekle.',
      );
    }
    return textValid && extraValid;
  }

  Future<bool> _preview() async {
    if (!marketplaceCanAct(context)) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    final confirmed = await marketplaceSheet<bool>(
      context,
      (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'İlan önizlemesi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MarketplacePhoto(assetId: _photos.first),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _title.text.trim(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _priceLabel,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_condition!.label} · ${_categoryName ?? ''}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${_districtName ?? ''}, ${_cityName ?? ''}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              Text(
                _description.text.trim(),
                style: const TextStyle(height: 1.55),
              ),
              const SizedBox(height: 16),
              Text(
                'Ödeme ve teslimat satıcı ile alıcı arasında kararlaştırılır.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              GradientOutlineButton(
                label: 'İlanı yayınla',
                onPressed: () => _popMarketplaceRoute(context, true),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true;
  }

  String get _priceLabel => _price.text.trim().isEmpty
      ? ''
      : _priceFormat(parseMarketplacePriceMinor(_price.text));
  String _priceFormat(int? value) =>
      value == null ? '' : _money.format(value / 100);
  String? get _categoryName =>
      _categories
          .expand((root) => root.children)
          .where((leaf) => leaf.id == _categoryId)
          .firstOrNull
          ?.name ??
      _draft?.category?.name;
  String? get _cityName =>
      _cities.where((city) => city.id == _cityId).firstOrNull?.name ??
      (_draft?.city?.id == _cityId ? _draft?.city?.name : null);
  String? get _districtName =>
      _districts
          .where((district) => district.id == _districtId)
          .firstOrNull
          ?.name ??
      (_draft?.district?.id == _districtId ? _draft?.district?.name : null);
  Future<void> _save({bool publish = false}) async {
    if (!marketplaceCanAct(context)) return;
    if (_busy || _previewOpen) return;
    setState(() => _saveError = null);
    if (!_valid(
      publish || (_draft != null && _draft!.status != MarketplaceStatus.draft),
    )) {
      return;
    }
    if (publish) {
      _previewOpen = true;
      try {
        if (!await _preview()) return;
      } finally {
        _previewOpen = false;
      }
    }
    if (!mounted || !marketplaceCanAct(context)) return;
    setState(() => _busy = true);
    try {
      if (!await _ensureDraft() || !mounted || !marketplaceCanAct(context)) {
        return;
      }
      final detached = _serverPhotoIds.difference(_photos.toSet());
      final tracked = await _cleanup!.trackPotentiallyDetached(detached);
      if (!mounted || !marketplaceCanAct(context)) return;
      if (!tracked.isSuccess) {
        setState(
          () => _saveError =
              tracked.error?.message ?? 'Fotoğraf değişikliği hazırlanamadı.',
        );
        return;
      }
      final result = await widget.repository.updateListing(
        _draft!.id,
        MarketplaceListingInput(
          title: _title.text,
          description: _description.text,
          categoryId: _categoryId,
          brand: _brand.text,
          model: _model.text,
          condition: _condition,
          priceMinor: _price.text.trim().isEmpty
              ? null
              : parseMarketplacePriceMinor(_price.text),
          districtId: _districtId,
          photoIds: List.of(_photos),
          negotiable: _negotiable,
          deliveryMethod: _delivery,
        ),
        expectedVersion: _draft!.version,
      );
      if (!mounted || !marketplaceCanAct(context)) return;
      final updated = result.data;
      if (!result.isSuccess || updated == null) {
        setState(
          () => _saveError =
              result.error?.message ??
              'İlan kaydedilemedi. Tekrar dene veya güncel kaydı yükle.',
        );
        return;
      }
      await _cleanup!.markCommitted(updated.photoIds);
      for (final id in detached) {
        await _cleanup!.discard(id);
      }
      if (!mounted || !marketplaceCanAct(context)) return;
      _draft = updated;
      _serverPhotoIds = updated.photoIds.toSet();
      _photos = List.of(updated.photoIds);
      _dirty = false;
      if (publish) {
        final published = await widget.repository.transition(
          updated.id,
          'publish',
          expectedVersion: updated.version,
        );
        if (!mounted || !marketplaceCanAct(context)) return;
        if (!published.isSuccess) {
          setState(
            () => _saveError =
                published.error?.message ??
                'Taslak kaydedildi, yayınlanamadı. Tekrar dene.',
          );
          return;
        }
        _draft = published.data;
      }
      if (mounted && marketplaceCanAct(context)) {
        _message(
          context,
          publish ? 'İlanın yayınlandı.' : 'İlanın kaydedildi.',
        );
        _exit();
      }
    } finally {
      if (mounted && marketplaceCanAct(context)) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    if (!marketplaceCanAct(context)) return;
    if (_draft == null || _busy) return;
    final yes = await marketplaceDialog<bool>(
      context,
      (context) => AlertDialog(
        title: const Text('Güncel ilan yüklensin mi?'),
        content: const Text(
          'Bu ekrandaki kaydedilmeyen değişiklikler bırakılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => _popMarketplaceRoute(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => _popMarketplaceRoute(context, true),
            child: const Text('Güncel kaydı yükle'),
          ),
        ],
      ),
    );
    if (!mounted || !marketplaceCanAct(context) || yes != true) return;
    setState(() => _busy = true);
    final result = await widget.repository.getListing(_draft!.id);
    if (!mounted || !marketplaceCanAct(context)) return;
    if (result.isSuccess && result.data != null) {
      await _cleanup?.close();
      _cleanup = null;
      if (!mounted || !marketplaceCanAct(context)) return;
      setState(() {
        _bind(result.data!);
        _saveError = null;
        _busy = false;
      });
      if (_cityId != null) unawaited(_loadDistricts(_cityId!));
    } else {
      setState(() {
        _busy = false;
        _saveError = result.error?.message ?? 'Güncel kayıt yüklenemedi.';
      });
    }
  }

  Future<void> _pickCategory() async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final leafId = await showMarketplaceCategoryPicker(
      context,
      categories: _categories,
      selectedId: _categoryId,
      leafOnly: true,
    );
    if (mounted && marketplaceCanAct(context) && leafId != null) {
      setState(() {
        _categoryId = leafId;
        _dirty = true;
      });
    }
  }

  Future<void> _pickCity() async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final id = await _pick(
      context,
      title: 'İl',
      options: {for (final city in _cities) city.id: city.name},
      selected: _cityId,
    );
    if (!mounted || !marketplaceCanAct(context) || id == null) return;
    if (id != _cityId) {
      setState(() {
        _cityId = id;
        _districtId = null;
        _dirty = true;
      });
    }
    await _loadDistricts(id);
  }

  Future<void> _pickDistrict() async {
    if (!marketplaceCanAct(context)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final id = await _pick(
      context,
      title: 'İlçe',
      options: {for (final district in _districts) district.id: district.name},
      selected: _districtId,
    );
    if (mounted && marketplaceCanAct(context) && id != null) {
      setState(() {
        _districtId = id;
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final existingPublished = _draft?.status == MarketplaceStatus.published;
    final existingNonDraft =
        _draft != null && _draft!.status != MarketplaceStatus.draft;
    return PopScope(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.listing == null ? 'İlan ver' : 'İlanı düzenle'),
          leading: IconButton(
            tooltip: 'Geri dön',
            onPressed: _busy ? null : _leave,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Text(
                'Ekipmanına yeni bir sahne bul.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Detaylarını paylaş, yayınlamadan önce ilanını gözden geçir.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (_catalogLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
              if (_catalogError != null)
                _MarketplaceError(
                  message: _catalogError!,
                  retry: _loadCatalogs,
                ),
              AbsorbPointer(
                absorbing: _busy,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section(
                      title: 'Ürün bilgileri',
                      subtitle: 'Doğru kategoriyle arayan kişilere ulaş.',
                      icon: Icons.tune_rounded,
                      children: _productFields(),
                    ),
                    const SizedBox(height: 16),
                    _section(
                      title: 'Fiyat',
                      subtitle: 'İlan fiyatını Türk lirası olarak belirt.',
                      icon: Icons.sell_outlined,
                      children: [
                        TextFormField(
                          controller: _price,
                          onChanged: _changed,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.3,
                          ),
                          decoration: _decoration(
                            'Fiyat (TL)',
                          ).copyWith(hintText: '12.500,00'),
                          validator: _validatePrice,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Pazarlığa açık',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: _negotiable,
                          onChanged: (value) => setState(() {
                            _negotiable = value;
                            _dirty = true;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _section(
                      title: 'Fotoğraflar (${_photos.length}/8)',
                      subtitle: 'İlk fotoğrafın ilanın kapağı olur.',
                      icon: Icons.photo_library_outlined,
                      children: _photoFields(),
                    ),
                    const SizedBox(height: 16),
                    _section(
                      title: 'Açıklama',
                      subtitle: 'Alıcının bilmesini istediğin detayları ekle.',
                      icon: Icons.notes_rounded,
                      children: [
                        TextFormField(
                          controller: _description,
                          onChanged: _changed,
                          minLines: 5,
                          maxLines: 12,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration('Açıklama').copyWith(
                            alignLabelWithHint: true,
                            hintText:
                                'Ürünün özellikleri, varsa kusurları, yapılan onarımlar ve kutuya dahil olanlar…',
                          ),
                          validator: (value) =>
                              _validatePublication &&
                                  (value?.trim().length ?? 0) < 10
                              ? 'En az 10 karakterlik bir açıklama yaz.'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _section(
                      title: 'Konum ve teslim',
                      subtitle: 'İlanda yalnız il ve ilçe görünür.',
                      icon: Icons.location_on_outlined,
                      children: _locationFields(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _actionBar(
          existingPublished: existingPublished,
          existingNonDraft: existingNonDraft,
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: colors.onSurface),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  List<Widget> _productFields() => [
    _selectField(
      label: 'Kategori',
      value:
          marketplaceCategoryLabel(_categories, _categoryId) ?? _categoryName,
      onTap: _catalogLoading || _catalogError != null ? null : _pickCategory,
      error: _validatePublication && _categoryId == null
          ? 'Kategori seç.'
          : null,
    ),
    TextFormField(
      controller: _title,
      onChanged: _changed,
      maxLength: 120,
      textCapitalization: TextCapitalization.sentences,
      decoration: _decoration(
        'İlan başlığı',
      ).copyWith(hintText: 'Örn. Fender Player Stratocaster'),
      validator: (value) =>
          _validatePublication && (value?.trim().length ?? 0) < 5
          ? 'En az 5 karakterlik bir başlık yaz.'
          : null,
    ),
    const SizedBox(height: 12),
    Text(
      'Marka ve model · isteğe bağlı',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
      ),
    ),
    const SizedBox(height: 9),
    LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
          TextField(
            controller: _brand,
            onChanged: _changed,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('Marka').copyWith(counterText: ''),
          ),
          TextField(
            controller: _model,
            onChanged: _changed,
            maxLength: 100,
            decoration: _decoration('Model').copyWith(counterText: ''),
          ),
        ];
        final stackFields =
            constraints.maxWidth < 290 ||
            MediaQuery.textScalerOf(context).scale(14) > 19;
        if (stackFields) {
          return Column(
            children: [fields[0], const SizedBox(height: 12), fields[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 12),
            Expanded(child: fields[1]),
          ],
        );
      },
    ),
    const SizedBox(height: 20),
    const Text(
      'Ürün durumu',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 9),
    Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final condition in MarketplaceCondition.values)
          ChoiceChip(
            label: Text(condition.label),
            selected: _condition == condition,
            onSelected: (_) => setState(() {
              _condition = condition;
              _dirty = true;
            }),
          ),
      ],
    ),
  ];

  List<Widget> _photoFields() {
    final colors = Theme.of(context).colorScheme;
    return [
      if (_photos.isNotEmpty) ...[
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: 128,
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MarketplacePhoto(assetId: _photos[index]),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .72),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      index == 0 ? 'Kapak' : '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 3,
                            right: 3,
                            child: IconButton.filled(
                              tooltip: 'Fotoğrafı kaldır',
                              onPressed: () => _removePhoto(index),
                              style: IconButton.styleFrom(
                                backgroundColor: colors.surface.withValues(
                                  alpha: .9,
                                ),
                                foregroundColor: colors.onSurface,
                              ),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox.square(
                        dimension: 48,
                        child: IconButton(
                          tooltip: 'Öne taşı',
                          onPressed: index == 0
                              ? null
                              : () => _movePhoto(index, index - 1),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        ),
                      ),
                      SizedBox.square(
                        dimension: 48,
                        child: IconButton(
                          tooltip: 'Arkaya taşı',
                          onPressed: index == _photos.length - 1
                              ? null
                              : () => _movePhoto(index, index + 1),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_photos.length < 8)
        OutlinedButton(
          onPressed: _addPhotos,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: _photos.isEmpty ? 23 : 13,
            ),
            backgroundColor: colors.surfaceContainerHighest,
            side: BorderSide(color: colors.outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _photos.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 28),
                    SizedBox(height: 9),
                    Text('Fotoğraf ekle'),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 20),
                    SizedBox(width: 8),
                    Flexible(child: Text('Fotoğraf ekle')),
                  ],
                ),
        ),
      const SizedBox(height: 10),
      Text(
        'JPG, PNG veya WebP · Fotoğraf başına en fazla 10 MB',
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 11,
          height: 1.45,
        ),
      ),
    ];
  }

  List<Widget> _locationFields() => [
    _selectField(
      label: 'İl',
      value: _cityName,
      onTap: _catalogLoading || _catalogError != null ? null : _pickCity,
      error: _validatePublication && _cityId == null ? 'İl seç.' : null,
    ),
    _selectField(
      label: 'İlçe',
      value: _districtName,
      onTap: _cityId == null || _districtLoading || _districtError != null
          ? null
          : _pickDistrict,
      loading: _districtLoading,
      error: _validatePublication && _districtId == null ? 'İlçe seç.' : null,
    ),
    if (_districtError != null)
      _MarketplaceError(
        message: _districtError!,
        retry: () => _loadDistricts(_cityId!),
      ),
    const SizedBox(height: 4),
    const Text(
      'Teslim tercihi',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 9),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final delivery in MarketplaceDelivery.values)
          ChoiceChip(
            label: Text(delivery.label),
            selected: _delivery == delivery,
            onSelected: (_) => setState(() {
              _delivery = delivery;
              _dirty = true;
            }),
          ),
      ],
    ),
  ];

  Widget _actionBar({
    required bool existingPublished,
    required bool existingNonDraft,
  }) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_progressLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      children: [
                        Text(
                          _progressLabel!,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _progress),
                      ],
                    ),
                  ),
                ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 132),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _saveError!,
                              style: TextStyle(
                                color: colors.error,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            if (_draft != null)
                              TextButton(
                                onPressed: _busy ? null : _reload,
                                child: const Text(
                                  'Sunucudaki güncel kaydı yükle',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (existingPublished)
                GradientOutlineButton(
                  label: 'Değişiklikleri kaydet',
                  onPressed: _busy ? null : _save,
                  loading: _busy && _progressLabel == null,
                  maxLines: 2,
                  backgroundColor: colors.surfaceContainerHigh,
                )
              else ...[
                GradientOutlineButton(
                  label: 'Önizle ve yayınla',
                  onPressed: _busy || _catalogLoading || _catalogError != null
                      ? null
                      : () => _save(publish: true),
                  leading: const Icon(Icons.visibility_outlined, size: 19),
                  loading: _busy && _progressLabel == null,
                  maxLines: 2,
                  backgroundColor: colors.surfaceContainerHigh,
                ),
                const SizedBox(height: 3),
                TextButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    existingNonDraft
                        ? 'Değişiklikleri kaydet'
                        : 'Taslağı kaydet',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _movePhoto(int from, int to) {
    setState(() {
      final id = _photos.removeAt(from);
      _photos.insert(to, id);
      _dirty = true;
    });
  }

  Future<void> _removePhoto(int index) async {
    if (!marketplaceCanAct(context) || _busy) return;
    final id = _photos[index];
    setState(() {
      _photos.removeAt(index);
      _dirty = true;
    });
    // Persisted references remain until a successful save. A newly uploaded,
    // discarded image can be released now so repeated selection respects quota.
    if (!_serverPhotoIds.contains(id) && _cleanup?.isTracked(id) == true) {
      await _cleanup!.discard(id);
    }
  }
}
