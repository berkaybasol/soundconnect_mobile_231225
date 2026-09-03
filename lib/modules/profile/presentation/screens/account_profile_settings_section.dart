import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../../data/models/venue_profile_save_request.dart';
import '../../domain/entities/listener_visibility_mode.dart';
import '../../domain/listener_profile_repository.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/studio_profile_repository.dart';
import '../../domain/venue_profile_repository.dart';
import '../listener_visibility_error_message.dart';
import 'profile_screen_support.dart';

enum _AccountProfileKind { musician, venue, studio, listener }

class AccountProfileSettingsSection extends StatefulWidget {
  const AccountProfileSettingsSection({super.key});

  @override
  State<AccountProfileSettingsSection> createState() =>
      _AccountProfileSettingsSectionState();
}

class _AccountProfileSettingsSectionState
    extends State<AccountProfileSettingsSection> {
  final _imagePicker = ImagePicker();
  final _descriptionController = TextEditingController();

  _AccountProfileKind? _kind;
  String? _profileId;
  String? _venueId;
  String? _profileImageUrl;
  String _description = '';
  int? _studioVersion;
  int? _listenerVersion;
  ListenerVisibilityMode _listenerVisibilityMode =
      ListenerVisibilityMode.standard;
  bool _listenerProfileContentEditable = true;
  bool _available = true;
  bool _loading = true;
  bool _editingDescription = false;
  bool _savingDescription = false;
  bool _uploadingPhoto = false;
  bool _updatingListenerVisibility = false;
  String? _loadError;

  bool get _profileMutationBusy =>
      _savingDescription || _uploadingPhoto || _updatingListenerVisibility;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  _AccountProfileKind? _resolveKind() {
    final session = serviceLocator<AuthSessionManager>().session;
    if (session.hasAnyRole(const ['ROLE_STUDIO', 'STUDIO'])) {
      return _AccountProfileKind.studio;
    }
    if (session.hasAnyRole(const ['ROLE_VENUE', 'VENUE'])) {
      return _AccountProfileKind.venue;
    }
    if (session.hasAnyRole(const ['ROLE_MUSICIAN', 'MUSICIAN'])) {
      return _AccountProfileKind.musician;
    }
    if (session.hasAnyRole(const ['ROLE_LISTENER', 'LISTENER'])) {
      return _AccountProfileKind.listener;
    }
    return null;
  }

  Future<void> _loadProfile() async {
    final kind = _resolveKind();
    if (kind == null || !_repositoryIsAvailable(kind)) {
      if (mounted) {
        setState(() {
          _available = false;
          _loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _kind = kind;
        _loading = true;
        _loadError = null;
      });
    }

    switch (kind) {
      case _AccountProfileKind.musician:
        final result = await serviceLocator<MusicianProfileRepository>()
            .getMyProfile();
        if (!mounted) return;
        final profile = result.data;
        if (!result.isSuccess || profile == null) {
          _setLoadFailure(result.error?.message);
          return;
        }
        _applyLoadedProfile(
          profileId: profile.id,
          imageUrl: profile.profilePicture,
          description: profile.bio,
        );
      case _AccountProfileKind.venue:
        final result = await serviceLocator<VenueProfileRepository>()
            .getMyVenueProfileDetail();
        if (!mounted) return;
        final profile = result.data;
        if (!result.isSuccess || profile == null) {
          _setLoadFailure(result.error?.message);
          return;
        }
        _venueId = profile.venueId;
        _applyLoadedProfile(
          profileId: profile.venueProfileId,
          imageUrl: profile.profilePictureUrl,
          description: profile.bio ?? profile.description,
        );
      case _AccountProfileKind.studio:
        final result = await serviceLocator<StudioProfileRepository>()
            .getMyProfile();
        if (!mounted) return;
        final profile = result.data;
        if (!result.isSuccess || profile == null) {
          _setLoadFailure(result.error?.message);
          return;
        }
        _studioVersion = profile.version;
        _applyLoadedProfile(
          profileId: profile.id,
          imageUrl: profile.profilePictureUrl,
          description: profile.description,
        );
      case _AccountProfileKind.listener:
        final result = await serviceLocator<ListenerProfileRepository>()
            .getMyProfile();
        if (!mounted) return;
        final profile = result.data;
        if (!result.isSuccess || profile == null) {
          _setLoadFailure(result.error?.message);
          return;
        }
        _applyLoadedProfile(
          profileId: profile.id,
          imageUrl: profile.profilePictureUrl,
          description: profile.bio,
          listenerVersion: profile.version,
          listenerVisibilityMode: profile.visibilityMode,
          listenerProfileContentEditable: profile.profileContentEditable,
        );
    }
  }

  bool _repositoryIsAvailable(_AccountProfileKind kind) => switch (kind) {
    _AccountProfileKind.musician =>
      serviceLocator.isRegistered<MusicianProfileRepository>(),
    _AccountProfileKind.venue =>
      serviceLocator.isRegistered<VenueProfileRepository>(),
    _AccountProfileKind.studio =>
      serviceLocator.isRegistered<StudioProfileRepository>(),
    _AccountProfileKind.listener =>
      serviceLocator.isRegistered<ListenerProfileRepository>(),
  };

  void _applyLoadedProfile({
    required String profileId,
    required String? imageUrl,
    required String? description,
    int? listenerVersion,
    ListenerVisibilityMode? listenerVisibilityMode,
    bool? listenerProfileContentEditable,
  }) {
    final normalizedDescription = description?.trim() ?? '';
    setState(() {
      _profileId = profileId;
      _profileImageUrl = imageUrl?.trim();
      _description = normalizedDescription;
      if (listenerVersion != null) _listenerVersion = listenerVersion;
      if (listenerVisibilityMode != null) {
        _listenerVisibilityMode = listenerVisibilityMode;
      }
      if (listenerProfileContentEditable != null) {
        _listenerProfileContentEditable = listenerProfileContentEditable;
      }
      if (!_editingDescription) {
        _descriptionController.text = normalizedDescription;
      }
      _loading = false;
      _loadError = null;
    });
  }

  void _setLoadFailure(String? message) {
    setState(() {
      _loading = false;
      _loadError = message ?? 'Profil bilgileri getirilemedi.';
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePhoto() async {
    final kind = _kind;
    final profileId = _profileId;
    if (kind == null || profileId == null || _profileMutationBusy) return;
    if (kind == _AccountProfileKind.listener && _listenerVersion == null) {
      _showMessage(
        'Profilin güncel sürümü alınamadı. Sayfayı yenileyip tekrar dene.',
      );
      return;
    }
    setState(() => _uploadingPhoto = true);
    try {
      final upload = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: switch (kind) {
          _AccountProfileKind.musician => 'MUSICIAN_PROFILE',
          _AccountProfileKind.venue => 'VENUE_PROFILE',
          _AccountProfileKind.studio => 'STUDIO_PROFILE',
          _AccountProfileKind.listener => 'LISTENER_PROFILE',
        },
        ownerId: profileId,
        profilePhotoTargetId: kind == _AccountProfileKind.venue
            ? _venueId
            : null,
        profilePhotoExpectedVersion: kind == _AccountProfileKind.listener
            ? _listenerVersion
            : null,
        cropTitle: 'Profil fotoğrafını kırp',
      );
      if (upload == null || !mounted) return;

      final failure = await _attachUploadedPhoto(kind, upload.assetId);
      if (!mounted) return;
      if (failure != null) {
        _showMessage(failure);
        return;
      }
      // Listener attachment reloads the authoritative owner projection above.
      // Do not replace its URL with an upload-host URL that may be temporary.
      if (kind != _AccountProfileKind.listener) {
        setState(() => _profileImageUrl = upload.preferredUrl);
      }
      _showMessage('Profil fotoğrafın güncellendi.');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<String?> _attachUploadedPhoto(
    _AccountProfileKind kind,
    String assetId,
  ) async {
    switch (kind) {
      case _AccountProfileKind.musician:
        final result = await serviceLocator<MusicianProfileRepository>()
            .updateMyProfile(
              MusicianProfileSaveRequest(profilePicture: assetId),
            );
        return result.isSuccess
            ? null
            : result.error?.message ?? 'Profil fotoğrafı güncellenemedi.';
      case _AccountProfileKind.venue:
        final result = await serviceLocator<VenueProfileRepository>()
            .updateMyVenueProfileDetail(
              VenueProfileSaveRequest(profilePicture: assetId),
              venueId: _venueId,
            );
        return result.isSuccess
            ? null
            : result.error?.message ?? 'Profil fotoğrafı güncellenemedi.';
      case _AccountProfileKind.studio:
        // Stüdyo medya yükleme akışı fotoğrafı profile kendisi bağlıyor.
        return null;
      case _AccountProfileKind.listener:
        // Listener profile-picture uploads are attached atomically by the
        // durable upload pipeline through the dedicated avatar endpoint. Read
        // the owner projection back so the optimistic visibility version is
        // rebased before the next settings mutation.
        final result = await serviceLocator<ListenerProfileRepository>()
            .getMyProfile();
        final profile = result.data;
        if (!result.isSuccess || profile == null) {
          return 'Profil fotoğrafı güncellendi ancak güncel profil bilgisi alınamadı. Sayfayı yenileyip tekrar kontrol et.';
        }
        if (mounted) {
          setState(() {
            _listenerVersion = profile.version;
            _listenerVisibilityMode = profile.visibilityMode;
            _listenerProfileContentEditable = profile.profileContentEditable;
            _profileImageUrl = profile.profilePictureUrl;
          });
        }
        return null;
    }
  }

  Future<void> _saveDescription() async {
    final kind = _kind;
    if (kind == null || _profileMutationBusy) return;
    final description = _descriptionController.text.trim();
    setState(() => _savingDescription = true);
    try {
      final failure = await _updateDescription(kind, description);
      if (!mounted) return;
      if (failure != null) {
        _showMessage(failure);
        return;
      }
      setState(() {
        _description = description;
        _editingDescription = false;
      });
      _showMessage('Açıklaman güncellendi.');
    } finally {
      if (mounted) setState(() => _savingDescription = false);
    }
  }

  Future<String?> _updateDescription(
    _AccountProfileKind kind,
    String description,
  ) async {
    switch (kind) {
      case _AccountProfileKind.musician:
        final result = await serviceLocator<MusicianProfileRepository>()
            .updateMyProfile(
              MusicianProfileSaveRequest(description: description),
            );
        return result.isSuccess
            ? null
            : result.error?.message ?? 'Açıklama güncellenemedi.';
      case _AccountProfileKind.venue:
        final result = await serviceLocator<VenueProfileRepository>()
            .updateMyVenueProfileDetail(
              VenueProfileSaveRequest(bio: description),
              venueId: _venueId,
            );
        return result.isSuccess
            ? null
            : result.error?.message ?? 'Açıklama güncellenemedi.';
      case _AccountProfileKind.studio:
        final result = await serviceLocator<StudioProfileRepository>()
            .updateMyProfile(
              StudioProfileSaveRequest(
                description: description,
                version: _studioVersion,
              ),
            );
        if (result.isSuccess) {
          _studioVersion = result.data?.version ?? _studioVersion;
          return null;
        }
        return result.error?.message ?? 'Açıklama güncellenemedi.';
      case _AccountProfileKind.listener:
        if (!_listenerProfileContentEditable) {
          return 'Hayalet profil açıkken profil açıklaması düzenlenemez.';
        }
        final result = await serviceLocator<ListenerProfileRepository>()
            .updateMyProfile(
              ListenerProfileSaveRequest(description: description),
            );
        final profile = result.data;
        if (!result.isSuccess || profile == null) {
          return result.error?.message ?? 'Açıklama güncellenemedi.';
        }
        if (mounted) {
          setState(() {
            _listenerVersion = profile.version;
            _listenerVisibilityMode = profile.visibilityMode;
            _listenerProfileContentEditable = profile.profileContentEditable;
            _profileImageUrl = profile.profilePictureUrl;
          });
        }
        return null;
    }
  }

  void _startEditingDescription() {
    if (_profileMutationBusy) return;
    _descriptionController.text = _description;
    setState(() => _editingDescription = true);
  }

  void _cancelEditingDescription() {
    FocusManager.instance.primaryFocus?.unfocus();
    _descriptionController.text = _description;
    setState(() => _editingDescription = false);
  }

  Future<void> _changeListenerVisibility(bool enableGhost) async {
    if (_kind != _AccountProfileKind.listener ||
        _profileMutationBusy ||
        _listenerVersion == null) {
      return;
    }

    if (enableGhost) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hayalet profile geç?'),
          content: const Text(
            'Mevcut takipçilerin kalıcı olarak kaldırılır ve bu işlem geri alınamaz.\n\n'
            'Profil içeriklerin silinmez; saklanır, görünmez olur ve Hayalet Profil açıkken düzenlenemez. Yeni takipçi alamazsın. Takip ettiklerin ve mesajların kalır.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              key: const Key('confirm-enable-ghost-profile'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hayalet profile geç'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    if (_profileMutationBusy) return;

    final requestedMode = enableGhost
        ? ListenerVisibilityMode.ghost
        : ListenerVisibilityMode.standard;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _updatingListenerVisibility = true;
      _editingDescription = false;
      _descriptionController.text = _description;
    });
    try {
      final result = await serviceLocator<ListenerProfileRepository>()
          .updateVisibility(
            ListenerVisibilityUpdateRequest(
              visibilityMode: requestedMode,
              expectedVersion: _listenerVersion!,
            ),
          );
      if (!mounted) return;
      final profile = result.data;
      if (!result.isSuccess || profile == null) {
        final code = result.error?.code.trim().toUpperCase();
        if (code == '1304' || code == 'LISTENER_PROFILE_VERSION_CONFLICT') {
          final refreshed = await _reloadListenerAfterConflict();
          if (!mounted) return;
          _showMessage(
            refreshed
                ? 'Görünürlük başka bir oturumda değişti. Güncel ayarı yükledik; kontrol edip tekrar dene.'
                : 'Görünürlük başka bir oturumda değişti. Profili yenileyip tekrar dene.',
          );
          return;
        }
        _showMessage(listenerVisibilityErrorMessage(result.error));
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _listenerVersion = profile.version;
        _listenerVisibilityMode = profile.visibilityMode;
        _listenerProfileContentEditable = profile.profileContentEditable;
        _profileImageUrl = profile.profilePictureUrl;
        _description = profile.bio?.trim() ?? _description;
        _editingDescription = false;
      });
      _showMessage(
        profile.isGhost
            ? 'Hayalet Profil açıldı.'
            : 'Profilin yeniden görünür.',
      );
    } finally {
      if (mounted) setState(() => _updatingListenerVisibility = false);
    }
  }

  Future<bool> _reloadListenerAfterConflict() async {
    final result = await serviceLocator<ListenerProfileRepository>()
        .getMyProfile();
    if (!mounted || !result.isSuccess || result.data == null) return false;
    final profile = result.data!;
    setState(() {
      _listenerVersion = profile.version;
      _listenerVisibilityMode = profile.visibilityMode;
      _listenerProfileContentEditable = profile.profileContentEditable;
      _profileImageUrl = profile.profilePictureUrl;
      _description = profile.bio?.trim() ?? _description;
      _editingDescription = false;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          ListTile(
            key: const Key('account-settings-profile-load-error'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Profil bilgileri getirilemedi'),
            subtitle: Text(_loadError!),
            trailing: TextButton(
              onPressed: _loadProfile,
              child: const Text('Tekrar dene'),
            ),
          )
        else ...[
          const SizedBox(height: 4),
          Center(
            key: const Key('account-settings-profile-photo'),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _profileMutationBusy ? null : _changePhoto,
              child: _ProfileAvatar(
                imageUrl: _profileImageUrl,
                uploading: _uploadingPhoto,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_kind == _AccountProfileKind.listener) ...[
            _ListenerVisibilityCard(
              isGhost: _listenerVisibilityMode.isGhost,
              updating: _profileMutationBusy,
              onChanged: _changeListenerVisibility,
            ),
            const SizedBox(height: 14),
          ],
          if (_kind != _AccountProfileKind.listener ||
              _listenerProfileContentEditable)
            InkWell(
              key: const Key('account-settings-profile-description'),
              borderRadius: BorderRadius.circular(12),
              onTap: _profileMutationBusy || _editingDescription
                  ? null
                  : _startEditingDescription,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _description.isEmpty
                            ? 'Açıklama eklemek için dokun'
                            : _description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          if (_kind == _AccountProfileKind.listener &&
              !_listenerProfileContentEditable)
            Padding(
              key: const Key('account-settings-ghost-content-notice'),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Profil içeriğin güvende. Hayalet Profil açıkken görünmez ve düzenlenemez; görünür profile döndüğünde yeniden burada olur.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          if (_editingDescription)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('account-settings-description-field'),
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1024,
                    textInputAction: TextInputAction.newline,
                    enabled: !_profileMutationBusy,
                    decoration: InputDecoration(
                      hintText: 'Profilini birkaç cümleyle anlat',
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _profileMutationBusy
                              ? null
                              : _cancelEditingDescription,
                          child: const Text('İptal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GradientOutlineButton(
                          key: const Key(
                            'account-settings-save-description-button',
                          ),
                          onPressed: _profileMutationBusy
                              ? null
                              : _saveDescription,
                          loading: _savingDescription,
                          label: _savingDescription
                              ? 'Kaydediliyor...'
                              : 'Kaydet',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _ListenerVisibilityCard extends StatelessWidget {
  const _ListenerVisibilityCard({
    required this.isGhost,
    required this.updating,
    required this.onChanged,
  });

  final bool isGhost;
  final bool updating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        key: const Key('account-settings-listener-visibility'),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isGhost
                ? AppColors.brandGradient.last.withValues(alpha: 0.5)
                : Theme.of(context).dividerColor,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile.adaptive(
          key: const Key('listener-ghost-profile-switch'),
          value: isGhost,
          onChanged: updating ? null : onChanged,
          secondary: Icon(
            isGhost ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          ),
          title: const Text('Hayalet Profil'),
          subtitle: Text(
            isGhost
                ? 'Profil içeriğin gizli; takip ettiklerin ve mesajların aktif.'
                : 'SoundConnect’i kullanırken profil içeriğini ve takipçilerini gizle.',
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl, required this.uploading});

  final String? imageUrl;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = imageUrl?.trim();
    final hasImage = isValidNetworkImageUrl(resolvedUrl);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient.last.withValues(alpha: 0.24),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: hasImage
                        ? AppCachedNetworkImage(
                            imageUrl: resolvedUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_) => const Icon(
                              Icons.person_outline_rounded,
                              size: 38,
                            ),
                          )
                        : const Icon(Icons.person_outline_rounded, size: 38),
                  ),
                ),
              ),
            ),
          ),
          if (uploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.pureBlack.withValues(alpha: 0.48),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(34),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    colors: AppColors.brandGradient,
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
