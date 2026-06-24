import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../dm/data/dm_auth_support.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/entities/table_group_participant.dart';
import '../../domain/entities/table_group.dart';
import 'table_group_detail_screen.dart';
import 'table_group_route_args.dart';
import '../cubit/table_group_list_cubit.dart';
import '../cubit/table_group_list_state.dart';

part 'table_group_list_screen_widgets.dart';

class TableGroupListScreen extends StatelessWidget {
  final TableGroupListArgs args;

  TableGroupListScreen({
    super.key,
    this.args = const TableGroupListArgs(),
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<TableGroupListCubit>()..initialize(),
      child: _TableGroupListView(args: args),
    );
  }
}

class _TableGroupListView extends StatefulWidget {
  final TableGroupListArgs args;

  _TableGroupListView({required this.args});

  @override
  State<_TableGroupListView> createState() => _TableGroupListViewState();
}

class _TableGroupListViewState extends State<_TableGroupListView> {
  final ScrollController _scrollController = ScrollController();
  Offset _fabOffset = Offset.zero;
  String? _currentUserId;
  bool _resolvingCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _ensureCurrentUserId();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 180;
    if (_scrollController.position.pixels >= threshold) {
      context.read<TableGroupListCubit>().loadMore();
    }
  }

  Future<void> _ensureCurrentUserId() async {
    if (_currentUserId != null || _resolvingCurrentUser) return;
    _resolvingCurrentUser = true;
    final tokenStore = serviceLocator<TokenStore>();
    _currentUserId = await resolveCurrentUserId(tokenStore);
    _resolvingCurrentUser = false;
  }

  bool _canOpenDetail(TableGroup group) {
    final currentUserId = _currentUserId?.trim();
    if (currentUserId == null || currentUserId.isEmpty) return false;
    if (group.ownerId == currentUserId) return true;
    for (final participant in group.participants) {
      if (participant.userId == currentUserId &&
          participant.status == TableGroupParticipantStatus.accepted) {
        return true;
      }
    }
    return false;
  }

  TableGroupParticipantStatus? _myParticipantStatus(TableGroup group) {
    final currentUserId = _currentUserId?.trim();
    if (currentUserId == null || currentUserId.isEmpty) return null;
    for (final participant in group.participants) {
      if (participant.userId == currentUserId) {
        return participant.status;
      }
    }
    return null;
  }

  Future<void> _showJoinPendingInfo() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bilgilendirme'),
        content: Text(
          "Masaya katılma talebin şu an beklemede. Kabul edildiğinde ya da reddedildiğinde sana hemen haber vereceğiz. Durumu 'Mesajlar > Müzik Birleştirir!' kısmından kontrol edebilirsin.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _showApplyRequiredInfo() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bilgilendirme'),
        content: Text('Bu masaya katılmak için başvuru göndermelisin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetailIfAllowed(TableGroup group) async {
    await _ensureCurrentUserId();
    if (!_canOpenDetail(group)) {
      final myStatus = _myParticipantStatus(group);
      if (myStatus == TableGroupParticipantStatus.pending) {
        await _showJoinPendingInfo();
      } else {
        await _showApplyRequiredInfo();
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRoutes.tableGroupDetail,
      arguments: TableGroupDetailArgs(
        tableGroupId: group.id,
        bottomBarStageMode: widget.args.bottomBarStageMode,
      ),
    );
    if (!mounted) return;
    context.read<TableGroupListCubit>().reload();
  }

  Future<void> _openJoinSheet(TableGroup group) async {
    final noteController = TextEditingController();
    final shouldJoin = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Masaya katilim notu',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLength: 256,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ornek: 21:00 gibi oradayim',
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gradientC,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text('Basvuru Gonder'),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(
                  'Vazgec',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (shouldJoin != true || !mounted) return;

    final ok = await context.read<TableGroupListCubit>().joinTableGroup(
      tableGroupId: group.id,
      note: noteController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Katilim istegi gonderildi' : 'Katilim istegi gonderilemedi',
        ),
      ),
    );
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
                final String? cityValue =
                    state.cities.any((city) => city.id == state.selectedCityId)
                    ? state.selectedCityId
                    : null;
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
                      value: cityValue,
                      decoration: _filterInputDecoration(context, 'Sehir sec'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      dropdownColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      iconEnabledColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      items: state.cities
                          .map(
                            (city) => DropdownMenuItem<String>(
                              value: city.id,
                              child: Text(city.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          context.read<TableGroupListCubit>().setCity(value),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: districtValue,
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
                          child: Text('Tum Ilceler'),
                        ),
                        ...state.districts.map(
                          (district) => DropdownMenuItem<String?>(
                            value: district.id,
                            child: Text(district.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => context
                          .read<TableGroupListCubit>()
                          .setDistrict(value),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: neighborhoodValue,
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
                          child: Text('Tum Mahalleler'),
                        ),
                        ...state.neighborhoods.map(
                          (neighborhood) => DropdownMenuItem<String?>(
                            value: neighborhood.id,
                            child: Text(neighborhood.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => context
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
    if (state.selectedDistrictId == null &&
        state.selectedNeighborhoodId == null) {
      return 'Tumu';
    }
    if (state.selectedNeighborhoodId != null) return 'Mahalle';
    return 'Ilce';
  }

  String _formatHour(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _weekday(DateTime? value) {
    if (value == null) return 'Bugun';
    switch (value.toLocal().weekday) {
      case DateTime.monday:
        return 'Pazartesi';
      case DateTime.tuesday:
        return 'Sali';
      case DateTime.wednesday:
        return 'Carsamba';
      case DateTime.thursday:
        return 'Persembe';
      case DateTime.friday:
        return 'Cuma';
      case DateTime.saturday:
        return 'Cumartesi';
      case DateTime.sunday:
        return 'Pazar';
      default:
        return 'Bugun';
    }
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
      listener: (context, state) {
        if (state.status == TableGroupListStatus.failure &&
            state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!.message)));
        }
      },
      builder: (context, state) {
        final loading = state.status == TableGroupListStatus.loading;
        final currentUserProfileImage = _resolveCurrentUserProfileImage(state);
        final screenSize = MediaQuery.sizeOf(context);
        final fabSize = Size(130, 126);
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(width: 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Müzik Birleştirir!',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 30,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Hadi sana bir masa bulalim',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _openFilterSheet,
                            icon: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: AppColors.brandGradient,
                              ).createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: Icon(
                                Icons.tune_rounded,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Filtreler:',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _filterLabel(state),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    context
                                        .read<TableGroupListCubit>()
                                        .setDistrict(null);
                                    context
                                        .read<TableGroupListCubit>()
                                        .setNeighborhood(null);
                                  },
                                  child: Icon(
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
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () =>
                            context.read<TableGroupListCubit>().reload(),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(12, 4, 12, 110),
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
                              return Padding(
                                padding: EdgeInsets.only(top: 130),
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
                              onApply: () => _openJoinSheet(group),
                              onOpenDetail: () async {
                                await _openDetailIfAllowed(group);
                              },
                              joining: state.joiningIds.contains(group.id),
                              timeText: _formatHour(group.expiresAt),
                              dayText: _weekday(group.expiresAt),
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
                Positioned(
                  left: fabLeft,
                  top: fabTop,
                  child: _CreateTableFab(
                    onTap: () async {
                      final created = await Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.tableGroupCreate);
                      if (created == true && context.mounted) {
                        context.read<TableGroupListCubit>().reload();
                      }
                    },
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
        );
      },
    );
  }
}
