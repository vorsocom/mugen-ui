class UserResetPasswordAdminInput {
  const UserResetPasswordAdminInput({
    required this.userId,
    required this.newPassword,
    required this.confirmNewPassword,
    this.rowVersion = 0,
  });

  final String userId;
  final String newPassword;
  final String confirmNewPassword;
  final int rowVersion;
}
