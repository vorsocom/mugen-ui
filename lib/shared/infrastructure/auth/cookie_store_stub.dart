import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';

CookieStore createCookieStore() => _CookieStoreStub();

class _CookieStoreStub implements CookieStore {
  final Map<String, _CookieRecord> _cookieStorage = <String, _CookieRecord>{};

  @override
  void setCookie(String key, String value, int maxAge, String path) {
    final normalizedPath = _normalizePath(path);
    final expiresAt = maxAge <= 0
        ? DateTime.now()
        : DateTime.now().add(Duration(seconds: maxAge));

    _cookieStorage[_storageKey(key, normalizedPath)] = _CookieRecord(
      key: key,
      value: value,
      path: normalizedPath,
      expiresAt: expiresAt,
      createdAt: DateTime.now(),
    );
  }

  @override
  String? getCookie(String key) {
    _purgeExpiredCookies();

    final candidates = _cookieStorage.values
        .where((record) => record.key == key)
        .toList(growable: false);

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final createdOrder = b.createdAt.compareTo(a.createdAt);
      if (createdOrder != 0) {
        return createdOrder;
      }

      return a.path.length.compareTo(b.path.length);
    });

    final value = candidates.first.value;
    return value.isEmpty ? null : value;
  }

  @override
  void removeCookie(String key, String path) {
    _cookieStorage.remove(_storageKey(key, _normalizePath(path)));
  }

  void _purgeExpiredCookies() {
    final now = DateTime.now();
    _cookieStorage.removeWhere((_, record) {
      final expiresAt = record.expiresAt;
      return expiresAt != null && !expiresAt.isAfter(now);
    });
  }
}

class _CookieRecord {
  _CookieRecord({
    required this.key,
    required this.value,
    required this.path,
    required this.expiresAt,
    required this.createdAt,
  });

  final String key;
  final String value;
  final String path;
  final DateTime? expiresAt;
  final DateTime createdAt;
}

String _normalizePath(String path) {
  return path.isEmpty ? '/' : path;
}

String _storageKey(String key, String path) {
  return '$path::$key';
}
