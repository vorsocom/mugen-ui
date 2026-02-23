import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';

enum ChatComposedPartType { text, attachment }

class ChatComposedPartEntity {
  const ChatComposedPartEntity._({
    required this.type,
    this.text,
    this.attachmentId,
    this.caption,
    this.metadata = const <String, dynamic>{},
  });

  const ChatComposedPartEntity.text({required String text})
    : this._(type: ChatComposedPartType.text, text: text);

  const ChatComposedPartEntity.attachment({
    required String attachmentId,
    String? caption,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) : this._(
         type: ChatComposedPartType.attachment,
         attachmentId: attachmentId,
         caption: caption,
         metadata: metadata,
       );

  final ChatComposedPartType type;
  final String? text;
  final String? attachmentId;
  final String? caption;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson({required ChatCompositionMode compositionMode}) {
    switch (type) {
      case ChatComposedPartType.text:
        return <String, dynamic>{'type': 'text', 'text': text ?? ''};
      case ChatComposedPartType.attachment:
        return <String, dynamic>{
          'type': 'attachment',
          'id': attachmentId ?? '',
          if (caption != null && caption!.trim().isNotEmpty) 'caption': caption,
          if (metadata.isNotEmpty) 'metadata': metadata,
        };
    }
  }
}
