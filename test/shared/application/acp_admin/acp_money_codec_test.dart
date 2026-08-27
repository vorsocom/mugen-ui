import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_money_codec.dart';
import 'package:mugen_ui/shared/domain/failure.dart';

void main() {
  group('AcpMoneyCodec', () {
    test('parses exact major-unit decimals without floating point', () {
      expect(AcpMoneyCodec.parseMajorUnits(' 19.99 ', minorUnit: 2).data, 1999);
      expect(AcpMoneyCodec.parseMajorUnits('19', minorUnit: 2).data, 1900);
      expect(AcpMoneyCodec.parseMajorUnits('19.9', minorUnit: 2).data, 1990);
      expect(AcpMoneyCodec.parseMajorUnits('19', minorUnit: 0).data, 19);
      expect(AcpMoneyCodec.parseMajorUnits('0.0001', minorUnit: 4).data, 1);
    });

    test('rejects invalid, negative, over-precise, and overflowing input', () {
      expect(
        AcpMoneyCodec.parseMajorUnits('1', minorUnit: -1).failure,
        isA<ValidationFailure>(),
      );
      expect(
        AcpMoneyCodec.parseMajorUnits('1', minorUnit: 5).failure,
        isA<ValidationFailure>(),
      );
      expect(
        AcpMoneyCodec.parseMajorUnits('-1.00', minorUnit: 2).failure?.message,
        contains('non-negative'),
      );
      expect(
        AcpMoneyCodec.parseMajorUnits('1.234', minorUnit: 2).failure?.message,
        contains('2 decimal places'),
      );
      expect(
        AcpMoneyCodec.parseMajorUnits('1.2', minorUnit: 0).failure?.message,
        contains('0 decimal places'),
      );
      expect(
        AcpMoneyCodec.parseMajorUnits(
          '99999999999999999999999999999999999999',
          minorUnit: 2,
        ).failure?.message,
        contains('too large'),
      );
    });

    test('formats positive, negative, zero-precision, and padded values', () {
      expect(AcpMoneyCodec.formatMinorUnits(1999, minorUnit: 2), '19.99');
      expect(AcpMoneyCodec.formatMinorUnits(1, minorUnit: 2), '0.01');
      expect(AcpMoneyCodec.formatMinorUnits(-25, minorUnit: 2), '-0.25');
      expect(AcpMoneyCodec.formatMinorUnits(25, minorUnit: 0), '25');
      expect(
        () => AcpMoneyCodec.formatMinorUnits(1, minorUnit: 5),
        throwsRangeError,
      );
    });
  });
}
