import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/delete_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/revoke_user_session_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/application/services/user_admin_service.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_session_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/delete_user_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/disable_user_account_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/edit_user_roles_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/enable_user_account_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/fetch_user_sessions_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/fetch_roles_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/fetch_users_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/register_user_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/reset_user_password_admin_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/revoke_user_session_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/update_user_usecase.dart';
import 'package:mugen_ui/features/user_admin/infrastructure/repositories/user_admin_repository_impl.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/result.dart';

part 'user_admin_providers.g.dart';

class UserAdminState {
  const UserAdminState({
    required this.users,
    required this.roles,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.searchTerm,
    required this.isLoadingUsers,
    required this.isLoadingRoles,
    this.errorMessage,
  });

  final List<UserEntity> users;
  final List<UserRoleEntity> roles;
  final int total;
  final int page;
  final int pageSize;
  final String searchTerm;
  final bool isLoadingUsers;
  final bool isLoadingRoles;
  final String? errorMessage;

  int get pages {
    if (pageSize <= 0) {
      return 1;
    }

    return (total / pageSize).ceil();
  }

  UserAdminState copyWith({
    List<UserEntity>? users,
    List<UserRoleEntity>? roles,
    int? total,
    int? page,
    int? pageSize,
    String? searchTerm,
    bool? isLoadingUsers,
    bool? isLoadingRoles,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserAdminState(
      users: users ?? this.users,
      roles: roles ?? this.roles,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      searchTerm: searchTerm ?? this.searchTerm,
      isLoadingUsers: isLoadingUsers ?? this.isLoadingUsers,
      isLoadingRoles: isLoadingRoles ?? this.isLoadingRoles,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

@Riverpod(keepAlive: true)
UserAdminRepository userAdminRepository(Ref ref) {
  return UserAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    cookieStore: ref.watch(cookieStoreProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
}

@Riverpod(keepAlive: true)
UserAdminService userAdminService(Ref ref) {
  final repository = ref.watch(userAdminRepositoryProvider);
  return UserAdminService(
    fetchUsersUseCase: FetchUsersUseCase(repository),
    fetchRolesUseCase: FetchRolesUseCase(repository),
    registerUserUseCase: RegisterUserUseCase(repository),
    updateUserUseCase: UpdateUserUseCase(repository),
    deleteUserUseCase: DeleteUserUseCase(repository),
    disableUserAccountUseCase: DisableUserAccountUseCase(repository),
    enableUserAccountUseCase: EnableUserAccountUseCase(repository),
    fetchUserSessionsUseCase: FetchUserSessionsUseCase(repository),
    revokeUserSessionUseCase: RevokeUserSessionUseCase(repository),
    resetUserPasswordAdminUseCase: ResetUserPasswordAdminUseCase(repository),
    editUserRolesUseCase: EditUserRolesUseCase(repository),
  );
}

@Riverpod(keepAlive: true)
class UserAdminController extends _$UserAdminController {
  @override
  UserAdminState build() {
    Future<void>.microtask(() async {
      await loadUsers();
      await loadRoles();
    });

    return const UserAdminState(
      users: <UserEntity>[],
      roles: <UserRoleEntity>[],
      total: 0,
      page: 1,
      pageSize: 15,
      searchTerm: '',
      isLoadingUsers: false,
      isLoadingRoles: false,
    );
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoadingUsers: true, clearError: true);

    final service = ref.read(userAdminServiceProvider);
    final currentUserName = ref
        .read(authControllerProvider)
        .session
        ?.username
        ?.trim();
    final response = await service.fetchUsers(
      UserListQuery(
        pageRequest: PageRequest(page: state.page, pageSize: state.pageSize),
        searchTerm: state.searchTerm,
        excludeUserName: currentUserName == null || currentUserName.isEmpty
            ? null
            : currentUserName,
      ),
    );

    if (response.isFailure) {
      state = state.copyWith(
        isLoadingUsers: false,
        errorMessage: response.failure?.message ?? 'Could not load users.',
      );
      return;
    }

    final page = response.data!;
    state = state.copyWith(
      users: page.items,
      total: page.total,
      isLoadingUsers: false,
      clearError: true,
    );
  }

  Future<void> loadRoles() async {
    state = state.copyWith(isLoadingRoles: true, clearError: true);

    final response = await ref.read(userAdminServiceProvider).fetchRoles();
    if (response.isFailure) {
      state = state.copyWith(
        isLoadingRoles: false,
        errorMessage: response.failure?.message ?? 'Could not load roles.',
      );
      return;
    }

    state = state.copyWith(
      roles: response.data!,
      isLoadingRoles: false,
      clearError: true,
    );
  }

  void setRowsPerPage(int rowsPerPage) {
    state = state.copyWith(pageSize: rowsPerPage, page: 1);
  }

  void setPage(int page) {
    var safePage = page;
    if (safePage < 1) {
      safePage = 1;
    }

    final maxPage = state.pages;
    if (maxPage > 0 && safePage > maxPage) {
      safePage = maxPage;
    }

    state = state.copyWith(page: safePage);
  }

  void setSearchTerm(String value) {
    state = state.copyWith(searchTerm: value, page: 1);
  }

  Future<bool> registerUser(UserRegistrationInput input) async {
    final response = await ref
        .read(userAdminServiceProvider)
        .registerUser(input);
    if (response.isFailure) {
      state = state.copyWith(
        errorMessage: response.failure?.message ?? 'API error.',
      );
      return false;
    }

    await loadUsers();
    return true;
  }

  Future<bool> updateUser(UpdateUserInput input) async {
    final response = await ref.read(userAdminServiceProvider).updateUser(input);
    if (response.isFailure) {
      state = state.copyWith(
        errorMessage: response.failure?.message ?? 'API error.',
      );
      return false;
    }

    await loadUsers();
    return true;
  }

  Future<bool> deleteUser(String userId) async {
    final response = await ref
        .read(userAdminServiceProvider)
        .deleteUser(DeleteUserInput(userId: userId));
    if (response.isFailure) {
      state = state.copyWith(
        errorMessage: response.failure?.message ?? 'API error.',
      );
      return false;
    }

    await loadUsers();
    return true;
  }

  Future<bool> enableUser(String userId) async {
    final response = await ref
        .read(userAdminServiceProvider)
        .enableUserAccount(ToggleUserAccountInput(userId: userId));
    if (response.isFailure) {
      state = state.copyWith(
        errorMessage: response.failure?.message ?? 'API error.',
      );
      return false;
    }

    await loadUsers();
    return true;
  }

  Future<bool> disableUser(String userId) async {
    final response = await ref
        .read(userAdminServiceProvider)
        .disableUserAccount(ToggleUserAccountInput(userId: userId));
    if (response.isFailure) {
      state = state.copyWith(
        errorMessage: response.failure?.message ?? 'API error.',
      );
      return false;
    }

    await loadUsers();
    return true;
  }

  Future<Result<List<UserSessionEntity>>> fetchUserSessions(
    String userId,
  ) async {
    final response = await ref
        .read(userAdminServiceProvider)
        .fetchUserSessions(userId);
    if (response.isFailure) {
      state = state.copyWith(
        errorMessage: response.failure?.message ?? 'API error.',
      );
    }

    return response;
  }

  Future<bool> revokeUserSession(String refreshTokenId) async {
    final response = await ref
        .read(userAdminServiceProvider)
        .revokeUserSession(
          RevokeUserSessionInput(refreshTokenId: refreshTokenId),
        );
    if (response.isFailure) {
      state = state.copyWith(
        errorMessage: response.failure?.message ?? 'API error.',
      );
      return false;
    }

    return true;
  }

  Future<bool> resetUserPasswordAdmin(UserResetPasswordAdminInput input) async {
    final response = await ref
        .read(userAdminServiceProvider)
        .resetUserPasswordAdmin(input);
    if (response.isFailure) {
      state = state.copyWith(
        errorMessage: response.failure?.message ?? 'API error.',
      );
      return false;
    }

    return true;
  }

  Future<bool> editUserRoles(EditUserRolesInput input) async {
    final response = await ref
        .read(userAdminServiceProvider)
        .editUserRoles(input);
    if (response.isFailure) {
      state = state.copyWith(
        errorMessage: response.failure?.message ?? 'API error.',
      );
      return false;
    }

    await loadUsers();
    return true;
  }
}
