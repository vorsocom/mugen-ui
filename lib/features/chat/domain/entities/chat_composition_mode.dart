enum ChatCompositionMode { messageWithAttachments, attachmentWithCaption }

extension ChatCompositionModeWire on ChatCompositionMode {
  String get wireValue {
    switch (this) {
      case ChatCompositionMode.messageWithAttachments:
        return 'message_with_attachments';
      case ChatCompositionMode.attachmentWithCaption:
        return 'attachment_with_caption';
    }
  }
}
