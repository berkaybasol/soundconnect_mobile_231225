import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../data/media_content_audience_repository.dart';
import '../../domain/entities/media_content_audience.dart';

class MediaContentAudienceField extends StatelessWidget {
  final String ownerType;
  final String value;
  final ValueChanged<String>? onChanged;
  const MediaContentAudienceField({
    super.key,
    required this.ownerType,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (!MediaContentAudience.canChoose(ownerType)) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('media-content-audience:$value'),
      initialValue: MediaContentAudience.isValid(value)
          ? value
          : MediaContentAudience.backstage,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Hedef kitle',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final option in [
          MediaContentAudience.mainstage,
          MediaContentAudience.backstage,
        ])
          DropdownMenuItem(
            value: option,
            child: Text(
              MediaContentAudience.label(option),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged == null
          ? null
          : (next) {
              if (next != null) onChanged!(next);
            },
    );
  }
}

Future<String?> chooseMediaContentAudience(
  BuildContext context, {
  required String ownerType,
  String initialValue = 'MAINSTAGE',
}) {
  if (!MediaContentAudience.canChoose(ownerType)) {
    return Future.value(MediaContentAudience.forOwner(ownerType, initialValue));
  }
  String selected = MediaContentAudience.isValid(initialValue)
      ? initialValue
      : MediaContentAudience.backstage;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Hedef kitle'),
        content: SizedBox(
          width: 360,
          child: MediaContentAudienceField(
            ownerType: ownerType,
            value: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, selected),
            child: const Text('Devam'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> editMediaContentAudience(
  BuildContext context, {
  required String assetId,
  required String ownerType,
  required String currentAudience,
  MediaContentAudienceRepository? repository,
  bool Function()? isCurrent,
}) async {
  if (!MediaContentAudience.canChoose(ownerType)) return false;
  final store =
      repository ??
      MediaContentAudienceRepository(
        serviceLocator<ApiClient>(),
        serviceLocator<AuthSessionManager>(),
      );
  final session = store.sessions.session;
  var revoked = false;
  void observe() {
    if (!identical(session, store.sessions.session)) revoked = true;
  }

  bool current() =>
      context.mounted &&
      !revoked &&
      identical(session, store.sessions.session) &&
      (isCurrent?.call() ?? true);
  if (!current()) return false;
  store.sessions.addListener(observe);
  try {
    final selected = await chooseMediaContentAudience(
      context,
      ownerType: ownerType,
      initialValue: currentAudience,
    );
    if (!current() || selected == null || selected == currentAudience) {
      return false;
    }
    final result = await store.update(
      assetId: assetId,
      ownerType: ownerType,
      contentAudience: selected,
    );
    if (!context.mounted || !current()) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: result.isSuccess
            ? AppSnackBarTone.success
            : AppSnackBarTone.error,
        content: Text(
          result.isSuccess
              ? 'Hedef kitle güncellendi.'
              : result.error?.message ?? 'Hedef kitle güncellenemedi.',
        ),
      ),
    );
    return result.isSuccess;
  } finally {
    store.sessions.removeListener(observe);
  }
}

class MediaContentAudienceMenu extends StatefulWidget {
  final String assetId, ownerType, contentAudience;
  final Future<void> Function() onChanged;
  const MediaContentAudienceMenu({
    super.key,
    required this.assetId,
    required this.ownerType,
    required this.contentAudience,
    required this.onChanged,
  });
  @override
  State<MediaContentAudienceMenu> createState() =>
      _MediaContentAudienceMenuState();
}

class _MediaContentAudienceMenuState extends State<MediaContentAudienceMenu> {
  bool _busy = false;
  int _generation = 0;
  @override
  void didUpdateWidget(covariant MediaContentAudienceMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assetId != oldWidget.assetId ||
        widget.ownerType != oldWidget.ownerType) {
      _generation++;
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (!MediaContentAudience.canChoose(widget.ownerType)) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      tooltip: 'Medya seçenekleri',
      enabled: !_busy,
      icon: Icon(Icons.more_vert, color: Colors.white),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'audience',
          child: Text('Hedef kitleyi düzenle'),
        ),
      ],
      onSelected: (_) async {
        final generation = _generation;
        final target = widget;
        setState(() => _busy = true);
        try {
          final changed = await editMediaContentAudience(
            context,
            assetId: target.assetId,
            ownerType: target.ownerType,
            currentAudience: target.contentAudience,
            isCurrent: () => mounted && generation == _generation,
          );
          if (changed && mounted && generation == _generation) {
            await target.onChanged();
          }
        } finally {
          if (mounted && generation == _generation) {
            setState(() => _busy = false);
          }
        }
      },
    );
  }
}
