import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/di/service_locator.dart';
import '../../../shared/widgets/gradient_outline_button.dart';
import '../data/user_block_repository.dart';
import 'user_block_action.dart';

class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});
  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  final _repository = serviceLocator<UserBlockRepository>();
  final _sessions = serviceLocator<AuthSessionManager>();
  late final AuthSession _owner;
  late final StreamSubscription<UserBlockChange> _changes;
  final _accounts = <BlockedAccount>[];
  int _generation = 0;
  int _nextPage = 0;
  bool _loading = false;
  bool _hasNext = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _owner = _sessions.session;
    _sessions.addListener(_sessionChanged);
    _changes = _repository.changes.listen((event) {
      if (event.actorId == _owner.userId &&
          identical(_sessions.session, _owner)) {
        unawaited(_load(reset: true));
      }
    });
    unawaited(_load());
  }

  void _sessionChanged() {
    if (identical(_sessions.session, _owner)) return;
    setState(() {
      _generation++;
      _accounts.clear();
      _loading = false;
      _hasNext = false;
      _error = 'Hesap değişti. Listeyi Hesap Ayarları’ndan yeniden aç.';
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (!identical(_sessions.session, _owner) ||
        (!reset && (_loading || !_hasNext))) {
      return;
    }
    final generation = ++_generation;
    final page = reset ? 0 : _nextPage;
    setState(() {
      if (reset) {
        _nextPage = 0;
        _accounts.clear();
        _hasNext = true;
      }
      _loading = true;
      _error = null;
    });
    final result = await _repository.list(page: page);
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _error = result.error?.message;
      final data = result.data;
      if (data != null) {
        final loaded = _accounts.map((account) => account.id).toSet();
        _accounts.addAll(data.items.where((account) => loaded.add(account.id)));
        _hasNext = data.hasNext;
        _nextPage = page + 1;
      }
    });
  }

  @override
  void dispose() {
    _sessions.removeListener(_sessionChanged);
    _changes.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = identical(_sessions.session, _owner);
    return Scaffold(
      appBar: AppBar(title: const Text('Engellenen hesaplar')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: _accounts.length + 1,
            itemBuilder: (context, index) {
              if (index < _accounts.length) {
                final account = _accounts[index];
                return Padding(
                  key: ValueKey(account.id),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.start,
                    spacing: 12,
                    overflowSpacing: 4,
                    children: [
                      Text(
                        '@${account.username}',
                        style: Theme.of(context).textTheme.bodyLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Semantics(
                        container: true,
                        button: true,
                        child: GradientOutlineButton(
                          label: 'Engeli kaldır',
                          strokeWidth: 0.9,
                          horizontalPadding: 16,
                          maxLines: null,
                          onPressed: () {
                            unawaited(
                              confirmUnblockUser(
                                context,
                                userId: account.id,
                                username: '@${account.username}',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (_loading) {
                return const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Hesaplar yükleniyor',
                  ),
                );
              }
              if (_error != null) {
                return Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    if (current)
                      GradientOutlineButton(
                        label: 'Tekrar dene',
                        strokeWidth: 0.9,
                        onPressed: _load,
                      ),
                  ],
                );
              }
              if (_accounts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Engellediğin hesap yok.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (_hasNext) {
                return Center(
                  child: GradientOutlineButton(
                    label: 'Daha fazla göster',
                    strokeWidth: 0.9,
                    onPressed: _load,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
