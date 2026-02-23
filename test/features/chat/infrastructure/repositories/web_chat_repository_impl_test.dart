import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_attachment_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_part_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/infrastructure/repositories/web_chat_repository_impl.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';

void main() {
  test(
    'sendText retries once after 401 and submits multipart fields',
    () async {
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'old-token',
          'refresh_token': 'refresh-token',
          'user_id': 'u1',
        }),
        60,
        '/',
      );

      final client = _QueueHttpClient(
        <http.StreamedResponse Function(http.BaseRequest)>[
          (_) => _streamedResponse(statusCode: 401),
          (_) => _streamedResponse(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'access_token': 'new-token',
              'refresh_token': 'new-refresh',
              'user_id': 'u1',
            }),
            headers: const <String, String>{'content-type': 'application/json'},
          ),
          (_) => _streamedResponse(
            statusCode: 202,
            body: jsonEncode(<String, dynamic>{
              'job_id': 'job-1',
              'conversation_id': 'conv-1',
              'accepted_at': '2026-01-01T00:00:00Z',
            }),
          ),
        ],
      );

      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: cookieStore,
        httpClient: client,
      );

      final result = await repository.sendText(
        conversationId: 'conv-1',
        clientMessageId: 'client-1',
        text: 'hello',
      );

      expect(result.isSuccess, isTrue);
      expect(client.requests.length, 3);
      final first = client.requests[0] as http.MultipartRequest;
      final third = client.requests[2] as http.MultipartRequest;
      expect(first.headers['Authorization'], 'Bearer old-token');
      expect(third.headers['Authorization'], 'Bearer new-token');
      expect(first.url.path, '/api/core/web/v1/messages');
      expect(first.fields['conversation_id'], 'conv-1');
      expect(first.fields['message_type'], 'text');
      expect(first.fields['client_message_id'], 'client-1');
      expect(first.fields['text'], 'hello');
    },
  );

  test('sendUpload maps image MIME to message_type=image', () async {
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-1',
        'refresh_token': 'refresh-1',
        'user_id': 'u1',
      }),
      60,
      '/',
    );

    final client = _QueueHttpClient(
      <http.StreamedResponse Function(http.BaseRequest)>[
        (_) => _streamedResponse(
          statusCode: 202,
          body: jsonEncode(<String, dynamic>{
            'job_id': 'job-2',
            'conversation_id': 'conv-2',
            'accepted_at': '2026-01-01T00:00:00Z',
          }),
        ),
      ],
    );

    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    final result = await repository.sendUpload(
      conversationId: 'conv-2',
      clientMessageId: 'client-2',
      filename: 'photo.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );

    expect(result.isSuccess, isTrue);
    final request = client.requests.single as http.MultipartRequest;
    expect(request.fields['message_type'], 'image');
    expect(request.files.length, 1);
    expect(request.files.first.filename, 'photo.png');
  });

  test(
    'sendComposed submits structured multipart fields and files by attachment id',
    () async {
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'token-structured',
          'refresh_token': 'refresh-structured',
          'user_id': 'u1',
        }),
        60,
        '/',
      );

      final client = _QueueHttpClient(
        <http.StreamedResponse Function(http.BaseRequest)>[
          (_) => _streamedResponse(
            statusCode: 202,
            body: jsonEncode(<String, dynamic>{
              'job_id': 'job-structured',
              'conversation_id': 'conv-structured',
              'accepted_at': '2026-01-01T00:00:00Z',
            }),
          ),
        ],
      );

      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: cookieStore,
        httpClient: client,
      );

      final result = await repository.sendComposed(
        conversationId: 'conv-structured',
        clientMessageId: 'client-structured',
        compositionMode: ChatCompositionMode.messageWithAttachments,
        parts: <ChatComposedPartEntity>[
          const ChatComposedPartEntity.text(text: 'hello'),
          const ChatComposedPartEntity.attachment(
            attachmentId: 'att-1',
            caption: 'first',
          ),
        ],
        attachments: <ChatComposedAttachmentEntity>[
          ChatComposedAttachmentEntity(
            id: 'att-1',
            filename: 'img.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
            caption: 'first',
          ),
        ],
      );

      expect(result.isSuccess, isTrue);
      final request = client.requests.single as http.MultipartRequest;
      expect(request.fields['conversation_id'], 'conv-structured');
      expect(request.fields['client_message_id'], 'client-structured');
      expect(
        request.fields['composition_mode'],
        ChatCompositionMode.messageWithAttachments.wireValue,
      );

      final parts = jsonDecode(request.fields['parts']!) as List<dynamic>;
      expect(parts, hasLength(2));
      expect(parts[0], containsPair('type', 'text'));
      expect(parts[0], containsPair('text', 'hello'));
      expect(parts[1], containsPair('type', 'attachment'));
      expect(parts[1], containsPair('id', 'att-1'));
      expect(parts[1], containsPair('caption', 'first'));

      expect(request.fields.containsKey('message_type'), isFalse);
      expect(request.fields.containsKey('text'), isFalse);

      expect(request.files.length, 1);
      expect(request.files.first.field, 'files[att-1]');
      expect(request.files.first.filename, 'img.png');
    },
  );

  test(
    'sendComposed retries once after 401 and refreshes bearer token',
    () async {
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'old-token',
          'refresh_token': 'refresh-token',
          'user_id': 'u1',
        }),
        60,
        '/',
      );

      final client = _QueueHttpClient(
        <http.StreamedResponse Function(http.BaseRequest)>[
          (_) => _streamedResponse(statusCode: 401),
          (_) => _streamedResponse(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'access_token': 'new-token',
              'refresh_token': 'new-refresh',
              'user_id': 'u1',
            }),
            headers: const <String, String>{'content-type': 'application/json'},
          ),
          (_) => _streamedResponse(
            statusCode: 202,
            body: jsonEncode(<String, dynamic>{
              'job_id': 'job-composed-2',
              'conversation_id': 'conv-composed-2',
              'accepted_at': '2026-01-01T00:00:00Z',
            }),
          ),
        ],
      );

      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: cookieStore,
        httpClient: client,
      );

      final result = await repository.sendComposed(
        conversationId: 'conv-composed-2',
        clientMessageId: 'client-composed-2',
        compositionMode: ChatCompositionMode.attachmentWithCaption,
        parts: <ChatComposedPartEntity>[
          const ChatComposedPartEntity.attachment(
            attachmentId: 'att-2',
            caption: 'required caption',
          ),
        ],
        attachments: <ChatComposedAttachmentEntity>[
          ChatComposedAttachmentEntity(
            id: 'att-2',
            filename: 'doc.txt',
            mimeType: 'text/plain',
            bytes: Uint8List.fromList(<int>[8, 9, 10]),
            caption: 'required caption',
          ),
        ],
      );

      expect(result.isSuccess, isTrue);
      expect(client.requests.length, 3);
      final first = client.requests[0] as http.MultipartRequest;
      final third = client.requests[2] as http.MultipartRequest;
      expect(first.headers['Authorization'], 'Bearer old-token');
      expect(third.headers['Authorization'], 'Bearer new-token');
    },
  );

  test(
    'streamEvents parses SSE and passes last_event_id header/query',
    () async {
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'token-1',
          'refresh_token': 'refresh-1',
          'user_id': 'u1',
        }),
        60,
        '/',
      );

      const payload = '''
id: 6
event: ack
data: {"job_id":"job-6"}

: ping

id: 7
event: message
data: {"message":{"type":"text",
data: "content":"hello"}}

''';

      final client = _QueueHttpClient(
        <http.StreamedResponse Function(http.BaseRequest)>[
          (_) => _streamedResponse(statusCode: 200, body: payload),
        ],
      );

      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: cookieStore,
        httpClient: client,
      );

      final results = await repository
          .streamEvents(conversationId: 'conv-stream', lastEventId: '5')
          .toList();

      expect(results.length, 2);
      expect(results[0].data?.event, 'ack');
      expect(results[0].data?.id, '6');
      expect(results[0].data?.data['job_id'], 'job-6');
      expect(results[1].data?.event, 'message');
      expect(
        (results[1].data?.data['message'] as Map<String, dynamic>)['content'],
        'hello',
      );

      final request = client.requests.single as http.Request;
      expect(request.headers['Last-Event-ID'], '5');
      expect(request.url.path, '/api/core/web/v1/events');
      expect(request.url.queryParameters['conversation_id'], 'conv-stream');
      expect(request.url.queryParameters['last_event_id'], '5');
    },
  );

  test('downloadMedia returns 404 failure for expired token', () async {
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-1',
        'refresh_token': 'refresh-1',
        'user_id': 'u1',
      }),
      60,
      '/',
    );

    final client = _QueueHttpClient(
      <http.StreamedResponse Function(http.BaseRequest)>[
        (_) => _streamedResponse(statusCode: 404),
      ],
    );

    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    final result = await repository.downloadMedia(
      mediaUrl: '/api/core/web/v1/media/missing',
    );

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<ApiFailure>());
    final failure = result.failure as ApiFailure;
    expect(failure.statusCode, 404);
  });
}

class _QueueHttpClient extends http.BaseClient {
  _QueueHttpClient(this._responders);

  final List<http.StreamedResponse Function(http.BaseRequest request)>
  _responders;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (_responders.isEmpty) {
      throw StateError(
        'No queued response for request: ${request.method} ${request.url}',
      );
    }
    return _responders.removeAt(0)(request);
  }
}

http.StreamedResponse _streamedResponse({
  required int statusCode,
  String body = '',
  Map<String, String> headers = const <String, String>{},
}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(body)),
    statusCode,
    headers: headers,
  );
}
