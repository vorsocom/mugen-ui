import 'dart:typed_data';

import 'package:mugen_ui/features/chat/presentation/platform/media_object_url_stub.dart'
    if (dart.library.html) 'package:mugen_ui/features/chat/presentation/platform/media_object_url_web.dart'
    as media_impl;

abstract class MediaObjectUrlPlatform {
  String createObjectUrl({required Uint8List bytes, required String mimeType});

  void revokeObjectUrl(String url);

  void triggerDownload({required String url, required String filename});
}

MediaObjectUrlPlatform createMediaObjectUrlPlatform() =>
    media_impl.createMediaObjectUrlPlatform();
