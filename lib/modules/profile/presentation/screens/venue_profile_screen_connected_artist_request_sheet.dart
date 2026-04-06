part of 'venue_profile_screen.dart';

Future<MusicianRequestPayload?> showConnectedArtistRequestBottomSheet({
  required BuildContext context,
  required Set<String> acceptedIds,
  required Set<String> pendingIds,
  required Future<List<MusicianSearchOption>> Function(String query)
  searchMusicians,
}) {
  return showModalBottomSheet<MusicianRequestPayload>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navBlueDeep,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ConnectedArtistRequestSheet(
      acceptedIds: acceptedIds,
      pendingIds: pendingIds,
      searchMusicians: searchMusicians,
    ),
  );
}

class _ConnectedArtistRequestSheet extends StatefulWidget {
  final Set<String> acceptedIds;
  final Set<String> pendingIds;
  final Future<List<MusicianSearchOption>> Function(String query)
  searchMusicians;

  const _ConnectedArtistRequestSheet({
    required this.acceptedIds,
    required this.pendingIds,
    required this.searchMusicians,
  });

  @override
  State<_ConnectedArtistRequestSheet> createState() =>
      _ConnectedArtistRequestSheetState();
}

class _ConnectedArtistRequestSheetState
    extends State<_ConnectedArtistRequestSheet> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedMusicianId;
  Timer? _searchDebounce;
  int _searchToken = 0;
  bool _loading = false;
  String _searchError = '';
  String _query = '';
  List<MusicianSearchOption> _results = const <MusicianSearchOption>[];

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.84,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Baglantili Muzisyenleri Duzenle',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Muzisyen ara...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onQueryChanged,
                ),
                const SizedBox(height: 10),
                if (_loading) const LinearProgressIndicator(),
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            _query.length < 2
                                ? 'Bir muzisyen aramak icin en az 2 karakter yaz.'
                                : _searchError.isNotEmpty
                                ? _searchError
                                : 'Sonuc bulunamadi.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            final checked =
                                _selectedMusicianId == item.profileId;
                            final isAccepted = widget.acceptedIds.contains(
                              item.profileId,
                            );
                            final isPending = widget.pendingIds.contains(
                              item.profileId,
                            );
                            final disabled = isAccepted || isPending;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _toggleSelection(item),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: checked
                                        ? Colors.transparent
                                        : AppColors.border.withValues(
                                            alpha: 0.45,
                                          ),
                                  ),
                                  gradient: checked
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0x22FF7A3D),
                                            Color(0x22EF5F86),
                                            Color(0x22B85CFF),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: checked ? null : AppColors.inputFill,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: checked
                                              ? Colors.transparent
                                              : AppColors.textMuted.withValues(
                                                  alpha: 0.55,
                                                ),
                                        ),
                                        gradient: checked
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF7A3D),
                                                  Color(0xFFEF5F86),
                                                  Color(0xFFB85CFF),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                      ),
                                      child: checked
                                          ? const Icon(
                                              Icons.check,
                                              size: 15,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.navBlueSoft,
                                      backgroundImage:
                                          isValidNetworkImageUrl(
                                            item.profilePictureUrl,
                                          )
                                          ? NetworkImage(
                                              item.profilePictureUrl!,
                                            )
                                          : null,
                                      child:
                                          !isValidNetworkImageUrl(
                                            item.profilePictureUrl,
                                          )
                                          ? const Icon(
                                              Icons.person_outline,
                                              color: AppColors.textMuted,
                                              size: 18,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.displayName,
                                            style: TextStyle(
                                              color: AppColors.textPrimary
                                                  .withValues(
                                                    alpha: disabled ? 0.55 : 1,
                                                  ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (item.secondaryLabel != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.secondaryLabel!,
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (disabled) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.inputFill,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          isPending ? 'Beklemede' : 'Bagli',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Iptal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _continue,
                        child: const Text('Devam'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
