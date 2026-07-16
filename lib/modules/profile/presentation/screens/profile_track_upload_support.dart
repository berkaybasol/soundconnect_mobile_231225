import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_colors.dart';
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
  Stream<List<int>>? pickedStream;
  int? pickedSize;
  String? pickedName;
  final titleController = TextEditingController();
  bool uploading = false;
  String? infoText;
  bool infoError = false;

  await showModalBottomSheet<void>(
    context: hostContext,
    isScrollControlled: true,
    backgroundColor: AppColors.navBlueDeep,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickAudio() async {
            final result = await FilePicker.pickFiles(
              type: FileType.custom,
              withData: false,
              withReadStream: true,
              allowMultiple: false,
              allowedExtensions: [
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
              pickedStream = file.readStream;
              pickedSize = file.size;
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
            final validationError = profileAudioUploadValidationError(
              fileName: name,
              filePath: path,
              bytes: bytesFromPicker,
            );
            if (validationError != null) {
              setSheetState(() {
                infoText = validationError;
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
              final source = await createProfileUploadSource(
                filePath: path,
                bytes: bytesFromPicker,
                readStream: pickedStream,
                sizeBytes: pickedSize,
              );
              final mimeType = profileAudioMimeTypeFromFileName(name);

              step = 'init-upload';
              final completed = await uploadProfileMediaAsset(
                source: source,
                ownerType: ownerType,
                ownerId: profileId,
                mediaKind: 'AUDIO',
                mimeType: mimeType,
                originalFileName: name,
                attachmentIntent: ProfileUploadAttachmentIntent.track(
                  ownerType: ownerType,
                  title: title,
                ),
                onStageChanged: (stage) {
                  if (!sheetContext.mounted) return;
                  final label = switch (stage) {
                    ProfileUploadStage.initializing => 'Yukleme hazirlaniyor',
                    ProfileUploadStage.uploading => 'Ses dosyasi yukleniyor',
                    ProfileUploadStage.verifying => 'Ses dosyasi dogrulaniyor',
                    ProfileUploadStage.attaching => 'Sarki profile ekleniyor',
                    ProfileUploadStage.backgroundProcessing =>
                      'Sarki arka planda hazirlaniyor',
                    ProfileUploadStage.completed => 'Sarki hazir',
                  };
                  setSheetState(() {
                    infoText = label;
                    infoError = false;
                  });
                },
              );

              step = 'complete-upload';
              final mediaAssetId = completed.uuid.trim();
              if (mediaAssetId.isEmpty) {
                throw Exception('Media asset id alinamadi');
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
                SnackBar(content: Text('Sarki basariyla eklendi.')),
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
            duration: Duration(milliseconds: 180),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'SoundConnect uzerinden sarki ekle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: uploading ? null : pickAudio,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      icon: Icon(Icons.library_music_outlined),
                      label: Text(
                        pickedName == null ? 'Ses dosyasi sec' : pickedName!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      enabled: !uploading,
                      controller: titleController,
                      cursorColor: Theme.of(context).colorScheme.onSurface,
                      decoration: InputDecoration(
                        hintText: 'Sarki adi',
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                    ),
                    if (infoText != null) ...[
                      SizedBox(height: 10),
                      Text(
                        infoText!,
                        style: TextStyle(
                          color: infoError
                              ? Color(0xFFFFB4B4)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: 14),
                    FilledButton(
                      onPressed: uploading ? null : uploadTrack,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coralAlt,
                        foregroundColor: AppColors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
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
