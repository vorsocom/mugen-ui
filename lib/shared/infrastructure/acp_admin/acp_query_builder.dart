import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';

class AcpQueryBuilder {
  const AcpQueryBuilder._(); // coverage:ignore-line

  static Map<String, dynamic> buildListQuery({
    required PageRequest pageRequest,
    String? orderBy,
    String? searchTerm,
    List<String> searchFields = const <String>[],
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    List<AcpExpandDescriptor> expansions = const <AcpExpandDescriptor>[],
  }) {
    final queryParameters = <String, dynamic>{r'$count': true};

    if (deletedView != AcpDeletedView.active) {
      queryParameters[r'$deleted'] = deletedView == AcpDeletedView.all
          ? 'all'
          : 'archived';
    }

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

    final expand = serializeExpansions(expansions);
    if (expand.isNotEmpty) {
      queryParameters[r'$expand'] = expand;
    }

    return queryParameters;
  }

  static Map<String, dynamic> buildReferenceBatchQuery({
    required List<String> ids,
    required List<String> selectFields,
    String idField = 'Id',
    AcpFilterLiteralType literalType = AcpFilterLiteralType.string,
    List<AcpExpandDescriptor> expansions = const <AcpExpandDescriptor>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
  }) {
    if (ids.isEmpty) {
      return const <String, dynamic>{};
    }

    final uniqueIds = _uniqueReferenceIds(ids, literalType: literalType);
    if (uniqueIds.isEmpty) {
      return const <String, dynamic>{};
    }

    final selected = <String>{
      idField,
      ...selectFields,
    }.where((value) => value.trim().isNotEmpty).join(',');
    final quotedIds = uniqueIds
        .map((value) {
          return switch (literalType) {
            AcpFilterLiteralType.string => "'${_escapeString(value)}'",
            AcpFilterLiteralType.guid => "guid'$value'",
          };
        })
        .join(',');
    final queryParameters = <String, dynamic>{
      r'$top': uniqueIds.length,
      r'$select': selected,
      r'$filter': '$idField in ($quotedIds)',
    };
    if (deletedView != AcpDeletedView.active) {
      queryParameters[r'$deleted'] = deletedView == AcpDeletedView.all
          ? 'all'
          : 'archived';
    }
    final expand = serializeExpansions(expansions);
    if (expand.isNotEmpty) {
      queryParameters[r'$expand'] = expand;
    }
    return queryParameters;
  }

  static Map<String, dynamic> buildEntityReferenceQuery({
    required List<AcpExpandDescriptor> expansions,
  }) {
    final expand = serializeExpansions(expansions);
    if (expand.isEmpty) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{r'$select': 'Id', r'$expand': expand};
  }

  static String serializeExpansions(List<AcpExpandDescriptor> expansions) {
    return expansions
        .where((expansion) => expansion.navigation.trim().isNotEmpty)
        .map(_serializeExpansion)
        .join(',');
  }

  static String _serializeExpansion(AcpExpandDescriptor expansion) {
    final options = <String>[];
    final selected = expansion.selectFields
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .join(',');
    if (selected.isNotEmpty) {
      options.add(r'$select=' + selected);
    }
    final nested = serializeExpansions(expansion.expands);
    if (nested.isNotEmpty) {
      options.add(r'$expand=' + nested);
    }
    final navigation = expansion.navigation.trim();
    return options.isEmpty ? navigation : '$navigation(${options.join(';')})';
  }

  static String _escapeString(String value) {
    return value.replaceAll("'", "''");
  }

  static List<String> _uniqueReferenceIds(
    List<String> ids, {
    required AcpFilterLiteralType literalType,
  }) {
    final uniqueIds = <String>[];
    final seen = <String>{};
    for (final value in ids) {
      final trimmed = value.trim();
      if (trimmed.isEmpty ||
          (literalType == AcpFilterLiteralType.guid &&
              !_guidPattern.hasMatch(trimmed))) {
        continue;
      }
      final identity = literalType == AcpFilterLiteralType.guid
          ? trimmed.toLowerCase()
          : trimmed;
      if (seen.add(identity)) {
        uniqueIds.add(trimmed);
      }
    }
    return uniqueIds;
  }

  static final RegExp _guidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
}
