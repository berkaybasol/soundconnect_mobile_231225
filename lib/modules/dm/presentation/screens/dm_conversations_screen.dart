import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../location/domain/location_repository.dart';
import '../../../profile/domain/entities/musician_search_option.dart';
import '../../../profile/domain/entities/profile_venue_models.dart';
import '../../../profile/domain/musician_profile_repository.dart';
import '../../../profile/domain/musician_search_repository.dart';
import '../../../profile/domain/venue_directory_repository.dart';
import '../../../profile/domain/venue_profile_repository.dart';
import '../../../tablegroup/domain/entities/table_group.dart';
import '../../../tablegroup/domain/entities/table_group_participant.dart';
import '../../../tablegroup/domain/table_group_repository.dart';
import '../../../tablegroup/presentation/screens/table_group_detail_screen.dart';
import '../../data/dm_auth_support.dart';
import '../../domain/entities/dm_conversation_preview.dart';
import '../cubit/dm_conversations_cubit.dart';
import '../cubit/dm_conversations_state.dart';
import 'dm_chat_screen.dart';

class DmConversationsScreen extends StatelessWidget {
  DmConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<DmConversationsCubit>()..load(),
      child: _DmConversationsView(),
    );
  }
}

class _DmConversationsView extends StatefulWidget {
  _DmConversationsView();

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
  final TableGroupRepository _tableGroupRepository =
      serviceLocator<TableGroupRepository>();
  final LocationRepository _locationRepository =
      serviceLocator<LocationRepository>();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  List<_DmSearchEntry> _searchResults = [];
  List<VenueOption>? _venueCache;
  final Map<String, String?> _venueImageById = <String, String?>{};
  final Map<String, List<_DmSearchEntry>> _searchCacheByQuery =
      <String, List<_DmSearchEntry>>{};

  bool _searchLoading = false;
  String? _searchError;
  int _searchToken = 0;
  String? _currentUserId;
  List<TableGroup> _musicJoinTables = const <TableGroup>[];
  bool _musicJoinLoading = false;
  bool _musicJoinLoaded = false;
  String? _musicJoinError;

  bool get _hasActiveQuery => _searchController.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _resolveCurrentUserAndLoadMusicJoin();
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
      Duration(milliseconds: 350),
      () => _runSearch(_searchController.text),
    );
  }

  Future<void> _resolveCurrentUserId() async {
    final resolved = await resolveCurrentUserId(_tokenStore);
    if (!mounted) return;
    final normalized = (resolved ?? '').trim();
    _currentUserId = normalized.isEmpty ? null : normalized;
  }

  Future<void> _resolveCurrentUserAndLoadMusicJoin() async {
    await _resolveCurrentUserId();
    await _loadMusicJoinTables(force: true);
  }

  Future<void> _loadMusicJoinTables({bool force = false}) async {
    if (_musicJoinLoading) return;
    if (!force && _musicJoinLoaded) return;

    final currentUserId = (_currentUserId ?? '').trim();
    if (currentUserId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _musicJoinTables = const <TableGroup>[];
        _musicJoinLoaded = true;
        _musicJoinLoading = false;
        _musicJoinError = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _musicJoinLoading = true;
      _musicJoinError = null;
    });

    final citiesResult = await _locationRepository.getCities();
    if (!mounted) return;
    if (!citiesResult.isSuccess || citiesResult.data == null) {
      setState(() {
        _musicJoinLoading = false;
        _musicJoinLoaded = true;
        _musicJoinError =
            citiesResult.error?.message ?? 'Masa listesi alinamadi';
      });
      return;
    }

    final Map<String, TableGroup> relevant = <String, TableGroup>{};
    for (final city in citiesResult.data!) {
      int page = 0;
      bool hasNext = true;
      int guard = 0;
      while (hasNext && guard < 25) {
        final result = await _tableGroupRepository.listActiveTableGroups(
          cityId: city.id,
          page: page,
          size: 50,
        );
        if (!result.isSuccess || result.data == null) {
          hasNext = false;
          continue;
        }
        for (final table in result.data!.items) {
          if (_isMusicJoinMember(table, currentUserId)) {
            relevant[table.id] = table;
          }
        }
        hasNext = result.data!.hasNext;
        page += 1;
        guard += 1;
      }
    }

    final sorted = relevant.values.toList()
      ..sort((a, b) {
        final aa = a.expiresAt?.millisecondsSinceEpoch ?? 0;
        final bb = b.expiresAt?.millisecondsSinceEpoch ?? 0;
        return bb.compareTo(aa);
      });

    if (!mounted) return;
    setState(() {
      _musicJoinTables = sorted;
      _musicJoinLoading = false;
      _musicJoinLoaded = true;
      _musicJoinError = null;
    });
  }

  bool _isMusicJoinMember(TableGroup table, String currentUserId) {
    if (table.ownerId == currentUserId) return true;
    for (final participant in table.participants) {
      if (participant.userId == currentUserId &&
          participant.status == TableGroupParticipantStatus.accepted) {
        return true;
      }
    }
    return false;
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    final queryKey = q.toLowerCase();
    final requestToken = ++_searchToken;

    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
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
        _searchResults = [];
        _searchError = musicianResult.error?.message ?? 'Arama basarisiz';
      });
      return;
    }

    final musicianEntries = (musicianResult.data ?? <MusicianSearchOption>[])
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
    return <VenueOption>[];
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mesajlar'),
              SizedBox(height: 2),
              Text(
                'DM kutun',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                context.read<DmConversationsCubit>().load();
                _loadMusicJoinTables(force: true);
              },
              icon: Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Birincil Mesajlar'),
              Tab(text: 'Müzik Birleştirir!'),
            ],
          ),
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.navBlueDeep, AppColors.navBlue],
            ),
          ),
          child: TabBarView(children: [_primaryMessagesTab(), _musicJoinTab()]),
        ),
      ),
    );
  }

  Widget _primaryMessagesTab() {
    return BlocBuilder<DmConversationsCubit, DmConversationsState>(
      builder: (context, state) {
        if (state.status == DmConversationsStatus.loading &&
            state.items.isEmpty) {
          return Center(child: CircularProgressIndicator());
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
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: _buildListItemCount(state.items.length),
            separatorBuilder: (_, __) => SizedBox(height: 10),
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
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_searchError != null) {
                    return _SearchInfo(text: _searchError!);
                  }
                  if (_searchResults.isEmpty) {
                    return _SearchInfo(text: 'Sonuc bulunamadi');
                  }
                  return _SearchInfo(text: 'Arama sonuclari');
                }
                final entry = _searchResults[index - 2];
                return _SearchResultTile(
                  item: entry,
                  onTap: () => _openChatFromSearch(entry),
                );
              }

              if (state.items.isEmpty) {
                return _EmptyState();
              }

              final item = state.items[index - 1];
              return _ConversationTile(item: item);
            },
          ),
        );
      },
    );
  }

  Widget _musicJoinTab() {
    if (_musicJoinLoading && _musicJoinTables.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    if (_musicJoinError != null && _musicJoinTables.isEmpty) {
      return _FailureState(
        message: _musicJoinError!,
        onRetry: () => _loadMusicJoinTables(force: true),
      );
    }
    if (_musicJoinTables.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadMusicJoinTables(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _SearchInfo(
              text: 'Müzik Birleştirir! için aktif masa bulunamadı',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadMusicJoinTables(force: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        itemCount: _musicJoinTables.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final table = _musicJoinTables[index];
          return _MusicJoinTableTile(
            table: table,
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.tableGroupDetail,
                arguments: TableGroupDetailArgs(tableGroupId: table.id),
              );
            },
          );
        },
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
  _InlineSearchBar({
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
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: Theme.of(context).colorScheme.onSurface,
              decoration: InputDecoration(
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
              icon: Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}

class _SearchInfo extends StatelessWidget {
  _SearchInfo({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  _SearchResultTile({required this.item, required this.onTap});

  final _DmSearchEntry item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl?.trim();
    final hasImage =
        imageUrl != null &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
            child: hasImage
                ? null
                : Icon(
                    item.type == _DmSearchEntryType.musician
                        ? Icons.person_outline
                        : Icons.storefront_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
          ),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final DmConversationPreview item;

  _ConversationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasUnread = item.lastMessageRead == false;
    final avatar = item.otherUserProfilePicture?.trim();
    final hasAvatar =
        avatar != null &&
        (avatar.startsWith('http://') || avatar.startsWith('https://'));
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasUnread
                  ? AppColors.coralLight
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
                child: hasAvatar
                    ? null
                    : Icon(
                        Icons.person_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
              SizedBox(width: 12),
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
                        SizedBox(width: 8),
                        Text(
                          _formatDate(item.lastMessageAt),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      item.lastMessageContent?.trim().isNotEmpty == true
                          ? item.lastMessageContent!.trim()
                          : 'Mesaj yok',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              if (hasUnread)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.coralLight,
                    shape: BoxShape.circle,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _MusicJoinTableTile extends StatelessWidget {
  final TableGroup table;
  final VoidCallback onTap;

  const _MusicJoinTableTile({required this.table, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final venueName = (table.venueName ?? '').trim();
    final ownerName = (table.ownerUsername ?? '').trim();
    final subtitle = ownerName.isNotEmpty ? ownerName : 'Masa sahibi';
    final avatar = table.ownerProfileImageUrl?.trim();
    final hasAvatar =
        avatar != null &&
        (avatar.startsWith('http://') || avatar.startsWith('https://'));
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
                child: hasAvatar
                    ? null
                    : Icon(
                        Icons.groups_2_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venueName.isNotEmpty
                          ? venueName
                          : 'Müzik Birleştirir! masası',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _participantSummary(table),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _participantSummary(TableGroup table) {
    final accepted = table.participants
        .where((p) => p.status == TableGroupParticipantStatus.accepted)
        .length;
    return '$accepted/${table.maxPersonCount} kisi';
  }
}

class _FailureState extends StatelessWidget {
  _FailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 30,
          ),
          SizedBox(height: 14),
          Text(
            'Henuz konusma yok',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Yukaridaki arama kutusundan mesajlasmak istedigin kisiyi bul.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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

  _DmSearchEntry({
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
