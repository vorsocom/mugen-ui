import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_assignable_user_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_entry_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_object_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_type_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_membership_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_member_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_summary_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/repositories/rbac_admin_repository.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class RbacAdminRepositoryImpl implements RbacAdminRepository {
  RbacAdminRepositoryImpl({
    required this.appConfig,
    required this.cookieStore,
    required this.authenticatedHttpClient,
  });

  static final DateFormat _rfc1123DateFormat = DateFormat(
    "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
    'en_US',
  );

  final AppConfig appConfig;
  final CookieStore cookieStore;
  final AuthenticatedHttpClient authenticatedHttpClient;

  @override
  Future<Result<List<RbacTenantSummaryEntity>>> fetchTenants({
    int top = 200,
  }) async {
    final response = await _sendRequest(
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
      return Result<List<RbacTenantSummaryEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacTenantSummaryEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacTenantSummaryEntity>>.success(
      _mapList(body['value'], _mapTenant),
    );
  }

  @override
  Future<Result<List<RbacRoleEntity>>> fetchGlobalRoles({int top = 200}) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: appConfig.api.endpoints.rbacGlobalRole,
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'DisplayName asc',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacRoleEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacRoleEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacRoleEntity>>.success(
      _mapList(body['value'], (raw) => _mapRole(raw, tenantId: null)),
    );
  }

  @override
  Future<Result<List<RbacAssignableUserEntity>>> fetchGlobalUsers({
    int top = 200,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: appConfig.api.endpoints.user,
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'Username asc',
          r'$expand': 'Person',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacAssignableUserEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacAssignableUserEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacAssignableUserEntity>>.success(
      _mapList(body['value'], _mapAssignableUser),
    );
  }

  @override
  Future<Result<void>> createGlobalRole(RbacCreateGlobalRoleInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacGlobalRole,
        body: <String, dynamic>{
          'Namespace': input.namespace,
          'Name': input.name,
          'DisplayName': input.displayName,
        },
      ),
    );
  }

  @override
  Future<Result<void>> updateGlobalRole(RbacUpdateGlobalRoleInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.patch,
        path: '${appConfig.api.endpoints.rbacGlobalRole}/${input.roleId}',
        body: <String, dynamic>{
          'DisplayName': input.displayName,
          'RowVersion': input.rowVersion,
        },
      ),
    );
  }

  @override
  Future<Result<List<RbacRoleEntity>>> fetchTenantRoles({
    required String tenantId,
    int top = 200,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: _tenantRoleBasePath(tenantId),
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'DisplayName asc',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacRoleEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacRoleEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacRoleEntity>>.success(
      _mapList(body['value'], (raw) => _mapRole(raw, tenantId: tenantId)),
    );
  }

  @override
  Future<Result<void>> createTenantRole(RbacCreateTenantRoleInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _tenantRoleBasePath(input.tenantId),
        body: <String, dynamic>{
          'Namespace': input.namespace,
          'Name': input.name,
          'DisplayName': input.displayName,
        },
      ),
    );
  }

  @override
  Future<Result<void>> updateTenantRole(RbacUpdateTenantRoleInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.patch,
        path: '${_tenantRoleBasePath(input.tenantId)}/${input.roleId}',
        body: <String, dynamic>{
          'DisplayName': input.displayName,
          'RowVersion': input.rowVersion,
        },
      ),
    );
  }

  @override
  Future<Result<void>> deprecateTenantRole(
    RbacTenantRoleLifecycleInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacTenantRoleActionDeprecate
            .replaceAll('{tenant_id}', input.tenantId)
            .replaceAll('{role_id}', input.roleId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<void>> reactivateTenantRole(
    RbacTenantRoleLifecycleInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacTenantRoleActionReactivate
            .replaceAll('{tenant_id}', input.tenantId)
            .replaceAll('{role_id}', input.roleId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<List<RbacPermissionObjectEntity>>> fetchPermissionObjects({
    int top = 200,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: appConfig.api.endpoints.rbacPermissionObject,
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'Namespace asc,Name asc',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacPermissionObjectEntity>>.failure(
        response.failure!,
      );
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacPermissionObjectEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacPermissionObjectEntity>>.success(
      _mapList(body['value'], _mapPermissionObject),
    );
  }

  @override
  Future<Result<void>> createPermissionObject(
    RbacCreatePermissionObjectInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacPermissionObject,
        body: <String, dynamic>{
          'Namespace': input.namespace,
          'Name': input.name,
        },
      ),
    );
  }

  @override
  Future<Result<void>> deprecatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacPermissionObjectActionDeprecate
            .replaceAll('{permission_object_id}', input.permissionObjectId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<void>> reactivatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacPermissionObjectActionReactivate
            .replaceAll('{permission_object_id}', input.permissionObjectId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<List<RbacPermissionTypeEntity>>> fetchPermissionTypes({
    int top = 200,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: appConfig.api.endpoints.rbacPermissionType,
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'Namespace asc,Name asc',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacPermissionTypeEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacPermissionTypeEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacPermissionTypeEntity>>.success(
      _mapList(body['value'], _mapPermissionType),
    );
  }

  @override
  Future<Result<void>> createPermissionType(
    RbacCreatePermissionTypeInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacPermissionType,
        body: <String, dynamic>{
          'Namespace': input.namespace,
          'Name': input.name,
        },
      ),
    );
  }

  @override
  Future<Result<void>> deprecatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacPermissionTypeActionDeprecate
            .replaceAll('{permission_type_id}', input.permissionTypeId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<void>> reactivatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacPermissionTypeActionReactivate
            .replaceAll('{permission_type_id}', input.permissionTypeId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<List<RbacPermissionEntryEntity>>> fetchGlobalPermissionEntries({
    int top = 200,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: appConfig.api.endpoints.rbacGlobalPermissionEntry,
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'CreatedAt desc',
          r'$expand': 'GlobalRole,PermissionObject,PermissionType',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacPermissionEntryEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacPermissionEntryEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacPermissionEntryEntity>>.success(
      _mapList(
        body['value'],
        (raw) => _mapPermissionEntry(raw, tenantId: null),
      ),
    );
  }

  @override
  Future<Result<void>> createGlobalPermissionEntry(
    RbacCreateGlobalPermissionEntryInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacGlobalPermissionEntry,
        body: <String, dynamic>{
          'GlobalRoleId': input.globalRoleId,
          'PermissionObjectId': input.permissionObjectId,
          'PermissionTypeId': input.permissionTypeId,
          'Permitted': input.permitted,
        },
      ),
    );
  }

  @override
  Future<Result<void>> updateGlobalPermissionEntry(
    RbacUpdateGlobalPermissionEntryInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.patch,
        path:
            '${appConfig.api.endpoints.rbacGlobalPermissionEntry}/${input.entryId}',
        body: <String, dynamic>{
          'Permitted': input.permitted,
          'RowVersion': input.rowVersion,
        },
      ),
    );
  }

  @override
  Future<Result<void>> deleteGlobalPermissionEntry(
    RbacDeleteGlobalPermissionEntryInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.delete,
        path:
            '${appConfig.api.endpoints.rbacGlobalPermissionEntry}/${input.entryId}',
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<List<RbacPermissionEntryEntity>>> fetchTenantPermissionEntries({
    required String tenantId,
    int top = 200,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: _tenantPermissionEntryBasePath(tenantId),
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'CreatedAt desc',
          r'$expand': 'Role,PermissionObject,PermissionType',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacPermissionEntryEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacPermissionEntryEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacPermissionEntryEntity>>.success(
      _mapList(
        body['value'],
        (raw) => _mapPermissionEntry(raw, tenantId: tenantId),
      ),
    );
  }

  @override
  Future<Result<void>> createTenantPermissionEntry(
    RbacCreateTenantPermissionEntryInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _tenantPermissionEntryBasePath(input.tenantId),
        body: <String, dynamic>{
          'RoleId': input.roleId,
          'PermissionObjectId': input.permissionObjectId,
          'PermissionTypeId': input.permissionTypeId,
          'Permitted': input.permitted,
        },
      ),
    );
  }

  @override
  Future<Result<void>> updateTenantPermissionEntry(
    RbacUpdateTenantPermissionEntryInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.patch,
        path:
            '${_tenantPermissionEntryBasePath(input.tenantId)}/${input.entryId}',
        body: <String, dynamic>{
          'Permitted': input.permitted,
          'RowVersion': input.rowVersion,
        },
      ),
    );
  }

  @override
  Future<Result<void>> deleteTenantPermissionEntry(
    RbacDeleteTenantPermissionEntryInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.delete,
        path:
            '${_tenantPermissionEntryBasePath(input.tenantId)}/${input.entryId}',
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<List<RbacRoleMembershipEntity>>> fetchTenantRoleMemberships({
    required String tenantId,
    int top = 200,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: _tenantRoleMembershipBasePath(tenantId),
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'CreatedAt desc',
          r'$expand': 'Role,User',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacRoleMembershipEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacRoleMembershipEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacRoleMembershipEntity>>.success(
      _mapList(body['value'], (raw) => _mapRoleMembership(raw, tenantId)),
    );
  }

  @override
  Future<Result<List<RbacRoleMembershipEntity>>> fetchGlobalRoleMemberships({
    int top = 200,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: appConfig.api.endpoints.rbacGlobalRoleMembership,
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'CreatedAt desc',
          r'$expand': 'GlobalRole,User',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacRoleMembershipEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacRoleMembershipEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacRoleMembershipEntity>>.success(
      _mapList(body['value'], (raw) => _mapRoleMembership(raw, null)),
    );
  }

  @override
  Future<Result<List<RbacTenantMemberEntity>>> fetchTenantMembers({
    required String tenantId,
    int top = 200,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: _tenantMembershipBasePath(tenantId),
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'CreatedAt desc',
          r'$expand': 'User',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<RbacTenantMemberEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<RbacTenantMemberEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<RbacTenantMemberEntity>>.success(
      _mapList(body['value'], (raw) => _mapTenantMember(raw, tenantId)),
    );
  }

  @override
  Future<Result<void>> createGlobalRoleMembership(
    RbacCreateGlobalRoleMembershipInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.rbacGlobalRoleMembership,
        body: <String, dynamic>{
          'GlobalRoleId': input.roleId,
          'UserId': input.userId,
        },
      ),
    );
  }

  @override
  Future<Result<void>> deleteGlobalRoleMembership(
    RbacDeleteGlobalRoleMembershipInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.delete,
        path:
            '${appConfig.api.endpoints.rbacGlobalRoleMembership}/${input.membershipId}',
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<void>> createTenantRoleMembership(
    RbacCreateRoleMembershipInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _tenantRoleMembershipBasePath(input.tenantId),
        body: <String, dynamic>{
          'TenantId': input.tenantId,
          'RoleId': input.roleId,
          'UserId': input.userId,
        },
      ),
    );
  }

  @override
  Future<Result<void>> deleteTenantRoleMembership(
    RbacDeleteRoleMembershipInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.delete,
        path:
            '${_tenantRoleMembershipBasePath(input.tenantId)}/${input.membershipId}',
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  Future<Result<AuthenticatedResponse>> _sendRequest(AcpRequest request) async {
    try {
      final response = await authenticatedHttpClient.send(request);
      if (response.sessionExpired) {
        cookieStore.removeCookie('auth', '/');
        return const Result<AuthenticatedResponse>.failure(
          SessionExpiredFailure(),
        );
      }

      if (!response.response.isSuccess) {
        return Result<AuthenticatedResponse>.failure(_mapApiFailure(response));
      }

      return Result<AuthenticatedResponse>.success(response);
    } catch (_) {
      return const Result<AuthenticatedResponse>.failure(
        NetworkFailure('Network error.'),
      );
    }
  }

  Future<Result<void>> _sendVoid(AcpRequest request) async {
    try {
      final response = await authenticatedHttpClient.send(request);
      if (response.sessionExpired) {
        cookieStore.removeCookie('auth', '/');
        return const Result<void>.failure(SessionExpiredFailure());
      }

      if (!response.response.isSuccess) {
        return Result<void>.failure(_mapApiFailure(response));
      }

      return const Result<void>.success(null);
    } catch (_) {
      return const Result<void>.failure(NetworkFailure('Network error.'));
    }
  }

  ApiFailure _mapApiFailure(AuthenticatedResponse response) {
    return ApiFailure(
      response.response.statusCode,
      _extractApiMessage(response.response.body),
    );
  }

  String _extractApiMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'API error.';
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['message', 'detail', 'error', 'description']) {
          final value = decoded[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    } catch (_) {
      // Fallback to textual response below.
    }

    if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
      return 'API error.';
    }

    if (trimmed.length > 220) {
      return 'API error.';
    }

    return trimmed;
  }

  List<T> _mapList<T>(
    dynamic rawItems,
    T Function(Map<String, dynamic> raw) mapper,
  ) {
    final items = <T>[];
    if (rawItems is! List) {
      return items;
    }

    for (final entry in rawItems) {
      final map = _toNullableMap(entry);
      if (map != null) {
        items.add(mapper(map));
      }
    }

    return items;
  }

  Map<String, dynamic>? _decodeMap(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  RbacTenantSummaryEntity _mapTenant(Map<String, dynamic> raw) {
    return RbacTenantSummaryEntity(
      id: _asString(raw['Id']),
      name: _asString(raw['Name']),
      slug: _asString(raw['Slug']),
      status: _asString(raw['Status']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
    );
  }

  RbacRoleEntity _mapRole(
    Map<String, dynamic> raw, {
    required String? tenantId,
  }) {
    final namespace = _asString(raw['Namespace']);
    final name = _asString(raw['Name']);
    final displayName = _asString(raw['DisplayName']);

    return RbacRoleEntity(
      id: _asString(raw['Id']),
      namespace: namespace,
      name: name,
      displayName: displayName.isEmpty
          ? (namespace.isEmpty || name.isEmpty ? name : '$namespace:$name')
          : displayName,
      status: _asString(raw['Status']).isEmpty
          ? 'active'
          : _asString(raw['Status']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      dateCreated: _parseDate(raw['CreatedAt']),
      dateLastModified: _parseDate(raw['UpdatedAt']),
      tenantId: tenantId ?? _asNullableString(raw['TenantId']),
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  RbacPermissionObjectEntity _mapPermissionObject(Map<String, dynamic> raw) {
    return RbacPermissionObjectEntity(
      id: _asString(raw['Id']),
      namespace: _asString(raw['Namespace']),
      name: _asString(raw['Name']),
      status: _asString(raw['Status']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      dateCreated: _parseDate(raw['CreatedAt']),
      dateLastModified: _parseDate(raw['UpdatedAt']),
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  RbacPermissionTypeEntity _mapPermissionType(Map<String, dynamic> raw) {
    return RbacPermissionTypeEntity(
      id: _asString(raw['Id']),
      namespace: _asString(raw['Namespace']),
      name: _asString(raw['Name']),
      status: _asString(raw['Status']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      dateCreated: _parseDate(raw['CreatedAt']),
      dateLastModified: _parseDate(raw['UpdatedAt']),
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  RbacPermissionEntryEntity _mapPermissionEntry(
    Map<String, dynamic> raw, {
    required String? tenantId,
  }) {
    final roleMap =
        _toNullableMap(raw['Role']) ?? _toNullableMap(raw['GlobalRole']);
    final roleNamespace = roleMap == null
        ? ''
        : _asString(roleMap['Namespace']);
    final roleName = roleMap == null ? '' : _asString(roleMap['Name']);
    final roleDisplayName = roleMap == null
        ? ''
        : _asString(roleMap['DisplayName']);
    final resolvedRoleDisplayName = roleDisplayName.isNotEmpty
        ? roleDisplayName
        : (roleNamespace.isEmpty || roleName.isEmpty
              ? roleName
              : '$roleNamespace:$roleName');

    final objectMap = _toNullableMap(raw['PermissionObject']);
    final objectNamespace = objectMap == null
        ? ''
        : _asString(objectMap['Namespace']);
    final objectName = objectMap == null ? '' : _asString(objectMap['Name']);
    final objectDisplay = objectNamespace.isEmpty || objectName.isEmpty
        ? objectName
        : '$objectNamespace:$objectName';

    final typeMap = _toNullableMap(raw['PermissionType']);
    final typeNamespace = typeMap == null
        ? ''
        : _asString(typeMap['Namespace']);
    final typeName = typeMap == null ? '' : _asString(typeMap['Name']);
    final typeDisplay = typeNamespace.isEmpty || typeName.isEmpty
        ? typeName
        : '$typeNamespace:$typeName';

    return RbacPermissionEntryEntity(
      id: _asString(raw['Id']),
      tenantId: tenantId ?? _asNullableString(raw['TenantId']),
      roleId: _asString(raw['RoleId']).isEmpty
          ? _asString(raw['GlobalRoleId'])
          : _asString(raw['RoleId']),
      roleDisplayName: resolvedRoleDisplayName,
      permissionObjectId: _asString(raw['PermissionObjectId']),
      permissionObjectDisplayName: objectDisplay,
      permissionTypeId: _asString(raw['PermissionTypeId']),
      permissionTypeDisplayName: typeDisplay,
      permitted: _toBool(raw['Permitted']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      dateCreated: _parseDate(raw['CreatedAt']),
      dateLastModified: _parseDate(raw['UpdatedAt']),
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  RbacRoleMembershipEntity _mapRoleMembership(
    Map<String, dynamic> raw,
    String? tenantId,
  ) {
    final roleMap =
        _toNullableMap(raw['Role']) ?? _toNullableMap(raw['GlobalRole']);
    final roleNamespace = roleMap == null
        ? ''
        : _asString(roleMap['Namespace']);
    final roleName = roleMap == null ? '' : _asString(roleMap['Name']);
    final roleId = _firstNonEmpty([
      _asString(raw['RoleId']),
      _asString(raw['GlobalRoleId']),
    ]);
    final roleKey = _roleKey(
      namespace: roleNamespace,
      name: roleName,
      fallback: roleId,
    );
    final roleDisplayName = _roleDisplayName(
      roleMap,
      roleKey: roleKey,
      roleId: roleId,
    );

    final userMap = _toNullableMap(raw['User']);
    final userId = _asString(raw['UserId']);
    final userEmail = userMap == null ? '' : _asString(userMap['LoginEmail']);
    final userName = userMap == null ? '' : _asString(userMap['Username']);
    final userDisplayName = _firstNonEmpty([userEmail, userName, userId]);

    return RbacRoleMembershipEntity(
      id: _asString(raw['Id']),
      tenantId: _asNullableString(raw['TenantId']) ?? tenantId,
      roleId: roleId,
      userId: userId,
      roleDisplayName: roleDisplayName,
      roleKey: roleKey,
      roleNamespace: roleNamespace,
      roleName: roleName,
      userDisplayName: userDisplayName,
      userEmail: userEmail,
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      dateCreated: _parseDate(raw['CreatedAt']),
      dateLastModified: _parseDate(raw['UpdatedAt']),
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  RbacAssignableUserEntity _mapAssignableUser(Map<String, dynamic> raw) {
    final personMap = _toNullableMap(raw['Person']);
    final firstName = personMap == null
        ? ''
        : _asString(personMap['FirstName']);
    final lastName = personMap == null ? '' : _asString(personMap['LastName']);
    final personName = _joinNonEmpty([firstName, lastName], separator: ' ');
    final username = _asString(raw['Username']);
    final email = _asString(raw['LoginEmail']);
    final id = _asString(raw['Id']);

    return RbacAssignableUserEntity(
      id: id,
      username: username,
      displayName: _firstNonEmpty([personName, email, username, id]),
      email: email,
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  RbacTenantMemberEntity _mapTenantMember(
    Map<String, dynamic> raw,
    String tenantId,
  ) {
    final userMap = _toNullableMap(raw['User']);
    final userId = _asString(raw['UserId']);
    final email = userMap == null ? '' : _asString(userMap['LoginEmail']);
    final username = userMap == null ? '' : _asString(userMap['Username']);

    return RbacTenantMemberEntity(
      membershipId: _asString(raw['Id']),
      tenantId: _asString(raw['TenantId']).isEmpty
          ? tenantId
          : _asString(raw['TenantId']),
      userId: userId,
      username: username,
      displayName: _firstNonEmpty([email, username, userId]),
      email: email,
      status: _asString(raw['Status']),
      deleted: raw['DeletedAt'] != null,
    );
  }

  String _tenantRoleBasePath(String tenantId) {
    return appConfig.api.endpoints.rbacTenantRole.replaceAll(
      '{tenant_id}',
      tenantId,
    );
  }

  String _tenantPermissionEntryBasePath(String tenantId) {
    return appConfig.api.endpoints.rbacTenantPermissionEntry.replaceAll(
      '{tenant_id}',
      tenantId,
    );
  }

  String _tenantRoleMembershipBasePath(String tenantId) {
    return appConfig.api.endpoints.rbacTenantRoleMembership.replaceAll(
      '{tenant_id}',
      tenantId,
    );
  }

  String _tenantMembershipBasePath(String tenantId) {
    return appConfig.api.endpoints.tenantMembership.replaceAll(
      '{tenant_id}',
      tenantId,
    );
  }

  String _roleKey({
    required String namespace,
    required String name,
    required String fallback,
  }) {
    if (namespace.isNotEmpty && name.isNotEmpty) {
      return '$namespace:$name';
    }
    if (name.isNotEmpty) {
      return name;
    }
    return fallback;
  }

  String _roleDisplayName(
    Map<String, dynamic>? roleMap, {
    required String roleKey,
    required String roleId,
  }) {
    final displayName = roleMap == null
        ? ''
        : _asString(roleMap['DisplayName']);
    return _firstNonEmpty([displayName, roleKey, roleId]);
  }

  DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value is String && value.isNotEmpty) {
      final parsedIso = DateTime.tryParse(value);
      if (parsedIso != null) {
        return parsedIso.toUtc();
      }

      try {
        return _rfc1123DateFormat.parseUtc(value);
      } catch (_) {
        return fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
    }

    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }

    return false;
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return '';
  }

  String _joinNonEmpty(List<String> values, {required String separator}) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(separator);
  }

  String? _asNullableString(dynamic value) {
    final normalized = _asString(value);
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Map<String, dynamic>? _toNullableMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    return null;
  }
}
