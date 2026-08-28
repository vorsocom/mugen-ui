import 'dart:convert';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
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
    if (enrichReferences && items.isNotEmpty) {
      items = await _enrichRows(
        rows: items,
        descriptor: descriptor,
        tenantId: tenantId,
        deletedView: deletedView,
        expansionPath: path.data!,
      );
    }
    final total = _parseCount(body['@count'], fallback: items.length);
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: items,
        total: total,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
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

    final rows = await _enrichRows(
      rows: <AcpRow>[body],
      descriptor: descriptor,
      tenantId: tenantId,
      deletedView: AcpDeletedView.active,
      expansionPath: path.data!,
      expansionIsEntity: true,
    );
    return Result<AcpRow>.success(rows.single);
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

  Future<List<AcpRow>> _enrichRows({
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
    if (descriptor.expansions.isNotEmpty) {
      enriched = await _enrichExpandedReferences(
        rows: enriched,
        expansions: descriptor.expansions,
        deletedView: deletedView,
        path: expansionPath,
        isEntity: expansionIsEntity,
      );
    }
    return _enrichBatchReferences(
      rows: enriched,
      descriptor: descriptor,
      tenantId: tenantId,
    );
  }

  Future<List<AcpRow>> _enrichExpandedReferences({
    required List<AcpRow> rows,
    required List<AcpExpandDescriptor> expansions,
    required AcpDeletedView deletedView,
    required String path,
    required bool isEntity,
  }) async {
    final ids = rows
        .map((row) => row.id?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      return rows;
    }

    final response = await _send(
      AcpRequest(
        method: HttpMethod.get,
        path: path,
        queryParameters: isEntity
            ? AcpQueryBuilder.buildEntityReferenceQuery(expansions: expansions)
            : AcpQueryBuilder.buildReferenceBatchQuery(
                ids: ids,
                selectFields: const <String>[],
                expansions: expansions,
                deletedView: deletedView,
              ),
      ),
    );
    if (response.isFailure) {
      return rows;
    }

    final entityRow = isEntity
        ? _decodeMap(response.data!.response.body)
        : null;
    final expandedRows = isEntity
        ? <AcpRow?>[entityRow].whereType<AcpRow>().toList(growable: false)
        : _decodeRows(_decodeMap(response.data!.response.body)?['value']);
    if (expandedRows.isEmpty) {
      return rows;
    }

    final byId = <String, AcpRow>{};
    for (final row in expandedRows) {
      final id = row.id;
      if (id != null) {
        byId[id] = row;
      }
    }
    return rows
        .map((row) {
          final expanded = byId[row.id];
          if (expanded == null) {
            return row;
          }
          final merged = Map<String, dynamic>.from(row);
          for (final expansion in expansions) {
            final navigation = expansion.navigation.trim();
            if (navigation.isNotEmpty && expanded.containsKey(navigation)) {
              merged[navigation] = expanded[navigation];
            }
          }
          return merged;
        })
        .toList(growable: false);
  }

  Future<List<AcpRow>> _enrichBatchReferences({
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
      return rows;
    }

    final enriched = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    for (final group in groups.values) {
      final ids = <String>{};
      for (final row in enriched) {
        for (final column in group.columns) {
          final id = row[column.key]?.toString().trim() ?? '';
          if (id.isNotEmpty) {
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
        continue;
      }
      final response = await _send(
        AcpRequest(
          method: HttpMethod.get,
          path: path.data!,
          queryParameters: AcpQueryBuilder.buildReferenceBatchQuery(
            ids: ids.toList(growable: false),
            idField: lookup.idField,
            selectFields: group.selectFields.toList(growable: false),
            deletedView: lookup.deletedView,
          ),
        ),
      );
      if (response.isFailure) {
        continue;
      }
      final body = _decodeMap(response.data!.response.body);
      final targets = _decodeRows(body?['value']);
      final byId = <String, AcpRow>{};
      for (final target in targets) {
        final id = target[lookup.idField]?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          byId[id] = target;
        }
      }
      for (final row in enriched) {
        for (final column in group.columns) {
          final id = row[column.key]?.toString().trim() ?? '';
          final target = byId[id];
          final path = column.reference?.navigationPath;
          if (target != null && path != null && path.trim().isNotEmpty) {
            _writePath(row, path, target);
          }
        }
      }
    }
    return enriched;
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
