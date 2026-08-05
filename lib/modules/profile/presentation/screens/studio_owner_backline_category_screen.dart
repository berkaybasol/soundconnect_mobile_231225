part of 'studio_profile_screen.dart';

class _StudioBacklineCategoryManagementScreen extends StatefulWidget {
  const _StudioBacklineCategoryManagementScreen();

  @override
  State<_StudioBacklineCategoryManagementScreen> createState() =>
      _StudioBacklineCategoryManagementScreenState();
}

class _StudioBacklineCategoryManagementScreenState
    extends State<_StudioBacklineCategoryManagementScreen> {
  static const _requestPageSize = 20;
  late final BacklineCatalogRepository _repository;
  List<BacklineCategoryRequest> _submittedRequests = const [];
  List<_BacklineCategory> _catalog = const [];
  int _requestPageIndex = 0;
  int _requestTotalPages = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _requestSheetOpen = false;
  bool _withdrawDialogOpen = false;
  String? _loadError;
  int _catalogLoadGeneration = 0;
  int _requestLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _repository = serviceLocator<BacklineCatalogRepository>();
    _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori Talep Et'), centerTitle: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadInitialData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              const _BacklineCategoryRequestInfoCard(),
              const SizedBox(height: 14),
              _StudioActionButton(
                icon: _isSubmitting
                    ? Icons.hourglass_top_rounded
                    : Icons.add_rounded,
                label: _isSubmitting
                    ? 'Talep Gönderiliyor...'
                    : 'Yeni Kategori / Alt Kategori Talep Et',
                outlined: true,
                onTap: _isSubmitting || _requestSheetOpen || _catalog.isEmpty
                    ? () => _showMessage(
                        _loadError ?? 'Kategori listesi henüz hazır değil.',
                      )
                    : _openRequestSheet,
              ),
              if (_isLoading) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_loadError != null &&
                  _submittedRequests.isEmpty &&
                  _catalog.isEmpty) ...[
                const SizedBox(height: 14),
                _StudioOwnerBacklineErrorState(
                  message: _loadError!,
                  onRetry: _loadInitialData,
                ),
              ],
              if (_submittedRequests.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Talepleriniz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final request in _submittedRequests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BacklineSubmittedCategoryRequestCard(
                      request: request,
                      onWithdraw:
                          request.status ==
                                  BacklineCategoryRequestStatus.pending &&
                              !_isSubmitting &&
                              !_withdrawDialogOpen
                          ? () => _withdrawRequest(request)
                          : null,
                    ),
                  ),
                if (_requestTotalPages > 1)
                  _StudioOwnerBacklinePagination(
                    pageIndex: _requestPageIndex,
                    totalPages: _requestTotalPages,
                    enabled: !_isLoading,
                    onPrevious: _requestPageIndex > 0
                        ? () => _loadRequests(_requestPageIndex - 1)
                        : null,
                    onNext: _requestPageIndex + 1 < _requestTotalPages
                        ? () => _loadRequests(_requestPageIndex + 1)
                        : null,
                  ),
              ],
              const SizedBox(height: 20),
              const Text(
                'SoundConnect Kategorileri',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_catalog.length} ana kategori • '
                '${_catalog.fold<int>(0, (sum, item) => sum + item.children.length)} alt kategori',
                style: const TextStyle(color: Color(0xFF929DAC), fontSize: 12),
              ),
              const SizedBox(height: 10),
              for (final category in _catalog)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BacklineManagementCategoryTile(category: category),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRequestSheet() async {
    if (_isSubmitting || _requestSheetOpen) return;
    _requestSheetOpen = true;
    CreateBacklineCategoryRequestCommand? command;
    try {
      command =
          await showModalBottomSheet<CreateBacklineCategoryRequestCommand>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _BacklineCategoryRequestSheet(categories: _catalog),
          );
    } finally {
      _requestSheetOpen = false;
    }
    if (command == null || !mounted) return;
    final submitted = await _submitCategoryRequest(command);
    if (!mounted || submitted == null) return;
    await _loadRequests(0, preserveItems: true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2D394C)),
        ),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Color(0xFF75D7A3)),
            SizedBox(width: 10),
            Expanded(child: Text('Talebiniz iletildi')),
          ],
        ),
        content: const Text(
          'Talep ettiğiniz kategori veya alt kategori SoundConnect '
          'yetkililerine ulaştırıldı. İnceleme ve onay sonrasında yalnızca '
          'bu stüdyo için değil, tüm SoundConnect kullanıcıları için '
          'geçerli olacaktır.',
          style: TextStyle(
            color: Color(0xFFB8C0CC),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          SizedBox(
            width: 120,
            child: _StudioActionButton(
              icon: Icons.check_rounded,
              label: 'Tamam',
              outlined: true,
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Future<BacklineCategoryRequest?> _submitCategoryRequest(
    CreateBacklineCategoryRequestCommand command,
  ) async {
    if (_isSubmitting) return null;
    while (mounted) {
      setState(() => _isSubmitting = true);
      final result = await _repository.submitRequest(command);
      if (!mounted) return null;
      setState(() => _isSubmitting = false);
      if (result.isSuccess && result.data != null) return result.data;
      final retry = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Talep gönderilemedi'),
          content: Text(
            result.error?.message ?? 'Bağlantıyı kontrol edip tekrar deneyin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
      if (retry != true) return null;
      // The same command instance intentionally keeps clientRequestId stable.
    }
    return null;
  }

  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    final catalogFuture = _loadCatalog();
    final catalogGeneration = _catalogLoadGeneration;
    final requestsFuture = _loadRequests(0);
    final requestGeneration = _requestLoadGeneration;
    await Future.wait<void>([catalogFuture, requestsFuture]);
    if (!mounted ||
        catalogGeneration != _catalogLoadGeneration ||
        requestGeneration != _requestLoadGeneration) {
      return;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadCatalog() async {
    final generation = ++_catalogLoadGeneration;
    final result = await _loadCompleteBacklineCatalog(_repository);
    if (!mounted || generation != _catalogLoadGeneration) return;
    if (result.$1 == null) {
      setState(() {
        _loadError ??= result.$2 ?? 'Kategoriler yüklenemedi.';
      });
      return;
    }
    setState(() => _catalog = result.$1!);
  }

  Future<void> _loadRequests(int page, {bool preserveItems = false}) async {
    final generation = ++_requestLoadGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (!preserveItems) _submittedRequests = const [];
      });
    }
    final result = await _repository.listOwnerRequests(
      page: page,
      size: _requestPageSize,
    );
    if (!mounted || generation != _requestLoadGeneration) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _isLoading = false;
        _loadError = result.error?.message ?? 'Kategori talepleri yüklenemedi.';
      });
      return;
    }
    setState(() {
      _submittedRequests = result.data!.items;
      _requestPageIndex = result.data!.pageIndex;
      _requestTotalPages = result.data!.totalPages;
      _isLoading = false;
    });
  }

  Future<void> _withdrawRequest(BacklineCategoryRequest request) async {
    if (_isSubmitting || _withdrawDialogOpen) return;
    _withdrawDialogOpen = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Talep geri çekilsin mi?'),
          content: Text(
            '“${request.requestedName}” talebi incelemeden kaldırılacak.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Geri Çek'),
            ),
          ],
        ),
      );
    } finally {
      _withdrawDialogOpen = false;
    }
    if (!mounted || confirmed != true || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    final result = await _repository.withdrawRequest(request.id);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!result.isSuccess) {
      _showMessage(result.error?.message ?? 'Talep geri çekilemedi.');
      return;
    }
    await _loadRequests(_requestPageIndex, preserveItems: true);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
