// coverage:ignore-file
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/audit_admin/application/dto/audit_admin_inputs.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_chain_verification_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_event_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_lifecycle_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_seal_backlog_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_tenant_option_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/repositories/audit_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class AuditAdminRepositoryImpl implements AuditAdminRepository {
  AuditAdminRepositoryImpl({
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
  Future<Result<PageResult<AuditEventEntity>>> fetchAuditEvents(
    AuditEventListQuery query,
  ) async {
    final tenantResolution = _resolveScopeTenant(
      scopeMode: query.scopeMode,
      tenantId: query.tenantId,
    );
    if (tenantResolution.isFailure) {
      return Result<PageResult<AuditEventEntity>>.failure(
        tenantResolution.failure!,
      );
    }

    final queryParameters = <String, dynamic>{
      r'$count': true,
      r'$orderby': 'OccurredAt desc',
    };

    if (query.pageRequest.pageSize > 0) {
      queryParameters[r'$skip'] = query.pageRequest.skip;
      queryParameters[r'$top'] = query.pageRequest.pageSize;
    }

    final filters = <String>[];
    if (query.scopeMode == AuditAdminScopeMode.global) {
      filters.add('TenantId eq null');
    }

    final searchTerm = query.searchTerm?.trim() ?? '';
    if (searchTerm.length >= 2) {
      final escaped = _escapeRGQLString(searchTerm);
      filters.add(
        "(contains(EntitySet,'$escaped')"
        " or contains(Entity,'$escaped')"
        " or contains(Operation,'$escaped')"
        " or contains(ActionName,'$escaped')"
        " or contains(SourcePlugin,'$escaped')"
        " or contains(Outcome,'$escaped')"
        " or contains(RequestId,'$escaped')"
        " or contains(CorrelationId,'$escaped'))",
      );
    }

    if (filters.isNotEmpty) {
      queryParameters[r'$filter'] = filters.join(' and ');
    }

    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.get,
        path: _auditBasePath(
          scopeMode: query.scopeMode,
          tenantId: tenantResolution.data,
        ),
        queryParameters: queryParameters,
      ),
    );
    if (response.isFailure) {
      return Result<PageResult<AuditEventEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<PageResult<AuditEventEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    final items = _mapList(body['value'], _mapAuditEvent);
    final total = _parseCount(body['@count'], fallback: items.length);
    return Result<PageResult<AuditEventEntity>>.success(
      PageResult<AuditEventEntity>(
        items: items,
        total: total,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<List<AuditTenantOptionEntity>>> fetchTenants({
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
      return Result<List<AuditTenantOptionEntity>>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<AuditTenantOptionEntity>>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<List<AuditTenantOptionEntity>>.success(
      _mapList(body['value'], _mapTenantOption),
    );
  }

  @override
  Future<Result<void>> placeLegalHold(AuditPlaceLegalHoldInput input) async {
    final tenantResolution = _resolveScopeTenant(
      scopeMode: input.scopeMode,
      tenantId: input.tenantId,
    );
    if (tenantResolution.isFailure) {
      return Result<void>.failure(tenantResolution.failure!);
    }

    final body = <String, dynamic>{
      'RowVersion': input.rowVersion,
      'Reason': input.reason,
    };
    if (input.legalHoldUntil != null) {
      body['LegalHoldUntil'] = input.legalHoldUntil!.toUtc().toIso8601String();
    }

    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _auditEntityActionPath(
          scopeMode: input.scopeMode,
          tenantId: tenantResolution.data,
          eventId: input.eventId,
          actionName: 'place_legal_hold',
        ),
        body: body,
      ),
    );
  }

  @override
  Future<Result<void>> releaseLegalHold(
    AuditReleaseLegalHoldInput input,
  ) async {
    final tenantResolution = _resolveScopeTenant(
      scopeMode: input.scopeMode,
      tenantId: input.tenantId,
    );
    if (tenantResolution.isFailure) {
      return Result<void>.failure(tenantResolution.failure!);
    }

    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _auditEntityActionPath(
          scopeMode: input.scopeMode,
          tenantId: tenantResolution.data,
          eventId: input.eventId,
          actionName: 'release_legal_hold',
        ),
        body: <String, dynamic>{
          'RowVersion': input.rowVersion,
          'Reason': input.reason,
        },
      ),
    );
  }

  @override
  Future<Result<void>> redactEvent(AuditRedactInput input) async {
    final tenantResolution = _resolveScopeTenant(
      scopeMode: input.scopeMode,
      tenantId: input.tenantId,
    );
    if (tenantResolution.isFailure) {
      return Result<void>.failure(tenantResolution.failure!);
    }

    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _auditEntityActionPath(
          scopeMode: input.scopeMode,
          tenantId: tenantResolution.data,
          eventId: input.eventId,
          actionName: 'redact',
        ),
        body: <String, dynamic>{
          'RowVersion': input.rowVersion,
          'Reason': input.reason,
        },
      ),
    );
  }

  @override
  Future<Result<void>> tombstoneEvent(AuditTombstoneInput input) async {
    final tenantResolution = _resolveScopeTenant(
      scopeMode: input.scopeMode,
      tenantId: input.tenantId,
    );
    if (tenantResolution.isFailure) {
      return Result<void>.failure(tenantResolution.failure!);
    }

    final body = <String, dynamic>{
      'RowVersion': input.rowVersion,
      'Reason': input.reason,
    };
    if (input.purgeAfterDays != null) {
      body['PurgeAfterDays'] = input.purgeAfterDays;
    }

    return _sendVoid(
      AcpRequest(
        method: HttpMethod.post,
        path: _auditEntityActionPath(
          scopeMode: input.scopeMode,
          tenantId: tenantResolution.data,
          eventId: input.eventId,
          actionName: 'tombstone',
        ),
        body: body,
      ),
    );
  }

  @override
  Future<Result<AuditLifecycleSummaryEntity>> runLifecycle(
    AuditRunLifecycleInput input,
  ) async {
    final tenantResolution = _resolveScopeTenant(
      scopeMode: input.scopeMode,
      tenantId: input.tenantId,
    );
    if (tenantResolution.isFailure) {
      return Result<AuditLifecycleSummaryEntity>.failure(
        tenantResolution.failure!,
      );
    }

    final body = <String, dynamic>{'DryRun': input.dryRun};
    if (input.batchSize != null) {
      body['BatchSize'] = input.batchSize;
    }
    if (input.maxBatches != null) {
      body['MaxBatches'] = input.maxBatches;
    }
    if (input.nowOverride != null) {
      body['NowOverride'] = input.nowOverride!.toUtc().toIso8601String();
    }
    if (input.phases != null && input.phases!.isNotEmpty) {
      body['Phases'] = input.phases;
    }

    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.post,
        path: _auditSetActionPath(
          scopeMode: input.scopeMode,
          tenantId: tenantResolution.data,
          actionName: 'run_lifecycle',
        ),
        body: body,
      ),
    );
    if (response.isFailure) {
      return Result<AuditLifecycleSummaryEntity>.failure(response.failure!);
    }

    final summaryPayload = _decodeMap(response.data!.response.body);
    if (summaryPayload == null) {
      return const Result<AuditLifecycleSummaryEntity>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<AuditLifecycleSummaryEntity>.success(
      _mapLifecycleSummary(summaryPayload),
    );
  }

  @override
  Future<Result<AuditChainVerificationSummaryEntity>> verifyChain(
    AuditVerifyChainInput input,
  ) async {
    final tenantResolution = _resolveScopeTenant(
      scopeMode: input.scopeMode,
      tenantId: input.tenantId,
    );
    if (tenantResolution.isFailure) {
      return Result<AuditChainVerificationSummaryEntity>.failure(
        tenantResolution.failure!,
      );
    }

    final body = <String, dynamic>{'RequireClean': input.requireClean};
    if (input.fromOccurredAt != null) {
      body['FromOccurredAt'] = input.fromOccurredAt!.toUtc().toIso8601String();
    }
    if (input.toOccurredAt != null) {
      body['ToOccurredAt'] = input.toOccurredAt!.toUtc().toIso8601String();
    }
    if (input.maxRows != null) {
      body['MaxRows'] = input.maxRows;
    }

    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.post,
        path: _auditSetActionPath(
          scopeMode: input.scopeMode,
          tenantId: tenantResolution.data,
          actionName: 'verify_chain',
        ),
        body: body,
      ),
    );
    if (response.isFailure) {
      return Result<AuditChainVerificationSummaryEntity>.failure(
        response.failure!,
      );
    }

    final summaryPayload = _decodeMap(response.data!.response.body);
    if (summaryPayload == null) {
      return const Result<AuditChainVerificationSummaryEntity>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<AuditChainVerificationSummaryEntity>.success(
      _mapChainSummary(summaryPayload),
    );
  }

  @override
  Future<Result<AuditSealBacklogSummaryEntity>> sealBacklog(
    AuditSealBacklogInput input,
  ) async {
    final tenantResolution = _resolveScopeTenant(
      scopeMode: input.scopeMode,
      tenantId: input.tenantId,
    );
    if (tenantResolution.isFailure) {
      return Result<AuditSealBacklogSummaryEntity>.failure(
        tenantResolution.failure!,
      );
    }

    final body = <String, dynamic>{};
    if (input.batchSize != null) {
      body['BatchSize'] = input.batchSize;
    }
    if (input.maxBatches != null) {
      body['MaxBatches'] = input.maxBatches;
    }

    final response = await _sendRequest(
      AcpRequest(
        method: HttpMethod.post,
        path: _auditSetActionPath(
          scopeMode: input.scopeMode,
          tenantId: tenantResolution.data,
          actionName: 'seal_backlog',
        ),
        body: body,
      ),
    );
    if (response.isFailure) {
      return Result<AuditSealBacklogSummaryEntity>.failure(response.failure!);
    }

    final summaryPayload = _decodeMap(response.data!.response.body);
    if (summaryPayload == null) {
      return const Result<AuditSealBacklogSummaryEntity>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<AuditSealBacklogSummaryEntity>.success(
      _mapSealBacklogSummary(summaryPayload),
    );
  }

  Result<String?> _resolveScopeTenant({
    required AuditAdminScopeMode scopeMode,
    required String? tenantId,
  }) {
    if (scopeMode == AuditAdminScopeMode.global) {
      return const Result<String?>.success(null);
    }

    final trimmed = tenantId?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const Result<String?>.failure(
        ValidationFailure('Tenant is required for tenant scope.'),
      );
    }

    return Result<String?>.success(trimmed);
  }

  String _auditBasePath({
    required AuditAdminScopeMode scopeMode,
    required String? tenantId,
  }) {
    if (scopeMode == AuditAdminScopeMode.global) {
      return appConfig.api.endpoints.auditEvent;
    }

    return appConfig.api.endpoints.auditEventTenant.replaceAll(
      '{tenant_id}',
      tenantId ?? '',
    );
  }

  String _auditEntityActionPath({
    required AuditAdminScopeMode scopeMode,
    required String? tenantId,
    required String eventId,
    required String actionName,
  }) {
    return '${_auditBasePath(scopeMode: scopeMode, tenantId: tenantId)}/'
        '$eventId/\$action/$actionName';
  }

  String _auditSetActionPath({
    required AuditAdminScopeMode scopeMode,
    required String? tenantId,
    required String actionName,
  }) {
    return '${_auditBasePath(scopeMode: scopeMode, tenantId: tenantId)}/'
        '\$action/$actionName';
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
      // Fall through to text fallback.
    }

    if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
      return 'API error.';
    }

    if (trimmed.length > 220) {
      return 'API error.';
    }

    return trimmed;
  }

  AuditEventEntity _mapAuditEvent(Map<String, dynamic> raw) {
    return AuditEventEntity(
      id: _asString(raw['Id']),
      rowVersion: _parseInt(raw['RowVersion']) ?? 0,
      tenantId: _asNullableString(raw['TenantId']),
      actorId: _asNullableString(raw['ActorId']),
      entitySet: _asString(raw['EntitySet']),
      entity: _asString(raw['Entity']),
      entityId: _asNullableString(raw['EntityId']),
      operation: _asString(raw['Operation']),
      actionName: _asNullableString(raw['ActionName']),
      occurredAt: _parseDate(raw['OccurredAt']),
      outcome: _asString(raw['Outcome']),
      requestId: _asNullableString(raw['RequestId']),
      correlationId: _asNullableString(raw['CorrelationId']),
      sourcePlugin: _asString(raw['SourcePlugin']),
      changedFields: _toStringList(raw['ChangedFields']),
      beforeSnapshot: _toJsonMap(raw['BeforeSnapshot']),
      afterSnapshot: _toJsonMap(raw['AfterSnapshot']),
      meta: _toJsonMap(raw['Meta']),
      scopeKey: _asString(raw['ScopeKey']),
      scopeSeq: _parseInt(raw['ScopeSeq']),
      prevEntryHash: _asNullableString(raw['PrevEntryHash']),
      entryHash: _asNullableString(raw['EntryHash']),
      hashAlg: _asString(raw['HashAlg']),
      hashKeyId: _asNullableString(raw['HashKeyId']),
      beforeSnapshotHash: _asNullableString(raw['BeforeSnapshotHash']),
      afterSnapshotHash: _asNullableString(raw['AfterSnapshotHash']),
      sealedAt: _parseOptionalDate(raw['SealedAt']),
      retentionUntil: _parseOptionalDate(raw['RetentionUntil']),
      redactionDueAt: _parseOptionalDate(raw['RedactionDueAt']),
      redactedAt: _parseOptionalDate(raw['RedactedAt']),
      redactionReason: _asNullableString(raw['RedactionReason']),
      legalHoldAt: _parseOptionalDate(raw['LegalHoldAt']),
      legalHoldUntil: _parseOptionalDate(raw['LegalHoldUntil']),
      legalHoldByUserId: _asNullableString(raw['LegalHoldByUserId']),
      legalHoldReason: _asNullableString(raw['LegalHoldReason']),
      legalHoldReleasedAt: _parseOptionalDate(raw['LegalHoldReleasedAt']),
      legalHoldReleasedByUserId: _asNullableString(
        raw['LegalHoldReleasedByUserId'],
      ),
      legalHoldReleaseReason: _asNullableString(raw['LegalHoldReleaseReason']),
      tombstonedAt: _parseOptionalDate(raw['TombstonedAt']),
      tombstonedByUserId: _asNullableString(raw['TombstonedByUserId']),
      tombstoneReason: _asNullableString(raw['TombstoneReason']),
      purgeDueAt: _parseOptionalDate(raw['PurgeDueAt']),
    );
  }

  AuditTenantOptionEntity _mapTenantOption(Map<String, dynamic> raw) {
    return AuditTenantOptionEntity(
      id: _asString(raw['Id']),
      name: _asString(raw['Name']),
      slug: _asString(raw['Slug']),
      status: _asString(raw['Status']),
    );
  }

  AuditLifecycleSummaryEntity _mapLifecycleSummary(Map<String, dynamic> raw) {
    final phases = <String, AuditLifecyclePhaseSummaryEntity>{};
    final phaseMap = _toNullableMap(raw['Phases']) ?? <String, dynamic>{};

    phaseMap.forEach((key, value) {
      final phase = _toNullableMap(value) ?? <String, dynamic>{};
      phases[key] = AuditLifecyclePhaseSummaryEntity(
        rowsProcessed:
            _parseInt(phase['RowsProcessed']) ??
            _parseInt(phase['RowsSealed']) ??
            0,
        remainingCount: _parseInt(phase['RemainingCount']) ?? 0,
        batches: _parseInt(phase['Batches']) ?? 0,
      );
    });

    final mapped = AuditLifecycleSummaryEntity(
      dryRun: _toBool(raw['DryRun']),
      now: _parseOptionalDate(raw['Now']),
      batchSize: _parseInt(raw['BatchSize']) ?? 0,
      maxBatches: _parseInt(raw['MaxBatches']) ?? 0,
      phases: phases,
      totalProcessed: _parseInt(raw['TotalProcessed']) ?? 0,
    );

    if (mapped.totalProcessed > 0) {
      return mapped;
    }

    final computedTotal = phases.values.fold<int>(
      0,
      (total, phase) => total + phase.rowsProcessed,
    );
    return AuditLifecycleSummaryEntity(
      dryRun: mapped.dryRun,
      now: mapped.now,
      batchSize: mapped.batchSize,
      maxBatches: mapped.maxBatches,
      phases: mapped.phases,
      totalProcessed: computedTotal,
    );
  }

  AuditChainVerificationSummaryEntity _mapChainSummary(
    Map<String, dynamic> raw,
  ) {
    final mismatches = <AuditChainMismatchEntity>[];
    final rawMismatches = raw['Mismatches'];
    if (rawMismatches is List) {
      for (final entry in rawMismatches) {
        final map = _toNullableMap(entry);
        if (map == null) {
          continue;
        }
        mismatches.add(
          AuditChainMismatchEntity(
            id: _asString(map['Id']),
            scopeKey: _asString(map['ScopeKey']),
            scopeSeq: _parseInt(map['ScopeSeq']),
            reasons: _toStringList(map['Reasons']),
          ),
        );
      }
    }

    return AuditChainVerificationSummaryEntity(
      isValid: _toBool(raw['IsValid']),
      checkedRows: _parseInt(raw['CheckedRows']) ?? 0,
      mismatchCount: _parseInt(raw['MismatchCount']) ?? mismatches.length,
      mismatches: mismatches,
    );
  }

  AuditSealBacklogSummaryEntity _mapSealBacklogSummary(
    Map<String, dynamic> raw,
  ) {
    return AuditSealBacklogSummaryEntity(
      rowsSealed: _parseInt(raw['RowsSealed']) ?? 0,
      remainingCount: _parseInt(raw['RemainingCount']) ?? 0,
      batches: _parseInt(raw['Batches']) ?? 0,
      batchSize: _parseInt(raw['BatchSize']) ?? 0,
      maxBatches: _parseInt(raw['MaxBatches']) ?? 0,
    );
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

  Map<String, dynamic>? _toJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        return null;
      }
    }

    return null;
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

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((entry) => entry.toString()).toList(growable: false);
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((entry) => entry.toString())
              .toList(growable: false);
        }
      } catch (_) {
        // Fall through.
      }
    }

    return const <String>[];
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  String? _asNullableString(dynamic value) {
    final normalized = _asString(value).trim();
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

  String _escapeRGQLString(String input) {
    return input.replaceAll("'", "''");
  }
}
