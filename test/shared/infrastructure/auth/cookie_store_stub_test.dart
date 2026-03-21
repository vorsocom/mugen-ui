import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';

void main() {
  test('cookie store purges immediately-expired cookies', () {
    final store = createCookieStore();
    store.setCookie('auth', 'expired', -1, '/');

    expect(store.getCookie('auth'), isNull);
  });

  test('cookie store returns newest value for duplicate keys', () async {
    final store = createCookieStore();
    store.setCookie('auth', 'first', 60, '/');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    store.setCookie('auth', 'second', 60, '/');

    expect(store.getCookie('auth'), 'second');
  });

  test('cookie store sorts duplicate keys across paths by recency', () async {
    final store = createCookieStore();
    store.setCookie('auth', 'root', 60, '/');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    store.setCookie('auth', 'admin', 60, '/admin');

    expect(store.getCookie('auth'), 'admin');
  });
}
