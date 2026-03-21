import 'dart:convert' as convert;

import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

AuthSession? parseAuthSession(String? rawCookie) {
  if (rawCookie == null || rawCookie.isEmpty) {
    return null;
  }

  try {
    final decoded = convert.jsonDecode(rawCookie);
    if (decoded is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(decoded);
    final accessToken = _requiredString(map['access_token']);
    final refreshToken = _requiredString(map['refresh_token']);
    final userId = _requiredString(map['user_id']);

    if (accessToken == null || refreshToken == null || userId == null) {
      return null;
    }

    final roles = _parseRoles(map['roles']);
    final username = _optionalString(map['username']);

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      username: username,
      accessTokenExpires: _parseExpires(map['access_token_expires']),
      roles: roles,
    );
  } catch (_) {
    return null;
  }
}

String encodeAuthSession(Map<String, dynamic> payload) {
  return convert.jsonEncode(payload);
}

DateTime? _parseExpires(Object? value) {
  if (value is int) {
    return DateTime.fromMicrosecondsSinceEpoch(value * 1000000);
  }

  if (value is num) {
    return DateTime.fromMicrosecondsSinceEpoch((value * 1000000).toInt());
  }

  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return DateTime.fromMicrosecondsSinceEpoch(parsed * 1000000);
    }
  }

  return null;
}

String? _requiredString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

String? _optionalString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

List<String> _parseRoles(Object? rawRoles) {
  if (rawRoles is! List) {
    return const <String>[];
  }

  return rawRoles
      .map((role) => role?.toString().trim() ?? '')
      .where((role) => role.isNotEmpty)
      .toList(growable: false);
}
