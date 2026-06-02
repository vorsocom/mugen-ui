// coverage:ignore-file
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/human_handoff/application/dto/human_handoff_inputs.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_delivery_result_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_event_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_session_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_tenant_option_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_transcript_item_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/repositories/human_handoff_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/auth/auth_cookie_codec.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class HumanHandoffRepositoryImpl implements HumanHandoffRepository {
  HumanHandoffRepositoryImpl({
    required this.appConfig,
    required this.authenticatedHttpClient,
    required this.cookieStore,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final AppConfig appConfig;
  final AuthenticatedHttpClient authenticatedHttpClient;
  final CookieStore cookieStore;
  final http.Client _httpClient;

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
      r'$orderby':
          'LastUserMessageAt desc, LastHumanReplyAt desc, ActivatedAt desc',
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
  Future<Result<HumanHandoffTranscriptResultEntity>> listTranscript(
    HumanHandoffTranscriptQuery query,
  ) async {
    final tenantId = query.tenantId.trim();
    final sessionId = query.sessionId.trim();
    if (tenantId.isEmpty || sessionId.isEmpty) {
      return const Result<HumanHandoffTranscriptResultEntity>.failure(
        ValidationFailure('A tenant and handoff session must be selected.'),
      );
    }

    final body = <String, dynamic>{
      'Limit': query.limit,
      if (query.afterSequenceNo != null)
        'AfterSequenceNo': query.afterSequenceNo,
    };
    final response = await _send(
      AcpRequest(
        method: HttpMethod.post,
        path: _entityActionPath(tenantId, sessionId, 'list_transcript'),
        body: body,
      ),
    );
    if (response.isFailure) {
      return Result<HumanHandoffTranscriptResultEntity>.failure(
        response.failure!,
      );
    }

    final payload = _decodeMap(response.data!.response.body);
    if (payload == null) {
      return const Result<HumanHandoffTranscriptResultEntity>.failure(
        UnexpectedFailure('Unexpected transcript response.'),
      );
    }

    final items = _mapList(payload['Items'], _mapTranscriptItem)
      ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));
    return Result<HumanHandoffTranscriptResultEntity>.success(
      HumanHandoffTranscriptResultEntity(
        items: items,
        count: _asInt(payload['Count'], fallback: items.length),
        latestSequenceNo: _asNullableInt(payload['LatestSequenceNo']),
        hasMore: _asBool(payload['HasMore']),
      ),
    );
  }

  @override
  Stream<Result<HumanHandoffEventEntity>> streamEvents(
    HumanHandoffEventStreamQuery query,
  ) async* {
    final tenantId = query.tenantId.trim();
    if (tenantId.isEmpty) {
      yield const Result<HumanHandoffEventEntity>.failure(
        ValidationFailure('A tenant must be selected.'),
      );
      return;
    }

    final streamOpenResult = await _openSseStream(query);
    if (streamOpenResult.isFailure) {
      yield Result<HumanHandoffEventEntity>.failure(streamOpenResult.failure!);
      return;
    }

    final response = streamOpenResult.data!;
    try {
      await for (final event in _parseSseEvents(response.stream)) {
        yield Result<HumanHandoffEventEntity>.success(event);
      }
    } catch (_) {
      yield const Result<HumanHandoffEventEntity>.failure(
        NetworkFailure('Handoff event stream disconnected.'),
      );
    }
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
      lastUserMessageAt: _asDateTime(row['LastUserMessageAt']),
      lastTranscriptSequenceNo: _asNullableInt(row['LastTranscriptSequenceNo']),
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

  HumanHandoffEventEntity _mapEvent(
    String eventName,
    Map<String, dynamic> payload,
  ) {
    return HumanHandoffEventEntity(
      eventId: _asNullableString(payload['event_id']),
      eventType: _asString(payload['event_type'], fallback: eventName),
      tenantId: _asString(payload['tenant_id']),
      sessionId: _asString(payload['session_id']),
      occurredAt: _asDateTime(payload['occurred_at']),
      sequenceNo: _asNullableInt(payload['sequence_no']),
      deliveryStatus: _asNullableString(payload['delivery_status']),
      deliveryError: _asNullableString(payload['delivery_error']),
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

  String _eventsStreamPath(String tenantId) {
    return '${appConfig.api.endpoints.acpBase}/tenants/$tenantId/'
        'HumanHandoffEvents/stream';
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

  int _asInt(Object? raw, {int fallback = 0}) {
    if (raw is int) {
      return raw;
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  int? _asNullableInt(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    return int.tryParse(raw.toString());
  }

  bool _asBool(Object? raw) {
    if (raw is bool) {
      return raw;
    }
    final normalized = raw?.toString().toLowerCase().trim();
    return normalized == 'true' || normalized == '1';
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

  Future<Result<http.StreamedResponse>> _openSseStream(
    HumanHandoffEventStreamQuery query,
  ) async {
    final session = parseAuthSession(cookieStore.getCookie('auth'));
    if (session == null) {
      return const Result<http.StreamedResponse>.failure(
        SessionExpiredFailure(),
      );
    }

    Future<http.StreamedResponse> send(String token) {
      final normalizedLastEventId = query.lastEventId?.trim();
      final normalizedSessionId = query.sessionId?.trim();
      final request = http.Request(
        'GET',
        _buildUri(
          _eventsStreamPath(query.tenantId.trim()),
          queryParameters: <String, dynamic>{
            if (normalizedLastEventId != null &&
                normalizedLastEventId.isNotEmpty)
              'last_event_id': normalizedLastEventId,
            if (normalizedSessionId != null && normalizedSessionId.isNotEmpty)
              'session_id': normalizedSessionId,
          },
        ),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'text/event-stream';
      if (normalizedLastEventId != null && normalizedLastEventId.isNotEmpty) {
        request.headers['Last-Event-ID'] = normalizedLastEventId;
      }
      return _httpClient.send(request);
    }

    var response = await send(session.accessToken);
    if (response.statusCode == 401) {
      final refreshedAccessToken = await _refreshAccessToken();
      if (refreshedAccessToken == null) {
        return const Result<http.StreamedResponse>.failure(
          SessionExpiredFailure(),
        );
      }
      response = await send(refreshedAccessToken);
    }

    if (response.statusCode == 401) {
      cookieStore.removeCookie('auth', '/');
      return const Result<http.StreamedResponse>.failure(
        SessionExpiredFailure(),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = await response.stream.bytesToString();
      return Result<http.StreamedResponse>.failure(
        ApiFailure(response.statusCode, _errorMessageFor(payload)),
      );
    }

    return Result<http.StreamedResponse>.success(response);
  }

  Stream<HumanHandoffEventEntity> _parseSseEvents(
    Stream<List<int>> byteStream,
  ) async* {
    String? eventId;
    String eventName = 'message';
    final dataLines = <String>[];

    HumanHandoffEventEntity? flush() {
      if (eventId == null && dataLines.isEmpty && eventName == 'message') {
        return null;
      }

      final payload = _parseSsePayload(dataLines);
      if (eventId != null && eventId!.trim().isNotEmpty) {
        payload.putIfAbsent('event_id', () => eventId);
      }
      final parsed = _mapEvent(eventName, payload);

      eventId = null;
      eventName = 'message';
      dataLines.clear();
      if (parsed.sessionId.isEmpty || parsed.eventType.isEmpty) {
        return null;
      }
      return parsed;
    }

    final lines = byteStream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final rawLine in lines) {
      if (rawLine.isEmpty) {
        final event = flush();
        if (event != null) {
          yield event;
        }
        continue;
      }

      if (rawLine.startsWith(':')) {
        continue;
      }

      if (rawLine.startsWith('id:')) {
        eventId = _sseFieldValue(rawLine, prefix: 'id:');
        continue;
      }

      if (rawLine.startsWith('event:')) {
        final value = _sseFieldValue(rawLine, prefix: 'event:');
        eventName = value.isEmpty ? 'message' : value;
        continue;
      }

      if (rawLine.startsWith('data:')) {
        dataLines.add(_sseFieldValue(rawLine, prefix: 'data:'));
      }
    }

    final trailing = flush();
    if (trailing != null) {
      yield trailing;
    }
  }

  Map<String, dynamic> _parseSsePayload(List<String> dataLines) {
    if (dataLines.isEmpty) {
      return const <String, dynamic>{};
    }

    final joined = dataLines.join('\n').trim();
    if (joined.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(joined);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return <String, dynamic>{'value': decoded};
    } catch (_) {
      return <String, dynamic>{'raw': joined};
    }
  }

  String _sseFieldValue(String line, {required String prefix}) {
    final value = line.substring(prefix.length);
    return value.startsWith(' ') ? value.substring(1) : value;
  }

  Uri _buildUri(String path, {Map<String, dynamic>? queryParameters}) {
    final sanitizedBase = appConfig.api.baseUrl.endsWith('/')
        ? appConfig.api.baseUrl.substring(0, appConfig.api.baseUrl.length - 1)
        : appConfig.api.baseUrl;
    final sanitizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$sanitizedBase/$sanitizedPath');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final normalizedQuery = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value == null) {
        return;
      }
      normalizedQuery[key] = value.toString();
    });

    return uri.replace(queryParameters: normalizedQuery);
  }

  Future<String?> _refreshAccessToken() async {
    final session = parseAuthSession(cookieStore.getCookie('auth'));
    if (session == null || session.refreshToken.isEmpty) {
      cookieStore.removeCookie('auth', '/');
      return null;
    }

    final response = await _httpClient.post(
      _buildUri(appConfig.api.endpoints.authRefresh),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{'RefreshToken': session.refreshToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      cookieStore.removeCookie('auth', '/');
      return null;
    }

    cookieStore.removeCookie('auth', '/');
    cookieStore.setCookie('auth', response.body, 60 * 60 * 24 * 7, '/');

    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['access_token'] == null) {
        cookieStore.removeCookie('auth', '/');
        return null;
      }

      final accessToken = payload['access_token'].toString().trim();
      if (accessToken.isEmpty) {
        cookieStore.removeCookie('auth', '/');
        return null;
      }

      return accessToken;
    } catch (_) {
      cookieStore.removeCookie('auth', '/');
      return null;
    }
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
