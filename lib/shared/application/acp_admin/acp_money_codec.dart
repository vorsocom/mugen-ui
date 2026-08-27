import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class AcpMoneyCodec {
  const AcpMoneyCodec._(); // coverage:ignore-line

  static Result<int> parseMajorUnits(String value, {required int minorUnit}) {
    if (minorUnit < 0 || minorUnit > 4) {
      return const Result<int>.failure(
        ValidationFailure('Currency minor-unit precision must be from 0 to 4.'),
      );
    }
    final normalized = value.trim();
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(normalized);
    if (match == null) {
      return const Result<int>.failure(
        ValidationFailure('Enter a non-negative decimal amount.'),
      );
    }
    final fraction = match.group(2) ?? '';
    if (fraction.length > minorUnit) {
      return Result<int>.failure(
        ValidationFailure(
          'Enter no more than $minorUnit decimal place${minorUnit == 1 ? '' : 's'}.',
        ),
      );
    }
    final paddedFraction = fraction.padRight(minorUnit, '0');
    final digits = '${match.group(1)}$paddedFraction';
    final parsed = int.tryParse(digits);
    if (parsed == null) {
      return const Result<int>.failure(
        ValidationFailure('The amount is too large.'),
      );
    }
    return Result<int>.success(parsed);
  }

  static String formatMinorUnits(int value, {required int minorUnit}) {
    if (minorUnit < 0 || minorUnit > 4) {
      throw RangeError.range(minorUnit, 0, 4, 'minorUnit');
    }
    final negative = value.isNegative;
    final digits = value.abs().toString().padLeft(minorUnit + 1, '0');
    if (minorUnit == 0) {
      return '${negative ? '-' : ''}$digits';
    }
    final whole = digits.substring(0, digits.length - minorUnit);
    final fraction = digits.substring(digits.length - minorUnit);
    return '${negative ? '-' : ''}$whole.$fraction';
  }
}
