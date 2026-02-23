import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/person_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/auth/auth_cookie_codec.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class UserAdminRepositoryImpl implements UserAdminRepository {
  UserAdminRepositoryImpl({
    required this.appConfig,
    required this.cookieStore,
    required this.authenticatedHttpClient,
  });

  static final DateFormat _rfc1123DateFormat = DateFormat(
    "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
    'en_US',
  );

  final AppConfig appConfig;
  final CookieStore cookieStore;
  final AuthenticatedHttpClient authenticatedHttpClient;

  @override
  Future<Result<PageResult<UserEntity>>> fetchUsers(UserListQuery query) async {
    try {
      final queryParameters = <String, dynamic>{
        r'$count': true,
        r'$orderby': 'CreatedAt desc',
        r'$expand': 'Person,GlobalRoleMemberships',
      };

      if (query.pageRequest.pageSize > 0) {
        queryParameters[r'$skip'] = query.pageRequest.skip;
        queryParameters[r'$top'] = query.pageRequest.pageSize;
      }

      final filterParts = <String>[];
      if (query.excludeUserName != null && query.excludeUserName!.isNotEmpty) {
        filterParts.add(
          "Username ne '${_escapeRGQLString(query.excludeUserName!)}'",
        );
      }

      final term = query.searchTerm?.trim() ?? '';
      if (term.length >= 2) {
        final escaped = _escapeRGQLString(term);
        filterParts.add(
          "(contains(Username,'$escaped') or contains(LoginEmail,'$escaped') or contains(Person/FirstName,'$escaped') or contains(Person/LastName,'$escaped'))",
        );
      }

      if (filterParts.isNotEmpty) {
        queryParameters[r'$filter'] = filterParts.join(' and ');
      }

      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.get,
          path: appConfig.api.endpoints.user,
          queryParameters: queryParameters,
        ),
      );

      if (response.sessionExpired) {
        return const Result<PageResult<UserEntity>>.failure(
          SessionExpiredFailure(),
        );
      }

      if (!response.response.isSuccess) {
        return Result<PageResult<UserEntity>>.failure(
          ApiFailure(response.response.statusCode, 'API error.'),
        );
      }

      final decoded = jsonDecode(response.response.body);
      if (decoded is! Map<String, dynamic>) {
        return const Result<PageResult<UserEntity>>.failure(
          UnexpectedFailure('Unexpected API response.'),
        );
      }

      final rawItems = decoded['value'];
      final items = <UserEntity>[];
      if (rawItems is List) {
        for (final rawItem in rawItems) {
          if (rawItem is Map) {
            items.add(_mapUser(Map<String, dynamic>.from(rawItem)));
          }
        }
      }

      final total = _parseCount(decoded['@count'], fallback: items.length);

      return Result<PageResult<UserEntity>>.success(
        PageResult<UserEntity>(
          items: items,
          total: total,
          page: query.pageRequest.page,
          pageSize: query.pageRequest.pageSize,
        ),
      );
    } catch (_) {
      return const Result<PageResult<UserEntity>>.failure(
        NetworkFailure('Network error.'),
      );
    }
  }

  @override
  Future<Result<List<UserRoleEntity>>> fetchRoles() async {
    try {
      final filter = _buildActiveRolesFilter();
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.get,
          path: appConfig.api.endpoints.userRole,
          queryParameters: <String, dynamic>{
            r'$count': true,
            if (filter.isNotEmpty) r'$filter': filter,
            r'$orderby': 'DisplayName asc',
          },
        ),
      );

      if (response.sessionExpired) {
        return const Result<List<UserRoleEntity>>.failure(
          SessionExpiredFailure(),
        );
      }

      if (!response.response.isSuccess) {
        return Result<List<UserRoleEntity>>.failure(
          ApiFailure(response.response.statusCode, 'API error.'),
        );
      }

      final decoded = jsonDecode(response.response.body);
      if (decoded is! Map<String, dynamic>) {
        return const Result<List<UserRoleEntity>>.failure(
          UnexpectedFailure('Unexpected API response.'),
        );
      }

      final rawItems = decoded['value'];
      final items = <UserRoleEntity>[];
      if (rawItems is List) {
        for (final rawItem in rawItems) {
          if (rawItem is Map) {
            items.add(_mapRole(Map<String, dynamic>.from(rawItem)));
          }
        }
      }

      return Result<List<UserRoleEntity>>.success(items);
    } catch (_) {
      return const Result<List<UserRoleEntity>>.failure(
        NetworkFailure('Network error.'),
      );
    }
  }

  @override
  Future<Result<void>> registerUser(UserRegistrationInput input) async {
    final loginEmail = input.email.trim();
    if (loginEmail.isEmpty) {
      return const Result<void>.failure(
        ValidationFailure('Email is required.'),
      );
    }

    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.post,
          path: appConfig.api.endpoints.authProvisionUser,
          body: <String, dynamic>{
            'Username': input.userName,
            'Password': input.password,
            'LoginEmail': loginEmail,
            'FirstName': input.firstName,
            'LastName': input.lastName,
          },
        ),
      );

      return _mapVoidResponse(response);
    } catch (_) {
      return const Result<void>.failure(NetworkFailure('Network error.'));
    }
  }

  @override
  Future<Result<void>> updateUser(UpdateUserInput input) async {
    final actionPath = appConfig.api.endpoints.authUpdateProfile.replaceAll(
      '{user_id}',
      input.userId,
    );

    final rowVersion = await _fetchUserRowVersion(input.userId);
    if (rowVersion == null) {
      return const Result<void>.failure(ApiFailure(500, 'API error.'));
    }

    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.post,
          path: actionPath,
          body: <String, dynamic>{
            'RowVersion': rowVersion,
            'FirstName': input.firstName,
            'LastName': input.lastName,
          },
        ),
      );

      return _mapVoidResponse(response);
    } catch (_) {
      return const Result<void>.failure(NetworkFailure('Network error.'));
    }
  }

  @override
  Future<Result<void>> disableUserAccount(ToggleUserAccountInput input) async {
    return _toggleUser(input.userId, appConfig.api.endpoints.authDisableUser);
  }

  @override
  Future<Result<void>> enableUserAccount(ToggleUserAccountInput input) async {
    return _toggleUser(input.userId, appConfig.api.endpoints.authEnableUser);
  }

  @override
  Future<Result<void>> resetUserPasswordAdmin(
    UserResetPasswordAdminInput input,
  ) async {
    var rowVersion = input.rowVersion;
    if (rowVersion <= 0) {
      final fetched = await _fetchUserRowVersion(input.userId);
      if (fetched == null) {
        return const Result<void>.failure(ApiFailure(500, 'API error.'));
      }

      rowVersion = fetched;
    }

    final actionPath = appConfig.api.endpoints.authResetPasswordAdmin
        .replaceAll('{user_id}', input.userId);

    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.post,
          path: actionPath,
          body: <String, dynamic>{
            'RowVersion': rowVersion,
            'NewPassword': input.newPassword,
            'ConfirmNewPassword': input.confirmNewPassword,
          },
        ),
      );

      return _mapVoidResponse(response);
    } catch (_) {
      return const Result<void>.failure(NetworkFailure('Network error.'));
    }
  }

  @override
  Future<Result<void>> editUserRoles(EditUserRolesInput input) async {
    final actionPath = appConfig.api.endpoints.authUpdateRolesAdmin.replaceAll(
      '{user_id}',
      input.userId,
    );

    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.post,
          path: actionPath,
          body: <String, dynamic>{'Roles': input.roles},
        ),
      );

      return _mapVoidResponse(response);
    } catch (_) {
      return const Result<void>.failure(NetworkFailure('Network error.'));
    }
  }

  Future<Result<void>> _toggleUser(
    String userId,
    String endpointTemplate,
  ) async {
    final actionPath = endpointTemplate.replaceAll('{user_id}', userId);
    final rowVersion = await _fetchUserRowVersion(userId);
    if (rowVersion == null) {
      return const Result<void>.failure(ApiFailure(500, 'API error.'));
    }

    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.post,
          path: actionPath,
          body: <String, dynamic>{'RowVersion': rowVersion},
        ),
      );

      return _mapVoidResponse(response);
    } catch (_) {
      return const Result<void>.failure(NetworkFailure('Network error.'));
    }
  }

  Future<int?> _fetchUserRowVersion(String userId) async {
    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.get,
          path: '${appConfig.api.endpoints.user}/$userId',
        ),
      );

      if (response.sessionExpired || !response.response.isSuccess) {
        return null;
      }

      final decoded = jsonDecode(response.response.body);
      if (decoded is Map<String, dynamic>) {
        final direct = _parseInt(decoded['RowVersion']);
        if (direct != null) {
          return direct;
        }

        final values = decoded['value'];
        if (values is List && values.isNotEmpty && values.first is Map) {
          return _parseInt((values.first as Map)['RowVersion']);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Result<void> _mapVoidResponse(AuthenticatedResponse response) {
    if (response.sessionExpired) {
      cookieStore.removeCookie('auth', '/');
      return const Result<void>.failure(SessionExpiredFailure());
    }

    if (!response.response.isSuccess) {
      return Result<void>.failure(
        ApiFailure(response.response.statusCode, 'API error.'),
      );
    }

    return const Result<void>.success(null);
  }

  UserEntity _mapUser(Map<String, dynamic> element) {
    final createdAt = _parseDate(element['CreatedAt']);
    final updatedAt = _parseDate(element['UpdatedAt']);
    final personData = _toNullableMap(element['Person']);
    final username = _asString(element['Username']);
    final loginEmail = _asString(element['LoginEmail']);
    final personId = _asString(element['PersonId']);

    final person = personData != null
        ? _mapPerson(
            personData,
            fallbackCreatedAt: createdAt,
            fallbackUpdatedAt: updatedAt,
          )
        : PersonEntity(
            id: personId,
            firstName: '',
            lastName: '',
            fullName: '',
            dateCreated: createdAt,
            dateLastModified: updatedAt,
            deleted: false,
            seedData: false,
          );

    final roles = <String>[];
    final roleMemberships = element['GlobalRoleMemberships'];
    if (roleMemberships is List) {
      for (final role in roleMemberships) {
        final roleMap = _toNullableMap(role);
        final roleId = roleMap?['GlobalRoleId']?.toString();
        if (roleId != null && roleId.isNotEmpty) {
          roles.add(roleId);
        }
      }
    }

    return UserEntity(
      id: _asString(element['Id']),
      userName: username,
      email: loginEmail,
      personRef: personId,
      dateCreated: createdAt,
      dateLastModified: updatedAt,
      deleted: element['DeletedAt'] != null,
      isLocked: element['LockedAt'] != null,
      rowVersion: _parseInt(element['RowVersion']) ?? 0,
      seedData: _toBool(element['SeedData']),
      person: person,
      roles: roles,
    );
  }

  PersonEntity _mapPerson(
    Map<String, dynamic> personData, {
    required DateTime fallbackCreatedAt,
    required DateTime fallbackUpdatedAt,
  }) {
    final firstName = _asString(personData['FirstName']);
    final lastName = _asString(personData['LastName']);

    return PersonEntity(
      id: _asString(personData['Id']),
      firstName: firstName,
      lastName: lastName,
      fullName: '$firstName $lastName'.trim(),
      dateCreated: _parseDate(
        personData['CreatedAt'],
        fallback: fallbackCreatedAt,
      ),
      dateLastModified: _parseDate(
        personData['UpdatedAt'],
        fallback: fallbackUpdatedAt,
      ),
      deleted: personData['DeletedAt'] != null,
      seedData: _toBool(personData['SeedData']),
    );
  }

  UserRoleEntity _mapRole(Map<String, dynamic> element) {
    final roleNamespace = element['Namespace']?.toString() ?? '';
    final roleName = element['Name']?.toString() ?? '';
    final namespacedRole = roleNamespace.isEmpty || roleName.isEmpty
        ? roleName
        : '$roleNamespace:$roleName';

    return UserRoleEntity(
      id: _asString(element['Id']),
      name: namespacedRole,
      displayName: _asString(element['DisplayName']).isEmpty
          ? namespacedRole
          : _asString(element['DisplayName']),
      dateCreated: _parseDate(element['CreatedAt']),
      dateLastModified: _parseDate(element['UpdatedAt']),
      deleted: element['DeletedAt'] != null,
      seedData: _toBool(element['SeedData']),
    );
  }

  DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      final parsedIso = DateTime.tryParse(value);
      if (parsedIso != null) {
        return parsedIso.toUtc();
      }

      try {
        return _rfc1123DateFormat.parseUtc(value);
      } catch (_) {
        return fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
    }

    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  int _parseCount(dynamic value, {required int fallback}) {
    final parsed = _parseInt(value);
    return parsed ?? fallback;
  }

  int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }

    return false;
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  Map<String, dynamic>? _toNullableMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      // coverage:ignore-line
      return Map<String, dynamic>.from(value); // coverage:ignore-line
    }

    return null;
  }

  String _buildActiveRolesFilter() {
    final roleFilters = <String>[];
    for (final role in appConfig.activeRoles) {
      final roleName = role.name.split(':').last;
      roleFilters.add("Name eq '$roleName'");
    }

    return roleFilters.join(' or ');
  }

  String _escapeRGQLString(String input) {
    return input.replaceAll("'", "''");
  }

  String? currentUserName() {
    final session = parseAuthSession(cookieStore.getCookie('auth'));
    return session?.username;
  }
}
