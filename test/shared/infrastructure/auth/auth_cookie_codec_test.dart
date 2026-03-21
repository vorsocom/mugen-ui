import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/infrastructure/auth/auth_cookie_codec.dart';

void main() {
  test('parseAuthSession returns null for invalid payloads', () {
    expect(parseAuthSession(null), isNull);
    expect(parseAuthSession(''), isNull);
    expect(parseAuthSession('not-json'), isNull);
    expect(parseAuthSession('[]'), isNull);
  });

  test('parseAuthSession parses valid auth cookie payload', () {
    final session = parseAuthSession(
      '{"access_token":"a","refresh_token":"r","user_id":"u1","username":"admin","roles":["role:a","role:b"],"access_token_expires":4102444800}',
    );

    expect(session, isNotNull);
    expect(session!.accessToken, 'a');
    expect(session.refreshToken, 'r');
    expect(session.userId, 'u1');
    expect(session.username, 'admin');
    expect(session.roles, <String>['role:a', 'role:b']);
    expect(session.accessTokenExpires, isNotNull);
  });

  test(
    'parseAuthSession normalizes roles and supports numeric/string expiries',
    () {
      final fromNum = parseAuthSession(
        '{"access_token":"a","refresh_token":"r","user_id":"u1","roles":["admin"," ","user"],"access_token_expires":4102444800.25}',
      );
      expect(fromNum, isNotNull);
      expect(fromNum!.roles, <String>['admin', 'user']);
      expect(fromNum.accessTokenExpires, isNotNull);

      final fromString = parseAuthSession(
        '{"access_token":"a","refresh_token":"r","user_id":"u1","access_token_expires":"4102444801"}',
      );
      expect(fromString?.accessTokenExpires, isNotNull);
    },
  );

  test('encodeAuthSession returns JSON payload', () {
    final encoded = encodeAuthSession(<String, dynamic>{
      'access_token': 'a',
      'refresh_token': 'r',
      'user_id': 'u1',
    });

    expect(encoded, contains('"access_token":"a"'));
    expect(encoded, contains('"refresh_token":"r"'));
    expect(encoded, contains('"user_id":"u1"'));
  });
}
