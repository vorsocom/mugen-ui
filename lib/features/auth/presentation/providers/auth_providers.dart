import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/application/dto/credentials.dart';
import 'package:mugen_ui/features/auth/application/services/auth_application_service.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/domain/usecases/check_user_authenticated_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/check_user_roles_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/fetch_own_profile_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/login_user_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/logout_user_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/reset_own_password_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/update_own_profile_usecase.dart';
import 'package:mugen_ui/features/auth/infrastructure/repositories/auth_repository_impl.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

part 'auth_providers.g.dart';

final StreamProvider<AuthSession> authSessionRefreshEventsProvider =
    StreamProvider<AuthSession>(
      (ref) => ref.watch(authSessionRefreshBusProvider).stream,
    );

class AuthControllerState {
  const AuthControllerState({
    required this.isLoading,
    required this.session,
    this.errorMessage,
  });

  final bool isLoading;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated => session != null;

  AuthControllerState copyWith({
    bool? isLoading,
    AuthSession? session,
    bool clearSession = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthControllerState(
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    cookieStore: ref.watch(cookieStoreProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
}

@Riverpod(keepAlive: true)
AuthApplicationService authApplicationService(Ref ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthApplicationService(
    loginUserUseCase: LoginUserUseCase(repository),
    logoutUserUseCase: LogoutUserUseCase(repository),
    checkUserAuthenticatedUseCase: CheckUserAuthenticatedUseCase(repository),
    checkUserRolesUseCase: CheckUserRolesUseCase(repository),
    resetOwnPasswordUseCase: ResetOwnPasswordUseCase(repository),
    fetchOwnProfileUseCase: FetchOwnProfileUseCase(repository),
    updateOwnProfileUseCase: UpdateOwnProfileUseCase(repository),
  );
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AuthControllerState build() {
    ref.listen<AsyncValue<AuthSession>>(authSessionRefreshEventsProvider, (
      _,
      next,
    ) {
      final refreshedSession = next.valueOrNull;
      if (refreshedSession == null) {
        return;
      }

      state = state.copyWith(session: refreshedSession, clearError: true);
    });

    final repository = ref.watch(authRepositoryProvider);
    final session = repository.currentSession().data;
    return AuthControllerState(isLoading: false, session: session);
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final service = ref.read(authApplicationServiceProvider);
    final response = await service.login(
      Credentials(username: username, password: password),
    );

    if (response.isFailure) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: response.failure?.message ?? 'Login failed.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: false,
      session: response.data,
      clearError: true,
    );
    return true;
  }

  Future<bool> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final service = ref.read(authApplicationServiceProvider);
    final response = await service.logout();

    if (response.isFailure) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: response.failure?.message ?? 'Logout failed.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: false,
      clearSession: true,
      clearError: true,
    );
    return true;
  }

  void refreshSession() {
    final repository = ref.read(authRepositoryProvider);
    state = state.copyWith(
      session: repository.currentSession().data,
      clearError: true,
    );
  }

  bool hasRoles(List<String> roles, {String operator = 'and'}) {
    final service = ref.read(authApplicationServiceProvider);
    return service.hasRoles(roles: roles, operator: operator).data ?? false;
  }
}
