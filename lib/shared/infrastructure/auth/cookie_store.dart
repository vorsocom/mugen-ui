import 'package:mugen_ui/shared/infrastructure/auth/cookie_store_stub.dart'
    if (dart.library.html) 'package:mugen_ui/shared/infrastructure/auth/cookie_store_web.dart'
    as cookie_impl;

abstract class CookieStore {
  void setCookie(String key, String value, int maxAge, String path);
  String? getCookie(String key);
  void removeCookie(String key, String path);
}

CookieStore createCookieStore() => cookie_impl.createCookieStore();
