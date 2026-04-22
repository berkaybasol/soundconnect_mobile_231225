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
    shape: RoundedRectangleBorder(
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

  _ConnectedArtistRequestSheet({
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
  List<MusicianSearchOption> _results = <MusicianSearchOption>[];

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
      duration: Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.84,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Baglantili Muzisyenleri Duzenle',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Muzisyen ara...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onQueryChanged,
                ),
                SizedBox(height: 10),
                if (_loading) LinearProgressIndicator(),
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
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
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
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: checked
                                        ? Colors.transparent
                                        : Theme.of(context).dividerColor
                                              .withValues(alpha: 0.45),
                                  ),
                                  gradient: checked
                                      ? LinearGradient(
                                          colors: [
                                            Color(0x22FF7A3D),
                                            Color(0x22EF5F86),
                                            Color(0x22B85CFF),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: checked
                                      ? null
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
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
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.55),
                                        ),
                                        gradient: checked
                                            ? LinearGradient(
                                                colors: [
                                                  AppColors.socialOrange,
                                                  AppColors.socialPink,
                                                  AppColors.socialPurple,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                      ),
                                      child: checked
                                          ? Icon(
                                              Icons.check,
                                              size: 15,
                                              color: AppColors.white,
                                            )
                                          : null,
                                    ),
                                    SizedBox(width: 12),
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainer,
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
                                          ? Icon(
                                              Icons.person_outline,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              size: 18,
                                            )
                                          : null,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.displayName,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(
                                                    alpha: disabled ? 0.55 : 1,
                                                  ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (item.secondaryLabel != null) ...[
                                            SizedBox(height: 2),
                                            Text(
                                              item.secondaryLabel!,
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (disabled) ...[
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .dividerColor
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Text(
                                          isPending ? 'Beklemede' : 'Bagli',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
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
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Iptal'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _continue,
                        child: Text('Devam'),
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
