import 'package:mugen_ui/shared/application/pagination.dart';

class AcpQueryBuilder {
  const AcpQueryBuilder._(); // coverage:ignore-line

  static Map<String, dynamic> buildListQuery({
    required PageRequest pageRequest,
    String? orderBy,
    String? searchTerm,
    List<String> searchFields = const <String>[],
    List<String> extraFilters = const <String>[],
  }) {
    final queryParameters = <String, dynamic>{r'$count': true};

    if (orderBy != null && orderBy.trim().isNotEmpty) {
      queryParameters[r'$orderby'] = orderBy.trim();
    }

    if (pageRequest.pageSize > 0) {
      queryParameters[r'$skip'] = pageRequest.skip;
      queryParameters[r'$top'] = pageRequest.pageSize;
    }

    final filters = <String>[
      ...extraFilters.where((value) => value.trim().isNotEmpty),
    ];
    final normalizedSearch = searchTerm?.trim() ?? '';
    if (normalizedSearch.length >= 2 && searchFields.isNotEmpty) {
      final escaped = _escapeString(normalizedSearch);
      final clauses = searchFields
          .map((field) => "contains($field,'$escaped')")
          .toList(growable: false);
      filters.add('(${clauses.join(' or ')})');
    }

    if (filters.isNotEmpty) {
      queryParameters[r'$filter'] = filters.join(' and ');
    }

    return queryParameters;
  }

  static String _escapeString(String value) {
    return value.replaceAll("'", "''");
  }
}
