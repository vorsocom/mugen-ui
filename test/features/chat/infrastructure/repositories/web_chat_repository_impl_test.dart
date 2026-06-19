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
    'default constructor initializes internal http client and fails fast without auth',
    () async {
      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: createCookieStore(),
      );

      final result = await repository.sendText(
        conversationId: 'conv-default',
        clientMessageId: 'client-default',
        text: 'hello',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<SessionExpiredFailure>());
    },
  );

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

  test('send APIs fail fast when auth session is missing', () async {
    final cookieStore = createCookieStore();
    final client = _QueueHttpClient(
      <http.StreamedResponse Function(http.BaseRequest)>[],
    );
    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    final sendText = await repository.sendText(
      conversationId: 'conv-auth',
      clientMessageId: 'client-auth',
      text: 'hello',
    );
    final sendUpload = await repository.sendUpload(
      conversationId: 'conv-auth',
      clientMessageId: 'client-auth',
      filename: 'file.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(<int>[1]),
    );
    final sendComposed = await repository.sendComposed(
      conversationId: 'conv-auth',
      clientMessageId: 'client-auth',
      compositionMode: ChatCompositionMode.attachmentWithCaption,
      parts: const <ChatComposedPartEntity>[
        ChatComposedPartEntity.attachment(
          attachmentId: 'att-1',
          caption: 'caption',
        ),
      ],
      attachments: <ChatComposedAttachmentEntity>[
        ChatComposedAttachmentEntity(
          id: 'att-1',
          filename: 'doc.txt',
          mimeType: 'text/plain',
          bytes: Uint8List.fromList(<int>[1, 2]),
        ),
      ],
    );

    expect(sendText.failure, isA<SessionExpiredFailure>());
    expect(sendUpload.failure, isA<SessionExpiredFailure>());
    expect(sendComposed.failure, isA<SessionExpiredFailure>());
    expect(client.requests, isEmpty);
  });

  test(
    'sendText persists metadata and accepts missing accepted_at in response',
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

      final client = _QueueHttpClient(
        <http.StreamedResponse Function(http.BaseRequest)>[
          (_) => _streamedResponse(
            statusCode: 202,
            body: jsonEncode(<String, dynamic>{
              'job_id': 'job-no-accepted-at',
              'conversation_id': 'conv-no-accepted-at',
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
        conversationId: 'conv-meta',
        clientMessageId: 'client-meta',
        text: 'hello meta',
        metadata: const <String, dynamic>{'channel': 'ci'},
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.acceptedAt, isNotNull);
      final request = client.requests.single as http.MultipartRequest;
      expect(request.fields['metadata'], '{"channel":"ci"}');
    },
  );

  test('sendUpload maps audio/video MIME types correctly', () async {
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-av',
        'refresh_token': 'refresh-av',
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
            'job_id': 'job-audio',
            'conversation_id': 'conv-audio',
          }),
        ),
        (_) => _streamedResponse(
          statusCode: 202,
          body: jsonEncode(<String, dynamic>{
            'job_id': 'job-video',
            'conversation_id': 'conv-video',
          }),
        ),
      ],
    );
    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    await repository.sendUpload(
      conversationId: 'conv-audio',
      clientMessageId: 'client-audio',
      filename: 'sound.wav',
      mimeType: 'audio/wav',
      bytes: Uint8List.fromList(<int>[1]),
    );
    await repository.sendUpload(
      conversationId: 'conv-video',
      clientMessageId: 'client-video',
      filename: 'clip.mp4',
      mimeType: 'video/mp4',
      bytes: Uint8List.fromList(<int>[2]),
    );

    expect(
      (client.requests[0] as http.MultipartRequest).fields['message_type'],
      'audio',
    );
    expect(
      (client.requests[1] as http.MultipartRequest).fields['message_type'],
      'video',
    );
  });

  test('sendComposed includes metadata payload when provided', () async {
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-composed-meta',
        'refresh_token': 'refresh-composed-meta',
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
            'job_id': 'job-composed-meta',
            'conversation_id': 'conv-composed-meta',
          }),
        ),
      ],
    );
    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    await repository.sendComposed(
      conversationId: 'conv-composed-meta',
      clientMessageId: 'client-composed-meta',
      compositionMode: ChatCompositionMode.attachmentWithCaption,
      parts: const <ChatComposedPartEntity>[
        ChatComposedPartEntity.attachment(
          attachmentId: 'att-1',
          caption: 'caption',
        ),
      ],
      attachments: <ChatComposedAttachmentEntity>[
        ChatComposedAttachmentEntity(
          id: 'att-1',
          filename: 'doc.txt',
          mimeType: 'text/plain',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      ],
      metadata: const <String, dynamic>{'origin': 'test'},
    );

    final request = client.requests.single as http.MultipartRequest;
    expect(request.fields['metadata'], '{"origin":"test"}');
  });

  test('sendText maps non-2xx responses into API failures', () async {
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-api-fail',
        'refresh_token': 'refresh-api-fail',
        'user_id': 'u1',
      }),
      60,
      '/',
    );
    final client = _QueueHttpClient(
      <http.StreamedResponse Function(http.BaseRequest)>[
        (_) => _streamedResponse(statusCode: 500, body: 'raw backend error'),
      ],
    );
    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    final result = await repository.sendText(
      conversationId: 'conv-api-fail',
      clientMessageId: 'client-api-fail',
      text: 'hello',
    );

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<ApiFailure>());
    final failure = result.failure as ApiFailure;
    expect(failure.statusCode, 500);
    expect(failure.message, 'raw backend error');
  });

  test('sendText extracts readable messages from HTML API failures', () async {
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-html-fail',
        'refresh_token': 'refresh-html-fail',
        'user_id': 'u1',
      }),
      60,
      '/',
    );
    final client =
        _QueueHttpClient(<http.StreamedResponse Function(http.BaseRequest)>[
          (_) => _streamedResponse(
            statusCode: 403,
            body: '''
<!doctype html>
<html lang=en>
<title>403 Forbidden</title>
<h1>Forbidden</h1>
<p>You don&#39;t have the permission to access the requested resource.</p>
''',
          ),
        ]);
    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    final result = await repository.sendText(
      conversationId: 'conv-html-fail',
      clientMessageId: 'client-html-fail',
      text: 'hello',
    );

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<ApiFailure>());
    final failure = result.failure as ApiFailure;
    expect(failure.statusCode, 403);
    expect(
      failure.message,
      "403 Forbidden: You don't have the permission to access the requested resource.",
    );
  });

  test('sendText normalizes alternate HTML API failure shapes', () async {
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-html-shapes',
        'refresh_token': 'refresh-html-shapes',
        'user_id': 'u1',
      }),
      60,
      '/',
    );
    final client = _QueueHttpClient(<
      http.StreamedResponse Function(http.BaseRequest)
    >[
      (_) => _streamedResponse(
        statusCode: 403,
        body: '''
<html>
<title>Access denied</title>
<h1>Missing grant</h1>
<p>Request blocked.</p>
''',
      ),
      (_) => _streamedResponse(
        statusCode: 502,
        body: '<section><p>Gateway returned &quot;blocked&quot;.</p></section>',
      ),
    ]);
    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    final titledResult = await repository.sendText(
      conversationId: 'conv-html-title',
      clientMessageId: 'client-html-title',
      text: 'hello',
    );
    final fallbackResult = await repository.sendText(
      conversationId: 'conv-html-fallback',
      clientMessageId: 'client-html-fallback',
      text: 'hello again',
    );

    expect(titledResult.isFailure, isTrue);
    expect(
      (titledResult.failure as ApiFailure).message,
      'Access denied: Missing grant Request blocked.',
    );
    expect(fallbackResult.isFailure, isTrue);
    expect(
      (fallbackResult.failure as ApiFailure).message,
      '502 HTTP error: Gateway returned "blocked".',
    );
  });

  test(
    'sendText returns API failure after a second 401 even after refresh',
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
          (_) => _streamedResponse(statusCode: 401),
        ],
      );
      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: cookieStore,
        httpClient: client,
      );

      final result = await repository.sendText(
        conversationId: 'conv-2x401',
        clientMessageId: 'client-2x401',
        text: 'retry me',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<SessionExpiredFailure>());
    },
  );

  test(
    'downloadMedia retries on 401 and resolves MIME/filename from headers',
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
            statusCode: 200,
            body: 'abc',
            headers: const <String, String>{
              'content-type': 'text/plain',
              'content-disposition': 'attachment; filename="notes.txt"',
            },
          ),
        ],
      );
      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: cookieStore,
        httpClient: client,
      );

      final result = await repository.downloadMedia(
        mediaUrl: '/api/core/web/v1/media/notes',
      );
      expect(result.isSuccess, isTrue);
      expect(result.data?.mimeType, 'text/plain');
      expect(result.data?.filename, 'notes.txt');

      final first = client.requests[0] as http.Request;
      final third = client.requests[2] as http.Request;
      expect(first.headers['Authorization'], 'Bearer old-token');
      expect(third.headers['Authorization'], 'Bearer new-token');
    },
  );

  test(
    'downloadMedia surfaces non-404 API failures with parsed response message',
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

      final client = _QueueHttpClient(
        <http.StreamedResponse Function(http.BaseRequest)>[
          (_) => _streamedResponse(
            statusCode: 500,
            body: jsonEncode(<String, dynamic>{'detail': 'backend down'}),
          ),
        ],
      );
      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: cookieStore,
        httpClient: client,
      );

      final result = await repository.downloadMedia(
        mediaUrl: '/api/core/web/v1/media/error',
      );
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ApiFailure>());
      final failure = result.failure as ApiFailure;
      expect(failure.statusCode, 500);
      expect(failure.message, 'backend down');
    },
  );

  test(
    'relative media URLs use buildUri path resolution for base URLs ending with slash',
    () async {
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'token-rel',
          'refresh_token': 'refresh-rel',
          'user_id': 'u1',
        }),
        60,
        '/',
      );
      final client = _QueueHttpClient(
        <http.StreamedResponse Function(http.BaseRequest)>[
          (_) => _streamedResponse(statusCode: 200, body: 'ok'),
        ],
      );
      final appConfig = AppConfig.defaults().merge(
        const AppConfigurationOverride(
          api: ApiConfigOverride(baseUrl: 'https://example.test/api/'),
        ),
      );
      final repository = WebChatRepositoryImpl(
        appConfig: appConfig,
        cookieStore: cookieStore,
        httpClient: client,
      );

      final result = await repository.downloadMedia(
        mediaUrl: 'core/web/v1/media/relative?id=1',
        suggestedFilename: 'f.txt',
        suggestedMimeType: 'text/plain',
      );
      expect(result.isSuccess, isTrue);
      final request = client.requests.single as http.Request;
      expect(
        request.url.toString(),
        'https://example.test/api/core/web/v1/media/relative?id=1',
      );
    },
  );

  test(
    'streamEvents yields session-expired failure when auth is unavailable',
    () async {
      final cookieStore = createCookieStore();
      final client = _QueueHttpClient(
        <http.StreamedResponse Function(http.BaseRequest)>[],
      );
      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: cookieStore,
        httpClient: client,
      );

      final results = await repository
          .streamEvents(conversationId: 'conv-no-auth')
          .toList();
      expect(results, hasLength(1));
      expect(results.single.failure, isA<SessionExpiredFailure>());
    },
  );

  test(
    'streamEvents returns API failure payload for non-2xx stream open',
    () async {
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'token-stream-fail',
          'refresh_token': 'refresh-stream-fail',
          'user_id': 'u1',
        }),
        60,
        '/',
      );
      final client = _QueueHttpClient(
        <http.StreamedResponse Function(http.BaseRequest)>[
          (_) => _streamedResponse(
            statusCode: 500,
            body: jsonEncode(<String, dynamic>{
              'message': 'stream unavailable',
            }),
          ),
        ],
      );
      final repository = WebChatRepositoryImpl(
        appConfig: AppConfig.defaults(),
        cookieStore: cookieStore,
        httpClient: client,
      );

      final results = await repository
          .streamEvents(conversationId: 'conv-stream-fail')
          .toList();
      expect(results, hasLength(1));
      expect(results.single.failure, isA<ApiFailure>());
      expect(results.single.failure?.message, 'stream unavailable');
    },
  );

  test(
    'streamEvents parses scalar JSON and raw non-JSON data payloads',
    () async {
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'token-sse-shapes',
          'refresh_token': 'refresh-sse-shapes',
          'user_id': 'u1',
        }),
        60,
        '/',
      );
      const payload = '''
id: 1
event: system
data: 42

id: 2
event: system
data: not-json

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
          .streamEvents(conversationId: 'conv-sse-shapes')
          .toList();
      expect(results, hasLength(2));
      expect(results[0].data?.data['value'], 42);
      expect(results[1].data?.data['raw'], 'not-json');
    },
  );

  test(
    'refresh failure branches return session-expired for sendText',
    () async {
      final scenarios = <Map<String, dynamic>>[
        <String, dynamic>{
          'refreshToken': '',
          'responders': <http.StreamedResponse Function(http.BaseRequest)>[
            (_) => _streamedResponse(statusCode: 401),
          ],
        },
        <String, dynamic>{
          'refreshToken': 'refresh-token',
          'responders': <http.StreamedResponse Function(http.BaseRequest)>[
            (_) => _streamedResponse(statusCode: 401),
            (_) => _streamedResponse(statusCode: 500, body: 'failed refresh'),
          ],
        },
        <String, dynamic>{
          'refreshToken': 'refresh-token',
          'responders': <http.StreamedResponse Function(http.BaseRequest)>[
            (_) => _streamedResponse(statusCode: 401),
            (_) => _streamedResponse(
              statusCode: 200,
              body: jsonEncode(<String, dynamic>{
                'refresh_token': 'missing-access',
              }),
            ),
          ],
        },
        <String, dynamic>{
          'refreshToken': 'refresh-token',
          'responders': <http.StreamedResponse Function(http.BaseRequest)>[
            (_) => _streamedResponse(statusCode: 401),
            (_) => _streamedResponse(
              statusCode: 200,
              body: jsonEncode(<String, dynamic>{'access_token': '   '}),
            ),
          ],
        },
        <String, dynamic>{
          'refreshToken': 'refresh-token',
          'responders': <http.StreamedResponse Function(http.BaseRequest)>[
            (_) => _streamedResponse(statusCode: 401),
            (_) => _streamedResponse(statusCode: 200, body: '{invalid-json'),
          ],
        },
      ];

      for (final scenario in scenarios) {
        final cookieStore = createCookieStore();
        cookieStore.setCookie(
          'auth',
          jsonEncode(<String, dynamic>{
            'access_token': 'old-token',
            'refresh_token': scenario['refreshToken'],
            'user_id': 'u1',
          }),
          60,
          '/',
        );
        final responders =
            scenario['responders']
                as List<http.StreamedResponse Function(http.BaseRequest)>;
        final client = _QueueHttpClient(
          List<http.StreamedResponse Function(http.BaseRequest)>.from(
            responders,
          ),
        );
        final repository = WebChatRepositoryImpl(
          appConfig: AppConfig.defaults(),
          cookieStore: cookieStore,
          httpClient: client,
        );

        final result = await repository.sendText(
          conversationId: 'conv-refresh-failure',
          clientMessageId: 'client-refresh-failure',
          text: 'hello',
        );
        expect(result.isFailure, isTrue);
        expect(result.failure, isA<SessionExpiredFailure>());
      }
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

  test('downloadMedia removes auth cookie on repeated 401 responses', () async {
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-repeat-401',
        'refresh_token': 'refresh-repeat-401',
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
            'access_token': 'new-token-repeat-401',
            'refresh_token': 'new-refresh-repeat-401',
            'user_id': 'u1',
          }),
          headers: const <String, String>{'content-type': 'application/json'},
        ),
        (_) => _streamedResponse(statusCode: 401),
      ],
    );
    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    final result = await repository.downloadMedia(
      mediaUrl: '/api/core/web/v1/media/repeat-401',
    );

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<SessionExpiredFailure>());
    expect(cookieStore.getCookie('auth'), isNull);
  });

  test('streamEvents removes auth cookie on repeated 401 responses', () async {
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-stream-401',
        'refresh_token': 'refresh-stream-401',
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
            'access_token': 'new-token-stream-401',
            'refresh_token': 'new-refresh-stream-401',
            'user_id': 'u1',
          }),
          headers: const <String, String>{'content-type': 'application/json'},
        ),
        (_) => _streamedResponse(statusCode: 401),
      ],
    );
    final repository = WebChatRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      httpClient: client,
    );

    final results = await repository
        .streamEvents(conversationId: 'conv-stream-401')
        .toList();
    expect(results, hasLength(1));
    expect(results.single.failure, isA<SessionExpiredFailure>());
    expect(cookieStore.getCookie('auth'), isNull);
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
