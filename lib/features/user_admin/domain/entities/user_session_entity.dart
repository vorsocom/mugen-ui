class UserSessionEntity {
  const UserSessionEntity({
    required this.id,
    required this.userId,
    required this.tokenJti,
    required this.expiresAt,
    required this.dateCreated,
    required this.dateLastModified,
  });

  final String id;
  final String userId;
  final String tokenJti;
  final DateTime expiresAt;
  final DateTime dateCreated;
  final DateTime dateLastModified;
}
