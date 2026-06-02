// coverage:ignore-file
import 'dart:convert';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/human_handoff/application/dto/human_handoff_inputs.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_delivery_result_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_session_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_tenant_option_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_transcript_item_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/repositories/human_handoff_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class HumanHandoffRepositoryImpl implements HumanHandoffRepository {
  HumanHandoffRepositoryImpl({
    required this.appConfig,
    required this.authenticatedHttpClient,
  });

  final AppConfig appConfig;
  final AuthenticatedHttpClient authenticatedHttpClient;

  @override
  Future<Result<List<HumanHandoffTenantOptionEntity>>> fetchTenants({
    int top = 200,
  }) async {
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
      return Result<List<HumanHandoffTenantOptionEntity>>.failure(
        response.failure!,
      );
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<HumanHandoffTenantOptionEntity>>.failure(
        UnexpectedFailure('Unexpected tenant response.'),
      );
    }

    final tenants =
        _mapList(
              body['value'],
              (row) => HumanHandoffTenantOptionEntity(
                id: _asString(row['Id']),
                name: _asString(row['Name'], fallback: _asString(row['Slug'])),
                slug: _asNullableString(row['Slug']),
              ),
            )
            .where((tenant) => tenant.id.isNotEmpty && tenant.name.isNotEmpty)
            .where(_isTenantSessionScope)
            .toList(growable: false);

    return Result<List<HumanHandoffTenantOptionEntity>>.success(tenants);
  }

  @override
  Future<Result<PageResult<HumanHandoffSessionEntity>>> fetchSessions(
    HumanHandoffSessionListQuery query,
  ) async {
    final tenantId = query.tenantId.trim();
    if (tenantId.isEmpty) {
      return const Result<PageResult<HumanHandoffSessionEntity>>.failure(
        ValidationFailure('A tenant must be selected.'),
      );
    }

    final filters = _buildSessionFilters(query);
    final queryParameters = <String, dynamic>{
      r'$count': true,
      r'$orderby': 'ActivatedAt desc',
      r'$skip': query.pageRequest.skip,
      r'$top': query.pageRequest.pageSize,
      if (filters.isNotEmpty) r'$filter': filters.join(' and '),
    };

    final response = await _send(
      AcpRequest(
        method: HttpMethod.get,
        path: _collectionPath(tenantId),
        queryParameters: queryParameters,
      ),
    );
    if (response.isFailure) {
      return Result<PageResult<HumanHandoffSessionEntity>>.failure(
        response.failure!,
      );
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<PageResult<HumanHandoffSessionEntity>>.failure(
        UnexpectedFailure('Unexpected session response.'),
      );
    }

    final sessions = _mapList(body['value'], _mapSession);
    final total = _parseCount(body['@count'], fallback: sessions.length);
    return Result<PageResult<HumanHandoffSessionEntity>>.success(
      PageResult<HumanHandoffSessionEntity>(
        items: sessions,
        total: total,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<List<HumanHandoffTranscriptItemEntity>>> listTranscript(
    HumanHandoffTranscriptQuery query,
  ) async {
    final tenantId = query.tenantId.trim();
    final sessionId = query.sessionId.trim();
    if (tenantId.isEmpty || sessionId.isEmpty) {
      return const Result<List<HumanHandoffTranscriptItemEntity>>.failure(
        ValidationFailure('A tenant and handoff session must be selected.'),
      );
    }

    final response = await _send(
      AcpRequest(
        method: HttpMethod.post,
        path: _entityActionPath(tenantId, sessionId, 'list_transcript'),
        body: <String, dynamic>{'Limit': query.limit},
      ),
    );
    if (response.isFailure) {
      return Result<List<HumanHandoffTranscriptItemEntity>>.failure(
        response.failure!,
      );
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<List<HumanHandoffTranscriptItemEntity>>.failure(
        UnexpectedFailure('Unexpected transcript response.'),
      );
    }

    final items = _mapList(body['Items'], _mapTranscriptItem)
      ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));
    return Result<List<HumanHandoffTranscriptItemEntity>>.success(items);
  }

  @override
  Future<Result<HumanHandoffDeliveryResultEntity>> sendReply(
    HumanHandoffReplyInput input,
  ) async {
    final tenantId = input.tenantId.trim();
    final sessionId = input.sessionId.trim();
    final content = input.content.trim();
    if (tenantId.isEmpty || sessionId.isEmpty) {
      return const Result<HumanHandoffDeliveryResultEntity>.failure(
        ValidationFailure('A tenant and handoff session must be selected.'),
      );
    }
    if (content.isEmpty) {
      return const Result<HumanHandoffDeliveryResultEntity>.failure(
        ValidationFailure('Reply text is required.'),
      );
    }

    final metadata = <String, dynamic>{};
    final operatorDisplayName = input.operatorDisplayName?.trim();
    if (operatorDisplayName != null && operatorDisplayName.isNotEmpty) {
      metadata['operator_display_name'] = operatorDisplayName;
    }

    final body = <String, dynamic>{
      'Content': content,
      'MessageId': input.messageId,
      if (input.traceId?.trim().isNotEmpty ?? false)
        'TraceId': input.traceId!.trim(),
      if (metadata.isNotEmpty) 'Metadata': metadata,
    };

    final response = await _send(
      AcpRequest(
        method: HttpMethod.post,
        path: _entityActionPath(tenantId, sessionId, 'human_reply'),
        body: body,
      ),
    );
    if (response.isFailure) {
      return Result<HumanHandoffDeliveryResultEntity>.failure(
        response.failure!,
      );
    }

    final payload = _decodeMap(response.data!.response.body);
    if (payload == null) {
      return const Result<HumanHandoffDeliveryResultEntity>.failure(
        UnexpectedFailure('Unexpected reply response.'),
      );
    }

    return Result<HumanHandoffDeliveryResultEntity>.success(
      HumanHandoffDeliveryResultEntity(
        decision: _asString(payload['Decision']),
        deliveryStatus: _asString(payload['DeliveryStatus']),
        deliveryError: _asNullableString(payload['DeliveryError']),
      ),
    );
  }

  @override
  Future<Result<void>> deactivate(HumanHandoffDeactivateInput input) async {
    final tenantId = input.tenantId.trim();
    final sessionId = input.sessionId.trim();
    if (tenantId.isEmpty || sessionId.isEmpty) {
      return const Result<void>.failure(
        ValidationFailure('A tenant and handoff session must be selected.'),
      );
    }

    final reason = input.reason?.trim();
    final body = reason == null || reason.isEmpty
        ? const <String, dynamic>{}
        : <String, dynamic>{'Reason': reason};

    final response = await _send(
      AcpRequest(
        method: HttpMethod.post,
        path: _entityActionPath(tenantId, sessionId, 'deactivate_handoff'),
        body: body,
      ),
    );
    if (response.isFailure) {
      return Result<void>.failure(response.failure!);
    }

    return const Result<void>.success(null);
  }

  List<String> _buildSessionFilters(HumanHandoffSessionListQuery query) {
    final filters = <String>[];
    final status = query.status?.trim();
    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      filters.add("Status eq '${_escapeString(status)}'");
    }

    final platform = query.platform?.trim();
    if (platform != null && platform.isNotEmpty) {
      filters.add("Platform eq '${_escapeString(platform)}'");
    }

    final serviceRouteKey = query.serviceRouteKey?.trim();
    if (serviceRouteKey != null && serviceRouteKey.isNotEmpty) {
      filters.add("ServiceRouteKey eq '${_escapeString(serviceRouteKey)}'");
    }

    final ownerUserId = query.ownerUserId?.trim();
    if (ownerUserId != null && ownerUserId.isNotEmpty) {
      filters.add("OwnerUserId eq '${_escapeString(ownerUserId)}'");
    }

    return filters;
  }

  HumanHandoffSessionEntity _mapSession(Map<String, dynamic> row) {
    return HumanHandoffSessionEntity(
      id: _asString(row['Id']),
      tenantId: _asString(row['TenantId']),
      scopeKey: _asString(row['ScopeKey']),
      platform: _asString(row['Platform']),
      channelId: _asNullableString(row['ChannelId']),
      roomId: _asNullableString(row['RoomId']),
      senderId: _asNullableString(row['SenderId']),
      conversationId: _asNullableString(row['ConversationId']),
      clientProfileId: _asNullableString(row['ClientProfileId']),
      serviceRouteKey: _asNullableString(row['ServiceRouteKey']),
      status: _asString(row['Status']),
      ownerUserId: _asNullableString(row['OwnerUserId']),
      reason: _asNullableString(row['Reason']),
      activatedAt: _asDateTime(row['ActivatedAt']),
      deactivatedAt: _asDateTime(row['DeactivatedAt']),
      lastHumanReplyAt: _asDateTime(row['LastHumanReplyAt']),
      lastDeliveryStatus: _asNullableString(row['LastDeliveryStatus']),
      lastDeliveryError: _asNullableString(row['LastDeliveryError']),
    );
  }

  HumanHandoffTranscriptItemEntity _mapTranscriptItem(
    Map<String, dynamic> row,
  ) {
    return HumanHandoffTranscriptItemEntity(
      sequenceNo: _asInt(row['SequenceNo']),
      role: _asString(row['Role']),
      content: row['Content'],
      messageId: _asNullableString(row['MessageId']),
      traceId: _asNullableString(row['TraceId']),
      source: _asString(row['Source']),
      occurredAt: _asDateTime(row['OccurredAt']),
    );
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

  String _collectionPath(String tenantId) {
    return '${appConfig.api.endpoints.acpBase}/tenants/$tenantId/'
        'HumanHandoffSessions';
  }

  String _entityActionPath(String tenantId, String sessionId, String action) {
    return '${_collectionPath(tenantId)}/$sessionId/\$action/$action';
  }

  List<T> _mapList<T>(Object? raw, T Function(Map<String, dynamic>) mapper) {
    if (raw is! List) {
      return const <Never>[];
    }
    return raw
        .whereType<Map>()
        .map((item) => mapper(Map<String, dynamic>.from(item)))
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

  String _asString(Object? raw, {String fallback = ''}) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) {
      return fallback;
    }
    return text;
  }

  String? _asNullableString(Object? raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  int _asInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int _parseCount(Object? raw, {required int fallback}) {
    if (raw is int) {
      return raw;
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  DateTime? _asDateTime(Object? raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text)?.toUtc();
  }

  String _escapeString(String value) {
    return value.replaceAll("'", "''");
  }

  bool _isTenantSessionScope(HumanHandoffTenantOptionEntity tenant) {
    final normalizedId = _normalizeTenantScopeValue(tenant.id);
    final normalizedSlug = _normalizeTenantScopeValue(tenant.slug);
    final normalizedName = _normalizeTenantScopeValue(tenant.name);
    return !_isReservedGlobalTenantValue(normalizedId) &&
        !_isReservedGlobalTenantValue(normalizedSlug) &&
        normalizedName != 'global' &&
        normalizedName != 'acpglobaltenant';
  }

  bool _isReservedGlobalTenantValue(String value) {
    return value == 'global' || value.startsWith('reservedglobal');
  }

  String _normalizeTenantScopeValue(String? value) {
    return value?.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '') ??
        '';
  }

  String _errorMessageFor(String raw) {
    final decoded = _decodeJson(raw);
    if (decoded is Map) {
      for (final key in const <String>['message', 'error', 'detail']) {
        final value = decoded[key];
        final text = value?.toString().trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
    }

    final htmlMessage = _htmlErrorMessageFor(raw);
    if (htmlMessage != null) {
      return htmlMessage;
    }

    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'API request failed.';
  }

  String? _htmlErrorMessageFor(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.toLowerCase().contains('<html')) {
      return null;
    }

    final title = _htmlTagText(trimmed, 'title');
    final heading = _htmlTagText(trimmed, 'h1');
    final headingText =
        heading != null &&
            !(title?.toLowerCase().contains(heading.toLowerCase()) ?? false)
        ? heading
        : null;
    final paragraph = _htmlTagText(trimmed, 'p');
    final parts = <String>[?title, ?headingText, ?paragraph];
    if (parts.isEmpty) {
      return 'API request failed.';
    }
    return parts.join(': ');
  }

  String? _htmlTagText(String raw, String tagName) {
    final match = RegExp(
      '<$tagName[^>]*>(.*?)</$tagName>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(raw);
    final text = match?.group(1);
    if (text == null) {
      return null;
    }
    final normalized = text
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? null : normalized;
  }
}
