import 'package:flutter/material.dart';

import '../auth/auth_session_manager.dart';
import '../di/service_locator.dart';
import 'push_coordinator.dart';
import 'push_device_api.dart';
import 'push_provider.dart';

class PushSettingsScreen extends StatefulWidget {
  const PushSettingsScreen({super.key});
  @override
  State<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends State<PushSettingsScreen>
    with WidgetsBindingObserver {
  late final PushCoordinator _push = serviceLocator<PushCoordinator>();
  PushPreferences? _preferences;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _push.reconcile();
  }

  Future<void> _load() async {
    final session = serviceLocator<AuthSessionManager>().session;
    try {
      await _push.start();
      if (!_push.enabled) return;
      final preferences = await serviceLocator<PushDeviceApi>().preferences(
        session,
      );
      if (!mounted ||
          serviceLocator<AuthSessionManager>().session.token != session.token) {
        return;
      }
      setState(() {
        _preferences = preferences;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Bildirim tercihleri yüklenemedi. Tekrar deneyebilirsin.',
        );
      }
    }
  }

  Future<void> _save(bool enabled) async {
    if (_busy || _preferences == null) return;
    final session = serviceLocator<AuthSessionManager>().session;
    final next = PushPreferences(
      enabled: enabled,
      disabledCategories: _preferences!.disabledCategories,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await serviceLocator<PushDeviceApi>().savePreferences(session, next);
      if (!mounted ||
          serviceLocator<AuthSessionManager>().session.token != session.token) {
        return;
      }
      setState(() => _preferences = next);
      if (enabled) await _push.requestPermission();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Tercihin kaydedilemedi. Tekrar deneyebilirsin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _permissionText => switch (_push.permission) {
    PushPermission.authorized => 'Bu telefonda bildirim izni açık.',
    PushPermission.provisional =>
      'Bu telefonda bildirimler sessiz olarak gösteriliyor.',
    PushPermission.denied =>
      'Bildirim izni kapalı. Telefon ayarlarından Soundconnect bildirimlerini açabilirsin.',
    PushPermission.notDetermined =>
      'Yeni mesajlardan haberdar olmak için bildirimlere izin verebilirsin.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bildirim ayarları')),
    body: ListenableBuilder(
      listenable: _push,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Uygulama kapalıyken yeni bildirimleri telefonunda gör. Özel mesajın içeriği bildirimlerde gösterilmez; ghost profillerin gerçek kimliği gizli kalır.',
          ),
          const SizedBox(height: 16),
          if (!_push.enabled || _push.status == PushStatus.unavailable)
            const Text(
              'Telefon bildirimleri bu sürümde henüz kullanıma hazır değil. Uygulama içindeki bildirim kutunu kullanabilirsin.',
            )
          else ...[
            Text(_permissionText),
            if (!_push.permission.canDeliver)
              FilledButton(
                onPressed: _busy ? null : _push.requestPermission,
                child: const Text('Bildirim iznini kontrol et'),
              ),
            if (_preferences != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Telefon bildirimleri'),
                subtitle: const Text(
                  'Bu hesabının bağlı cihazlarında geçerlidir. Uygulama içindeki bildirim kutusu çalışmaya devam eder.',
                ),
                value: _preferences!.enabled,
                onChanged: _busy ? null : _save,
              ),
            if (_push.status == PushStatus.retrying)
              const Text(
                'Telefon kaydı tamamlanamadı. Bağlantı geldiğinde yeniden denenecek.',
              ),
            if (_preferences == null && _error == null)
              const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ],
      ),
    ),
  );
}
