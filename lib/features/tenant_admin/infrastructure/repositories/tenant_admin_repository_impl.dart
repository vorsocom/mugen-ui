import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/tenant_admin/application/dto/tenant_admin_inputs.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_domain_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_invitation_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_membership_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/repositories/tenant_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class TenantAdminRepositoryImpl implements TenantAdminRepository {
  TenantAdminRepositoryImpl({
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
  Future<Result<PageResult<TenantEntity>>> fetchTenants(
    TenantListQuery query,
  ) async {
    final queryParameters = <String, dynamic>{
      r'$count': true,
      r'$orderby': 'CreatedAt desc',
    };

    if (query.pageRequest.pageSize > 0) {
      queryParameters[r'$skip'] = query.pageRequest.skip;
      queryParameters[r'$top'] = query.pageRequest.pageSize;
    }

    final term = query.searchTerm?.trim() ?? '';
    if (term.length >= 2) {
      final escaped = _escapeRGQLString(term);
      queryParameters[r'$filter'] =
          "contains(Name,'$escaped') or contains(Slug,'$escaped')";
    }

    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: appConfig.api.endpoints.tenant,
        queryParameters: queryParameters,
      ),
    );
    if (response.isFailure) {
      return Result<PageResult<TenantEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<PageResult<TenantEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    final items = _mapList(body['value'], _mapTenant);
    final total = _parseCount(body['@count'], fallback: items.length);
    return Result<PageResult<TenantEntity>>.success(
      PageResult<TenantEntity>(
        items: items,
        total: total,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<void>> createTenant(CreateTenantInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.tenant,
        body: <String, dynamic>{'Name': input.name, 'Slug': input.slug},
      ),
    );
  }

  @override
  Future<Result<void>> updateTenant(UpdateTenantInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.patch,
        path: '${appConfig.api.endpoints.tenant}/${input.tenantId}',
        body: <String, dynamic>{
          'Name': input.name,
          'Slug': input.slug,
          'RowVersion': input.rowVersion,
        },
      ),
    );
  }

  @override
  Future<Result<void>> deactivateTenant(TenantLifecycleInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.tenantActionDeactivate.replaceAll(
          '{tenant_id}',
          input.tenantId,
        ),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<void>> reactivateTenant(TenantLifecycleInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.tenantActionReactivate.replaceAll(
          '{tenant_id}',
          input.tenantId,
        ),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<List<TenantDomainEntity>>> fetchTenantDomains({
    required String tenantId,
    int top = 100,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: _tenantDomainBasePath(tenantId),
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'CreatedAt desc',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<TenantDomainEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<TenantDomainEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<TenantDomainEntity>>.success(
      _mapList(body['value'], (raw) => _mapTenantDomain(raw, tenantId)),
    );
  }

  @override
  Future<Result<void>> createTenantDomain(CreateTenantDomainInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _tenantDomainBasePath(input.tenantId),
        body: <String, dynamic>{
          'Domain': input.domain,
          'IsPrimary': input.isPrimary,
        },
      ),
    );
  }

  @override
  Future<Result<void>> updateTenantDomain(UpdateTenantDomainInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.patch,
        path: '${_tenantDomainBasePath(input.tenantId)}/${input.domainId}',
        body: <String, dynamic>{
          'Domain': input.domain,
          'IsPrimary': input.isPrimary,
          'RowVersion': input.rowVersion,
        },
      ),
    );
  }

  @override
  Future<Result<void>> deleteTenantDomain(DeleteTenantDomainInput input) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.delete,
        path: '${_tenantDomainBasePath(input.tenantId)}/${input.domainId}',
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<List<TenantInvitationEntity>>> fetchTenantInvitations({
    required String tenantId,
    int top = 100,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: _tenantInvitationBasePath(tenantId),
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$orderby': 'CreatedAt desc',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<TenantInvitationEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<TenantInvitationEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<TenantInvitationEntity>>.success(
      _mapList(body['value'], (raw) => _mapTenantInvitation(raw, tenantId)),
    );
  }

  @override
  Future<Result<void>> createTenantInvitation(
    CreateTenantInvitationInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _tenantInvitationBasePath(input.tenantId),
        body: <String, dynamic>{
          'Email': input.email,
          'RoleInTenant': input.roleInTenant,
        },
      ),
    );
  }

  @override
  Future<Result<void>> resendTenantInvitation(
    TenantInvitationActionInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.tenantInvitationActionResend
            .replaceAll('{tenant_id}', input.tenantId)
            .replaceAll('{invitation_id}', input.invitationId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<void>> revokeTenantInvitation(
    TenantInvitationActionInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.tenantInvitationActionRevoke
            .replaceAll('{tenant_id}', input.tenantId)
            .replaceAll('{invitation_id}', input.invitationId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<List<TenantMembershipEntity>>> fetchTenantMemberships({
    required String tenantId,
    int top = 100,
  }) async {
    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: _tenantMembershipBasePath(tenantId),
        queryParameters: <String, dynamic>{
          r'$top': top,
          r'$expand': 'User',
          r'$orderby': 'CreatedAt desc',
        },
      ),
    );
    if (response.isFailure) {
      return Result<List<TenantMembershipEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<TenantMembershipEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<TenantMembershipEntity>>.success(
      _mapList(body['value'], (raw) => _mapTenantMembership(raw, tenantId)),
    );
  }

  @override
  Future<Result<void>> createTenantMembership(
    CreateTenantMembershipInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _tenantMembershipBasePath(input.tenantId),
        body: <String, dynamic>{
          'UserId': input.userId,
          'RoleInTenant': input.roleInTenant,
        },
      ),
    );
  }

  @override
  Future<Result<void>> updateTenantMembership(
    UpdateTenantMembershipInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.patch,
        path:
            '${_tenantMembershipBasePath(input.tenantId)}/${input.membershipId}',
        body: <String, dynamic>{
          'RoleInTenant': input.roleInTenant,
          'RowVersion': input.rowVersion,
        },
      ),
    );
  }

  @override
  Future<Result<void>> suspendTenantMembership(
    TenantMembershipActionInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.tenantMembershipActionSuspend
            .replaceAll('{tenant_id}', input.tenantId)
            .replaceAll('{membership_id}', input.membershipId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<void>> unsuspendTenantMembership(
    TenantMembershipActionInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.tenantMembershipActionUnsuspend
            .replaceAll('{tenant_id}', input.tenantId)
            .replaceAll('{membership_id}', input.membershipId),
        body: <String, dynamic>{'RowVersion': input.rowVersion},
      ),
    );
  }

  @override
  Future<Result<void>> removeTenantMembership(
    TenantMembershipActionInput input,
  ) async {
    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: appConfig.api.endpoints.tenantMembershipActionRemove
            .replaceAll('{tenant_id}', input.tenantId)
            .replaceAll('{membership_id}', input.membershipId),
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
        return Result<AuthenticatedResponse>.failure(
          ApiFailure(response.response.statusCode, 'API error.'),
        );
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
        return Result<void>.failure(
          ApiFailure(response.response.statusCode, 'API error.'),
        );
      }

      return const Result<void>.success(null);
    } catch (_) {
      return const Result<void>.failure(NetworkFailure('Network error.'));
    }
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

  TenantEntity _mapTenant(Map<String, dynamic> raw) {
    return TenantEntity(
      id: _asString(raw['Id']),
      name: _asString(raw['Name']),
      slug: _asString(raw['Slug']),
      status: _asString(raw['Status']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      dateCreated: _parseDate(raw['CreatedAt']),
      dateLastModified: _parseDate(raw['UpdatedAt']),
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  TenantDomainEntity _mapTenantDomain(
    Map<String, dynamic> raw,
    String tenantId,
  ) {
    return TenantDomainEntity(
      id: _asString(raw['Id']),
      tenantId: _asString(raw['TenantId']).isEmpty
          ? tenantId
          : _asString(raw['TenantId']),
      domain: _asString(raw['Domain']),
      isPrimary: _toBool(raw['IsPrimary']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      dateCreated: _parseDate(raw['CreatedAt']),
      dateLastModified: _parseDate(raw['UpdatedAt']),
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  TenantInvitationEntity _mapTenantInvitation(
    Map<String, dynamic> raw,
    String tenantId,
  ) {
    return TenantInvitationEntity(
      id: _asString(raw['Id']),
      tenantId: _asString(raw['TenantId']).isEmpty
          ? tenantId
          : _asString(raw['TenantId']),
      email: _asString(raw['Email']),
      roleInTenant: _asString(raw['RoleInTenant']),
      status: _asString(raw['Status']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      dateCreated: _parseDate(raw['CreatedAt']),
      dateLastModified: _parseDate(raw['UpdatedAt']),
      expiresAt: _parseOptionalDate(raw['ExpiresAt']),
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  TenantMembershipEntity _mapTenantMembership(
    Map<String, dynamic> raw,
    String tenantId,
  ) {
    final user = _toNullableMap(raw['User']);
    return TenantMembershipEntity(
      id: _asString(raw['Id']),
      tenantId: _asString(raw['TenantId']).isEmpty
          ? tenantId
          : _asString(raw['TenantId']),
      userId: _asString(raw['UserId']),
      userName: _asNullableNonEmptyString(user?['Username']),
      userEmail: _asNullableNonEmptyString(user?['LoginEmail']),
      roleInTenant: _asString(raw['RoleInTenant']),
      status: _asString(raw['Status']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      dateCreated: _parseDate(raw['CreatedAt']),
      dateLastModified: _parseDate(raw['UpdatedAt']),
      deleted: raw['DeletedAt'] != null,
      seedData: _toBool(raw['SeedData']),
    );
  }

  String _tenantDomainBasePath(String tenantId) {
    return appConfig.api.endpoints.tenantDomain.replaceAll(
      '{tenant_id}',
      tenantId,
    );
  }

  String _tenantInvitationBasePath(String tenantId) {
    return appConfig.api.endpoints.tenantInvitation.replaceAll(
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

  DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return _parseDate(value);
  }

  int _parseCount(dynamic value, {required int fallback}) {
    final parsed = _parseInt(value);
    return parsed ?? fallback;
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

  String? _asNullableNonEmptyString(dynamic value) {
    final text = _asString(value).trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic>? _toNullableMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    return null;
  }

  String _escapeRGQLString(String input) {
    return input.replaceAll("'", "''");
  }
}
