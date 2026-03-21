import 'dart:typed_data';

class ChatComposedAttachmentEntity {
  const ChatComposedAttachmentEntity({
    required this.id,
    required this.filename,
    required this.mimeType,
    required this.bytes,
    this.caption,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String filename;
  final String mimeType;
  final Uint8List bytes;
  final String? caption;
  final Map<String, dynamic> metadata;
}
