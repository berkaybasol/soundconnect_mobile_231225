import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/profile_search_result.dart';
import '../../domain/profile_search_repository.dart';
import '../navigation/profile_search_navigation.dart';
import 'band_profile_screen.dart';
import 'profile_route_args.dart';

Future<void> showBackstageProfileSearch(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navBlueDeep,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _BackstageProfileSearchSheet(),
  );
}

class _BackstageProfileSearchSheet extends StatefulWidget {
  const _BackstageProfileSearchSheet();

  @override
  State<_BackstageProfileSearchSheet> createState() =>
      _BackstageProfileSearchSheetState();
}

class _BackstageProfileSearchSheetState
    extends State<_BackstageProfileSearchSheet> {
  final _repository = serviceLocator<ProfileSearchRepository>();
  final _controller = TextEditingController();
  Timer? _debounce;
  int _searchToken = 0;
  bool _loading = false;
  String? _message;
  List<ProfileSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(_controller.text),
    );
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    final token = ++_searchToken;
    if (query.length < 2) {
      setState(() {
        _loading = false;
        _results = const [];
        _message = query.isEmpty ? null : 'Arama için en az 2 karakter yaz.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final result = await _repository.searchProfiles(query);
    if (!mounted || token != _searchToken) return;
    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _results = const [];
        _message = result.error?.message ?? 'Arama şu anda yapılamıyor.';
      });
      return;
    }

    final results = result.data ?? const <ProfileSearchResult>[];
    setState(() {
      _loading = false;
      _results = results;
      _message = results.isEmpty ? 'Sonuç bulunamadı.' : null;
    });
  }

  void _openResult(ProfileSearchResult item) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final destination = resolveProfileSearchDestination(
      result: item,
      currentUserId: serviceLocator<AuthSessionManager>().session.userId,
    );
    navigator.pop();

    if (destination?.opensOwnerProfile == true) {
      navigator.pushNamed(destination!.route);
      return;
    }

    switch (item.type) {
      case ProfileSearchResultType.musician:
        navigator.pushNamed(
          destination!.route,
          arguments: PublicProfileArgs(profileId: item.targetId),
        );
        return;
      case ProfileSearchResultType.listener:
        _showComingSoon(messenger, 'Dinleyici profili yakında açılacak.');
        return;
      case ProfileSearchResultType.band:
        navigator.pushNamed(
          destination!.route,
          arguments: BandProfileScreenArgs(
            bandId: item.targetId,
            viewMode: BandProfileViewMode.public,
          ),
        );
        return;
      case ProfileSearchResultType.studio:
        navigator.pushNamed(
          destination!.route,
          arguments: PublicProfileArgs(profileId: item.targetId),
        );
        return;
      case ProfileSearchResultType.venue:
        navigator.pushNamed(
          destination!.route,
          arguments: VenuePublicProfileArgs(venueId: item.targetId),
        );
        return;
      case ProfileSearchResultType.unknown:
        return;
    }
  }

  void _showComingSoon(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _runSearch,
                  decoration: InputDecoration(
                    hintText:
                        'Müzisyen, dinleyici, grup, stüdyo veya mekân ara...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _controller.clear,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_message != null && !_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_results.isNotEmpty)
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 12),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return _ProfileSearchResultTile(
                          item: item,
                          onTap: () => _openResult(item),
                        );
                      },
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSearchResultTile extends StatelessWidget {
  final ProfileSearchResult item;
  final VoidCallback onTap;

  const _ProfileSearchResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl?.trim();
    final hasImage =
        imageUrl != null &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              child: ClipOval(
                child: hasImage
                    ? AppCachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 44,
                        height: 44,
                        cacheWidth: 132,
                        cacheHeight: 132,
                        errorBuilder: (context) => Icon(
                          _iconForType(item.type),
                          color: AppColors.coralAlt,
                        ),
                      )
                    : Icon(_iconForType(item.type), color: AppColors.coralAlt),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty ? item.typeLabel : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(ProfileSearchResultType type) {
    return switch (type) {
      ProfileSearchResultType.musician => Icons.person_outline,
      ProfileSearchResultType.listener => Icons.headphones_outlined,
      ProfileSearchResultType.band => Icons.groups_2_outlined,
      ProfileSearchResultType.studio => Icons.graphic_eq_outlined,
      ProfileSearchResultType.venue => Icons.storefront_outlined,
      ProfileSearchResultType.unknown => Icons.search,
    };
  }

  String _subtitle(ProfileSearchResult item) {
    final raw = item.subtitle?.trim();
    if (raw == null || raw.isEmpty || raw == item.title) {
      return item.typeLabel;
    }
    if (item.type == ProfileSearchResultType.musician && !raw.startsWith('@')) {
      return '@$raw';
    }
    return '${item.typeLabel} - $raw';
  }
}
