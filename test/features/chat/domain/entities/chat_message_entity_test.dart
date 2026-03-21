import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_media_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_message_entity.dart';

void main() {
  test('copyWith updates fields and supports clear flags', () {
    final original = ChatMessageEntity(
      id: 'm1',
      role: ChatMessageRole.user,
      type: ChatMessageType.image,
      status: ChatMessageStatus.pending,
      createdAt: DateTime.utc(2026, 1, 1),
      text: 'hello',
      media: const ChatMediaEntity(url: 'https://example.com/a.png'),
      clientMessageId: 'client-1',
      jobId: 'job-1',
      eventId: 'event-1',
      errorMessage: 'boom',
    );

    expect(original.isMedia, isTrue);

    final updated = original.copyWith(
      role: ChatMessageRole.assistant,
      type: ChatMessageType.text,
      status: ChatMessageStatus.delivered,
      text: 'updated',
      createdAt: DateTime.utc(2026, 2, 2),
    );
    expect(updated.role, ChatMessageRole.assistant);
    expect(updated.type, ChatMessageType.text);
    expect(updated.status, ChatMessageStatus.delivered);
    expect(updated.text, 'updated');
    expect(updated.createdAt, DateTime.utc(2026, 2, 2));
    expect(updated.isMedia, isFalse);

    final cleared = updated.copyWith(
      clearText: true,
      clearMedia: true,
      clearClientMessageId: true,
      clearJobId: true,
      clearEventId: true,
      clearErrorMessage: true,
    );
    expect(cleared.text, isNull);
    expect(cleared.media, isNull);
    expect(cleared.clientMessageId, isNull);
    expect(cleared.jobId, isNull);
    expect(cleared.eventId, isNull);
    expect(cleared.errorMessage, isNull);
  });

  test('fromJson parses enums and optional fields', () {
    final value = ChatMessageEntity.fromJson(<String, dynamic>{
      'id': 'm2',
      'role': 'assistant',
      'type': 'video',
      'status': 'accepted',
      'created_at': '2026-01-02T03:04:05Z',
      'text': ' message ',
      'media': <String, dynamic>{
        'url': 'https://example.com/video.mp4',
        'mime_type': 'video/mp4',
      },
      'client_message_id': 'client-2',
      'job_id': 'job-2',
      'event_id': 'event-2',
      'error_message': ' error ',
    });

    expect(value.id, 'm2');
    expect(value.role, ChatMessageRole.assistant);
    expect(value.type, ChatMessageType.video);
    expect(value.status, ChatMessageStatus.accepted);
    expect(value.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(value.text, 'message');
    expect(value.media, isNotNull);
    expect(value.media!.mimeType, 'video/mp4');
    expect(value.clientMessageId, 'client-2');
    expect(value.jobId, 'job-2');
    expect(value.eventId, 'event-2');
    expect(value.errorMessage, 'error');
  });

  test('fromJson falls back for unknown enum values and missing date', () {
    final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
    final value = ChatMessageEntity.fromJson(<String, dynamic>{
      'id': 'm3',
      'role': 'unknown',
      'type': 'unknown',
      'status': 'unknown',
      'created_at': 'not-a-date',
      'media': 'not-a-map',
      'text': '   ',
      'client_message_id': '',
      'job_id': '',
      'event_id': '',
      'error_message': '',
    });
    final after = DateTime.now().toUtc().add(const Duration(seconds: 1));

    expect(value.role, ChatMessageRole.system);
    expect(value.type, ChatMessageType.text);
    expect(value.status, ChatMessageStatus.pending);
    expect(value.media, isNull);
    expect(value.text, isNull);
    expect(value.clientMessageId, isNull);
    expect(value.jobId, isNull);
    expect(value.eventId, isNull);
    expect(value.errorMessage, isNull);
    expect(value.createdAt.isAfter(before), isTrue);
    expect(value.createdAt.isBefore(after), isTrue);
  });

  test('toJson emits enum names and optional fields when present', () {
    final withOptionals = ChatMessageEntity(
      id: 'm4',
      role: ChatMessageRole.error,
      type: ChatMessageType.file,
      status: ChatMessageStatus.failed,
      createdAt: DateTime.utc(2026, 4, 5, 6, 7, 8),
      text: 'text',
      media: const ChatMediaEntity(url: 'https://example.com/file.bin'),
      clientMessageId: 'client-4',
      jobId: 'job-4',
      eventId: 'event-4',
      errorMessage: 'failed',
    );

    final json = withOptionals.toJson();
    expect(json['role'], 'error');
    expect(json['type'], 'file');
    expect(json['status'], 'failed');
    expect(json['created_at'], '2026-04-05T06:07:08.000Z');
    expect(json['media'], isA<Map<String, dynamic>>());
    expect(json['client_message_id'], 'client-4');
    expect(json['job_id'], 'job-4');
    expect(json['event_id'], 'event-4');
    expect(json['error_message'], 'failed');

    final minimal = ChatMessageEntity(
      id: 'm5',
      role: ChatMessageRole.system,
      type: ChatMessageType.text,
      status: ChatMessageStatus.delivered,
      createdAt: DateTime.utc(2026, 6, 1),
    );
    final minimalJson = minimal.toJson();
    expect(minimalJson.containsKey('text'), isFalse);
    expect(minimalJson.containsKey('media'), isFalse);
    expect(minimalJson.containsKey('client_message_id'), isFalse);
    expect(minimalJson.containsKey('job_id'), isFalse);
    expect(minimalJson.containsKey('event_id'), isFalse);
    expect(minimalJson.containsKey('error_message'), isFalse);
  });
}
