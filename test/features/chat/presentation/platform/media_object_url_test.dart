import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/chat/presentation/platform/media_object_url.dart';

void main() {
  test('createMediaObjectUrlPlatform uses stub behavior on VM tests', () {
    final platform = createMediaObjectUrlPlatform();

    final objectUrl = platform.createObjectUrl(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      mimeType: 'image/png',
    );
    expect(objectUrl, '');

    platform.revokeObjectUrl('');
    platform.revokeObjectUrl('blob:example');
    platform.triggerDownload(url: 'blob:example', filename: 'photo.png');
  });
}
