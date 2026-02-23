class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.roles,
    this.username,
    this.accessTokenExpires,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String? username;
  final DateTime? accessTokenExpires;
  final List<String> roles;
}
