import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/track_management_repository.dart';
import '../cubit/profile_media_cubit.dart';
import 'profile_audio_file_support.dart';
import 'profile_screen_support.dart';

Future<void> showProfileTrackUploadSheet({
  required BuildContext hostContext,
  required String profileId,
  required String ownerType,
  required String profileType,
}) async {
  final messenger = ScaffoldMessenger.of(hostContext);
  String? pickedPath;
  Uint8List? pickedBytes;
  String? pickedName;
  final titleController = TextEditingController();
  bool uploading = false;
  String? infoText;
  bool infoError = false;

  await showModalBottomSheet<void>(
    context: hostContext,
    isScrollControlled: true,
    backgroundColor: AppColors.navBlueDeep,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickAudio() async {
            final result = await FilePicker.pickFiles(
              type: FileType.custom,
              withData: true,
              allowMultiple: false,
              allowedExtensions: const [
                'mp3',
                'm4a',
                'aac',
                'wav',
                'waw',
                'ogg',
                'flac',
              ],
            );
            final file = result?.files.isNotEmpty == true
                ? result!.files.first
                : null;
            if (file == null) return;
            final name = file.name.trim().isNotEmpty
                ? file.name.trim()
                : (file.path != null
                      ? profileAudioFileNameFromPath(
                          file.path!,
                          fallback: 'audio.mp3',
                        )
                      : 'audio.mp3');
            setSheetState(() {
              pickedPath = file.path;
              pickedBytes = file.bytes;
              pickedName = name;
              if (titleController.text.trim().isEmpty) {
                titleController.text = profileAudioTitleFromFileName(name);
              }
            });
          }

          Future<void> uploadTrack() async {
            final mediaCubit = hostContext.read<ProfileMediaCubit>();
            var step = 'dosya okuma';
            final path = pickedPath;
            final bytesFromPicker = pickedBytes;
            final name = pickedName;
            final title = titleController.text.trim();
            if ((path == null && bytesFromPicker == null) || name == null) {
              setSheetState(() {
                infoText = 'Once bir ses dosyasi sec.';
                infoError = true;
              });
              return;
            }
            if (title.isEmpty) {
              setSheetState(() {
                infoText = 'Sarki adi zorunlu.';
                infoError = true;
              });
              return;
            }

            setSheetState(() {
              uploading = true;
              infoText = null;
              infoError = false;
            });

            try {
              final bytes = bytesFromPicker ?? await File(path!).readAsBytes();
              if (bytes.isEmpty) {
                throw Exception('Dosya okunamadi');
              }
              final mimeType = profileAudioMimeTypeFromFileName(name);

              step = 'init-upload';
              final completed = await uploadProfileMediaAsset(
                bytes: bytes,
                ownerType: ownerType,
                ownerId: profileId,
                mediaKind: 'AUDIO',
                mimeType: mimeType,
                originalFileName: name,
              );

              step = 'complete-upload';
              final mediaAssetId = completed.uuid.trim();
              if (mediaAssetId.isEmpty) {
                throw Exception('Media asset id alinamadi');
              }

              step = 'track olusturma';
              final trackManagementRepository =
                  serviceLocator<TrackManagementRepository>();
              final trackResult = await trackManagementRepository.createTrack(
                profileId: profileId,
                ownerType: ownerType,
                mediaAssetId: mediaAssetId,
                title: title,
              );
              if (!trackResult.isSuccess) {
                throw Exception(
                  trackResult.error?.message ?? 'Track olusturulamadi',
                );
              }

              try {
                await mediaCubit.loadMedia(
                  profileType: profileType,
                  profileId: profileId,
                );
              } catch (_) {
                // Liste yenileme hatasi non-fatal.
              }
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Sarki basariyla eklendi.')),
              );
            } catch (e) {
              if (!sheetContext.mounted) return;
              setSheetState(() {
                infoText = 'Yukleme basarisiz ($step): $e';
                infoError = true;
              });
              messenger.showSnackBar(
                SnackBar(content: Text('Yukleme basarisiz ($step): $e')),
              );
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => uploading = false);
              }
            }
          }

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'SoundConnect uzerinden sarki ekle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: uploading ? null : pickAudio,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        backgroundColor: AppColors.inputFill,
                      ),
                      icon: const Icon(Icons.library_music_outlined),
                      label: Text(
                        pickedName == null ? 'Ses dosyasi sec' : pickedName!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      enabled: !uploading,
                      controller: titleController,
                      cursorColor: AppColors.textPrimary,
                      decoration: InputDecoration(
                        hintText: 'Sarki adi',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    if (infoText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        infoText!,
                        style: TextStyle(
                          color: infoError
                              ? const Color(0xFFFFB4B4)
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: uploading ? null : uploadTrack,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coralAlt,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(uploading ? 'Yukleniyor...' : 'Yukle'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
