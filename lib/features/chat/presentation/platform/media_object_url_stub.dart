import 'dart:typed_data';

import 'package:mugen_ui/features/chat/presentation/platform/media_object_url.dart';

MediaObjectUrlPlatform createMediaObjectUrlPlatform() =>
    _MediaObjectUrlPlatformStub();

class _MediaObjectUrlPlatformStub implements MediaObjectUrlPlatform {
  @override
  String createObjectUrl({required Uint8List bytes, required String mimeType}) {
    return '';
  }

  @override
  void revokeObjectUrl(String url) {}

  @override
  void triggerDownload({required String url, required String filename}) {}
}
