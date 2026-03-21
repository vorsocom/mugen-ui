import 'dart:convert';

import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class AcpJsonCodec {
  const AcpJsonCodec._(); // coverage:ignore-line

  static String prettyPrint(Object? value) {
    if (value == null) {
      return '';
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return '';
      }

      try {
        final decoded = jsonDecode(trimmed);
        return prettyPrint(decoded);
      } catch (_) {
        return value;
      }
    }

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(value);
  }

  static Result<Object?> parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const Result<Object?>.success(null);
    }

    try {
      return Result<Object?>.success(jsonDecode(trimmed));
    } catch (_) {
      return const Result<Object?>.failure(
        ValidationFailure('Enter valid JSON.'),
      );
    }
  }
}
