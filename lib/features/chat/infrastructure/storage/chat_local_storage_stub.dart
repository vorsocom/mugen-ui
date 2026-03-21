import 'package:mugen_ui/features/chat/infrastructure/storage/chat_local_storage.dart';

ChatLocalStorage createChatLocalStorage() => _ChatLocalStorageStub();

class _ChatLocalStorageStub implements ChatLocalStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  String? getItem(String key) {
    return _values[key];
  }

  @override
  void removeItem(String key) {
    _values.remove(key);
  }

  @override
  void setItem(String key, String value) {
    _values[key] = value;
  }
}
