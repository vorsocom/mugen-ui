import 'package:mugen_ui/shared/domain/failure.dart';

// Leave room for the resource path within the API's 32,768-character URL limit.
const int _maxEncodedSearchQueryLength = 30000;

ValidationFailure? validateAcpSearchQuery({
  required String? searchTerm,
  required Map<String, dynamic> queryParameters,
}) {
  if (searchTerm == null || searchTerm.trim().isEmpty) {
    return null;
  }
  final query = Uri(
    queryParameters: queryParameters.map(
      (key, value) => MapEntry(key, value.toString()),
    ),
  ).query;
  if (query.length > _maxEncodedSearchQueryLength) {
    return const ValidationFailure('Use a shorter search or fewer filters.');
  }
  return null;
}
