class UpdateUserInput {
  const UpdateUserInput({
    required this.userId,
    required this.personId,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String userId;
  final String personId;
  final String firstName;
  final String lastName;
  final String email;
}
