import 'dart:convert';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
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

    final items = _decodeRows(body['value']);
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

    return Result<AcpRow>.success(body);
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
    if (rowVersion != null && rowVersion > 0) {
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

    final body = rowVersion == null || rowVersion <= 0
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

    final body = rowVersion == null || rowVersion <= 0
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
      if (rowVersion == null || rowVersion <= 0) {
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
        return Result<AuthenticatedResponse>.failure(
          ApiFailure(
            response.response.statusCode,
            _errorMessageFor(response.response.body),
          ),
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

  String _errorMessageFor(String raw) {
    final decoded = _decodeJson(raw);
    if (decoded is Map) {
      for (final key in const <String>['message', 'error', 'detail']) {
        final candidate = decoded[key];
        if (candidate != null) {
          final text = candidate.toString().trim();
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
    }

    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    return 'API request failed.';
  }
}
