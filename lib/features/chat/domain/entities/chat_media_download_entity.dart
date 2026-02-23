import 'dart:typed_data';

class ChatMediaDownloadEntity {
  const ChatMediaDownloadEntity({
    required this.bytes,
    this.mimeType,
    this.filename,
  });

  final Uint8List bytes;
  final String? mimeType;
  final String? filename;
}
