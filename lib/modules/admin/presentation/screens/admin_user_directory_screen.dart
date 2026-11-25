import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../../../core/pagination/page.dart';
import '../../data/admin_user_directory_repository.dart';
import '../../domain/admin_user_directory.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_user_directory_widgets.dart';
import '../widgets/application_review_widgets.dart';
import 'admin_user_detail_screen.dart';

class AdminUserDirectoryScreen extends StatefulWidget {
  const AdminUserDirectoryScreen({
    super.key,
    required this.repository,
    required this.sessions,
    required this.initialSession,
    this.frame,
  });
  final AdminUserDirectoryRepository repository;
  final AuthSessionManager sessions;
  final AuthSession initialSession;
  final AdminSubpageFrame? frame;

  @override
  State<AdminUserDirectoryScreen> createState() => _AdminUserDirectoryState();
}

class _AdminUserDirectoryState extends State<AdminUserDirectoryScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController(keepScrollOffset: false);
  late final _access = ValueNotifier(_currentSession);
  Timer? _debounce;
  int _request = 0;
  int _page = 0;
  bool _checkingReturn = false;
  bool _reloadOnReveal = false;
  AdminUserProfileType? _type;
  AdminUserStatus? _status;
  bool _suspendedOnly = false;
  Result<Page<AdminUserAccount>>? _result;
  bool get _currentSession =>
      identical(widget.sessions.session, widget.initialSession) &&
      canReadAdminUsers(widget.initialSession);

  @override
  void initState() {
    super.initState();
    widget.sessions.addListener(_sessionChanged);
    if (_access.value) _fetch(++_request);
  }

  void _sessionChanged() {
    if (!_currentSession) _deny();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.isCurrentOf(context) == true && _reloadOnReveal) {
      _reloadOnReveal = false;
      _fetch(++_request);
    }
  }

  void _deny() {
    if (!mounted || !_access.value) return;
    _debounce?.cancel();
    _request++;
    _query.clear();
    _result = null;
    _access.value = false;
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_sessionChanged);
    _debounce?.cancel();
    _access.dispose();
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _search({int page = 0, bool delayed = false}) {
    if (!_access.value || !_currentSession) return;
    _debounce?.cancel();
    final revision = ++_request;
    setState(() {
      _checkingReturn = false;
      _page = page;
      _result = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (delayed) {
      _debounce = Timer(
        const Duration(milliseconds: 300),
        () => _fetch(revision),
      );
    } else {
      _fetch(revision);
    }
  }

  Future<void> _fetch(int revision) async {
    if (!_access.value || !_currentSession || revision != _request) return;
    final result = await widget.repository.search(
      query: _query.text,
      profileType: _type,
      status: _status,
      suspendedOnly: _suspendedOnly,
      page: _page,
    );
    if (!mounted || !_access.value) return;
    if (!_currentSession || isAdminUsersAccessError(result.error)) {
      _deny();
      return;
    }
    if (revision != _request) return;
    final total = result.data?.totalElements;
    if (_page > 0 &&
        total != null &&
        _page * AdminUserDirectoryRepository.pageSize >= total) {
      _search(
        page: total == 0
            ? 0
            : (total - 1) ~/ AdminUserDirectoryRepository.pageSize,
      );
      return;
    }
    setState(() {
      _checkingReturn = false;
      _result = result;
    });
  }

  void _open(AdminUserAccount account) {
    if (!_access.value ||
        !_currentSession ||
        _checkingReturn ||
        ModalRoute.of(context)?.isCurrent != true ||
        _result?.data?.items.contains(account) != true) {
      return;
    }
    _focus.unfocus();
    _reloadOnReveal = true;
    setState(() => _checkingReturn = true);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminUserDetailScreen(
          userId: account.userId,
          repository: widget.repository,
          access: _access,
          onAccessLost: _deny,
          frame: widget.frame,
        ),
      ),
    );
  }

  void _clear() {
    _query.clear();
    _status = null;
    _type = null;
    _suspendedOnly = false;
    _search();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _access,
    builder: (context, allowed, _) => Actions(
      actions: <Type, Action<Intent>>{
        FocusAdminUserSearch: CallbackAction<FocusAdminUserSearch>(
          onInvoke: (_) {
            if (allowed && _currentSession && !_checkingReturn) {
              if (_scroll.hasClients) _scroll.jumpTo(0);
              _focus.requestFocus();
            }
            return null;
          },
        ),
      },
      child: Builder(
        builder: (context) {
          final body = allowed
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    // Keep the list laid out at its original offset while fresh
                    // data is requested. Covered records are neither visible
                    // nor accessible during the return transition.
                    Visibility(
                      visible: !_checkingReturn,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      child: Builder(builder: _list),
                    ),
                    if (_checkingReturn)
                      const Center(child: CircularProgressIndicator()),
                  ],
                )
              : Center(child: Text(adminUsersAccessError.message));
          final frame = widget.frame;
          return frame != null
              ? frame(body)
              : ApplicationPageFrame(
                  frame: null,
                  title: 'Kullanıcı ara',
                  backLabel: 'Admin paneli',
                  child: body,
                );
        },
      ),
    ),
  );

  Widget _list(BuildContext context) {
    final data = _result?.data;
    final total = data?.totalElements ?? 0;
    final pages =
        (total + AdminUserDirectoryRepository.pageSize - 1) ~/
        AdminUserDirectoryRepository.pageSize;
    final theme = Theme.of(context);
    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      children: [
        if (widget.frame != null) ...[
          Semantics(
            header: true,
            child: Text(
              'Kullanıcı ara',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -.9,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          key: const Key('admin-users-query'),
          controller: _query,
          focusNode: _focus,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.search,
          inputFormatters: [
            LengthLimitingTextInputFormatter(
              AdminUserDirectoryRepository.maxQueryLength,
            ),
          ],
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Kullanıcı adı, kimlik veya SC kodu',
          ),
          onChanged: (_) => _search(delayed: true),
          onSubmitted: (_) {
            if (_debounce?.isActive == true) _search();
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final typeFilter = AdminUserFilter<AdminUserProfileType>(
              key: const Key('admin-users-type'),
              label: 'Profil türü',
              value: _type,
              values: AdminUserProfileType.values,
              labelFor: (v) => v.label,
              onChanged: (v) {
                if (_type != v) {
                  _type = v;
                  _search();
                }
              },
            );
            final statusFilter = AdminUserFilter<AdminUserStatus>(
              key: const Key('admin-users-status'),
              label: 'Hesap durumu',
              value: _status,
              values: AdminUserStatus.values,
              labelFor: (v) => v.label,
              onChanged: (v) {
                if (_status != v) {
                  _status = v;
                  _search();
                }
              },
            );
            if (constraints.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(14) > 19) {
              return Column(
                children: [typeFilter, const SizedBox(height: 8), statusFilter],
              );
            }
            return Row(
              children: [
                Expanded(child: typeFilter),
                const SizedBox(width: 10),
                Expanded(child: statusFilter),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Yalnızca askıdaki hesaplar'),
          value: _suspendedOnly,
          onChanged: (value) {
            _suspendedOnly = value ?? false;
            _search();
          },
        ),
        if (_result == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (data == null) ...[
          Text(_result!.error!.message),
          TextButton(
            onPressed: () => _search(page: _page),
            child: const Text('Tekrar dene'),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '$total hesap',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
              if (pages > 1) ...[
                IconButton(
                  tooltip: 'Önceki sayfa',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _page > 0 ? () => _search(page: _page - 1) : null,
                ),
                Text('${_page + 1} / $pages', style: theme.textTheme.bodySmall),
                IconButton(
                  tooltip: 'Sonraki sayfa',
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      data.hasNext &&
                          _page < AdminUserDirectoryRepository.maxPage
                      ? () => _search(page: _page + 1)
                      : null,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (data.items.isEmpty)
            ApplicationSurface(
              rows: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hesap bulunamadı',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kullanıcı adını, kimliği veya seçtiğin filtreleri kontrol et.',
                      ),
                      if (_query.text.isNotEmpty ||
                          _type != null ||
                          _status != null ||
                          _suspendedOnly)
                        TextButton(
                          onPressed: _clear,
                          child: const Text('Aramayı temizle'),
                        ),
                    ],
                  ),
                ),
              ],
            )
          else
            ApplicationSurface(
              rows: [
                for (final account in data.items)
                  AdminUserRow(
                    key: ValueKey(account.userId),
                    account: account,
                    onTap: () => _open(account),
                  ),
              ],
            ),
          if (data.hasNext && _page == AdminUserDirectoryRepository.maxPage)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Diğer hesapları görmek için aramanı daralt.'),
            ),
        ],
      ],
    );
  }
}
