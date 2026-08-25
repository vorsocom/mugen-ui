import 'dart:convert';

const int _maximumApiErrorLength = 600;
const String _defaultApiErrorMessage = 'API request failed.';

/// Converts an untrusted API response body into safe, readable plain text.
///
/// JSON problem details and validation maps are reduced to their useful
/// messages. HTML response pages are summarized without retaining markup,
/// scripts, or styles. The result is intentionally bounded for alert surfaces.
String normalizeApiErrorMessage(
  String? raw, {
  String fallback = _defaultApiErrorMessage,
}) {
  final normalizedFallback = _normalizeCandidate(fallback);
  final resolvedFallback = normalizedFallback.isEmpty
      ? _defaultApiErrorMessage
      : normalizedFallback;
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) {
    return _bounded(resolvedFallback);
  }

  final structured = _decodeStructuredMessage(trimmed);
  final normalized = _normalizeCandidate(structured ?? trimmed);
  return _bounded(normalized.isEmpty ? resolvedFallback : normalized);
}

String? _decodeStructuredMessage(String raw) {
  try {
    return _messageFromStructuredValue(jsonDecode(raw)) ?? '';
  } catch (_) {
    return null;
  }
}

String? _messageFromStructuredValue(Object? value, {String? fieldName}) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is List) {
    final messages = value
        .map((item) => _messageFromStructuredValue(item))
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (messages.isEmpty) {
      return null;
    }
    final joined = messages.join(' ');
    return fieldName == null ? joined : '$fieldName: $joined';
  }
  if (value is Map) {
    for (final key in const <String>[
      'message',
      'detail',
      'error',
      'description',
      'title',
    ]) {
      final matchingKey = value.keys.cast<Object?>().firstWhere(
        (candidate) => candidate.toString().toLowerCase() == key,
        orElse: () => null,
      );
      if (matchingKey == null) {
        continue;
      }
      final message = _messageFromStructuredValue(value[matchingKey]);
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    final errorsKey = value.keys.cast<Object?>().firstWhere(
      (candidate) => candidate.toString().toLowerCase() == 'errors',
      orElse: () => null,
    );
    if (errorsKey != null) {
      final errors = _flattenMap(value[errorsKey]);
      if (errors != null) {
        return errors;
      }
    }

    return _flattenMap(value);
  }
  return value.toString(); // coverage:ignore-line
}

String? _flattenMap(Object? value) {
  if (value is! Map) {
    return _messageFromStructuredValue(value);
  }
  final messages = <String>[];
  for (final entry in value.entries) {
    final fieldName = entry.key.toString().trim();
    final message = _messageFromStructuredValue(
      entry.value,
      fieldName: fieldName.isEmpty ? null : fieldName,
    );
    if (message == null || message.isEmpty) {
      continue;
    }
    messages.add(
      fieldName.isEmpty || message.startsWith('$fieldName:')
          ? message
          : '$fieldName: $message',
    );
  }
  return messages.isEmpty ? null : messages.join('\n');
}

String _normalizeCandidate(String value) {
  final withoutUnsafeBlocks = value
      .replaceAll(
        RegExp(
          r'<(?:script|style)\b[^>]*>.*?</(?:script|style)>',
          caseSensitive: false,
          dotAll: true,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
  if (_looksLikeHtml(withoutUnsafeBlocks)) {
    return _htmlSummary(withoutUnsafeBlocks);
  }
  return _normalizeWhitespace(_decodeHtmlEntities(withoutUnsafeBlocks));
}

bool _looksLikeHtml(String value) {
  return RegExp(
    r'<!doctype\s+html|</?[a-z][a-z0-9:-]*\b[^>]*>',
    caseSensitive: false,
  ).hasMatch(value);
}

String _htmlSummary(String value) {
  final parts = <String>[];
  for (final tagName in const <String>['title', 'h1']) {
    final text = _firstElementText(value, tagName);
    if (text != null) {
      _addDistinct(parts, text);
    }
  }
  for (final match in RegExp(
    r'<p\b[^>]*>(.*?)</p>',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(value)) {
    final text = _plainText(match.group(1) ?? '');
    if (text.isNotEmpty) {
      _addDistinct(parts, text);
    }
  }
  if (parts.isNotEmpty) {
    if (parts.length == 1) {
      return parts.single;
    }
    return '${parts.first}: ${parts.skip(1).join(' ')}';
  }
  return _plainText(value);
}

String? _firstElementText(String value, String tagName) {
  final match = RegExp(
    '<$tagName\\b[^>]*>(.*?)</$tagName>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  final text = _plainText(match.group(1) ?? '');
  return text.isEmpty ? null : text;
}

String _plainText(String value) {
  return _normalizeWhitespace(
    _decodeHtmlEntities(
      value
          .replaceAll(RegExp(r'<br\b[^>]*>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), ' '),
    ),
  );
}

void _addDistinct(List<String> values, String candidate) {
  final lowerCandidate = candidate.toLowerCase();
  if (values.any((value) => value.toLowerCase().contains(lowerCandidate))) {
    return;
  }
  values.add(candidate);
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAllMapped(RegExp(r'&#(x?[0-9a-f]+);', caseSensitive: false), (
        match,
      ) {
        final raw = match.group(1)!;
        final isHex = raw.toLowerCase().startsWith('x');
        final codePoint = int.tryParse(
          isHex ? raw.substring(1) : raw,
          radix: isHex ? 16 : 10,
        );
        if (codePoint == null ||
            codePoint < 0 ||
            codePoint > 0x10ffff ||
            (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
          return match.group(0)!;
        }
        return String.fromCharCode(codePoint);
      })
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');
}

String _normalizeWhitespace(String value) {
  return value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[^\S\n]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _bounded(String value) {
  if (value.length <= _maximumApiErrorLength) {
    return value;
  }
  return '${value.substring(0, _maximumApiErrorLength - 1).trimRight()}…';
}
