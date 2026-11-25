import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/result.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../profile/presentation/navigation/profile_route_resolver.dart';
import '../../data/admin_user_directory_repository.dart';
import '../../domain/admin_user_directory.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_decision_reason_sheet.dart';
import '../widgets/admin_user_detail_view.dart';
import '../widgets/application_review_widgets.dart';

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    required this.repository,
    required this.access,
    required this.onAccessLost,
    this.frame,
    this.backLabel = 'Arama sonuçları',
  });
  final String userId;
  final AdminUserDirectoryRepository repository;
  final ValueListenable<bool> access;
  final VoidCallback onAccessLost;
  final AdminSubpageFrame? frame;
  final String backLabel;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailState();
}

class _AdminUserDetailState extends State<AdminUserDetailScreen>
    with WidgetsBindingObserver {
  Result<AdminUserDetail>? _result;
  int _request = 0;
  Timer? _refreshTimer;
  ModalRoute<dynamic>? _reasonRoute;
  bool _loading = false;
  bool _wasCurrent = false;
  bool _reloadOnReveal = false;
  bool _deciding = false;
  String? _decisionNotice;

  @override
  void initState() {
    super.initState();
    widget.access.addListener(_accessChanged);
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_result != null &&
          !_missingAccount(_result) &&
          !_loading &&
          _visible) {
        _load(quietly: true);
      }
    });
    if (widget.access.value) _load();
  }

  bool get _visible =>
      widget.access.value &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
      (ModalRoute.of(context)?.isCurrent == true ||
          _reasonRoute?.isCurrent == true);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) _load();
  }

  void _accessChanged() {
    if (!widget.access.value) {
      setState(() => _result = null);
      _closeReasonSheet();
    }
  }

  bool _missingAccount(Result<AdminUserDetail>? result) =>
      const {'404', '1001'}.contains(result?.error?.code);

  void _closeReasonSheet() {
    final sheet = _reasonRoute;
    if (sheet?.isActive == true) sheet!.navigator?.removeRoute(sheet);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) == true;
    if (!current && _wasCurrent && !_deciding) _reloadOnReveal = true;
    _wasCurrent = current;
    if (current && _reloadOnReveal) {
      _reloadOnReveal = false;
      _load();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.access.removeListener(_accessChanged);
    super.dispose();
  }

  Future<Result<AdminUserDetail>?> _load({bool quietly = false}) async {
    if (!widget.access.value) return null;
    final revision = ++_request;
    _loading = true;
    if (!quietly) setState(() => _result = null);
    final result = await widget.repository.detail(widget.userId);
    if (!mounted || !widget.access.value) return null;
    if (isAdminUsersAccessError(result.error)) {
      widget.onAccessLost();
      return null;
    }
    if (revision != _request) return null;
    _loading = false;
    setState(() => _result = result);
    if (_missingAccount(result) || result.data?.canManageAccess == false) {
      _closeReasonSheet();
    }
    return result;
  }

  bool get _canAct =>
      mounted &&
      widget.access.value &&
      _result?.data != null &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _copy(String value, String label) async {
    if (!_canAct) return;
    final detail = _result?.data;
    String message;
    AppSnackBarTone tone;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      message = '$label kopyalandı.';
      tone = AppSnackBarTone.success;
    } on PlatformException {
      message = '$label kopyalanamadı.';
      tone = AppSnackBarTone.error;
    }
    if (!_canAct || !mounted || !identical(detail, _result?.data)) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(context, content: Text(message), tone: tone));
  }

  Future<String?> _checkDecision(AdminUserDetail original) async {
    final sheet = _reasonRoute;
    final fresh = await _load(quietly: true);
    if (!mounted ||
        fresh == null ||
        sheet == null ||
        !identical(sheet, _reasonRoute) ||
        !sheet.isCurrent) {
      return 'Güncel hesap bilgilerini tekrar kontrol et.';
    }
    if (fresh.error case final error?) return error.message;
    final current = fresh.data!;
    if (!current.canManageAccess ||
        current.accessRevision != original.accessRevision ||
        current.account.suspended != original.account.suspended) {
      const notice = 'Hesap erişimi değişti. Güncel kararı kontrol et.';
      setState(() => _decisionNotice = notice);
      _closeReasonSheet();
      return notice;
    }
    return null;
  }

  Future<void> _changeAccess() async {
    if (!_canAct || _deciding) return;
    final detail = _result!.data!;
    if (!detail.canManageAccess || detail.accessRevision == null) return;
    final restore = detail.account.suspended;
    setState(() => _deciding = true);
    try {
      final reason = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) {
          _reasonRoute = ModalRoute.of(context);
          return ValueListenableBuilder<bool>(
            valueListenable: widget.access,
            builder: (_, allowed, _) => allowed
                ? AdminDecisionReasonSheet(
                    heading: restore
                        ? 'Askı kaldırılsın mı?'
                        : 'Hesap askıya alınsın mı?',
                    title: '@${detail.account.username}',
                    impact: restore
                        ? 'Kullanıcı yeniden giriş yaptığında hesabının güncel durumuna göre devam eder. Önceki oturumları kapalı kalır.'
                        : 'Bu hesabın tüm cihazlardaki erişimi kesilecek. Açık sohbetler kapanacak.',
                    submitLabel: restore ? 'Askıyı kaldır' : 'Askıya al',
                    helper: 'Yalnızca yöneticiler görür.',
                    destructive: !restore,
                    checkBeforeSubmit: () => _checkDecision(detail),
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(adminUsersAccessError.message),
                  ),
          );
        },
      );
      _reasonRoute = null;
      if (reason == null || !_canAct) return;
      setState(() {
        _result = null;
        _decisionNotice = null;
      });
      final result = await widget.repository.changeAccess(detail, reason);
      if (!mounted || !widget.access.value) return;
      _decisionNotice = switch (result.error?.code) {
        null => 'Karar kaydedildi.',
        '409' || '1010' => 'Hesap erişimi değişti. Güncel kararı kontrol et.',
        '403' || '1102' => 'Bu hesabın erişimini değiştirme yetkin yok.',
        _ =>
          'Karar yanıtı alınamadı. Yeniden işlem yapmadan önce hesabın güncel durumunu kontrol et.',
      };
      await _load();
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  void _openProfile() {
    if (!_canAct) return;
    final detail = _result!.data!;
    final id = detail.profileId;
    if (id == null) return;
    final kind = switch (detail.account.profileType) {
      AdminUserProfileType.listener => ProfileRouteKind.listener,
      AdminUserProfileType.musician => ProfileRouteKind.musician,
      AdminUserProfileType.venue => ProfileRouteKind.venue,
      AdminUserProfileType.studio => ProfileRouteKind.studio,
    };
    final target = ProfileRouteTarget(kind: kind, id: id);
    _reloadOnReveal = true;
    setState(() => _result = null);
    Navigator.of(
      context,
    ).pushNamed(target.publicRoute, arguments: target.publicArguments);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final detail = result?.data;
    final Widget content;
    if (!widget.access.value) {
      content = Center(child: Text(adminUsersAccessError.message));
    } else if (result == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (detail == null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result.error!.message, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
    } else {
      content = AdminUserDetailView(
        detail: detail,
        onOpenProfile: _openProfile,
        onCopy: _copy,
        onChangeAccess: _deciding ? null : _changeAccess,
        decisionNotice: _decisionNotice,
      );
    }
    return ApplicationPageFrame(
      frame: widget.frame,
      title: 'Hesap detayı',
      backLabel: widget.backLabel,
      onRefresh: widget.access.value && !_deciding && !_loading ? _load : null,
      refreshTooltip: 'Hesabı yenile',
      child: content,
    );
  }
}
