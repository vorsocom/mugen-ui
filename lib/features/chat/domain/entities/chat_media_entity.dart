class ChatMediaEntity {
  const ChatMediaEntity({
    required this.url,
    this.mimeType,
    this.filename,
    this.expiresAt,
  });

  final String url;
  final String? mimeType;
  final String? filename;
  final DateTime? expiresAt;

  ChatMediaEntity copyWith({
    String? url,
    String? mimeType,
    String? filename,
    DateTime? expiresAt,
    bool clearMimeType = false,
    bool clearFilename = false,
    bool clearExpiresAt = false,
  }) {
    return ChatMediaEntity(
      url: url ?? this.url,
      mimeType: clearMimeType ? null : (mimeType ?? this.mimeType),
      filename: clearFilename ? null : (filename ?? this.filename),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
    );
  }

  factory ChatMediaEntity.fromJson(Map<String, dynamic> json) {
    return ChatMediaEntity(
      url: json['url']?.toString() ?? '',
      mimeType: _readNullableString(json['mime_type']),
      filename: _readNullableString(json['filename']),
      expiresAt: _readExpiresAt(json['expires_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      if (mimeType != null) 'mime_type': mimeType,
      if (filename != null) 'filename': filename,
      if (expiresAt != null)
        'expires_at': expiresAt!.millisecondsSinceEpoch ~/ 1000,
    };
  }
}

String? _readNullableString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

DateTime? _readExpiresAt(Object? value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }

  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value.toDouble() * 1000).toInt(),
      isUtc: true,
    );
  }

  final asString = value?.toString().trim();
  if (asString == null || asString.isEmpty) {
    return null;
  }

  final asNum = num.tryParse(asString);
  if (asNum != null) {
    return DateTime.fromMillisecondsSinceEpoch(
      (asNum.toDouble() * 1000).toInt(),
      isUtc: true,
    );
  }

  return DateTime.tryParse(asString)?.toUtc();
}
