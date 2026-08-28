import 'dart:convert';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_reference_display.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/application/api_error_message.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_path_builder.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_query_builder.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class AcpAdminRepositoryImpl implements AcpAdminRepository {
  AcpAdminRepositoryImpl({
    required this.appConfig,
    required this.authenticatedHttpClient,
  });

  final AppConfig appConfig;
  final AuthenticatedHttpClient authenticatedHttpClient;

  @override
  Future<Result<List<AcpTenantOption>>> fetchTenants({int top = 200}) async {
    final response = await _send(
      AcpRequest(
        method: HttpMethod.get,
        path: appConfig.api.endpoints.tenant,
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'Name asc',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<AcpTenantOption>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<AcpTenantOption>>.failure(
        UnexpectedFailure('Unexpected tenant response.'),
      );
    }

    final rawItems = body['value'];
    if (rawItems is! List) {
      return const Result<List<AcpTenantOption>>.success(<AcpTenantOption>[]);
    }

    final tenants = rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => AcpTenantOption(
            id: item['Id']?.toString() ?? '',
            name: item['Name']?.toString() ?? item['Slug']?.toString() ?? '',
            slug: item['Slug']?.toString(),
          ),
        )
        .where((tenant) => tenant.id.isNotEmpty && tenant.name.isNotEmpty)
        .toList(growable: false);

    return Result<List<AcpTenantOption>>.success(tenants);
  }

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
  }) async {
    final path = AcpPathBuilder.collectionPath(
      endpoints: appConfig.api.endpoints,
      entitySet: descriptor.entitySet,
      scopeMode: descriptor.scopeMode,
      tenantId: tenantId,
    );
    if (path.isFailure) {
      return Result<AcpRowPage>.failure(path.failure!);
    }

    final response = await _send(
      AcpRequest(
        method: HttpMethod.get,
        path: path.data!,
        queryParameters: AcpQueryBuilder.buildListQuery(
          pageRequest: pageRequest,
          orderBy: descriptor.defaultOrderBy,
          searchTerm: searchTerm,
          searchFields: descriptor.searchFields,
          extraFilters: extraFilters,
          deletedView: deletedView,
        ),
      ),
    );
    if (response.isFailure) {
      return Result<AcpRowPage>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<AcpRowPage>.failure(
        UnexpectedFailure('Unexpected list response.'),
      );
    }

    var items = _decodeRows(body['value']);
    String? referenceWarning;
    if (enrichReferences && items.isNotEmpty) {
      final enrichment = await _enrichRows(
        rows: items,
        descriptor: descriptor,
        tenantId: tenantId,
        deletedView: deletedView,
        expansionPath: path.data!,
      );
      items = enrichment.rows;
      referenceWarning = enrichment.referenceWarning;
    }
    final total = _parseCount(body['@count'], fallback: items.length);
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: items,
        total: total,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
        referenceWarning: referenceWarning,
      ),
    );
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    final path = AcpPathBuilder.entityPath(
      endpoints: appConfig.api.endpoints,
      entitySet: descriptor.entitySet,
      entityId: rowId,
      scopeMode: descriptor.scopeMode,
      tenantId: tenantId,
    );
    if (path.isFailure) {
      return Result<AcpRow>.failure(path.failure!);
    }

    final response = await _send(
      AcpRequest(method: HttpMethod.get, path: path.data!),
    );
    if (response.isFailure) {
      return Result<AcpRow>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<AcpRow>.failure(
        UnexpectedFailure('Unexpected row response.'),
      );
    }

    final enrichment = await _enrichRows(
      rows: <AcpRow>[body],
      descriptor: descriptor,
      tenantId: tenantId,
      deletedView: AcpDeletedView.active,
      expansionPath: path.data!,
      expansionIsEntity: true,
    );
    return Result<AcpRow>.success(enrichment.rows.single);
  }

  @override
  Future<Result<Object?>> createRow({
    required AcpResourceDescriptor descriptor,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    final path = AcpPathBuilder.collectionPath(
      endpoints: appConfig.api.endpoints,
      entitySet: descriptor.entitySet,
      scopeMode: descriptor.scopeMode,
      tenantId: tenantId,
    );
    if (path.isFailure) {
      return Result<Object?>.failure(path.failure!);
    }

    return _sendForObject(
      AcpRequest(method: HttpMethod.post, path: path.data!, body: values),
    );
  }

  @override
  Future<Result<Object?>> updateRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    final path = AcpPathBuilder.entityPath(
      endpoints: appConfig.api.endpoints,
      entitySet: descriptor.entitySet,
      entityId: rowId,
      scopeMode: descriptor.scopeMode,
      tenantId: tenantId,
    );
    if (path.isFailure) {
      return Result<Object?>.failure(path.failure!);
    }

    final body = <String, dynamic>{...values};
    if (rowVersion != null && rowVersion >= 0) {
      body['RowVersion'] = rowVersion;
    }

    return _sendForObject(
      AcpRequest(method: HttpMethod.patch, path: path.data!, body: body),
    );
  }

  @override
  Future<Result<void>> deleteRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    final path = AcpPathBuilder.entityPath(
      endpoints: appConfig.api.endpoints,
      entitySet: descriptor.entitySet,
      entityId: rowId,
      scopeMode: descriptor.scopeMode,
      tenantId: tenantId,
    );
    if (path.isFailure) {
      return Result<void>.failure(path.failure!);
    }

    final body = rowVersion == null || rowVersion < 0
        ? null
        : <String, dynamic>{'RowVersion': rowVersion};
    return _sendForVoid(
      AcpRequest(method: HttpMethod.delete, path: path.data!, body: body),
    );
  }

  @override
  Future<Result<void>> restoreRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    final path = AcpPathBuilder.restorePath(
      endpoints: appConfig.api.endpoints,
      entitySet: descriptor.entitySet,
      entityId: rowId,
      scopeMode: descriptor.scopeMode,
      tenantId: tenantId,
    );
    if (path.isFailure) {
      return Result<void>.failure(path.failure!);
    }

    final body = rowVersion == null || rowVersion < 0
        ? null
        : <String, dynamic>{'RowVersion': rowVersion};
    return _sendForVoid(
      AcpRequest(method: HttpMethod.post, path: path.data!, body: body),
    );
  }

  @override
  Future<Result<Object?>> runCollectionAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    final path = AcpPathBuilder.collectionActionPath(
      endpoints: appConfig.api.endpoints,
      entitySet: descriptor.entitySet,
      action: action.name,
      scopeMode: descriptor.scopeMode,
      tenantId: tenantId,
    );
    if (path.isFailure) {
      return Result<Object?>.failure(path.failure!);
    }

    return _sendForObject(
      AcpRequest(method: HttpMethod.post, path: path.data!, body: values),
    );
  }

  @override
  Future<Result<Object?>> runEntityAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    final path = AcpPathBuilder.entityActionPath(
      endpoints: appConfig.api.endpoints,
      entitySet: descriptor.entitySet,
      entityId: rowId,
      action: action.name,
      scopeMode: descriptor.scopeMode,
      tenantId: tenantId,
    );
    if (path.isFailure) {
      return Result<Object?>.failure(path.failure!);
    }

    final body = <String, dynamic>{...values};
    if (action.includeRowVersion) {
      if (rowVersion == null || rowVersion < 0) {
        return const Result<Object?>.failure(
          ValidationFailure('RowVersion is required for this action.'),
        );
      }
      body['RowVersion'] = rowVersion;
    }

    return _sendForObject(
      AcpRequest(method: HttpMethod.post, path: path.data!, body: body),
    );
  }

  Future<Result<Object?>> _sendForObject(AcpRequest request) async {
    final response = await _send(request);
    if (response.isFailure) {
      return Result<Object?>.failure(response.failure!);
    }

    return Result<Object?>.success(_decodeJson(response.data!.response.body));
  }

  Future<Result<void>> _sendForVoid(AcpRequest request) async {
    final response = await _send(request);
    if (response.isFailure) {
      return Result<void>.failure(response.failure!);
    }

    return const Result<void>.success(null);
  }

  Future<_AcpReferenceEnrichment> _enrichRows({
    required List<AcpRow> rows,
    required AcpResourceDescriptor descriptor,
    required String? tenantId,
    required AcpDeletedView deletedView,
    required String expansionPath,
    bool expansionIsEntity = false,
  }) async {
    var enriched = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final failures = <String>{};
    if (descriptor.expansions.isNotEmpty) {
      final expansion = await _enrichExpandedReferences(
        rows: enriched,
        descriptor: descriptor,
        deletedView: deletedView,
        path: expansionPath,
        isEntity: expansionIsEntity,
      );
      enriched = expansion.rows;
      failures.addAll(expansion.failures);
    }
    final batch = await _enrichBatchReferences(
      rows: enriched,
      descriptor: descriptor,
      tenantId: tenantId,
    );
    failures.addAll(batch.failures);
    final unresolvedLabels = <String>{};
    for (final column in descriptor.columns) {
      if (column.reference == null) {
        continue;
      }
      final unresolved = batch.rows.any((row) {
        final id = row[column.key]?.toString().trim() ?? '';
        return id.isNotEmpty &&
            !acpReferenceHasReadableValue(row: row, column: column);
      });
      if (unresolved) {
        unresolvedLabels.add(column.label);
      }
    }
    return _AcpReferenceEnrichment(
      rows: batch.rows,
      failures: failures.toList(growable: false),
      referenceWarning: _referenceWarning(
        unresolvedLabels: unresolvedLabels,
        failures: failures,
      ),
    );
  }

  Future<_AcpReferenceEnrichment> _enrichExpandedReferences({
    required List<AcpRow> rows,
    required AcpResourceDescriptor descriptor,
    required AcpDeletedView deletedView,
    required String path,
    required bool isEntity,
  }) async {
    final ids = rows
        .where(
          (row) => _needsExpansion(
            row: row,
            columns: descriptor.columns,
            expansions: descriptor.expansions,
          ),
        )
        .map((row) => row.id?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      return _AcpReferenceEnrichment(rows: rows);
    }

    final queryParameters = isEntity
        ? AcpQueryBuilder.buildEntityReferenceQuery(
            expansions: descriptor.expansions,
          )
        : AcpQueryBuilder.buildReferenceBatchQuery(
            ids: ids,
            selectFields: const <String>[],
            literalType: descriptor.keyLiteralType,
            expansions: descriptor.expansions,
            deletedView: deletedView,
          );
    if (queryParameters.isEmpty) {
      return _AcpReferenceEnrichment(rows: rows);
    }

    final response = await _send(
      AcpRequest(
        method: HttpMethod.get,
        path: path,
        queryParameters: queryParameters,
      ),
    );
    if (response.isFailure) {
      return _AcpReferenceEnrichment(
        rows: rows,
        failures: <String>[
          'Navigation expansion: ${response.failure!.message}',
        ],
      );
    }

    final entityRow = isEntity
        ? _decodeMap(response.data!.response.body)
        : null;
    final expandedRows = isEntity
        ? <AcpRow?>[entityRow].whereType<AcpRow>().toList(growable: false)
        : _decodeRows(_decodeMap(response.data!.response.body)?['value']);
    if (expandedRows.isEmpty) {
      return _AcpReferenceEnrichment(rows: rows);
    }

    final byId = <String, AcpRow>{};
    for (final row in expandedRows) {
      final id = row.id;
      if (id != null) {
        byId[_referenceIdKey(id, descriptor.keyLiteralType)] = row;
      }
    }
    final enriched = rows
        .map((row) {
          final rowId = row.id;
          final expanded = rowId == null
              ? null
              : byId[_referenceIdKey(rowId, descriptor.keyLiteralType)];
          if (expanded == null) {
            return row;
          }
          final merged = Map<String, dynamic>.from(row);
          for (final expansion in descriptor.expansions) {
            final navigation = expansion.navigation.trim();
            if (navigation.isNotEmpty &&
                expanded.containsKey(navigation) &&
                row[navigation] is! Map) {
              merged[navigation] = expanded[navigation];
            }
          }
          return merged;
        })
        .toList(growable: false);
    return _AcpReferenceEnrichment(rows: enriched);
  }

  Future<_AcpReferenceEnrichment> _enrichBatchReferences({
    required List<AcpRow> rows,
    required AcpResourceDescriptor descriptor,
    required String? tenantId,
  }) async {
    final groups = <String, _AcpBatchReferenceGroup>{};
    for (final column in descriptor.columns) {
      final reference = column.reference;
      final lookup = reference?.batchLookup;
      if (reference == null || lookup == null) {
        continue;
      }
      final key = <Object>[
        lookup.entitySet,
        lookup.scopeMode.name,
        lookup.idField,
        lookup.literalType.name,
        lookup.deletedView.name,
      ].join('|');
      final group = groups.putIfAbsent(
        key,
        () => _AcpBatchReferenceGroup(lookup),
      );
      group.columns.add(column);
      group.selectFields.addAll(lookup.selectFields);
    }
    if (groups.isEmpty) {
      return _AcpReferenceEnrichment(rows: rows);
    }

    final enriched = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final failures = <String>[];
    for (final group in groups.values) {
      final ids = <String>{};
      for (final row in enriched) {
        for (final column in group.columns) {
          final id = row[column.key]?.toString().trim() ?? '';
          if (id.isNotEmpty &&
              !acpReferenceHasReadableValue(row: row, column: column)) {
            ids.add(id);
          }
        }
      }
      if (ids.isEmpty) {
        continue;
      }

      final lookup = group.lookup;
      final path = AcpPathBuilder.collectionPath(
        endpoints: appConfig.api.endpoints,
        entitySet: lookup.entitySet,
        scopeMode: lookup.scopeMode,
        tenantId: tenantId,
      );
      if (path.isFailure) {
        failures.add(_lookupFailure(group, path.failure!.message));
        continue;
      }
      final queryParameters = AcpQueryBuilder.buildReferenceBatchQuery(
        ids: ids.toList(growable: false),
        idField: lookup.idField,
        literalType: lookup.literalType,
        selectFields: group.selectFields.toList(growable: false),
        deletedView: lookup.deletedView,
      );
      if (queryParameters.isEmpty) {
        continue;
      }
      final response = await _send(
        AcpRequest(
          method: HttpMethod.get,
          path: path.data!,
          queryParameters: queryParameters,
        ),
      );
      if (response.isFailure) {
        failures.add(_lookupFailure(group, response.failure!.message));
        continue;
      }
      final body = _decodeMap(response.data!.response.body);
      final targets = _decodeRows(body?['value']);
      final byId = <String, AcpRow>{};
      for (final target in targets) {
        final id = target[lookup.idField]?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          byId[_referenceIdKey(id, lookup.literalType)] = target;
        }
      }
      for (final row in enriched) {
        for (final column in group.columns) {
          final id = row[column.key]?.toString().trim() ?? '';
          final target = byId[_referenceIdKey(id, lookup.literalType)];
          final path = column.reference?.navigationPath;
          if (target != null && path != null && path.trim().isNotEmpty) {
            _writePath(row, path, target);
          }
        }
      }
    }
    return _AcpReferenceEnrichment(rows: enriched, failures: failures);
  }

  bool _needsExpansion({
    required AcpRow row,
    required List<AcpColumnDescriptor> columns,
    required List<AcpExpandDescriptor> expansions,
  }) {
    for (final expansion in expansions) {
      final navigation = expansion.navigation.trim();
      if (navigation.isEmpty) {
        continue;
      }
      final matchingColumns = columns
          .where((column) {
            final reference = column.reference;
            return reference != null &&
                reference.navigationPath.split('.').first == navigation;
          })
          .toList(growable: false);
      if (matchingColumns.isEmpty) {
        if (row[navigation] is! Map) {
          return true;
        }
        continue;
      }
      for (final column in matchingColumns) {
        final id = row[column.key]?.toString().trim() ?? '';
        if (id.isNotEmpty &&
            !acpReferenceHasReadableValue(row: row, column: column)) {
          return true;
        }
      }
    }
    return false;
  }

  String _lookupFailure(_AcpBatchReferenceGroup group, String message) {
    final labels = group.columns
        .map((column) => column.label)
        .toSet()
        .join(', ');
    return '$labels (${group.lookup.entitySet}): $message';
  }

  String _referenceIdKey(String id, AcpFilterLiteralType literalType) {
    return literalType == AcpFilterLiteralType.guid ? id.toLowerCase() : id;
  }

  String? _referenceWarning({
    required Set<String> unresolvedLabels,
    required Set<String> failures,
  }) {
    if (unresolvedLabels.isEmpty) {
      return null;
    }
    final labels = unresolvedLabels.join(', ');
    final base =
        'Some reference labels could not be resolved: $labels. '
        'Raw identifiers are shown instead.';
    if (failures.isEmpty) {
      return base;
    }
    return '$base Details: ${failures.join(' ')}';
  }

  void _writePath(Map<String, dynamic> row, String path, Object? value) {
    final segments = path
        .split('.')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return;
    }
    Map<String, dynamic> current = row;
    for (final segment in segments.take(segments.length - 1)) {
      final nested = switch (current[segment]) {
        final Map value => Map<String, dynamic>.from(value),
        _ => <String, dynamic>{},
      };
      current[segment] = nested;
      current = nested;
    }
    current[segments.last] = value;
  }

  Future<Result<AuthenticatedResponse>> _send(AcpRequest request) async {
    try {
      final response = await authenticatedHttpClient.send(request);
      if (response.sessionExpired) {
        return const Result<AuthenticatedResponse>.failure(
          SessionExpiredFailure(),
        );
      }

      if (response.response.statusCode == 401) {
        return const Result<AuthenticatedResponse>.failure(
          UnauthorizedFailure(),
        );
      }

      if (!response.response.isSuccess) {
        final message = normalizeApiErrorMessage(
          response.response.body,
          maximumLength: null,
        );
        if (response.response.statusCode == 409) {
          final normalizedMessage = message.toLowerCase();
          return Result<AuthenticatedResponse>.failure(
            ConflictFailure(
              normalizedMessage.contains('rowversion') ||
                      normalizedMessage.contains('row version')
                  ? ConflictKind.staleRowVersion
                  : ConflictKind.lifecycle,
              message,
            ),
          );
        }
        return Result<AuthenticatedResponse>.failure(
          ApiFailure(response.response.statusCode, message),
        );
      }

      return Result<AuthenticatedResponse>.success(response);
    } catch (_) {
      return const Result<AuthenticatedResponse>.failure(
        NetworkFailure('Network request failed.'),
      );
    }
  }

  List<AcpRow> _decodeRows(Object? raw) {
    if (raw is! List) {
      return const <AcpRow>[];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Map<String, dynamic>? _decodeMap(String raw) {
    final decoded = _decodeJson(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  Object? _decodeJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return trimmed;
    }
  }

  int _parseCount(Object? raw, {required int fallback}) {
    if (raw is int) {
      return raw;
    }
    final parsed = int.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }
}

class _AcpBatchReferenceGroup {
  _AcpBatchReferenceGroup(this.lookup);

  final AcpBatchReferenceDescriptor lookup;
  final List<AcpColumnDescriptor> columns = <AcpColumnDescriptor>[];
  final Set<String> selectFields = <String>{};
}

class _AcpReferenceEnrichment {
  const _AcpReferenceEnrichment({
    required this.rows,
    this.failures = const <String>[],
    this.referenceWarning,
  });

  final List<AcpRow> rows;
  final List<String> failures;
  final String? referenceWarning;
}
