import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';

class RecordingAuthController extends AuthController {
  int refreshCount = 0;

  @override
  AuthControllerState build() {
    return const AuthControllerState(isLoading: false, session: null);
  }

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    return true;
  }

  @override
  Future<bool> logout() async => true;

  @override
  bool hasRoles(List<String> roles, {String operator = 'and'}) => true;

  @override
  void refreshSession() {
    refreshCount += 1;
  }
}
