import 'package:web/web.dart' as web;
import 'package:mugen_ui/shared/infrastructure/auth/cookie_codec.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';

CookieStore createCookieStore() => _CookieStoreWeb();

class _CookieStoreWeb implements CookieStore {
  @override
  void setCookie(String key, String value, int maxAge, String path) {
    web.window.document.cookie = buildSetCookieDirective(
      key: key,
      value: value,
      maxAge: maxAge,
      path: path,
      secure: _isHttps,
      sameSite: 'Lax',
    );
  }

  @override
  String? getCookie(String key) {
    final cookies = web.window.document.cookie;
    if (cookies.isEmpty) {
      return null;
    }

    final parsed = parseCookieHeader(cookies);
    final value = parsed[key];
    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  @override
  void removeCookie(String key, String path) {
    web.window.document.cookie = buildSetCookieDirective(
      key: key,
      value: '',
      maxAge: 0,
      path: path,
      secure: _isHttps,
      sameSite: 'Lax',
    );
  }

  bool get _isHttps => web.window.location.protocol.toLowerCase() == 'https:';
}
