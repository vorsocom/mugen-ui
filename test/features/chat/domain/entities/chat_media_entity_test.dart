import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_media_entity.dart';

void main() {
  test('copyWith applies overrides and clear flags', () {
    final original = ChatMediaEntity(
      url: 'https://example.com/one.png',
      mimeType: 'image/png',
      filename: 'one.png',
      expiresAt: DateTime.utc(2026, 1, 1),
    );

    final updated = original.copyWith(
      url: 'https://example.com/two.png',
      mimeType: 'image/jpeg',
      filename: 'two.jpg',
      expiresAt: DateTime.utc(2027, 1, 1),
    );
    expect(updated.url, 'https://example.com/two.png');
    expect(updated.mimeType, 'image/jpeg');
    expect(updated.filename, 'two.jpg');
    expect(updated.expiresAt, DateTime.utc(2027, 1, 1));

    final unchanged = updated.copyWith();
    expect(unchanged.mimeType, 'image/jpeg');
    expect(unchanged.filename, 'two.jpg');
    expect(unchanged.expiresAt, DateTime.utc(2027, 1, 1));

    final cleared = updated.copyWith(
      clearMimeType: true,
      clearFilename: true,
      clearExpiresAt: true,
    );
    expect(cleared.mimeType, isNull);
    expect(cleared.filename, isNull);
    expect(cleared.expiresAt, isNull);
  });

  test('fromJson parses string fields and multiple expires_at formats', () {
    final fromInt = ChatMediaEntity.fromJson(<String, dynamic>{
      'url': ' https://example.com/file ',
      'mime_type': ' image/png ',
      'filename': ' file.png ',
      'expires_at': 1700000000,
    });
    expect(fromInt.url, ' https://example.com/file ');
    expect(fromInt.mimeType, 'image/png');
    expect(fromInt.filename, 'file.png');
    expect(
      fromInt.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
    );

    final fromNum = ChatMediaEntity.fromJson(<String, dynamic>{
      'url': 'https://example.com/num',
      'expires_at': 1700000000.5,
    });
    expect(
      fromNum.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(
        (1700000000.5 * 1000).toInt(),
        isUtc: true,
      ),
    );

    final fromNumericString = ChatMediaEntity.fromJson(<String, dynamic>{
      'url': 'https://example.com/string',
      'expires_at': '1700000011',
      'mime_type': '   ',
      'filename': '',
    });
    expect(fromNumericString.mimeType, isNull);
    expect(fromNumericString.filename, isNull);
    expect(
      fromNumericString.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1700000011 * 1000, isUtc: true),
    );

    final fromIso = ChatMediaEntity.fromJson(<String, dynamic>{
      'url': 'https://example.com/iso',
      'expires_at': '2026-01-02T03:04:05Z',
    });
    expect(fromIso.expiresAt, DateTime.utc(2026, 1, 2, 3, 4, 5));

    final invalid = ChatMediaEntity.fromJson(<String, dynamic>{
      'url': 'https://example.com/invalid',
      'expires_at': 'not-a-date',
    });
    expect(invalid.expiresAt, isNull);
  });

  test('toJson serializes only non-null optional fields', () {
    final value = ChatMediaEntity(
      url: 'https://example.com/file',
      mimeType: 'application/pdf',
      filename: 'file.pdf',
      expiresAt: DateTime.utc(2028, 5, 6, 7, 8, 9),
    );

    final json = value.toJson();
    expect(json['url'], 'https://example.com/file');
    expect(json['mime_type'], 'application/pdf');
    expect(json['filename'], 'file.pdf');
    expect(
      json['expires_at'],
      DateTime.utc(2028, 5, 6, 7, 8, 9).millisecondsSinceEpoch ~/ 1000,
    );

    final noOptionals = const ChatMediaEntity(url: 'https://example.com/min');
    expect(noOptionals.toJson(), <String, dynamic>{
      'url': 'https://example.com/min',
    });
  });
}
