Map<String, String> parseCookieHeader(String cookieHeader) {
  final values = <String, String>{};

  for (final rawPart in cookieHeader.split(';')) {
    final part = rawPart.trim();
    if (part.isEmpty) {
      continue;
    }

    final delimiter = part.indexOf('=');
    if (delimiter <= 0) {
      continue;
    }

    final rawKey = part.substring(0, delimiter).trim();
    final rawValue = part.substring(delimiter + 1).trim();
    final key = _decodeSafely(rawKey);
    final value = _decodeSafely(rawValue);

    if (key.isEmpty) {
      continue;
    }

    values[key] = value;
  }

  return values;
}

String buildSetCookieDirective({
  required String key,
  required String value,
  required int maxAge,
  required String path,
  bool secure = false,
  String sameSite = 'Lax',
}) {
  final normalizedPath = path.isEmpty ? '/' : path;
  final parts = <String>[
    '${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}',
    'Max-Age=$maxAge',
    'Path=$normalizedPath',
    'SameSite=$sameSite',
  ];

  if (secure) {
    parts.add('Secure');
  }

  return parts.join('; ');
}

String _decodeSafely(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}
