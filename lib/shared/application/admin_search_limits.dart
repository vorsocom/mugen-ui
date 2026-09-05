import 'package:characters/characters.dart';

import 'package:mugen_ui/shared/domain/failure.dart';

abstract final class AdminSearchLimits {
  static const int maxLength = 200;
  static const String lengthMessage = 'Use 200 characters or fewer to search.';

  static ValidationFailure? validate(String? value) {
    if ((value ?? '').characters.length > maxLength) {
      return const ValidationFailure(lengthMessage);
    }
    return null;
  }
}
