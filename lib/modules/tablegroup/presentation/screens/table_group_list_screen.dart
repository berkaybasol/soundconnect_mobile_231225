import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/table_group_participant.dart';
import '../../domain/entities/table_group.dart';
import '../cubit/table_group_list_cubit.dart';
import '../cubit/table_group_list_state.dart';

class TableGroupListScreen extends StatelessWidget {
  const TableGroupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<TableGroupListCubit>()..initialize(),
      child: const _TableGroupListView(),
    );
  }
}

class _TableGroupListView extends StatefulWidget {
  const _TableGroupListView();

  @override
  State<_TableGroupListView> createState() => _TableGroupListViewState();
}

class _TableGroupListViewState extends State<_TableGroupListView> {
  final ScrollController _scrollController = ScrollController();
  Offset _fabOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  Future<void> _openJoinSheet(TableGroup group) async {
    final noteController = TextEditingController();
    final shouldJoin = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
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
              const Text(
                'Masaya katilim notu',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ornek: 21:00 gibi oradayim',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gradientC,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Basvuru Gonder'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text(
                  'Vazgec',
                  style: TextStyle(color: AppColors.textMuted),
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          child: BlocBuilder<TableGroupListCubit, TableGroupListState>(
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filtreler',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: state.selectedCityId,
                    decoration: _filterInputDecoration('Sehir sec'),
                    style: const TextStyle(color: AppColors.textPrimary),
                    dropdownColor: AppColors.navBlueSoft,
                    iconEnabledColor: AppColors.textMuted,
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
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: state.selectedDistrictId,
                    decoration: _filterInputDecoration('Ilce sec'),
                    style: const TextStyle(color: AppColors.textPrimary),
                    dropdownColor: AppColors.navBlueSoft,
                    iconEnabledColor: AppColors.textMuted,
                    items: [
                      const DropdownMenuItem<String?>(
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
                    onChanged: (value) =>
                        context.read<TableGroupListCubit>().setDistrict(value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: state.selectedNeighborhoodId,
                    decoration: _filterInputDecoration('Mahalle sec'),
                    style: const TextStyle(color: AppColors.textPrimary),
                    dropdownColor: AppColors.navBlueSoft,
                    iconEnabledColor: AppColors.textMuted,
                    items: [
                      const DropdownMenuItem<String?>(
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
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gradientC,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Kapat'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static InputDecoration _filterInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.inputFill,
      hintStyle: const TextStyle(color: AppColors.textMuted),
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
        borderSide: const BorderSide(color: AppColors.gradientC, width: 1.2),
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
        final screenSize = MediaQuery.sizeOf(context);
        const fabSize = Size(130, 126);
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
          backgroundColor: AppColors.navBlue,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Muzik Birlestir!',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 30,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Hadi sana bir masa bulalim',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _openFilterSheet,
                            icon: const Icon(
                              Icons.tune_rounded,
                              color: AppColors.gradientC,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          const Text(
                            'Filtreler:',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.inputFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _filterLabel(state),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    context
                                        .read<TableGroupListCubit>()
                                        .setDistrict(null);
                                    context
                                        .read<TableGroupListCubit>()
                                        .setNeighborhood(null);
                                  },
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: AppColors.textPrimary,
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
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
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
                              return const Padding(
                                padding: EdgeInsets.only(top: 120),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (state.items.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 130),
                                child: Center(
                                  child: Text(
                                    'Bu filtrede aktif masa bulunamadi',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (index >= state.items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(14),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final group = state.items[index];
                            return _TableGroupListCard(
                              group: group,
                              onTap: () => _openJoinSheet(group),
                              joining: state.joiningIds.contains(group.id),
                              timeText: _formatHour(group.expiresAt),
                              dayText: _weekday(group.expiresAt),
                            );
                          },
                        ),
                      ),
                    ),
                    const _BottomNavMock(),
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

class _TableGroupListCard extends StatelessWidget {
  final TableGroup group;
  final VoidCallback onTap;
  final bool joining;
  final String timeText;
  final String dayText;

  const _TableGroupListCard({
    required this.group,
    required this.onTap,
    required this.joining,
    required this.timeText,
    required this.dayText,
  });

  @override
  Widget build(BuildContext context) {
    final venue = group.venueName?.trim().isNotEmpty == true
        ? group.venueName!.trim()
        : 'Mekan belirtilmedi';
    final username = _resolveUsername(group);
    final avatarUrl = _validUrlOrNull(group.ownerProfileImageUrl);
    final initials = _initialsFrom(username);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: joining ? null : onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: AppColors.navBlueSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.brandGradient,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: AppColors.inputFill,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GradientVenueText(text: venue),
                    const SizedBox(height: 2),
                    Text(
                      username,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_2_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '+${(group.acceptedCount - 1).clamp(0, 99)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          timeText,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            dayText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MiniAvatars(
                participants: group.participants,
                ownerId: group.ownerId,
                maxPersonCount: group.maxPersonCount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveUsername(TableGroup group) {
    final fromBackend = group.ownerUsername?.trim();
    if (fromBackend != null && fromBackend.isNotEmpty) return fromBackend;
    final owner = group.ownerId.trim();
    if (owner.isEmpty) return 'Kullanici';
    return owner.length <= 8 ? owner : owner.substring(0, 8);
  }

  String _initialsFrom(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final first = words.first;
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.toUpperCase();
    }
    return (words.first[0] + words[1][0]).toUpperCase();
  }

  String? _validUrlOrNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    return text;
  }
}

class _GradientVenueText extends StatelessWidget {
  final String text;

  const _GradientVenueText({required this.text});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          height: 1.05,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationThickness: 1.0,
        ),
      ),
    );
  }
}

class _MiniAvatars extends StatelessWidget {
  final List<TableGroupParticipant> participants;
  final String ownerId;
  final int maxPersonCount;

  const _MiniAvatars({
    required this.participants,
    required this.ownerId,
    required this.maxPersonCount,
  });

  @override
  Widget build(BuildContext context) {
    final acceptedGuests =
        participants
            .where(
              (p) =>
                  p.status == TableGroupParticipantStatus.accepted &&
                  p.userId != ownerId,
            )
            .toList()
          ..sort((a, b) {
            final at = a.joinedAt?.millisecondsSinceEpoch ?? 0;
            final bt = b.joinedAt?.millisecondsSinceEpoch ?? 0;
            return at.compareTo(bt);
          });

    final slotCount = (maxPersonCount - 1).clamp(0, 5);
    final shown = acceptedGuests.take(slotCount).toList();

    return SizedBox(
      width: 74,
      height: 30,
      child: Stack(
        children: [
          for (int i = 0; i < slotCount; i++)
            Positioned(
              left: i * 12,
              top: 2,
              child: i < shown.length
                  ? _FilledParticipantAvatar(participant: shown[i])
                  : const _EmptyParticipantSlot(),
            ),
        ],
      ),
    );
  }
}

class _FilledParticipantAvatar extends StatelessWidget {
  final TableGroupParticipant participant;

  const _FilledParticipantAvatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _validUrlOrNull(participant.profilePictureUrl);
    final initials = _initialsFrom(
      participant.username?.trim().isNotEmpty == true
          ? participant.username!.trim()
          : participant.userId,
    );
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.navBlueSoft, width: 1.4),
      ),
      child: CircleAvatar(
        radius: 13,
        backgroundColor: AppColors.border,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
            ? Text(
                initials,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }

  String? _validUrlOrNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    return text;
  }

  String _initialsFrom(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final one = parts.first;
      return one.length >= 2
          ? one.substring(0, 2).toUpperCase()
          : one.toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

class _EmptyParticipantSlot extends StatelessWidget {
  const _EmptyParticipantSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: const Icon(
        Icons.add_rounded,
        size: 12,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _BottomNavMock extends StatelessWidget {
  const _BottomNavMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: const BoxDecoration(
        color: AppColors.navBlueDeep,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(Icons.list_alt_rounded, color: AppColors.textMuted, size: 26),
          Icon(Icons.show_chart_rounded, color: AppColors.textMuted, size: 26),
          Icon(
            Icons.mail_outline_rounded,
            color: AppColors.textMuted,
            size: 26,
          ),
          Icon(
            Icons.person_outline_rounded,
            color: AppColors.textMuted,
            size: 26,
          ),
        ],
      ),
    );
  }
}

class _CreateTableFab extends StatefulWidget {
  final Future<void> Function() onTap;
  final ValueChanged<Offset> onDragDelta;

  const _CreateTableFab({required this.onTap, required this.onDragDelta});

  @override
  State<_CreateTableFab> createState() => _CreateTableFabState();
}

class _CreateTableFabState extends State<_CreateTableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    _scale = Tween<double>(
      begin: 0.98,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: (details) => widget.onDragDelta(details.delta),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.navBlueSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Masa olusturmak\nicin buraya tiklayin',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient.last.withValues(alpha: 0.42),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.groups_2_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
