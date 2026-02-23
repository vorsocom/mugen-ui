import 'package:web/web.dart' as web;

import 'package:mugen_ui/features/chat/infrastructure/storage/chat_local_storage.dart';

ChatLocalStorage createChatLocalStorage() => _ChatLocalStorageWeb();

class _ChatLocalStorageWeb implements ChatLocalStorage {
  @override
  String? getItem(String key) {
    return web.window.localStorage.getItem(key);
  }

  @override
  void removeItem(String key) {
    web.window.localStorage.removeItem(key);
  }

  @override
  void setItem(String key, String value) {
    web.window.localStorage.setItem(key, value);
  }
}
