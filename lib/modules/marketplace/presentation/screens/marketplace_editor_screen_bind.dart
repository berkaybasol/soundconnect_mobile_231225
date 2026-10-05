part of 'marketplace_screen.dart';

extension _MarketplaceEditorStateBindMethods on _MarketplaceEditorState {
  void _bind(MarketplaceListing listing) {
    _draft = listing;
    _title.text = listing.title;
    _description.text = listing.description;
    _brand.text = listing.brand ?? '';
    _model.text = listing.model ?? '';
    this._price.text = marketplacePriceInput(listing.priceMinor);
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
    _updateView(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    final values = await Future.wait([
      widget.repository.getCategories(),
      widget.locationRepository.getCities(),
    ]);
    if (!mounted || !marketplaceCanAct(context)) return;
    _updateView(() {
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
    _updateView(() {
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
    _updateView(() {
      _districtLoading = false;
      _districts = result.data ?? const [];
      _districtError = result.error?.message;
    });
  }

  void _changed([String? _]) {
    if (!_dirty) _updateView(() => _dirty = true);
  }

  void _exit() {
    _updateView(() {
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
      _updateView(
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
    _updateView(() => _busy = true);
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
        _updateView(() {
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
              _updateView(() => _progress = total > 0 ? sent / total : null);
            }
          },
          onStageChanged: (stage) {
            if (mounted &&
                marketplaceCanAct(context) &&
                stage == ProfileUploadStage.verifying) {
              _updateView(() {
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
            _updateView(() {
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
        _updateView(() {
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

  String? _validateTextLength(
    String? value, {
    required int max,
    int min = 0,
    String? minimumMessage,
  }) {
    final length = marketplaceTextLength(value?.trim() ?? '');
    if (length > max) return 'En fazla $max karakter yaz.';
    if (length < min) return minimumMessage ?? 'En az $min karakter yaz.';
    return null;
  }

  bool _valid(bool publication) {
    _updateView(() => _validatePublication = publication);
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
      _updateView(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Düzenlemeye dön',
                    onPressed: () => _popMarketplaceRoute(context, false),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'İlan önizlemesi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GradientOutlineButton(
                    label: 'İlanı yayınla',
                    maxLines: 2,
                    onPressed: () => _popMarketplaceRoute(context, true),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh,
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => _popMarketplaceRoute(context, false),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Düzenlemeye dön'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  String get _priceLabel => this._price.text.trim().isEmpty
      ? ''
      : _priceFormat(parseMarketplacePriceMinor(this._price.text));

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
    _updateView(() => _saveError = null);
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
    _updateView(() => _busy = true);
    try {
      if (!await _ensureDraft() || !mounted || !marketplaceCanAct(context)) {
        return;
      }
      final detached = _serverPhotoIds.difference(_photos.toSet());
      final tracked = await _cleanup!.trackPotentiallyDetached(detached);
      if (!mounted || !marketplaceCanAct(context)) return;
      if (!tracked.isSuccess) {
        _updateView(
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
          priceMinor: this._price.text.trim().isEmpty
              ? null
              : parseMarketplacePriceMinor(this._price.text),
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
        _updateView(
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
          _updateView(
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
      if (mounted && marketplaceCanAct(context)) {
        _updateView(() => _busy = false);
      }
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
    _updateView(() => _busy = true);
    final result = await widget.repository.getListing(_draft!.id);
    if (!mounted || !marketplaceCanAct(context)) return;
    if (result.isSuccess && result.data != null) {
      await _cleanup?.close();
      _cleanup = null;
      if (!mounted || !marketplaceCanAct(context)) return;
      _updateView(() {
        _bind(result.data!);
        _saveError = null;
        _busy = false;
      });
      if (_cityId != null) unawaited(_loadDistricts(_cityId!));
    } else {
      _updateView(() {
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
      _updateView(() {
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
      _updateView(() {
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
      _updateView(() {
        _districtId = id;
        _dirty = true;
      });
    }
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
}
