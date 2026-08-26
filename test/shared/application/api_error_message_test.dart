import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/api_error_message.dart';

void main() {
  group('normalizeApiErrorMessage', () {
    test('uses a safe fallback for missing or unusable input', () {
      expect(normalizeApiErrorMessage(null), 'API request failed.');
      expect(
        normalizeApiErrorMessage('   ', fallback: 'Request could not load.'),
        'Request could not load.',
      );
      expect(
        normalizeApiErrorMessage('', fallback: '<script>bad()</script>'),
        'API request failed.',
      );
    });

    test('extracts standard JSON problem messages case-insensitively', () {
      expect(
        normalizeApiErrorMessage('{"DETAIL":"Catalog is unavailable."}'),
        'Catalog is unavailable.',
      );
      expect(
        normalizeApiErrorMessage('{"message":"<b>Duplicate</b> code"}'),
        'Duplicate code',
      );
      expect(
        normalizeApiErrorMessage('{"error":{"message":"Nested error"}}'),
        'Nested error',
      );
      expect(normalizeApiErrorMessage('42'), '42');
      expect(normalizeApiErrorMessage('true'), 'true');
    });

    test('flattens validation maps, lists, and otherwise unknown objects', () {
      expect(
        normalizeApiErrorMessage(
          '{"errors":{"Code":["Already exists.","Choose another."],"Name":"Required."}}',
        ),
        'Code: Already exists. Choose another.\nName: Required.',
      );
      expect(
        normalizeApiErrorMessage('{"errors":["First", "Second"]}'),
        'First Second',
      );
      expect(
        normalizeApiErrorMessage(
          '["First problem",{"detail":"Second problem"}]',
        ),
        'First problem Second problem',
      );
      expect(
        normalizeApiErrorMessage('{"field":"invalid","count":2,"empty":null}'),
        'field: invalid\ncount: 2',
      );
      expect(normalizeApiErrorMessage('{}'), 'API request failed.');
      expect(normalizeApiErrorMessage('[]'), 'API request failed.');
    });

    test('summarizes HTML and removes unsafe or duplicate content', () {
      const body = '''
        <!DOCTYPE html>
        <html><head>
          <title>403 Forbidden</title>
          <style>body { color: red; }</style>
          <script>alert('bad')</script>
        </head><body>
          <!-- proxy detail -->
          <h1>403 Forbidden</h1>
          <p>You don&#39;t have &quot;catalog&quot; permission.&nbsp;</p>
          <p>Request &#x62;locked.</p>
        </body></html>
      ''';

      expect(
        normalizeApiErrorMessage(body),
        '403 Forbidden: You don\'t have "catalog" permission. Request blocked.',
      );
      expect(
        normalizeApiErrorMessage('<section><p>Gateway failed.</p></section>'),
        'Gateway failed.',
      );
      expect(
        normalizeApiErrorMessage('<html><body><br>Unavailable</body></html>'),
        'Unavailable',
      );
      expect(
        normalizeApiErrorMessage('<html><title> </title></html>'),
        'API request failed.',
      );
    });

    test('preserves plain text, line structure, and non-HTML comparisons', () {
      expect(
        normalizeApiErrorMessage('  First line \r\n  Second   line  '),
        'First line\nSecond line',
      );
      expect(
        normalizeApiErrorMessage('Amount must be < total and > zero.'),
        'Amount must be < total and > zero.',
      );
      expect(
        normalizeApiErrorMessage('Bad &#x110000; and &#xD800; entities'),
        'Bad &#x110000; and &#xD800; entities',
      );
    });

    test('bounds excessively long messages', () {
      final normalized = normalizeApiErrorMessage('x' * 700);
      final complete = normalizeApiErrorMessage('x' * 700, maximumLength: null);
      final tiny = normalizeApiErrorMessage('long', maximumLength: 1);

      expect(normalized.length, 600);
      expect(normalized.endsWith('…'), isTrue);
      expect(complete.length, 700);
      expect(tiny, '…');
    });
  });
}
