import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_entry_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_object_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_type_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_summary_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/repositories/rbac_admin_repository.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/providers/rbac_admin_providers.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/widgets/rbac_management_panel.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets('RbacManagementPanel supports tab switching', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('New Global Role'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-permission-objects')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Permission Object'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-permission-types')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Permission Type'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-grants')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Global Grant'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rbac-management-tab-tenant-roles')));
    await tester.pumpAndSettle();
    expect(find.text('New Tenant Role'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-tenant-grants')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Tenant Grant'), findsOneWidget);
  });

  testWidgets('RbacManagementPanel validates role dialogs', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rbac-global-role-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Global Role'));
    await tester.pumpAndSettle();
    expect(find.text('Field cannot be empty.'), findsNWidgets(2));

    await _fillDialogFields(
      tester,
      values: <String>['acp', 'auditor', 'Auditor'],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Global Role'));
    await tester.pumpAndSettle();

    expect(repository.createGlobalRoleInputs, hasLength(1));
    expect(find.text('Create Global Role'), findsNothing);

    await tester.tap(find.byTooltip('Edit global role').first);
    await tester.pumpAndSettle();
    await _fillDialogFields(tester, values: <String>['Administrator Updated']);
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();
    expect(repository.updateGlobalRoleInputs, hasLength(1));
  });

  testWidgets('RbacManagementPanel lifecycle confirmations call actions', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-permission-objects')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Deprecate permission object').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deprecatePermissionObjectInputs, isEmpty);

    await tester.tap(find.byTooltip('Deprecate permission object').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.deprecatePermissionObjectInputs, hasLength(1));

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-permission-types')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Deprecate permission type').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.deprecatePermissionTypeInputs, hasLength(1));

    await tester.tap(find.byKey(const Key('rbac-management-tab-tenant-roles')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Deprecate tenant role').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.deprecateTenantRoleInputs, hasLength(1));

    await tester.tap(find.byTooltip('Reactivate tenant role').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.reactivateTenantRoleInputs, hasLength(1));
  });

  testWidgets('RbacManagementPanel toggles and deletes grants', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-grants')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Set denied').first);
    await tester.pumpAndSettle();
    expect(repository.updateGlobalPermissionEntryInputs, hasLength(1));

    await tester.tap(find.byTooltip('Delete global grant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleteGlobalPermissionEntryInputs, isEmpty);

    await tester.tap(find.byTooltip('Delete global grant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleteGlobalPermissionEntryInputs, hasLength(1));

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-tenant-grants')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Set denied').first);
    await tester.pumpAndSettle();
    expect(repository.updateTenantPermissionEntryInputs, hasLength(1));

    await tester.tap(find.byTooltip('Delete tenant grant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleteTenantPermissionEntryInputs, isEmpty);

    await tester.tap(find.byTooltip('Delete tenant grant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleteTenantPermissionEntryInputs, hasLength(1));
  });

  testWidgets('RbacManagementPanel keeps long grant labels within dialogs', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository()
      ..replacePermissionCatalogForTest(
        permissionObject: RbacPermissionObjectEntity(
          id: 'po-long',
          namespace: 'com.vorsocomputing.mugen.acp',
          name: 'dedup_record',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
        permissionType: RbacPermissionTypeEntity(
          id: 'pt-long',
          namespace: 'com.vorsocomputing.mugen.acp',
          name: 'create',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      );
    await _pumpPanel(tester, repository, surfaceSize: const Size(640, 640));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-grants')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rbac-global-grant-create-button')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RbacManagementPanel enforces tenant-required tabs', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository()..returnNoTenants = true;
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rbac-management-tab-tenant-roles')));
    await tester.pumpAndSettle();
    expect(
      find.text('Select a tenant to manage tenant roles.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-tenant-grants')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Select a tenant to manage tenant grants.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakeRbacAdminRepository repository, {
  Size surfaceSize = const Size(1800, 1300),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        rbacAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
        appNavigatorProvider.overrideWith((ref) => _FakeAppNavigator()),
        snackBarDispatcherProvider.overrideWith((ref) => _RecordingSnackBars()),
      ],
      child: const MaterialApp(home: Scaffold(body: RbacManagementPanel())),
    ),
  );
}

Future<void> _fillDialogFields(
  WidgetTester tester, {
  required List<String> values,
}) async {
  final fields = find.descendant(
    of: find.byType(Dialog).last,
    matching: find.byType(TextFormField),
  );

  for (var i = 0; i < values.length; i++) {
    await tester.enterText(fields.at(i), values[i]);
  }
}

class _TestAuthController extends AuthController {
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
}

class _FakeAppNavigator extends AppNavigator {}

class _RecordingSnackBars extends SnackBarDispatcher {
  @override
  void show(AppNavigator navigator, String content) {}
}

class _FakeRbacAdminRepository implements RbacAdminRepository {
  _FakeRbacAdminRepository()
    : _tenants = const <RbacTenantSummaryEntity>[
        RbacTenantSummaryEntity(
          id: 'tenant-1',
          name: 'Tenant One',
          slug: 'tenant-one',
          status: 'Active',
          rowVersion: 1,
        ),
      ],
      _globalRoles = <RbacRoleEntity>[
        RbacRoleEntity(
          id: 'gr-1',
          namespace: 'acp',
          name: 'administrator',
          displayName: 'Administrator',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          tenantId: null,
          deleted: false,
          seedData: false,
        ),
      ],
      _tenantRoles = <RbacRoleEntity>[
        RbacRoleEntity(
          id: 'tr-1',
          namespace: 'acp',
          name: 'member',
          displayName: 'Member',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          tenantId: 'tenant-1',
          deleted: false,
          seedData: false,
        ),
        RbacRoleEntity(
          id: 'tr-2',
          namespace: 'acp',
          name: 'legacy',
          displayName: 'Legacy',
          status: 'deprecated',
          rowVersion: 2,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          tenantId: 'tenant-1',
          deleted: false,
          seedData: false,
        ),
      ],
      _permissionObjects = <RbacPermissionObjectEntity>[
        RbacPermissionObjectEntity(
          id: 'po-1',
          namespace: 'acp',
          name: 'tenant',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _permissionTypes = <RbacPermissionTypeEntity>[
        RbacPermissionTypeEntity(
          id: 'pt-1',
          namespace: 'acp',
          name: 'manage',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _globalEntries = <RbacPermissionEntryEntity>[
        RbacPermissionEntryEntity(
          id: 'gpe-1',
          tenantId: null,
          roleId: 'gr-1',
          roleDisplayName: 'Administrator',
          permissionObjectId: 'po-1',
          permissionObjectDisplayName: 'acp:tenant',
          permissionTypeId: 'pt-1',
          permissionTypeDisplayName: 'acp:manage',
          permitted: true,
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _tenantEntries = <RbacPermissionEntryEntity>[
        RbacPermissionEntryEntity(
          id: 'tpe-1',
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          roleDisplayName: 'Member',
          permissionObjectId: 'po-1',
          permissionObjectDisplayName: 'acp:tenant',
          permissionTypeId: 'pt-1',
          permissionTypeDisplayName: 'acp:manage',
          permitted: true,
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ];

  final List<RbacTenantSummaryEntity> _tenants;
  final List<RbacRoleEntity> _globalRoles;
  final List<RbacRoleEntity> _tenantRoles;
  final List<RbacPermissionObjectEntity> _permissionObjects;
  final List<RbacPermissionTypeEntity> _permissionTypes;
  final List<RbacPermissionEntryEntity> _globalEntries;
  final List<RbacPermissionEntryEntity> _tenantEntries;

  bool returnNoTenants = false;
  bool mutationShouldSucceed = true;

  void replacePermissionCatalogForTest({
    required RbacPermissionObjectEntity permissionObject,
    required RbacPermissionTypeEntity permissionType,
  }) {
    _permissionObjects
      ..clear()
      ..add(permissionObject);
    _permissionTypes
      ..clear()
      ..add(permissionType);
  }

  final List<RbacCreateGlobalRoleInput> createGlobalRoleInputs =
      <RbacCreateGlobalRoleInput>[];
  final List<RbacUpdateGlobalRoleInput> updateGlobalRoleInputs =
      <RbacUpdateGlobalRoleInput>[];
  final List<RbacTenantRoleLifecycleInput> deprecateTenantRoleInputs =
      <RbacTenantRoleLifecycleInput>[];
  final List<RbacTenantRoleLifecycleInput> reactivateTenantRoleInputs =
      <RbacTenantRoleLifecycleInput>[];
  final List<RbacPermissionObjectLifecycleInput>
  deprecatePermissionObjectInputs = <RbacPermissionObjectLifecycleInput>[];
  final List<RbacPermissionTypeLifecycleInput> deprecatePermissionTypeInputs =
      <RbacPermissionTypeLifecycleInput>[];
  final List<RbacUpdateGlobalPermissionEntryInput>
  updateGlobalPermissionEntryInputs = <RbacUpdateGlobalPermissionEntryInput>[];
  final List<RbacDeleteGlobalPermissionEntryInput>
  deleteGlobalPermissionEntryInputs = <RbacDeleteGlobalPermissionEntryInput>[];
  final List<RbacUpdateTenantPermissionEntryInput>
  updateTenantPermissionEntryInputs = <RbacUpdateTenantPermissionEntryInput>[];
  final List<RbacDeleteTenantPermissionEntryInput>
  deleteTenantPermissionEntryInputs = <RbacDeleteTenantPermissionEntryInput>[];

  @override
  Future<Result<void>> createGlobalPermissionEntry(
    RbacCreateGlobalPermissionEntryInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> createGlobalRole(RbacCreateGlobalRoleInput input) async {
    createGlobalRoleInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> createPermissionObject(
    RbacCreatePermissionObjectInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> createPermissionType(
    RbacCreatePermissionTypeInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> createTenantPermissionEntry(
    RbacCreateTenantPermissionEntryInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> createTenantRole(RbacCreateTenantRoleInput input) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> deleteGlobalPermissionEntry(
    RbacDeleteGlobalPermissionEntryInput input,
  ) async {
    deleteGlobalPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deleteTenantPermissionEntry(
    RbacDeleteTenantPermissionEntryInput input,
  ) async {
    deleteTenantPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deprecatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    deprecatePermissionObjectInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deprecatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    deprecatePermissionTypeInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deprecateTenantRole(
    RbacTenantRoleLifecycleInput input,
  ) async {
    deprecateTenantRoleInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<List<RbacPermissionEntryEntity>>> fetchGlobalPermissionEntries({
    int top = 200,
  }) async {
    return Result<List<RbacPermissionEntryEntity>>.success(_globalEntries);
  }

  @override
  Future<Result<List<RbacRoleEntity>>> fetchGlobalRoles({int top = 200}) async {
    return Result<List<RbacRoleEntity>>.success(_globalRoles);
  }

  @override
  Future<Result<List<RbacPermissionObjectEntity>>> fetchPermissionObjects({
    int top = 200,
  }) async {
    return Result<List<RbacPermissionObjectEntity>>.success(_permissionObjects);
  }

  @override
  Future<Result<List<RbacPermissionTypeEntity>>> fetchPermissionTypes({
    int top = 200,
  }) async {
    return Result<List<RbacPermissionTypeEntity>>.success(_permissionTypes);
  }

  @override
  Future<Result<List<RbacTenantSummaryEntity>>> fetchTenants({
    int top = 200,
  }) async {
    if (returnNoTenants) {
      return const Result<List<RbacTenantSummaryEntity>>.success(
        <RbacTenantSummaryEntity>[],
      );
    }

    return Result<List<RbacTenantSummaryEntity>>.success(_tenants);
  }

  @override
  Future<Result<List<RbacPermissionEntryEntity>>> fetchTenantPermissionEntries({
    required String tenantId,
    int top = 200,
  }) async {
    return Result<List<RbacPermissionEntryEntity>>.success(_tenantEntries);
  }

  @override
  Future<Result<List<RbacRoleEntity>>> fetchTenantRoles({
    required String tenantId,
    int top = 200,
  }) async {
    return Result<List<RbacRoleEntity>>.success(_tenantRoles);
  }

  @override
  Future<Result<void>> reactivatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> reactivatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> reactivateTenantRole(
    RbacTenantRoleLifecycleInput input,
  ) async {
    reactivateTenantRoleInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateGlobalPermissionEntry(
    RbacUpdateGlobalPermissionEntryInput input,
  ) async {
    updateGlobalPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateGlobalRole(RbacUpdateGlobalRoleInput input) async {
    updateGlobalRoleInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateTenantPermissionEntry(
    RbacUpdateTenantPermissionEntryInput input,
  ) async {
    updateTenantPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateTenantRole(RbacUpdateTenantRoleInput input) async {
    return _mutationResult();
  }

  Result<void> _mutationResult() {
    if (!mutationShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('mutation failed'));
    }

    return const Result<void>.success(null);
  }
}
