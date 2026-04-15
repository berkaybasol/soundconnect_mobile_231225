import 'dart:typed_data';

const Set<String> _allowedAudioExtensions = <String>{
  'mp3',
  'm4a',
  'aac',
  'wav',
  'waw',
  'ogg',
  'flac',
};

String profileAudioMimeTypeFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.waw')) return 'audio/wav';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  if (lower.endsWith('.flac')) return 'audio/flac';
  return 'audio/mpeg';
}

String profileAudioFileNameFromPath(
  String path, {
  String fallback = 'audio.mp3',
}) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  final name = parts.isNotEmpty ? parts.last.trim() : '';
  return name.isEmpty ? fallback : name;
}

String profileAudioTitleFromFileName(String fileName) {
  final idx = fileName.lastIndexOf('.');
  if (idx <= 0) return fileName;
  return fileName.substring(0, idx);
}

String? profileAudioUploadValidationError({
  required String fileName,
  String? filePath,
  Uint8List? bytes,
}) {
  final extension = _audioExtensionOf(fileName, filePath: filePath);
  if (extension == null || !_allowedAudioExtensions.contains(extension)) {
    return 'Sadece ses dosyasi secilebilir: ${_allowedAudioExtensions.join(', ')}';
  }

  if (bytes != null && _looksLikeImage(bytes)) {
    return 'Secilen dosya bir gorsel gibi gorunuyor. Lutfen ses dosyasi sec.';
  }

  return null;
}

String? _audioExtensionOf(String fileName, {String? filePath}) {
  String source = fileName.trim();
  if (source.isEmpty && filePath != null && filePath.trim().isNotEmpty) {
    source = profileAudioFileNameFromPath(filePath);
  }
  final int idx = source.lastIndexOf('.');
  if (idx < 0 || idx == source.length - 1) return null;
  return source.substring(idx + 1).toLowerCase();
}

bool _looksLikeImage(Uint8List bytes) {
  if (bytes.length < 4) return false;

  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
  // PNG
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return true;
  }
  // GIF
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return true;
  }
  // WEBP: RIFF....WEBP
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  // BMP
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
  // HEIC/HEIF family: ....ftypheic / heix / hevc / mif1 / msf1
  if (bytes.length >= 12 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    final String brand = String.fromCharCodes(
      bytes.sublist(8, 12),
    ).toLowerCase();
    if (brand == 'heic' ||
        brand == 'heix' ||
        brand == 'hevc' ||
        brand == 'hevx' ||
        brand == 'mif1' ||
        brand == 'msf1') {
      return true;
    }
  }

  return false;
}
