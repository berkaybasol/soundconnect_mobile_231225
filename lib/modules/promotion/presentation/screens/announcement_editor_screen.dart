import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/widgets/soundconnect_date_picker.dart';
import '../../../musician_feed/presentation/musician_feed_visual_theme.dart';
import '../../../profile/domain/media_gallery_repository.dart';
import '../../../profile/presentation/screens/video_reel_screen.dart';
import '../../../profile/presentation/screens/profile_screen_support.dart'
    show
        createProfileUploadSource,
        inferImageMimeType,
        ProfileMediaUploadRepository,
        ProfileUploadSource,
        ProfileUploadCancellation,
        ProfileUploadAttachmentIntent,
        DraftMediaCleanupCoordinator;
import '../../domain/announcement_access.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/promotion_repository.dart';
import '../widgets/announcement_content.dart';
import 'announcement_statistics_screen.dart';

class AnnouncementEditorScreen extends StatefulWidget {
  const AnnouncementEditorScreen({
    super.key,
    this.id,
    this.repository,
    this.sessions,
  });
  final String? id;
  final PromotionRepository? repository;
  final AuthSessionManager? sessions;
  @override
  State<AnnouncementEditorScreen> createState() =>
      _AnnouncementEditorScreenState();
}

class _AnnouncementEditorScreenState extends State<AnnouncementEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _targets = <String>{'MUSICIAN'};
  late final _sessions =
      widget.sessions ?? serviceLocator<AuthSessionManager>();
  late final AnnouncementSessionIdentity? _identity;
  late final _repository =
      widget.repository ?? serviceLocator<PromotionRepository>();
  DraftMediaCleanupCoordinator? _cleanup;
  ProfileUploadCancellation? _cancellation;
  Announcement? _item;
  String? _error;
  bool _busy = false;
  bool _loading = false;
  bool _revoked = false;
  bool _uncertain = false;
  bool _picking = false;
  double? _progress;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool get _current =>
      mounted &&
      !_revoked &&
      _identity != null &&
      _identity == announcementSessionIdentity(_sessions.session, admin: true);
  bool get _editable =>
      _current &&
      !_busy &&
      !_loading &&
      !_uncertain &&
      (widget.id == null || _item != null) &&
      _item?.status != AnnouncementStatus.archived;
  bool get _dirty =>
      _item != null &&
      (_title.text.trim() != _item!.title ||
          _body.text.trim() != _item!.body ||
          _targets.length != _item!.targetProfiles.length ||
          !_targets.containsAll(_item!.targetProfiles));
  @override
  void initState() {
    super.initState();
    _identity = announcementSessionIdentity(_sessions.session, admin: true);
    _sessions.addListener(_sessionChanged);
    if (widget.id != null) unawaited(_load(widget.id!));
  }

  void _sessionChanged() {
    if (_identity !=
        announcementSessionIdentity(_sessions.session, admin: true)) {
      _revoked = true;
      _cancellation?.cancel();
      if (mounted) {
        setState(() {
          _item = null;
          _error = 'Yetkin veya oturumun değişti. Sayfayı yeniden aç.';
        });
      }
    }
  }

  void _accept(Announcement item) {
    _item = item;
    _title.text = item.title;
    _body.text = item.body;
    _targets
      ..clear()
      ..addAll(item.targetProfiles);
    _startsAt = item.status == AnnouncementStatus.scheduled
        ? item.startsAt?.toLocal()
        : null;
    _endsAt = item.endsAt?.toLocal();
    _uncertain = false;
    _cleanup ??= DraftMediaCleanupCoordinator(
      repository: serviceLocator<ProfileMediaUploadRepository>(),
      ownerType: 'PROMOTION',
      ownerId: item.id,
    );
  }

  Future<void> _load(String id) async {
    if (!_current || _busy) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repository.announcement(id, admin: true);
    if (!mounted || !_current) return;
    setState(() {
      _loading = false;
      if (result.isSuccess && result.data != null) {
        _accept(result.data!);
      } else {
        _uncertain = true;
        _error = result.error?.message ?? 'Duyuru getirilemedi.';
      }
    });
  }

  AnnouncementWrite _input({String? mediaAssetId}) => AnnouncementWrite(
    title: _title.text.trim(),
    body: _body.text.trim(),
    targetProfiles: Set.of(_targets),
    mediaAssetId: mediaAssetId,
  );
  Future<bool> _save() async {
    if (!_editable || _form.currentState?.validate() != true) return false;
    if (_targets.isEmpty) {
      setState(() => _error = 'En az bir hedef profil seç.');
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = _item;
      final result = item == null
          ? await _repository.createAnnouncement(_input())
          : await _repository.updateAnnouncement(
              item.id,
              _input(mediaAssetId: item.media?.assetId),
              expectedVersion: item.version,
            );
      if (!_current) return false;
      if (!result.isSuccess || result.data == null) {
        _failedWrite(result.error?.message);
        return false;
      }
      setState(() => _accept(result.data!));
      return true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _failedWrite(String? message) {
    setState(() {
      _uncertain = true;
      _error =
          '${message ?? 'İşlem doğrulanamadı.'} Tekrar işlem yapmadan kayıtlı durumu yenile.';
    });
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _transition(String action) async {
    final item = _item;
    if (!_editable || item == null) return;
    if (_dirty) {
      setState(() => _error = 'Önce metin ve hedef değişikliklerini kaydet.');
      return;
    }
    if (action == 'publish' &&
        (_startsAt != null && !_startsAt!.isAfter(DateTime.now()) ||
            _endsAt != null &&
                !_endsAt!.isAfter(_startsAt ?? DateTime.now()))) {
      setState(
        () => _error = 'Başlangıç gelecekte, bitiş başlangıçtan sonra olmalı.',
      );
      return;
    }
    final label = switch (action) {
      'publish' => _startsAt == null ? 'Duyuruyu yayınla' : 'Duyuruyu planla',
      'end' => 'Yayını sonlandır',
      'archive' => 'Duyuruyu arşivle',
      _ => 'Duyuruyu kalıcı sil',
    };
    if (!await _confirm(
      label,
      '“${item.title}”\nHedefler: ${item.targetProfiles.map(announcementProfileLabel).join(', ')}\n${action == 'publish'
          ? 'Başlangıç: ${_startsAt == null ? 'Şimdi' : announcementDateLabel(_startsAt!)}\nBitiş: ${_endsAt == null ? 'Belirsiz' : announcementDateLabel(_endsAt!)}'
          : action == 'delete'
          ? 'Bu işlem geri alınamaz.'
          : 'Duyuru kullanıcı akışından ve duyuru listesinden kalkar.'}',
    )) {
      return;
    }
    if (!_current || _item?.version != item.version || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action == 'delete') {
        final result = await _repository.deleteAnnouncement(
          item.id,
          expectedVersion: item.version,
        );
        if (!mounted || !_current) return;
        if (result.isSuccess) {
          Navigator.of(context).pop();
        } else {
          _failedWrite(result.error?.message);
        }
        return;
      }
      final Result<Announcement> result = switch (action) {
        'publish' => await _repository.publishAnnouncement(
          item.id,
          expectedVersion: item.version,
          startsAt: _startsAt,
          endsAt: _endsAt,
        ),
        'end' => await _repository.endAnnouncement(
          item.id,
          expectedVersion: item.version,
        ),
        _ => await _repository.archiveAnnouncement(
          item.id,
          expectedVersion: item.version,
        ),
      };
      if (!mounted || !_current) return;
      if (result.isSuccess && result.data != null) {
        setState(() => _accept(result.data!));
      } else if (action == 'publish' && result.error?.code == '9913') {
        // The server rejects this before any publication/version change.
        setState(() => _error = result.error!.message);
      } else {
        _failedWrite(result.error?.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickMedia(bool video) async {
    if (!_editable || _picking) return;
    _picking = true;
    try {
      await _pickMediaImpl(video);
    } catch (_) {
      if (_current) {
        setState(
          () => _error = 'Dosya seçilemedi veya okunamadı. Yeniden dene.',
        );
      }
    } finally {
      _picking = false;
    }
  }

  Future<void> _pickMediaImpl(bool video) async {
    if (!_editable) return;
    if ((_item == null || _dirty) && !await _save()) return;
    final item = _item;
    if (!_current || item == null) return;
    ProfileUploadSource source;
    String name;
    String mime;
    if (video) {
      final selected = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp4', 'mov'],
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
      if (!_current || selected == null || selected.files.isEmpty) return;
      final file = selected.files.single;
      source = await createProfileUploadSource(
        filePath: file.path,
        bytes: file.bytes,
        readStream: file.readStream,
        sizeBytes: file.size,
      );
      name = file.name;
      mime = name.toLowerCase().endsWith('.mov')
          ? 'video/quicktime'
          : 'video/mp4';
    } else {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (!_current || file == null) return;
      source = await createProfileUploadSource(filePath: file.path);
      name = file.name;
      mime = inferImageMimeType(name);
    }
    if (!mounted || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    _cancellation = ProfileUploadCancellation();
    try {
      final uploaded = await serviceLocator<ProfileMediaUploadRepository>()
          .uploadAsset(
            source: source,
            ownerType: 'PROMOTION',
            ownerId: item.id,
            mediaKind: video ? 'VIDEO' : 'IMAGE',
            mimeType: mime,
            originalFileName: name,
            visibility: 'PRIVATE',
            attachmentIntent: const ProfileUploadAttachmentIntent.draft(),
            cancellation: _cancellation,
            onProgress: (sent, total) {
              if (_current && total > 0) {
                setState(() => _progress = sent / total);
              }
            },
          );
      if (!mounted || !_current) return;
      final asset = uploaded.data;
      if (!uploaded.isSuccess || asset == null) {
        setState(
          () => _error = uploaded.error?.message ?? 'Medya yüklenemedi.',
        );
        return;
      }
      final tracked = await _cleanup!.trackUploaded(asset.uuid);
      if (!mounted || !_current) return;
      if (!tracked.isSuccess) {
        setState(
          () =>
              _error = tracked.error?.message ?? 'Medya güvenle kaydedilemedi.',
        );
        return;
      }
      if (item.media != null) {
        final detached = await _cleanup!.trackPotentiallyDetached([
          item.media!.assetId,
        ]);
        if (!_current || !detached.isSuccess) return;
      }
      final result = await _repository.updateAnnouncement(
        item.id,
        _input(mediaAssetId: asset.uuid),
        expectedVersion: item.version,
      );
      if (!mounted || !_current) return;
      if (result.isSuccess && result.data != null) {
        await _cleanup!.markCommitted([asset.uuid]);
        if (_current) setState(() => _accept(result.data!));
      } else {
        _failedWrite(result.error?.message);
      }
      await _cleanup!.discardAll();
    } catch (_) {
      if (_current) {
        setState(
          () => _error = 'Medya seçilemedi veya yüklenemedi. Yeniden dene.',
        );
      }
    } finally {
      _cancellation = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _removeMedia() async {
    final item = _item;
    if (!_editable || item?.media == null) return;
    if (!await _confirm(
      'Medyayı kaldır',
      'Duyuru metni korunur. Kayıtlı fotoğraf veya video kaldırılır.',
    )) {
      return;
    }
    if (!_current || _busy) return;
    setState(() => _busy = true);
    try {
      final tracked = await _cleanup!.trackPotentiallyDetached([
        item!.media!.assetId,
      ]);
      if (!_current || !tracked.isSuccess) return;
      final result = await _repository.updateAnnouncement(
        item.id,
        _input(),
        expectedVersion: item.version,
      );
      if (!mounted || !_current) return;
      if (result.isSuccess && result.data != null) {
        setState(() => _accept(result.data!));
      } else {
        _failedWrite(result.error?.message);
      }
      await _cleanup!.discardAll();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final selected = (start ? _startsAt : _endsAt) ?? now;
    final initial = selected.isBefore(now) ? now : selected;
    final day = await showSoundConnectDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
      helpText: start ? 'Yayın başlangıcı' : 'Yayın bitişi',
    );
    if (!mounted || !_current || day == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime((start ? _startsAt : _endsAt) ?? now),
    );
    if (!_current || time == null) return;
    setState(() {
      final date = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _startsAt = date;
      } else {
        _endsAt = date;
      }
    });
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    _sessions.removeListener(_sessionChanged);
    _title.dispose();
    _body.dispose();
    final cleanup = _cleanup;
    if (cleanup != null) unawaited(cleanup.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MusicianFeedThemeScope(
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.id == null && _item == null
                ? 'Duyuru oluştur'
                : 'Duyuruyu yönet',
          ),
          actions: [
            if (_item != null)
              IconButton(
                onPressed: _busy ? null : () => _load(_item!.id),
                tooltip: 'Kayıtlı durumu yenile',
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_current
            ? Center(child: Text(_error ?? 'Duyuru yönetim yetkisi gerekli.'))
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_item != null)
                      Text(
                        _item!.status.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _title,
                      enabled: _editable,
                      maxLength: 150,
                      decoration: const InputDecoration(labelText: 'Başlık'),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Başlık gerekli.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _body,
                      enabled: _editable,
                      maxLength: 5000,
                      minLines: 5,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: 'Duyuru metni',
                      ),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Duyuru metni gerekli.',
                    ),
                    const Text('Hedef profiller'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final role in announcementTargetProfiles)
                          FilterChip(
                            label: Text(announcementProfileLabel(role)),
                            selected: _targets.contains(role),
                            onSelected: !_editable
                                ? null
                                : (selected) => setState(() {
                                    if (selected) {
                                      _targets.add(role);
                                    } else {
                                      _targets.remove(role);
                                    }
                                  }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Duyuruya isteğe bağlı tek fotoğraf veya video eklenebilir.',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _editable ? () => _pickMedia(false) : null,
                          icon: const Icon(Icons.photo_outlined),
                          label: const Text('Fotoğraf'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _editable ? () => _pickMedia(true) : null,
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Video'),
                        ),
                        if (_item?.media != null)
                          TextButton(
                            onPressed: _editable ? _removeMedia : null,
                            child: const Text('Medyayı kaldır'),
                          ),
                      ],
                    ),
                    if (_busy) LinearProgressIndicator(value: _progress),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_uncertain)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : (_item?.id ?? widget.id) != null
                            ? () => _load((_item?.id ?? widget.id)!)
                            : () => Navigator.pop(context),
                        child: Text(
                          (_item?.id ?? widget.id) != null
                              ? 'Kayıtlı durumu yeniden yükle'
                              : 'Taslak listesine dön ve kontrol et',
                        ),
                      ),
                    FilledButton(
                      onPressed: _editable ? _save : null,
                      child: Text(
                        _item == null
                            ? 'Taslağı kaydet'
                            : 'Değişiklikleri kaydet',
                      ),
                    ),
                    if (_item case final item?) ...[
                      const SizedBox(height: 24),
                      const Text('Yayın zamanı · cihazın yerel saati'),
                      if (item.status != AnnouncementStatus.published)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Başlangıç'),
                          subtitle: Text(
                            _startsAt == null
                                ? 'Şimdi'
                                : announcementDateLabel(_startsAt!),
                          ),
                          onTap: _editable ? () => _pickDate(true) : null,
                          trailing: IconButton(
                            onPressed: _editable
                                ? () => setState(() => _startsAt = null)
                                : null,
                            tooltip: 'Şimdi yayınla',
                            icon: const Icon(Icons.clear),
                          ),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bitiş'),
                        subtitle: Text(
                          _endsAt == null
                              ? 'Bitiş tarihi yok'
                              : announcementDateLabel(_endsAt!),
                        ),
                        onTap: _editable ? () => _pickDate(false) : null,
                        trailing: IconButton(
                          onPressed: _editable
                              ? () => setState(() => _endsAt = null)
                              : null,
                          tooltip: 'Bitiş tarihini kaldır',
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                      if (item.media != null && item.media!.status != 'READY')
                        const Text(
                          'Yayınlamak için medya hazır olmalı. Hazırlama tamamlanınca kayıtlı durumu yenile.',
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (item.status != AnnouncementStatus.archived)
                            FilledButton(
                              onPressed:
                                  _editable &&
                                      (item.media == null ||
                                          item.media!.status == 'READY')
                                  ? () => _transition('publish')
                                  : null,
                              child: Text(
                                item.status == AnnouncementStatus.published
                                    ? 'Bitişi güncelle'
                                    : _startsAt == null
                                    ? 'Yayınla'
                                    : 'Planla',
                              ),
                            ),
                          if (item.status == AnnouncementStatus.published ||
                              item.status == AnnouncementStatus.scheduled)
                            OutlinedButton(
                              onPressed: _editable
                                  ? () => _transition('end')
                                  : null,
                              child: const Text('Sonlandır'),
                            ),
                          if (item.status != AnnouncementStatus.archived)
                            OutlinedButton(
                              onPressed: _editable
                                  ? () => _transition('archive')
                                  : null,
                              child: const Text('Arşivle'),
                            ),
                          if (item.status == AnnouncementStatus.draft ||
                              item.status == AnnouncementStatus.archived)
                            TextButton(
                              onPressed: _current && !_busy && !_uncertain
                                  ? () => _deleteArchivedOrDraft()
                                  : null,
                              child: const Text('Kalıcı sil'),
                            ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnnouncementStatisticsScreen(
                                    id: item.id,
                                    repository: _repository,
                                    sessions: _sessions,
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('Duyuru istatistikleri'),
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Kayıtlı önizleme · kullanıcı istatistiklerine eklenmez',
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: AnnouncementContent(
                            announcement: item,
                            expanded: true,
                            showDirectory: false,
                            onPlay: _previewVideo,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    ),
  );
  Future<void> _previewVideo() async {
    final item = _item;
    final media = item?.media;
    if (!_current || _busy || item == null || media == null || !media.isVideo) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await serviceLocator<MediaGalleryRepository>().getAccess(
        media.assetId,
      );
      if (!mounted || !_current) return;
      final access = result.data;
      if (access == null || !result.isSuccess) {
        setState(() => _error = result.error?.message ?? 'Video açılamadı.');
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => VideoReelScreen(
            looping: false,
            title: item.title,
            playbackUrl: access.accessUrl,
            thumbnailUrl: access.thumbnailAccessUrl,
            targetType: 'ANNOUNCEMENT',
            targetId: item.id,
            initialLikeCount: null,
            initialCommentCount: null,
            showEngagement: false,
            accessChanges: _sessions,
            isPlaybackAllowed: () => _current,
            refreshPlaybackUrl: () async {
              if (!_current) return null;
              final refreshed = await serviceLocator<MediaGalleryRepository>()
                  .getAccess(media.assetId);
              return _current && refreshed.isSuccess
                  ? refreshed.data?.accessUrl
                  : null;
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteArchivedOrDraft() async {
    // Archived records cannot be edited, but their version-fenced delete is an
    // explicit lifecycle operation. Use the same confirmation and dispatch.
    if (_item?.status != AnnouncementStatus.archived) {
      return _transition('delete');
    }
    final item = _item!;
    if (!_current ||
        _busy ||
        _uncertain ||
        !await _confirm(
          'Duyuruyu kalıcı sil',
          '“${item.title}” kalıcı olarak silinecek. Bu işlem geri alınamaz.',
        )) {
      return;
    }
    if (!_current || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await _repository.deleteAnnouncement(
        item.id,
        expectedVersion: item.version,
      );
      if (!mounted || !_current) return;
      if (result.isSuccess) {
        Navigator.pop(context);
      } else {
        _failedWrite(result.error?.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

String announcementDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
