class UpdateOwnProfileInput {
  const UpdateOwnProfileInput({
    required this.firstName,
    required this.lastName,
    required this.personRowVersion,
  });

  final String firstName;
  final String lastName;
  final int personRowVersion;
}
