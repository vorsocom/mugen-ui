import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_attachment_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_part_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_media_download_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_send_accepted_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_sse_event_entity.dart';
import 'package:mugen_ui/features/chat/domain/repositories/chat_repository.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/auth/auth_cookie_codec.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

class WebChatRepositoryImpl implements ChatRepository {
  WebChatRepositoryImpl({
    required this.appConfig,
    required this.cookieStore,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final AppConfig appConfig;
  final CookieStore cookieStore;
  final http.Client _httpClient;

  @override
  Future<Result<ChatSendAcceptedEntity>> sendText({
    required String conversationId,
    required String clientMessageId,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    if (conversationId.trim().isEmpty) {
      return const Result<ChatSendAcceptedEntity>.failure(
        ValidationFailure('Conversation ID is required.'),
      );
    }

    if (text.trim().isEmpty) {
      return const Result<ChatSendAcceptedEntity>.failure(
        ValidationFailure('Message text is required.'),
      );
    }

    final response = await _sendMultipartWithAuth(
      buildRequest: (token) {
        return _buildMultipartRequest(
          token: token,
          conversationId: conversationId,
          clientMessageId: clientMessageId,
          messageType: 'text',
          text: text,
          metadata: metadata,
        );
      },
    );
    if (response.isFailure) {
      return Result<ChatSendAcceptedEntity>.failure(response.failure!);
    }

    final payload = _parseSendAcceptedPayload(response.data!);
    if (payload == null) {
      return const Result<ChatSendAcceptedEntity>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<ChatSendAcceptedEntity>.success(payload);
  }

  @override
  Future<Result<ChatSendAcceptedEntity>> sendUpload({
    required String conversationId,
    required String clientMessageId,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
    String? text,
    Map<String, dynamic>? metadata,
  }) async {
    if (conversationId.trim().isEmpty) {
      return const Result<ChatSendAcceptedEntity>.failure(
        ValidationFailure('Conversation ID is required.'),
      );
    }

    if (filename.trim().isEmpty) {
      return const Result<ChatSendAcceptedEntity>.failure(
        ValidationFailure('Filename is required.'),
      );
    }

    if (bytes.isEmpty) {
      return const Result<ChatSendAcceptedEntity>.failure(
        ValidationFailure('File bytes are required.'),
      );
    }

    final response = await _sendMultipartWithAuth(
      buildRequest: (token) {
        return _buildMultipartRequest(
          token: token,
          conversationId: conversationId,
          clientMessageId: clientMessageId,
          messageType: _messageTypeFromMimeType(mimeType),
          text: text,
          metadata: metadata,
          filename: filename,
          mimeType: mimeType,
          bytes: bytes,
        );
      },
    );
    if (response.isFailure) {
      return Result<ChatSendAcceptedEntity>.failure(response.failure!);
    }

    final payload = _parseSendAcceptedPayload(response.data!);
    if (payload == null) {
      return const Result<ChatSendAcceptedEntity>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<ChatSendAcceptedEntity>.success(payload);
  }

  @override
  Future<Result<ChatSendAcceptedEntity>> sendComposed({
    required String conversationId,
    required String clientMessageId,
    required ChatCompositionMode compositionMode,
    required List<ChatComposedPartEntity> parts,
    required List<ChatComposedAttachmentEntity> attachments,
    Map<String, dynamic>? metadata,
  }) async {
    if (conversationId.trim().isEmpty) {
      return const Result<ChatSendAcceptedEntity>.failure(
        ValidationFailure('Conversation ID is required.'),
      );
    }

    if (parts.isEmpty) {
      return const Result<ChatSendAcceptedEntity>.failure(
        ValidationFailure('At least one composed part is required.'),
      );
    }

    if (attachments.isEmpty) {
      return const Result<ChatSendAcceptedEntity>.failure(
        ValidationFailure('At least one attachment is required.'),
      );
    }

    final response = await _sendMultipartWithAuth(
      buildRequest: (token) {
        return _buildComposedMultipartRequest(
          token: token,
          conversationId: conversationId,
          clientMessageId: clientMessageId,
          compositionMode: compositionMode,
          parts: parts,
          attachments: attachments,
          metadata: metadata,
        );
      },
    );
    if (response.isFailure) {
      return Result<ChatSendAcceptedEntity>.failure(response.failure!);
    }

    final payload = _parseSendAcceptedPayload(response.data!);
    if (payload == null) {
      return const Result<ChatSendAcceptedEntity>.failure(
        UnexpectedFailure('Unexpected API response.'),
      );
    }

    return Result<ChatSendAcceptedEntity>.success(payload);
  }

  @override
  Stream<Result<ChatSseEventEntity>> streamEvents({
    required String conversationId,
    String? lastEventId,
  }) async* {
    if (conversationId.trim().isEmpty) {
      yield const Result<ChatSseEventEntity>.failure(
        ValidationFailure('Conversation ID is required.'),
      );
      return;
    }

    final streamOpenResult = await _openSseStream(
      conversationId: conversationId,
      lastEventId: lastEventId,
    );
    if (streamOpenResult.isFailure) {
      yield Result<ChatSseEventEntity>.failure(streamOpenResult.failure!);
      return;
    }

    final response = streamOpenResult.data!;
    try {
      await for (final event in _parseSseEvents(response.stream)) {
        yield Result<ChatSseEventEntity>.success(event);
      }
    } catch (_) {
      yield const Result<ChatSseEventEntity>.failure(
        NetworkFailure('Event stream disconnected.'),
      );
    }
  }

  @override
  Future<Result<ChatMediaDownloadEntity>> downloadMedia({
    required String mediaUrl,
    String? suggestedFilename,
    String? suggestedMimeType,
  }) async {
    if (mediaUrl.trim().isEmpty) {
      return const Result<ChatMediaDownloadEntity>.failure(
        ValidationFailure('Media URL is required.'),
      );
    }

    final session = _currentSession();
    if (session == null) {
      return const Result<ChatMediaDownloadEntity>.failure(
        SessionExpiredFailure(),
      );
    }

    Future<http.Response> send(String token) {
      return _httpClient.get(
        _resolveMediaUri(mediaUrl),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Accept': '*/*',
        },
      );
    }

    var response = await send(session.accessToken);
    if (response.statusCode == 401) {
      final refreshedAccessToken = await _refreshAccessToken();
      if (refreshedAccessToken == null) {
        return const Result<ChatMediaDownloadEntity>.failure(
          SessionExpiredFailure(),
        );
      }

      response = await send(refreshedAccessToken);
    }

    if (response.statusCode == 401) {
      cookieStore.removeCookie('auth', '/');
      return const Result<ChatMediaDownloadEntity>.failure(
        SessionExpiredFailure(),
      );
    }

    if (response.statusCode == 404) {
      return const Result<ChatMediaDownloadEntity>.failure(
        ApiFailure(404, 'Media is unavailable or expired.'),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Result<ChatMediaDownloadEntity>.failure(
        ApiFailure(
          response.statusCode,
          _extractApiMessage(response.body, statusCode: response.statusCode),
        ),
      );
    }

    final mimeType =
        suggestedMimeType ?? _sanitizeHeader(response.headers['content-type']);
    final filename =
        suggestedFilename ??
        _extractFilenameFromContentDisposition(
          response.headers['content-disposition'],
        ) ??
        'download';

    return Result<ChatMediaDownloadEntity>.success(
      ChatMediaDownloadEntity(
        bytes: response.bodyBytes,
        mimeType: mimeType,
        filename: filename,
      ),
    );
  }

  Future<Result<_MultipartResponsePayload>> _sendMultipartWithAuth({
    required http.MultipartRequest Function(String token) buildRequest,
  }) async {
    final session = _currentSession();
    if (session == null) {
      return const Result<_MultipartResponsePayload>.failure(
        SessionExpiredFailure(),
      );
    }

    Future<_MultipartResponsePayload> send(String token) async {
      final request = buildRequest(token);
      final response = await _httpClient.send(request);
      final body = await response.stream.bytesToString();
      return _MultipartResponsePayload(
        statusCode: response.statusCode,
        headers: response.headers,
        body: body,
      );
    }

    var response = await send(session.accessToken);
    if (response.statusCode == 401) {
      final refreshedAccessToken = await _refreshAccessToken();
      if (refreshedAccessToken == null) {
        return const Result<_MultipartResponsePayload>.failure(
          SessionExpiredFailure(),
        );
      }

      response = await send(refreshedAccessToken);
    }

    if (response.statusCode == 401) {
      cookieStore.removeCookie('auth', '/');
      return const Result<_MultipartResponsePayload>.failure(
        SessionExpiredFailure(),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Result<_MultipartResponsePayload>.failure(
        ApiFailure(
          response.statusCode,
          _extractApiMessage(response.body, statusCode: response.statusCode),
        ),
      );
    }

    return Result<_MultipartResponsePayload>.success(response);
  }

  http.MultipartRequest _buildMultipartRequest({
    required String token,
    required String conversationId,
    required String clientMessageId,
    required String messageType,
    String? text,
    Map<String, dynamic>? metadata,
    String? filename,
    String? mimeType,
    Uint8List? bytes,
  }) {
    final request = http.MultipartRequest(
      'POST',
      _buildUri(appConfig.api.endpoints.webMessages),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['conversation_id'] = conversationId;
    request.fields['message_type'] = messageType;
    request.fields['client_message_id'] = clientMessageId;
    if (text != null && text.trim().isNotEmpty) {
      request.fields['text'] = text;
    }
    if (metadata != null && metadata.isNotEmpty) {
      request.fields['metadata'] = jsonEncode(metadata);
    }

    if (bytes != null) {
      final contentType = _parseMediaType(mimeType);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      );
    }

    return request;
  }

  http.MultipartRequest _buildComposedMultipartRequest({
    required String token,
    required String conversationId,
    required String clientMessageId,
    required ChatCompositionMode compositionMode,
    required List<ChatComposedPartEntity> parts,
    required List<ChatComposedAttachmentEntity> attachments,
    Map<String, dynamic>? metadata,
  }) {
    final request = http.MultipartRequest(
      'POST',
      _buildUri(appConfig.api.endpoints.webMessages),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['conversation_id'] = conversationId;
    request.fields['client_message_id'] = clientMessageId;
    request.fields['composition_mode'] = compositionMode.wireValue;
    request.fields['parts'] = jsonEncode(
      parts
          .map((part) => part.toJson(compositionMode: compositionMode))
          .toList(growable: false),
    );
    if (metadata != null && metadata.isNotEmpty) {
      request.fields['metadata'] = jsonEncode(metadata);
    }

    for (final attachment in attachments) {
      final contentType = _parseMediaType(attachment.mimeType);
      request.files.add(
        http.MultipartFile.fromBytes(
          'files[${attachment.id}]',
          attachment.bytes,
          filename: attachment.filename,
          contentType: contentType,
        ),
      );
    }

    return request;
  }

  Future<Result<http.StreamedResponse>> _openSseStream({
    required String conversationId,
    String? lastEventId,
  }) async {
    final session = _currentSession();
    if (session == null) {
      return const Result<http.StreamedResponse>.failure(
        SessionExpiredFailure(),
      );
    }

    Future<http.StreamedResponse> send(String token) {
      final query = <String, dynamic>{'conversation_id': conversationId};
      final normalizedLastEventId = lastEventId?.trim();
      if (normalizedLastEventId != null && normalizedLastEventId.isNotEmpty) {
        query['last_event_id'] = normalizedLastEventId;
      }

      final request = http.Request(
        'GET',
        _buildUri(appConfig.api.endpoints.webEvents, queryParameters: query),
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
        ApiFailure(
          response.statusCode,
          _extractApiMessage(payload, statusCode: response.statusCode),
        ),
      );
    }

    return Result<http.StreamedResponse>.success(response);
  }

  Stream<ChatSseEventEntity> _parseSseEvents(
    Stream<List<int>> byteStream,
  ) async* {
    String? eventId;
    String eventName = 'message';
    final dataLines = <String>[];

    Future<ChatSseEventEntity?> flush() async {
      if (eventId == null && dataLines.isEmpty && eventName == 'message') {
        return null;
      }

      final payload = _parseSsePayload(dataLines);
      final parsed = ChatSseEventEntity(
        id: eventId,
        event: eventName,
        data: payload,
      );

      eventId = null;
      eventName = 'message';
      dataLines.clear();
      return parsed;
    }

    final lines = byteStream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final rawLine in lines) {
      if (rawLine.isEmpty) {
        final event = await flush();
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

    final trailing = await flush();
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

  ChatSendAcceptedEntity? _parseSendAcceptedPayload(
    _MultipartResponsePayload payload,
  ) {
    try {
      final decoded = jsonDecode(payload.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final jobId = decoded['job_id']?.toString();
      final conversationId = decoded['conversation_id']?.toString();
      if (jobId == null ||
          jobId.trim().isEmpty ||
          conversationId == null ||
          conversationId.trim().isEmpty) {
        return null;
      }

      final acceptedAt = decoded['accepted_at']?.toString();
      final parsedAcceptedAt = acceptedAt == null
          ? null
          : DateTime.tryParse(acceptedAt)?.toUtc();

      return ChatSendAcceptedEntity(
        jobId: jobId,
        conversationId: conversationId,
        acceptedAt: parsedAcceptedAt ?? DateTime.now().toUtc(),
      );
    } catch (_) {
      return null;
    }
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

  Uri _resolveMediaUri(String mediaUrl) {
    final raw = mediaUrl.trim();
    final parsed = Uri.parse(raw);
    if (parsed.hasScheme) {
      return parsed;
    }

    final base = Uri.parse(appConfig.api.baseUrl);
    if (raw.startsWith('/')) {
      return Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: parsed.path,
        query: parsed.hasQuery ? parsed.query : null,
      );
    }

    return _buildUri(raw);
  }

  String _messageTypeFromMimeType(String mimeType) {
    final normalized = mimeType.toLowerCase().trim();
    if (normalized.startsWith('image/')) {
      return 'image';
    }

    if (normalized.startsWith('audio/')) {
      return 'audio';
    }

    if (normalized.startsWith('video/')) {
      return 'video';
    }

    return 'file';
  }

  MediaType? _parseMediaType(String? mimeType) {
    final normalized = mimeType?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    try {
      return MediaType.parse(normalized);
    } catch (_) {
      return null;
    }
  }

  String _extractApiMessage(String body, {required int statusCode}) {
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty) {
      return 'API error.';
    }

    try {
      final decoded = jsonDecode(normalizedBody);
      if (decoded is Map<String, dynamic>) {
        final candidates = <Object?>[
          decoded['message'],
          decoded['error'],
          decoded['detail'],
          decoded['description'],
        ];
        for (final candidate in candidates) {
          final normalized = candidate?.toString().trim();
          if (normalized != null && normalized.isNotEmpty) {
            return normalized;
          }
        }
      }
    } catch (_) {
      // Fall through to readable HTML extraction or the raw body.
    }

    final htmlMessage = _extractHtmlMessage(
      normalizedBody,
      statusCode: statusCode,
    );
    if (htmlMessage != null) {
      return htmlMessage;
    }

    return normalizedBody;
  }

  String? _extractHtmlMessage(String body, {required int statusCode}) {
    final lowerBody = body.toLowerCase();
    final looksLikeHtml =
        lowerBody.contains('<!doctype html') ||
        lowerBody.contains('<html') ||
        RegExp(r'<[a-z][^>]*>', caseSensitive: false).hasMatch(body);
    if (!looksLikeHtml) {
      return null;
    }

    final title = _firstHtmlElementText(body, 'title');
    final heading = _firstHtmlElementText(body, 'h1');
    final paragraphs =
        RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true)
            .allMatches(body)
            .map((match) => _normalizeHtmlText(match.group(1) ?? ''))
            .where((value) => value.isNotEmpty)
            .toList(growable: false);

    final prefix = title ?? heading ?? '$statusCode HTTP error';
    final details = <String>[
      if (heading != null &&
          !prefix.toLowerCase().contains(heading.toLowerCase()))
        heading,
      ...paragraphs,
    ];

    if (details.isNotEmpty) {
      return '$prefix: ${details.join(' ')}';
    }
    return prefix;
  }

  String? _firstHtmlElementText(String body, String tagName) {
    final match = RegExp(
      '<$tagName[^>]*>(.*?)</$tagName>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body);
    if (match == null) {
      return null;
    }

    final normalized = _normalizeHtmlText(match.group(1) ?? '');
    return normalized.isEmpty ? null : normalized;
  }

  String _normalizeHtmlText(String value) {
    return _decodeHtmlEntities(
      value.replaceAll(RegExp(r'<[^>]+>'), ' '),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAllMapped(RegExp(r'&#(x?[0-9A-Fa-f]+);'), (match) {
          final raw = match.group(1)!;
          final radix = raw.toLowerCase().startsWith('x') ? 16 : 10;
          final digits = radix == 16 ? raw.substring(1) : raw;
          final codePoint = int.parse(digits, radix: radix);
          return String.fromCharCode(codePoint);
        })
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ');
  }

  String? _extractFilenameFromContentDisposition(String? headerValue) {
    if (headerValue == null || headerValue.trim().isEmpty) {
      return null;
    }

    final normalized = headerValue.trim();
    const token = 'filename=';
    final index = normalized.toLowerCase().indexOf(token);
    if (index < 0) {
      return null;
    }

    var value = normalized.substring(index + token.length).trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  String? _sanitizeHeader(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String _sseFieldValue(String line, {required String prefix}) {
    final value = line.substring(prefix.length);
    return value.startsWith(' ') ? value.substring(1) : value;
  }

  Future<String?> _refreshAccessToken() async {
    final session = _currentSession();
    if (session == null || session.refreshToken.isEmpty) {
      cookieStore.removeCookie('auth', '/'); // coverage:ignore-line
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

  AuthSession? _currentSession() {
    return parseAuthSession(cookieStore.getCookie('auth'));
  }
}

class _MultipartResponsePayload {
  const _MultipartResponsePayload({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}
