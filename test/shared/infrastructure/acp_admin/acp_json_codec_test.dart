import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_json_codec.dart';

void main() {
  test('parse accepts maps and lists', () {
    final mapResult = AcpJsonCodec.parse('{"name":"mugen"}');
    final listResult = AcpJsonCodec.parse('["a","b"]');

    expect(mapResult.isSuccess, isTrue);
    expect(mapResult.data, <String, Object?>{'name': 'mugen'});
    expect(listResult.isSuccess, isTrue);
    expect(listResult.data, <Object?>['a', 'b']);
  });

  test('parse rejects invalid json', () {
    final result = AcpJsonCodec.parse('{');

    expect(result.isFailure, isTrue);
    expect(result.failure?.message, 'Enter valid JSON.');
  });

  test('prettyPrint expands JSON strings and round-trips objects', () {
    final printedString = AcpJsonCodec.prettyPrint('{"name":"mugen"}');
    final printedObject = AcpJsonCodec.prettyPrint(<String, Object?>{
      'name': 'mugen',
      'enabled': true,
    });

    expect(printedString, '{\n  "name": "mugen"\n}');
    expect(printedObject, contains('"enabled": true'));
  });
}
