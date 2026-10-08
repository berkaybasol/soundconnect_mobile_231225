part of 'marketplace_screen.dart';

extension _MarketplaceEditorStateProductFieldsMethods
    on _MarketplaceEditorState {
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
      validator: (value) => _validateTextLength(
        value,
        max: 120,
        min: _validatePublication ? 5 : 0,
        minimumMessage: 'En az 5 karakterlik bir başlık yaz.',
      ),
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
          TextFormField(
            controller: _brand,
            onChanged: _changed,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('Marka').copyWith(counterText: ''),
            validator: (value) => _validateTextLength(value, max: 80),
          ),
          TextFormField(
            controller: _model,
            onChanged: _changed,
            maxLength: 100,
            decoration: _decoration('Model').copyWith(counterText: ''),
            validator: (value) => _validateTextLength(value, max: 100),
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
            onSelected: (_) => _updateView(() {
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
            onSelected: (_) => _updateView(() {
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
    _updateView(() {
      final id = _photos.removeAt(from);
      _photos.insert(to, id);
      _dirty = true;
    });
  }

  Future<void> _removePhoto(int index) async {
    if (!marketplaceCanAct(context) || _busy) return;
    final id = _photos[index];
    _updateView(() {
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
