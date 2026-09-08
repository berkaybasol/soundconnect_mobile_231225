import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../domain/venue_artist_directory_repository.dart';
import '../navigation/profile_route_resolver.dart';

Future<void> openVenueArtists(
  BuildContext context, {
  required String venueId,
  required String venueName,
  String? venueImageUrl,
}) async {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => VenueArtistsScreen(
        venueId: venueId,
        venueName: venueName,
        venueImageUrl: venueImageUrl,
      ),
    ),
  );
}

class VenueArtistsScreen extends StatefulWidget {
  const VenueArtistsScreen({
    super.key,
    required this.venueId,
    required this.venueName,
    this.venueImageUrl,
    this.repository,
  });

  final String venueId;
  final String venueName;
  final String? venueImageUrl;
  final VenueArtistDirectoryRepository? repository;

  @override
  State<VenueArtistsScreen> createState() => _VenueArtistsScreenState();
}

class _VenueArtistsScreenState extends State<VenueArtistsScreen> {
  late final VenueArtistDirectoryRepository _repository;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  AuthSessionManager? _sessions;
  Timer? _debounce;
  VenueArtistKind _kind = VenueArtistKind.musician;
  List<VenueArtistDirectoryItem> _items = [];
  String _query = '';
  String? _error;
  String? _pageError;
  int _generation = 0;
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _openingProfile = false;
  bool _routeWasCurrent = true;
  bool _sessionInvalidated = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? serviceLocator<VenueArtistDirectoryRepository>();
    if (serviceLocator.isRegistered<AuthSessionManager>()) {
      _sessions = serviceLocator<AuthSessionManager>();
      _sessions!.addListener(_sessionChanged);
    }
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current && !_routeWasCurrent && !_sessionInvalidated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ModalRoute.of(context)?.isCurrent != false &&
            !_sessionInvalidated) {
          unawaited(_load());
        }
      });
    }
    _routeWasCurrent = current;
  }

  @override
  void didUpdateWidget(covariant VenueArtistsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.venueId != widget.venueId) {
      _debounce?.cancel();
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _sessions?.removeListener(_sessionChanged);
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _sessionChanged() {
    _sessionInvalidated = true;
    _generation++;
    _debounce?.cancel();
    if (!mounted) return;
    setState(() {
      _items = [];
      _total = 0;
      _hasMore = false;
      _loading = _loadingMore = false;
      _pageError = null;
      _error = 'Hesabın değişti. Listeyi yeniden aç.';
    });
  }

  void _searchChanged(String value) {
    final query = value.trim();
    if (query == _query) return;
    _query = query;
    _debounce?.cancel();
    _generation++;
    setState(() {
      _items = [];
      _loading = true;
      _loadingMore = false;
      _error = _pageError = null;
      _hasMore = false;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_load()),
    );
  }

  void _selectKind(VenueArtistKind kind) {
    if (_kind == kind) return;
    _debounce?.cancel();
    setState(() => _kind = kind);
    unawaited(_load());
  }

  Future<void> _load({bool append = false}) async {
    if (!mounted || (append && (_loading || _loadingMore || !_hasMore))) return;
    _debounce?.cancel();
    _sessionInvalidated = false;
    final generation = ++_generation;
    final next = append ? _page + 1 : 0;
    setState(() {
      _error = _pageError = null;
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
        _items = [];
        _total = 0;
        _hasMore = false;
      }
    });
    if (!append && _scroll.hasClients && !_searchFocus.hasFocus) {
      _scroll.jumpTo(0);
    }
    try {
      final result = await _repository.list(
        venueId: widget.venueId,
        kind: _kind,
        query: _query,
        page: next,
        size: 20,
        expectedSessionKey: _sessions?.session.userId,
      );
      if (!mounted || generation != _generation) return;
      final data = result.data;
      if (!result.isSuccess || data == null) {
        throw StateError('directory-unavailable');
      }
      if (append &&
          (data.totalElements != _total ||
              data.items.any(
                (item) => _items.any((previous) => previous.id == item.id),
              ))) {
        await _load();
        return;
      }
      setState(() {
        _items = append ? [..._items, ...data.items] : data.items;
        _page = data.page;
        _total = data.totalElements;
        _hasMore = !data.last;
        _loading = _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = _loadingMore = false;
        if (append) {
          _pageError = 'Diğer sonuçlar yüklenemedi.';
        } else {
          _error = 'Liste yüklenemedi. Yeniden deneyebilirsin.';
        }
      });
    }
  }

  Future<void> _openProfile(VenueArtistDirectoryItem item) async {
    if (_openingProfile ||
        !_items.contains(item) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _openingProfile = true;
    final target = ProfileRouteTarget(
      kind: item.kind == VenueArtistKind.band
          ? ProfileRouteKind.band
          : ProfileRouteKind.musician,
      id: item.id,
    );
    try {
      await Navigator.of(
        context,
      ).pushNamed(target.publicRoute, arguments: target.publicArguments);
    } finally {
      _openingProfile = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Aktif Sanatçılar'), centerTitle: true),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _load(),
          child: CustomScrollView(
            key: const Key('venue-artists-list'),
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Row(
                        children: [
                          _DirectoryAvatar(
                            url: widget.venueImageUrl,
                            icon: Icons.storefront_outlined,
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GradientText(
                              text: widget.venueName,
                              gradient: LinearGradient(
                                colors: AppColors.brandGradient,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: VenueArtistKind.values
                              .map((kind) => Expanded(child: _kindButton(kind)))
                              .toList(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: TextField(
                        key: const Key('venue-artists-search'),
                        controller: _search,
                        focusNode: _searchFocus,
                        maxLength: 100,
                        textInputAction: TextInputAction.search,
                        onChanged: _searchChanged,
                        onSubmitted: (_) => unawaited(_load()),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: _kind == VenueArtistKind.band
                              ? 'Grup ara...'
                              : 'Sanatçı ara...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Aramayı temizle',
                                  onPressed: () {
                                    _search.clear();
                                    _searchChanged('');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _status(
                    Icons.cloud_off_outlined,
                    _error!,
                    retry: () => unawaited(_load()),
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _status(
                    _query.isNotEmpty
                        ? Icons.search_off_rounded
                        : Icons.people_outline_rounded,
                    _query.isNotEmpty
                        ? 'Aramana uygun sonuç bulunamadı.'
                        : _kind == VenueArtistKind.band
                        ? 'Henüz bağlı bir grup yok.'
                        : 'Henüz bağlı bir sanatçı yok.',
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Text(
                      '$_total ${_kind == VenueArtistKind.band ? 'grup' : 'sanatçı'}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _artistCard(_items[index]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    child: Column(
                      children: [
                        if (_pageError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _pageError!,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),
                        if (_loadingMore)
                          const CircularProgressIndicator()
                        else if (_hasMore)
                          SizedBox(
                            width: double.infinity,
                            child: GradientOutlineButton(
                              label: _pageError == null
                                  ? 'Daha fazla göster'
                                  : 'Yeniden dene',
                              strokeWidth: 1,
                              onPressed: () => unawaited(_load(append: true)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindButton(VenueArtistKind kind) {
    final selected = kind == _kind;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(colors: AppColors.brandGradient)
              : null,
        ),
        padding: const EdgeInsets.all(1),
        child: Material(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('venue-artists-tab-${kind.name}'),
            onTap: () => _selectKind(kind),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Text(
                kind == VenueArtistKind.band ? 'Gruplar' : 'Sanatçılar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? colors.onSurface : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(IconData icon, String text, {VoidCallback? retry}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center),
          if (retry != null) ...[
            const SizedBox(height: 18),
            GradientOutlineButton(
              label: 'Yeniden dene',
              strokeWidth: 1,
              onPressed: retry,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _artistCard(VenueArtistDirectoryItem item) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('venue-artist-${item.kind.name}-${item.id}'),
          onTap: () => _openProfile(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _DirectoryAvatar(
                  url: item.profileImageUrl,
                  icon: item.kind == VenueArtistKind.band
                      ? Icons.groups_outlined
                      : Icons.person_outline_rounded,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryAvatar extends StatelessWidget {
  const _DirectoryAvatar({
    required this.url,
    required this.icon,
    required this.size,
  });
  final String? url;
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext _) => Icon(
      icon,
      size: size * .5,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      child: ClipOval(
        child: AppCachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          cacheWidth: 144,
          cacheHeight: 144,
          placeholderBuilder: fallback,
          errorBuilder: fallback,
        ),
      ),
    );
  }
}
