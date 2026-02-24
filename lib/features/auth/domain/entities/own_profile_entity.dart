class OwnProfileEntity {
  const OwnProfileEntity({
    required this.userId,
    required this.personId,
    required this.personRowVersion,
    required this.firstName,
    required this.lastName,
  });

  final String userId;
  final String personId;
  final int personRowVersion;
  final String firstName;
  final String lastName;
}
