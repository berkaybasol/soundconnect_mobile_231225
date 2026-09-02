import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/access_policy.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../dm/data/dm_auth_support.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/entities/table_group.dart';
import '../../domain/table_group_expiry_policy.dart';
import 'table_group_detail_screen.dart';
import 'table_group_route_args.dart';
import '../cubit/table_group_list_cubit.dart';
import '../cubit/table_group_list_state.dart';
import '../widgets/table_group_overview_style.dart';

part 'table_group_list_screen_widgets.dart';

class TableGroupListScreen extends StatelessWidget {
  final TableGroupListArgs args;
  final DateTime Function() now;

  TableGroupListScreen({
    super.key,
    this.args = const TableGroupListArgs(),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<TableGroupListCubit>()..initialize(),
      child: _TableGroupListView(args: args, now: now),
    );
  }
}

class _TableGroupListView extends StatefulWidget {
  final TableGroupListArgs args;
  final DateTime Function() now;

  _TableGroupListView({required this.args, required this.now});

  @override
  State<_TableGroupListView> createState() => _TableGroupListViewState();
}

class _TableGroupListViewState extends State<_TableGroupListView>
    with WidgetsBindingObserver {
  static const String _allCitiesFilterValue = '__all_cities__';
  final ScrollController _scrollController = ScrollController();
  Offset _fabOffset = Offset.zero;
  String? _currentUserId;
  bool _currentUserResolved = false;
  Future<void>? _currentUserResolutionInFlight;
  late final TableGroupLocalDayRefreshScheduler _dayRefreshScheduler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _dayRefreshScheduler = TableGroupLocalDayRefreshScheduler(
      now: widget.now,
      onRefresh: () {
        if (mounted) setState(() {});
      },
    )..start();
    unawaited(_ensureCurrentUserId());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayRefreshScheduler.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dayRefreshScheduler.reschedule(refresh: true);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 180;
    if (_scrollController.position.pixels >= threshold) {
      context.read<TableGroupListCubit>().loadMore();
    }
  }

  Future<void> _ensureCurrentUserId() {
    if (_currentUserResolved) return Future<void>.value();
    final inFlight = _currentUserResolutionInFlight;
    if (inFlight != null) return inFlight;
    final future = _resolveCurrentUserId();
    _currentUserResolutionInFlight = future;
    return future.whenComplete(() {
      if (identical(_currentUserResolutionInFlight, future)) {
        _currentUserResolutionInFlight = null;
      }
    });
  }

  Future<void> _resolveCurrentUserId() async {
    String? userId;
    try {
      final tokenStore = serviceLocator<TokenStore>();
      userId = await resolveCurrentUserId(tokenStore);
    } catch (_) {
      userId = null;
    }
    if (!mounted) return;
    setState(() {
      _currentUserId = userId?.trim().isNotEmpty == true ? userId : null;
      _currentUserResolved = true;
    });
  }

  Future<void> _openDetail(TableGroup group) async {
    await _ensureCurrentUserId();
    if ((_currentUserId ?? '').trim().isEmpty) {
      _showSessionRequired();
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.tableGroupDetail,
      arguments: TableGroupDetailArgs(
        tableGroupId: group.id,
        bottomBarStageMode: widget.args.bottomBarStageMode,
        openChat: false,
      ),
    );
    if (!mounted) return;
    context.read<TableGroupListCubit>().reload();
  }

  void _showSessionRequired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Oturum bilgisi dogrulanamadi. Lutfen tekrar giris yap.'),
      ),
    );
  }

  void _showPersonalIdentityRequired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Masa oluşturma ve katılma işlemleri kişisel hesaplarla kullanılabilir.',
        ),
      ),
    );
  }

  bool get _canCreateOrJoin {
    try {
      return AccessPolicy.canCreateOrJoinTableGroups(
        serviceLocator<AuthSessionManager>().session.roles,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _openCreate() async {
    if (!_canCreateOrJoin) {
      _showPersonalIdentityRequired();
      return;
    }
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.tableGroupCreate);
    if (!mounted) return;
    final cubit = context.read<TableGroupListCubit>();
    if (result case TableGroupCreateResult(:final cityId)) {
      if (cubit.state.selectedCityId == null) {
        await cubit.reload();
      } else {
        await cubit.setCity(cityId);
      }
    } else if (result == true) {
      await cubit.reload();
    }
  }

  Future<void> _openFilterSheet() async {
    final tableGroupCubit = context.read<TableGroupListCubit>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return BlocProvider<TableGroupListCubit>.value(
          value: tableGroupCubit,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 20),
            child: BlocBuilder<TableGroupListCubit, TableGroupListState>(
              builder: (context, state) {
                final String cityValue =
                    state.cities.any((city) => city.id == state.selectedCityId)
                    ? state.selectedCityId!
                    : _allCitiesFilterValue;
                final String? districtValue =
                    state.districts.any(
                      (district) => district.id == state.selectedDistrictId,
                    )
                    ? state.selectedDistrictId
                    : null;
                final String? neighborhoodValue =
                    state.neighborhoods.any(
                      (neighborhood) =>
                          neighborhood.id == state.selectedNeighborhoodId,
                    )
                    ? state.selectedNeighborhoodId
                    : null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Filtreler',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('table_group_filter_city'),
                      value: cityValue,
                      isExpanded: true,
                      decoration: _filterInputDecoration(context, 'Şehir seç'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      dropdownColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      iconEnabledColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      items: [
                        const DropdownMenuItem<String>(
                          value: _allCitiesFilterValue,
                          child: Text(
                            'Tüm şehirler',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...state.cities.map(
                          (city) => DropdownMenuItem<String>(
                            value: city.id,
                            child: Text(
                              city.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          context.read<TableGroupListCubit>().setCity(
                            value == _allCitiesFilterValue ? null : value,
                          ),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      key: const Key('table_group_filter_district'),
                      value: districtValue,
                      isExpanded: true,
                      decoration: _filterInputDecoration(context, 'Ilce sec'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      dropdownColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      iconEnabledColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Tum Ilceler',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...state.districts.map(
                          (district) => DropdownMenuItem<String?>(
                            value: district.id,
                            child: Text(
                              district.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: state.selectedCityId == null
                          ? null
                          : (value) => context
                                .read<TableGroupListCubit>()
                                .setDistrict(value),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      key: const Key('table_group_filter_neighborhood'),
                      value: neighborhoodValue,
                      isExpanded: true,
                      decoration: _filterInputDecoration(
                        context,
                        'Mahalle sec',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      dropdownColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      iconEnabledColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Tum Mahalleler',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...state.neighborhoods.map(
                          (neighborhood) => DropdownMenuItem<String?>(
                            value: neighborhood.id,
                            child: Text(
                              neighborhood.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: state.selectedDistrictId == null
                          ? null
                          : (value) => context
                                .read<TableGroupListCubit>()
                                .setNeighborhood(value),
                    ),
                    SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gradientC,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Kapat'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  InputDecoration _filterInputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.gradientC, width: 1.2),
      ),
    );
  }

  String _filterLabel(TableGroupListState state) {
    final neighborhoodId = state.selectedNeighborhoodId;
    if (neighborhoodId != null) {
      for (final neighborhood in state.neighborhoods) {
        if (neighborhood.id == neighborhoodId) return neighborhood.name;
      }
      return 'Mahalle';
    }
    final districtId = state.selectedDistrictId;
    if (districtId != null) {
      for (final district in state.districts) {
        if (district.id == districtId) return district.name;
      }
      return 'İlçe';
    }
    final cityId = state.selectedCityId;
    if (cityId != null) {
      for (final city in state.cities) {
        if (city.id == cityId) return city.name;
      }
      return 'Şehir';
    }
    return 'Tümü';
  }

  bool _hasActiveFilters(TableGroupListState state) =>
      state.selectedCityId != null ||
      state.selectedDistrictId != null ||
      state.selectedNeighborhoodId != null;

  String _tableCountLabel(TableGroupListState state) {
    final totalElements = state.totalElements;
    if (totalElements != null) return '$totalElements masa';
    final loadedCount = state.items.length;
    return state.hasNext ? '$loadedCount+ masa' : '$loadedCount masa';
  }

  String _timeLabel(DateTime? value) {
    return formatTableGroupMeetingAt(value, now: widget.now());
  }

  String? _resolveCurrentUserProfileImage(TableGroupListState state) {
    final userId = (_currentUserId ?? '').trim();
    if (userId.isEmpty) return null;
    for (final group in state.items) {
      if (group.ownerId == userId) {
        final ownerImage = _validUrlOrNull(group.ownerProfileImageUrl);
        if (ownerImage != null) return ownerImage;
      }
      for (final participant in group.participants) {
        if (participant.userId != userId) continue;
        final participantImage = _validUrlOrNull(participant.profilePictureUrl);
        if (participantImage != null) return participantImage;
      }
    }
    return null;
  }

  String? _validUrlOrNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TableGroupListCubit, TableGroupListState>(
      listenWhen: (previous, current) =>
          current.status == TableGroupListStatus.failure &&
          current.error != null &&
          !(current.items.isEmpty && current.feedError != null) &&
          (previous.status != current.status ||
              previous.error != current.error),
      listener: (context, state) {
        if (state.status == TableGroupListStatus.failure &&
            state.error != null &&
            !(state.items.isEmpty && state.feedError != null)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!.message)));
        }
      },
      builder: (context, state) {
        final loading = state.status == TableGroupListStatus.loading;
        final canCreateOrJoin = _canCreateOrJoin;
        final currentUserProfileImage = _resolveCurrentUserProfileImage(state);
        final screenSize = MediaQuery.sizeOf(context);
        final fabSize = Size(145, 130);
        final baseFab = Offset(
          screenSize.width - fabSize.width - 16,
          screenSize.height - fabSize.height - 98,
        );
        final fabLeft = (baseFab.dx + _fabOffset.dx).clamp(
          8.0,
          screenSize.width - fabSize.width - 8,
        );
        final fabTop = (baseFab.dy + _fabOffset.dy).clamp(
          72.0,
          screenSize.height - fabSize.height - 8,
        );

        return Scaffold(
          backgroundColor: TableGroupOverviewStyle.pageBase,
          body: TableGroupOverviewBackdrop(
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(5, 6, 5, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: TableGroupOverviewStyle.bodyMuted,
                                      size: 28,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    key: const Key('table_group_open_filters'),
                                    onPressed: _openFilterSheet,
                                    icon: ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: TableGroupOverviewStyle
                                                .brandGradient,
                                          ).createShader(bounds),
                                      blendMode: BlendMode.srcIn,
                                      child: const Icon(
                                        Icons.tune_rounded,
                                        color: AppColors.white,
                                        size: 29,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(23, 14, 23, 0),
                              child: Text(
                                'Müzik Birleştirir!',
                                key: Key('table_group_hero_title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: TableGroupOverviewStyle.warmHeading,
                                  fontSize: 34,
                                  height: 1.02,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(23, 6, 23, 0),
                              child: Text(
                                'Hadi sana bir masa bulalim',
                                key: Key('table_group_hero_subtitle'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: TableGroupOverviewStyle.bodyMuted,
                                  fontSize: 17,
                                  height: 1.25,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Açık Masalar',
                                key: Key('table_group_section_title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: TableGroupOverviewStyle.headingMuted,
                                  fontSize: 23,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              key: const Key('table_group_count_pill'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111B2A),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: TableGroupOverviewStyle.cardBorder,
                                ),
                              ),
                              child: Text(
                                _tableCountLabel(state),
                                key: const Key('table_group_count_label'),
                                maxLines: 1,
                                style: const TextStyle(
                                  color: TableGroupOverviewStyle.primaryText,
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_hasActiveFilters(state))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Filtreler:',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                flex: 3,
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(12, 0, 0, 0),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _filterLabel(state),
                                          key: const Key(
                                            'table_group_filter_label',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      IconButton(
                                        key: const Key(
                                          'table_group_clear_filters',
                                        ),
                                        tooltip: 'Tüm filtreleri temizle',
                                        onPressed: () => context
                                            .read<TableGroupListCubit>()
                                            .setCity(null),
                                        constraints: const BoxConstraints(
                                          minWidth: 48,
                                          minHeight: 48,
                                        ),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () =>
                              context.read<TableGroupListCubit>().refresh(),
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 110),
                            itemCount: loading
                                ? 1
                                : state.items.isEmpty
                                ? 1
                                : state.items.length +
                                      (state.status ==
                                              TableGroupListStatus.loadingMore
                                          ? 1
                                          : 0),
                            itemBuilder: (context, index) {
                              if (loading) {
                                return Padding(
                                  padding: EdgeInsets.only(top: 120),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (state.items.isEmpty) {
                                final feedError = state.feedError;
                                if (feedError != null) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      110,
                                      24,
                                      0,
                                    ),
                                    child: Center(
                                      child: Column(
                                        key: const Key(
                                          'table_group_feed_error',
                                        ),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.cloud_off_rounded,
                                            size: 42,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            feedError.message,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          FilledButton.icon(
                                            key: const Key(
                                              'table_group_retry_feed',
                                            ),
                                            onPressed: () => context
                                                .read<TableGroupListCubit>()
                                                .refresh(),
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                            ),
                                            label: const Text('Tekrar dene'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 130),
                                  child: Center(
                                    child: Text(
                                      'Bu filtrede aktif masa bulunamadi',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              if (index >= state.items.length) {
                                return Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final group = state.items[index];
                              return _TableGroupListCard(
                                group: group,
                                onOpenDetail: () async {
                                  await _openDetail(group);
                                },
                                meetingTimeText: _timeLabel(group.meetingAt),
                              );
                            },
                          ),
                        ),
                      ),
                      ProfilePublicBottomBar(
                        currentIndex: 2,
                        profileImageUrl: currentUserProfileImage,
                        stageMode: widget.args.bottomBarStageMode,
                      ),
                    ],
                  ),
                  if (canCreateOrJoin)
                    Positioned(
                      left: fabLeft,
                      top: fabTop,
                      child: _CreateTableFab(
                        onTap: _openCreate,
                        onDragDelta: (delta) {
                          setState(() {
                            _fabOffset += delta;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
