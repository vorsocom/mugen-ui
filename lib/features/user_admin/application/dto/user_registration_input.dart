class UserRegistrationInput {
  const UserRegistrationInput({
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.email,
    required this.password,
  });

  final String firstName;
  final String lastName;
  final String userName;
  final String email;
  final String password;
}
