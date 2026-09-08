import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_summary.dart';
import '../../domain/entities/band_received_invitation.dart';
import 'band_profile_screen.dart';
import 'band_invite_decision_screen.dart';

class MyBandsScreenArgs {
  final List<String> bands;
  MyBandsScreenArgs({required this.bands});
}

class MyBandsScreen extends StatefulWidget {
  const MyBandsScreen({super.key});
  @override
  State<MyBandsScreen> createState() => _MyBandsScreenState();
}

class _MyBandsScreenState extends State<MyBandsScreen>
    with WidgetsBindingObserver {
  static const _pageSize = 20;
  late final BandRepository _repository = serviceLocator<BandRepository>();
  late final AuthSessionManager? _sessions =
      serviceLocator.isRegistered<AuthSessionManager>()
      ? serviceLocator<AuthSessionManager>()
      : null;
  AuthSession? _session;
  List<BandSummary> _bands = [];
  final List<BandReceivedInvitation> _invitations = [];
  int _bandGeneration = 0, _invitationGeneration = 0, _nextPage = 0, _total = 0;
  bool _loadingBands = false, _loadingInvitations = false, _hasNext = false;
  bool _bandsLoaded = false, _navigating = false;
  String? _bandError, _invitationError;
  int get _foundedBandCount =>
      _bands.where((band) => band.countsTowardCreationLimit == true).length;
  bool get _creationQuotaKnown =>
      _bandsLoaded &&
      _bands.every((band) => band.countsTowardCreationLimit != null);

  bool get _authorized =>
      _session?.isAuthenticated == true &&
      _session?.isActive == true &&
      (_session?.userId?.trim().isNotEmpty ?? false) &&
      _session!.hasAnyRole(const ['ROLE_MUSICIAN', 'MUSICIAN']);
  bool _current(AuthSession? session) =>
      mounted &&
      _authorized &&
      identical(session, _session) &&
      identical(session, _sessions?.session);

  @override
  void initState() {
    super.initState();
    _session = _sessions?.session;
    _sessions?.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    ++_bandGeneration;
    ++_invitationGeneration;
    _sessions?.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted || identical(_session, _sessions?.session)) return;
    setState(() {
      _session = _sessions?.session;
      ++_bandGeneration;
      ++_invitationGeneration;
      _bands = [];
      _bandsLoaded = false;
      _loadingBands = false;
      _bandError = null;
      _clearInvitations();
    });
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Child routes refresh on return, including a resume while they are open.
    if (state == AppLifecycleState.resumed && !_navigating) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    if (!_authorized || !mounted) return;
    await Future.wait([_loadBands(), _loadInvitations(reset: true)]);
  }

  Future<void> _loadBands() async {
    final session = _session;
    if (!_current(session)) return;
    final generation = ++_bandGeneration;
    setState(() {
      _loadingBands = true;
      _bandError = null;
    });
    try {
      final result = await _repository.getMyBands();
      if (!_current(session) || generation != _bandGeneration) return;
      if (!result.isSuccess || result.data == null) {
        throw StateError('Band read failed');
      }
      setState(() {
        _bands = result.data!;
        _bandsLoaded = true;
      });
    } catch (_) {
      if (_current(session) && generation == _bandGeneration) {
        setState(() => _bandError = 'Grupların yüklenemedi.');
      }
    } finally {
      if (_current(session) && generation == _bandGeneration) {
        setState(() => _loadingBands = false);
      }
    }
  }

  void _clearInvitations() {
    _invitations.clear();
    _nextPage = 0;
    _total = 0;
    _loadingInvitations = false;
    _hasNext = false;
    _invitationError = null;
  }

  Future<void> _loadInvitations({required bool reset}) async {
    final session = _session;
    if (!_current(session) || (!reset && (_loadingInvitations || !_hasNext))) {
      return;
    }
    final generation = reset ? ++_invitationGeneration : _invitationGeneration;
    final page = reset ? 0 : _nextPage;
    bool current() => _current(session) && generation == _invitationGeneration;
    setState(() {
      if (reset) _clearInvitations();
      _loadingInvitations = true;
      _invitationError = null;
    });
    try {
      final result = await _repository.getReceivedInvitations(
        page: page,
        size: _pageSize,
        expectedSessionKey: session!.userId!.trim(),
      );
      if (!current()) return;
      if (!result.isSuccess || result.data == null) {
        if (const {
          '401',
          '403',
          '9219',
          'unauthorized',
          'forbidden',
        }.contains(result.error?.code)) {
          _clearInvitations();
        }
        throw StateError('Invitation read failed');
      }
      final data = result.data!;
      if (data.page != page ||
          data.size != _pageSize ||
          data.totalElements < 0 ||
          data.items.length !=
              (data.totalElements - page * _pageSize).clamp(0, _pageSize) ||
          data.hasNext != ((page + 1) * _pageSize < data.totalElements) ||
          data.items.map((item) => item.bandId).toSet().length !=
              data.items.length ||
          data.items.any(
            (item) =>
                item.bandId.trim().isEmpty || item.bandName.trim().isEmpty,
          )) {
        throw const FormatException('Invalid invitation page');
      }
      final ids = _invitations.map((item) => item.bandId).toSet();
      if (!reset &&
          (data.totalElements != _total ||
              data.items.any((item) => ids.contains(item.bandId)))) {
        await _loadInvitations(reset: true);
        return;
      }
      setState(() {
        _invitations.addAll(data.items);
        _total = data.totalElements;
        _nextPage = page + 1;
        _hasNext = data.hasNext && _nextPage * _pageSize <= 100000;
      });
    } catch (_) {
      if (current()) {
        setState(() => _invitationError = 'Gelen davetler yüklenemedi.');
      }
    } finally {
      if (current()) setState(() => _loadingInvitations = false);
    }
  }

  Future<void> _open(Future<Object?> Function() navigate) async {
    if (!_current(_session) || _navigating) return;
    setState(() => _navigating = true);
    try {
      await navigate();
    } finally {
      if (mounted) {
        setState(() => _navigating = false);
        await _refresh();
      }
    }
  }

  Future<void> _openInvitation(BandReceivedInvitation invitation) {
    final sessionKey = _session?.userId;
    return _open(
      () => Navigator.of(context).push<Object?>(
        MaterialPageRoute(
          builder: (_) => BandInviteDecisionScreen(
            args: BandInviteDecisionScreenArgs(
              bandId: invitation.bandId,
              bandName: invitation.bandName,
              expectedSessionKey: sessionKey,
              invitationId: invitation.invitationId,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget box(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: child,
    );
    Widget section(String title, String count, IconData icon) => box(
      Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brandGradient[1], size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              count,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    Widget state(String text, {VoidCallback? retry, bool loading = false}) =>
        box(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                if (loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                if (retry != null)
                  TextButton(
                    onPressed: _navigating ? null : retry,
                    child: const Text('Tekrar dene'),
                  ),
              ],
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandlerim'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _authorized && !_navigating ? _refresh : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: !_authorized
            ? const Center(child: Text('Müzisyen hesabınla giriş yap.'))
            : RefreshIndicator(
                onRefresh: _navigating ? () async {} : _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: section(
                        'Grupların',
                        _bandsLoaded ? '${_bands.length} grup' : '—',
                        Icons.groups_outlined,
                      ),
                    ),
                    if (_bandError != null)
                      SliverToBoxAdapter(
                        child: state(_bandError!, retry: _loadBands),
                      ),
                    if (_loadingBands)
                      SliverToBoxAdapter(child: state('', loading: true)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: _bands.length,
                        itemBuilder: (context, index) {
                          final band = _bands[index];
                          return _BandListTile(
                            name: band.name,
                            picture: band.profilePictureUrl,
                            subtitle: 'Grup profili',
                            onTap: _navigating
                                ? null
                                : () => _open(
                                    () => Navigator.of(context).pushNamed(
                                      AppRoutes.bandProfile,
                                      arguments: BandProfileScreenArgs(
                                        bandId: band.id,
                                        viewMode: BandProfileViewMode.auto,
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: box(
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: GradientOutlineButton(
                            label: 'Grup oluştur',
                            leading: const Icon(Icons.add_rounded, size: 20),
                            onPressed:
                                !_navigating &&
                                    _bandsLoaded &&
                                    !_loadingBands &&
                                    _bandError == null &&
                                    _creationQuotaKnown &&
                                    _foundedBandCount < 3
                                ? () => _open(
                                    () => Navigator.of(
                                      context,
                                    ).pushNamed(AppRoutes.createBand),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (_bandsLoaded)
                      SliverToBoxAdapter(
                        child: state(
                          _creationQuotaKnown
                              ? 'Kurduğun gruplar: $_foundedBandCount / 3'
                              : 'Grup kurma hakkın doğrulanamadı. Listeyi yenile.',
                        ),
                      ),
                    if (_creationQuotaKnown && _foundedBandCount >= 3)
                      SliverToBoxAdapter(
                        child: state('En fazla 3 grup kurabilirsin.'),
                      ),
                    SliverToBoxAdapter(
                      child: section(
                        'Gelen Davetler',
                        '$_total',
                        Icons.mail_outline_rounded,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: _invitations.length,
                        itemBuilder: (context, index) {
                          final invitation = _invitations[index];
                          return _BandListTile(
                            name: invitation.bandName,
                            picture: invitation.profilePictureUrl,
                            subtitle: 'Grup daveti · Yanıtını bekliyor',
                            invitation: true,
                            onTap: _navigating
                                ? null
                                : () => _openInvitation(invitation),
                          );
                        },
                      ),
                    ),
                    if (_loadingInvitations)
                      SliverToBoxAdapter(child: state('', loading: true))
                    else if (_invitationError != null)
                      SliverToBoxAdapter(
                        child: state(
                          _invitationError!,
                          retry: () => _loadInvitations(reset: _nextPage == 0),
                        ),
                      )
                    else if (_invitations.isEmpty)
                      SliverToBoxAdapter(
                        child: state('Bekleyen grup davetin yok.'),
                      ),
                    if (_hasNext &&
                        !_loadingInvitations &&
                        _invitationError == null)
                      SliverToBoxAdapter(
                        child: box(
                          TextButton(
                            onPressed: _navigating
                                ? null
                                : () => _loadInvitations(reset: false),
                            child: const Text('Daha fazla göster'),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BandListTile extends StatelessWidget {
  const _BandListTile({
    required this.name,
    required this.picture,
    required this.subtitle,
    required this.onTap,
    this.invitation = false,
  });
  final String name, subtitle;
  final String? picture;
  final VoidCallback? onTap;
  final bool invitation;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget fallback(BuildContext _) => ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.groups_rounded, color: AppColors.brandGradient[1]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: .65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(1.3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: invitation
                        ? LinearGradient(colors: AppColors.brandGradient)
                        : null,
                  ),
                  child: ClipOval(
                    child: AppCachedNetworkImage(
                      imageUrl: picture,
                      width: 48,
                      height: 48,
                      cacheWidth: 144,
                      cacheHeight: 144,
                      placeholderBuilder: fallback,
                      errorBuilder: fallback,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
