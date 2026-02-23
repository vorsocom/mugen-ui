import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/chat/infrastructure/storage/chat_local_storage.dart';

void main() {
  test('createChatLocalStorage stores, reads, and removes values', () {
    final storage = createChatLocalStorage();

    expect(storage.getItem('missing'), isNull);

    storage.setItem('token', 'value-1');
    expect(storage.getItem('token'), 'value-1');

    storage.setItem('token', 'value-2');
    expect(storage.getItem('token'), 'value-2');

    storage.removeItem('token');
    expect(storage.getItem('token'), isNull);
  });
}
