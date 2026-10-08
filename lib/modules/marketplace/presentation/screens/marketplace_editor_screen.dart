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
  final _priceFormatter = MarketplacePriceInputFormatter();
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

  @override
  void dispose() {
    _uploadCancellation?.cancel();
    for (final controller in [_title, _description, _brand, _model, _price]) {
      controller.dispose();
    }
    if (_cleanup != null) unawaited(_cleanup!.close());
    super.dispose();
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
                'Ekipmanını satışa çıkar.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Ürün bilgilerini ve fotoğraflarını ekle, ilanını önizle ve yayınla.',
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
                          inputFormatters: [_priceFormatter],
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
                          validator: (value) => _validateTextLength(
                            value,
                            max: 4000,
                            min: _validatePublication ? 10 : 0,
                            minimumMessage:
                                'En az 10 karakterlik bir açıklama yaz.',
                          ),
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

  void _updateView(VoidCallback change) => setState(change);
}
