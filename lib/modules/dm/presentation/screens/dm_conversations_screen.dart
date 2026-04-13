import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../profile/domain/entities/musician_search_option.dart';
import '../../../profile/domain/entities/profile_venue_models.dart';
import '../../../profile/domain/musician_profile_repository.dart';
import '../../../profile/domain/musician_search_repository.dart';
import '../../../profile/domain/venue_directory_repository.dart';
import '../../../profile/domain/venue_profile_repository.dart';
import '../../data/dm_auth_support.dart';
import '../../domain/entities/dm_conversation_preview.dart';
import '../cubit/dm_conversations_cubit.dart';
import '../cubit/dm_conversations_state.dart';
import 'dm_chat_screen.dart';

class DmConversationsScreen extends StatelessWidget {
  const DmConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<DmConversationsCubit>()..load(),
      child: const _DmConversationsView(),
    );
  }
}

class _DmConversationsView extends StatefulWidget {
  const _DmConversationsView();

  @override
  State<_DmConversationsView> createState() => _DmConversationsViewState();
}

class _DmConversationsViewState extends State<_DmConversationsView> {
  final TokenStore _tokenStore = serviceLocator<TokenStore>();
  final MusicianSearchRepository _searchRepository =
      serviceLocator<MusicianSearchRepository>();
  final MusicianProfileRepository _profileRepository =
      serviceLocator<MusicianProfileRepository>();
  final VenueDirectoryRepository _venueDirectoryRepository =
      serviceLocator<VenueDirectoryRepository>();
  final VenueProfileRepository _venueProfileRepository =
      serviceLocator<VenueProfileRepository>();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  List<_DmSearchEntry> _searchResults = const [];
  List<VenueOption>? _venueCache;
  final Map<String, String?> _venueImageById = <String, String?>{};
  final Map<String, List<_DmSearchEntry>> _searchCacheByQuery =
      <String, List<_DmSearchEntry>>{};

  bool _searchLoading = false;
  String? _searchError;
  int _searchToken = 0;
  String? _currentUserId;

  bool get _hasActiveQuery => _searchController.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _resolveCurrentUserId();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (mounted) {
      setState(() {});
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(_searchController.text),
    );
  }

  Future<void> _resolveCurrentUserId() async {
    final resolved = await resolveCurrentUserId(_tokenStore);
    if (!mounted) return;
    final normalized = (resolved ?? '').trim();
    _currentUserId = normalized.isEmpty ? null : normalized;
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    final queryKey = q.toLowerCase();
    final requestToken = ++_searchToken;

    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _searchLoading = false;
        _searchError = null;
      });
      return;
    }

    final cached = _searchCacheByQuery[queryKey];
    if (cached != null) {
      setState(() {
        _searchResults = cached;
        _searchLoading = false;
        _searchError = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _searchLoading = true;
      _searchError = null;
    });

    final musicianFuture = _searchRepository.search(q);
    final venueFuture = _loadVenueOptions();

    final musicianResult = await musicianFuture;
    final venueOptions = await venueFuture;

    if (!mounted || requestToken != _searchToken) return;

    if (!musicianResult.isSuccess) {
      setState(() {
        _searchLoading = false;
        _searchResults = const [];
        _searchError = musicianResult.error?.message ?? 'Arama basarisiz';
      });
      return;
    }

    final musicianEntries =
        (musicianResult.data ?? const <MusicianSearchOption>[])
            .where((item) => item.profileId.trim().isNotEmpty)
            .map(_DmSearchEntry.fromMusician)
            .toList();

    final qLower = q.toLowerCase();
    final venueEntries = venueOptions
        .where((item) {
          final name = item.name.trim().toLowerCase();
          return item.id.trim().isNotEmpty &&
              name.isNotEmpty &&
              name.contains(qLower);
        })
        .take(30)
        .map((item) {
          final cachedImage = _venueImageById[item.id];
          return _DmSearchEntry.fromVenue(
            item,
            imageOverride: cachedImage ?? item.profilePictureUrl,
          );
        })
        .toList();

    setState(() {
      _searchResults = [...musicianEntries, ...venueEntries];
      _searchLoading = false;
      _searchError = null;
    });
    _searchCacheByQuery[queryKey] = _searchResults
        .map(
          (entry) => entry.copyWith(
            imageUrl: entry.imageUrl,
            subtitle: entry.subtitle,
          ),
        )
        .toList();

    unawaited(_hydrateVenueImages(requestToken, venueEntries));
  }

  Future<List<VenueOption>> _loadVenueOptions() async {
    if (_venueCache != null) return _venueCache!;
    final venueResult = await _venueDirectoryRepository.getAllVenues();
    if (venueResult.isSuccess && venueResult.data != null) {
      _venueCache = venueResult.data!;
      return _venueCache!;
    }
    return const <VenueOption>[];
  }

  Future<void> _hydrateVenueImages(
    int requestToken,
    List<_DmSearchEntry> venueEntries,
  ) async {
    final toResolve = venueEntries
        .where((item) => item.type == _DmSearchEntryType.venue)
        .where((item) => (item.imageUrl ?? '').trim().isEmpty)
        .where((item) => !_venueImageById.containsKey(item.referenceId))
        .take(8)
        .toList();

    if (toResolve.isEmpty) return;

    final pairs = await Future.wait(
      toResolve.map((entry) async {
        final result = await _venueProfileRepository.getPublicVenueProfile(
          venueId: entry.referenceId,
        );
        if (!result.isSuccess || result.data == null) {
          return MapEntry<String, String?>(entry.referenceId, null);
        }
        return MapEntry<String, String?>(
          entry.referenceId,
          result.data!.profilePictureUrl,
        );
      }),
    );

    if (!mounted || requestToken != _searchToken) return;

    for (final pair in pairs) {
      _venueImageById[pair.key] = pair.value;
    }

    setState(() {
      _searchResults = _searchResults.map((entry) {
        if (entry.type != _DmSearchEntryType.venue) return entry;
        final resolved = _venueImageById[entry.referenceId];
        if ((resolved ?? '').trim().isEmpty) return entry;
        return entry.copyWith(imageUrl: resolved);
      }).toList();
      final queryKey = _searchController.text.trim().toLowerCase();
      if (queryKey.isNotEmpty) {
        _searchCacheByQuery[queryKey] = _searchResults
            .map(
              (entry) => entry.copyWith(
                imageUrl: entry.imageUrl,
                subtitle: entry.subtitle,
              ),
            )
            .toList();
      }
    });
  }

  Future<void> _openChatFromSearch(_DmSearchEntry item) async {
    final selfUserId = (_currentUserId ?? '').trim();
    if (item.type == _DmSearchEntryType.musician) {
      final profileResult = await _profileRepository
          .getPublicProfileByProfileId(item.referenceId);
      if (!mounted) return;
      if (!profileResult.isSuccess || profileResult.data == null) {
        _showSnack(profileResult.error?.message ?? 'Muzisyen secilemedi');
        return;
      }
      final data = profileResult.data!;
      final userId = data.userId.trim();
      if (userId.isEmpty) {
        _showSnack('Kullanici kimligi bulunamadi');
        return;
      }
      if (selfUserId.isNotEmpty && userId == selfUserId) {
        _showSnack('Kendinize mesaj atamazsiniz');
        return;
      }
      final username = (data.username ?? '').trim();
      Navigator.of(context).pushNamed(
        AppRoutes.dmChat,
        arguments: DmChatScreenArgs(
          otherUserId: userId,
          otherUsername: username.isNotEmpty ? username : item.title,
          otherUserProfilePicture: data.profilePicture ?? item.imageUrl,
          otherMusicianProfileId: item.referenceId,
        ),
      );
      return;
    }

    final venueResult = await _venueProfileRepository.getPublicVenueProfile(
      venueId: item.referenceId,
    );
    if (!mounted) return;
    if (!venueResult.isSuccess || venueResult.data == null) {
      _showSnack(venueResult.error?.message ?? 'Mekan secilemedi');
      return;
    }
    final data = venueResult.data!;
    final ownerId = data.ownerUserId.trim();
    if (ownerId.isEmpty) {
      _showSnack('Mekan sahibi kullanici kimligi bulunamadi');
      return;
    }
    if (selfUserId.isNotEmpty && ownerId == selfUserId) {
      _showSnack('Kendinize mesaj atamazsiniz');
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.dmChat,
      arguments: DmChatScreenArgs(
        otherUserId: ownerId,
        otherUsername: data.venueName.trim().isNotEmpty
            ? data.venueName
            : item.title,
        otherUserProfilePicture: data.profilePictureUrl ?? item.imageUrl,
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mesajlar'),
            SizedBox(height: 2),
            Text(
              'DM kutun',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<DmConversationsCubit>().load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navBlueDeep, AppColors.navBlue],
          ),
        ),
        child: BlocBuilder<DmConversationsCubit, DmConversationsState>(
          builder: (context, state) {
            if (state.status == DmConversationsStatus.loading &&
                state.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == DmConversationsStatus.failure &&
                state.items.isEmpty) {
              return _FailureState(
                message: state.error?.message ?? 'Konusmalar getirilemedi',
                onRetry: () => context.read<DmConversationsCubit>().load(),
              );
            }

            return RefreshIndicator(
              onRefresh: () => context.read<DmConversationsCubit>().load(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                itemCount: _buildListItemCount(state.items.length),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _InlineSearchBar(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onClear: () {
                        _searchController.clear();
                      },
                    );
                  }

                  if (_hasActiveQuery) {
                    if (index == 1) {
                      if (_searchLoading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (_searchError != null) {
                        return _SearchInfo(text: _searchError!);
                      }
                      if (_searchResults.isEmpty) {
                        return const _SearchInfo(text: 'Sonuc bulunamadi');
                      }
                      return const _SearchInfo(text: 'Arama sonuclari');
                    }
                    final entry = _searchResults[index - 2];
                    return _SearchResultTile(
                      item: entry,
                      onTap: () => _openChatFromSearch(entry),
                    );
                  }

                  if (state.items.isEmpty) {
                    return const _EmptyState();
                  }

                  final item = state.items[index - 1];
                  return _ConversationTile(item: item);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  int _buildListItemCount(int conversationCount) {
    if (_hasActiveQuery) {
      return 2 + _searchResults.length;
    }
    if (conversationCount == 0) {
      return 2;
    }
    return 1 + conversationCount;
  }
}

class _InlineSearchBar extends StatelessWidget {
  const _InlineSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: AppColors.textPrimary,
              decoration: const InputDecoration(
                hintText: 'Muzisyen veya mekan ara...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            IconButton(
              onPressed: onClear,
              splashRadius: 18,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}

class _SearchInfo extends StatelessWidget {
  const _SearchInfo({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final _DmSearchEntry item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl?.trim();
    final hasImage =
        imageUrl != null &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));
    return Material(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.navBlueSoft,
            backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
            child: hasImage
                ? null
                : Icon(
                    item.type == _DmSearchEntryType.musician
                        ? Icons.person_outline
                        : Icons.storefront_outlined,
                    color: AppColors.textMuted,
                  ),
          ),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final DmConversationPreview item;

  const _ConversationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasUnread = item.lastMessageRead == false;
    final avatar = item.otherUserProfilePicture?.trim();
    final hasAvatar =
        avatar != null &&
        (avatar.startsWith('http://') || avatar.startsWith('https://'));
    return Material(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRoutes.dmChat,
            arguments: DmChatScreenArgs(
              otherUserId: item.otherUserId,
              otherUsername: item.otherUsername,
              otherUserProfilePicture: item.otherUserProfilePicture,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasUnread ? AppColors.coralLight : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.navBlueSoft,
                backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
                child: hasAvatar
                    ? null
                    : const Icon(
                        Icons.person_outline,
                        color: AppColors.textMuted,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.otherUsername.trim().isNotEmpty
                                ? item.otherUsername
                                : 'Kullanici',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(item.lastMessageAt),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.lastMessageContent?.trim().isNotEmpty == true
                          ? item.lastMessageContent!.trim()
                          : 'Mesaj yok',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (hasUnread)
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.coralLight,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd.$mm';
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, color: AppColors.textMuted, size: 30),
          SizedBox(height: 14),
          Text(
            'Henuz konusma yok',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Yukaridaki arama kutusundan mesajlasmak istedigin kisiyi bul.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

enum _DmSearchEntryType { musician, venue }

class _DmSearchEntry {
  final _DmSearchEntryType type;
  final String referenceId;
  final String title;
  final String subtitle;
  final String? imageUrl;

  const _DmSearchEntry({
    required this.type,
    required this.referenceId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  _DmSearchEntry copyWith({String? imageUrl, String? subtitle}) {
    return _DmSearchEntry(
      type: type,
      referenceId: referenceId,
      title: title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory _DmSearchEntry.fromMusician(MusicianSearchOption item) {
    final title = item.displayName.trim().isNotEmpty
        ? item.displayName.trim()
        : 'Muzisyen';
    final rawSecondary = (item.secondaryLabel ?? '').trim();
    return _DmSearchEntry(
      type: _DmSearchEntryType.musician,
      referenceId: item.profileId,
      title: title,
      subtitle: rawSecondary.isNotEmpty ? rawSecondary : 'Muzisyen',
      imageUrl: item.profilePictureUrl,
    );
  }

  factory _DmSearchEntry.fromVenue(VenueOption item, {String? imageOverride}) {
    final title = item.name.trim().isNotEmpty ? item.name.trim() : 'Mekan';
    final city = (item.cityName ?? '').trim();
    final district = (item.districtName ?? '').trim();
    final location = [
      district,
      city,
    ].where((part) => part.isNotEmpty).join(', ');
    return _DmSearchEntry(
      type: _DmSearchEntryType.venue,
      referenceId: item.id,
      title: title,
      subtitle: location.isNotEmpty ? 'Mekan - $location' : 'Mekan',
      imageUrl: imageOverride,
    );
  }
}
