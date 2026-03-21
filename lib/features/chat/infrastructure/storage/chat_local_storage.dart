import 'package:mugen_ui/features/chat/infrastructure/storage/chat_local_storage_stub.dart'
    if (dart.library.html) 'package:mugen_ui/features/chat/infrastructure/storage/chat_local_storage_web.dart'
    as storage_impl;

abstract class ChatLocalStorage {
  String? getItem(String key);
  void setItem(String key, String value);
  void removeItem(String key);
}

ChatLocalStorage createChatLocalStorage() =>
    storage_impl.createChatLocalStorage();
