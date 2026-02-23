import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:mugen_ui/features/chat/presentation/platform/media_object_url.dart';

MediaObjectUrlPlatform createMediaObjectUrlPlatform() =>
    _MediaObjectUrlPlatformWeb();

class _MediaObjectUrlPlatformWeb implements MediaObjectUrlPlatform {
  @override
  String createObjectUrl({required Uint8List bytes, required String mimeType}) {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    return web.URL.createObjectURL(blob);
  }

  @override
  void revokeObjectUrl(String url) {
    if (url.isEmpty) {
      return;
    }

    web.URL.revokeObjectURL(url);
  }

  @override
  void triggerDownload({required String url, required String filename}) {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }
}
