import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/shared/domain/failure.dart';

void main() {
  group('Failure', () {
    test('UnauthorizedFailure uses default message when omitted', () {
      final failure = UnauthorizedFailure();
      expect(
        failure.message,
        'Unauthorized request.',
      );
    });

    test('failure subtypes preserve provided messages', () {
      expect(const ValidationFailure('v').message, 'v');
      expect(const NetworkFailure('n').message, 'n');
      expect(const ApiFailure(418, 'a').message, 'a');
      expect(const SessionExpiredFailure('s').message, 's');
      expect(const UnexpectedFailure('u').message, 'u');
    });
  });
}
