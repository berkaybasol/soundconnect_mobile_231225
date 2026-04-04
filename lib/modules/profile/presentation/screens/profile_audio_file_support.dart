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
