import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
import 'package:mugen_ui/features/rbac_admin/infrastructure/repositories/rbac_admin_repository_impl.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  group('RbacAdminRepositoryImpl fetches', () {
    test('builds expected requests and maps expanded payloads', () async {
      final fixture = _RbacAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'tenant-1',
                  'Name': 'Tenant One',
                  'Slug': 'tenant-one',
                  'Status': 'Active',
                  'RowVersion': '3',
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'gr-1',
                  'Namespace': 'acp',
                  'Name': 'administrator',
                  'DisplayName': 'Administrator',
                  'Status': 'active',
                  'RowVersion': 4,
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': '2026-01-02T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': false,
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'tr-1',
                  'Namespace': 'acp',
                  'Name': 'viewer',
                  'DisplayName': '',
                  'Status': 'deprecated',
                  'RowVersion': 5,
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': '2026-01-02T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': false,
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'po-1',
                  'Namespace': 'acp',
                  'Name': 'tenant',
                  'Status': 'active',
                  'RowVersion': 1,
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': '2026-01-02T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': false,
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'pt-1',
                  'Namespace': 'acp',
                  'Name': 'manage',
                  'Status': 'active',
                  'RowVersion': 2,
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': '2026-01-02T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': true,
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'gpe-1',
                  'GlobalRoleId': 'gr-1',
                  'PermissionObjectId': 'po-1',
                  'PermissionTypeId': 'pt-1',
                  'Permitted': true,
                  'RowVersion': 6,
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': '2026-01-02T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': false,
                  'GlobalRole': <String, dynamic>{
                    'Namespace': 'acp',
                    'Name': 'administrator',
                    'DisplayName': '',
                  },
                  'PermissionObject': <String, dynamic>{
                    'Namespace': 'acp',
                    'Name': 'tenant',
                  },
                  'PermissionType': <String, dynamic>{
                    'Namespace': 'acp',
                    'Name': 'manage',
                  },
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'tpe-1',
                  'RoleId': 'tr-1',
                  'PermissionObjectId': 'po-1',
                  'PermissionTypeId': 'pt-1',
                  'Permitted': false,
                  'RowVersion': 9,
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': '2026-01-02T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': false,
                  'Role': <String, dynamic>{
                    'Namespace': 'acp',
                    'Name': 'viewer',
                    'DisplayName': 'Viewer',
                  },
                  'PermissionObject': <String, dynamic>{
                    'Namespace': 'acp',
                    'Name': 'tenant',
                  },
                  'PermissionType': <String, dynamic>{
                    'Namespace': 'acp',
                    'Name': 'manage',
                  },
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'rm-1',
                  'TenantId': 'tenant-1',
                  'RoleId': 'tr-1',
                  'UserId': 'user-1',
                  'RowVersion': 10,
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': '2026-01-02T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': false,
                  'Role': <String, dynamic>{
                    'Namespace': 'acp',
                    'Name': 'viewer',
                    'DisplayName': '',
                  },
                  'User': <String, dynamic>{
                    'Username': 'alice',
                    'LoginEmail': 'alice@example.com',
                  },
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'tm-1',
                  'TenantId': 'tenant-1',
                  'UserId': 'user-1',
                  'Status': 'active',
                  'DeletedAt': null,
                  'User': <String, dynamic>{
                    'Username': 'alice',
                    'LoginEmail': 'alice@example.com',
                  },
                },
              ],
            }),
          ),
        ],
      );

      final tenants = await fixture.repository.fetchTenants(top: 150);
      final globalRoles = await fixture.repository.fetchGlobalRoles(top: 77);
      final tenantRoles = await fixture.repository.fetchTenantRoles(
        tenantId: 'tenant-1',
        top: 66,
      );
      final permissionObjects = await fixture.repository.fetchPermissionObjects(
        top: 55,
      );
      final permissionTypes = await fixture.repository.fetchPermissionTypes(
        top: 44,
      );
      final globalEntries = await fixture.repository
          .fetchGlobalPermissionEntries(top: 33);
      final tenantEntries = await fixture.repository
          .fetchTenantPermissionEntries(tenantId: 'tenant-1', top: 22);
      final roleMemberships = await fixture.repository
          .fetchTenantRoleMemberships(tenantId: 'tenant-1', top: 11);
      final tenantMembers = await fixture.repository.fetchTenantMembers(
        tenantId: 'tenant-1',
        top: 10,
      );

      expect(tenants.isSuccess, isTrue);
      expect(tenants.data!.single.name, 'Tenant One');

      expect(globalRoles.isSuccess, isTrue);
      expect(globalRoles.data!.single.displayName, 'Administrator');

      expect(tenantRoles.isSuccess, isTrue);
      expect(tenantRoles.data!.single.displayName, 'acp:viewer');
      expect(tenantRoles.data!.single.status, 'deprecated');

      expect(permissionObjects.isSuccess, isTrue);
      expect(permissionObjects.data!.single.key, 'acp:tenant');

      expect(permissionTypes.isSuccess, isTrue);
      expect(permissionTypes.data!.single.seedData, isTrue);

      expect(globalEntries.isSuccess, isTrue);
      expect(globalEntries.data!.single.roleDisplayName, 'acp:administrator');
      expect(
        globalEntries.data!.single.permissionObjectDisplayName,
        'acp:tenant',
      );
      expect(
        globalEntries.data!.single.permissionTypeDisplayName,
        'acp:manage',
      );

      expect(tenantEntries.isSuccess, isTrue);
      expect(tenantEntries.data!.single.roleDisplayName, 'Viewer');
      expect(tenantEntries.data!.single.tenantId, 'tenant-1');
      expect(tenantEntries.data!.single.permitted, isFalse);

      expect(roleMemberships.isSuccess, isTrue);
      expect(roleMemberships.data!.single.roleDisplayName, 'acp:viewer');
      expect(roleMemberships.data!.single.roleKey, 'acp:viewer');
      expect(roleMemberships.data!.single.userDisplayName, 'alice@example.com');
      expect(roleMemberships.data!.single.userEmail, 'alice@example.com');
      expect(roleMemberships.data!.single.rowVersion, 10);

      expect(tenantMembers.isSuccess, isTrue);
      expect(tenantMembers.data!.single.membershipId, 'tm-1');
      expect(tenantMembers.data!.single.displayName, 'alice@example.com');
      expect(tenantMembers.data!.single.status, 'active');

      expect(fixture.client.requests, hasLength(9));
      expect(fixture.client.requests[0].path, 'core/acp/v1/Tenants');
      expect(fixture.client.requests[0].queryParameters[r'$top'], 150);
      expect(
        fixture.client.requests[0].queryParameters[r'$orderby'],
        'Name asc',
      );

      expect(fixture.client.requests[1].path, 'core/acp/v1/GlobalRoles');
      expect(
        fixture.client.requests[1].queryParameters[r'$orderby'],
        'DisplayName asc',
      );

      expect(
        fixture.client.requests[2].path,
        'core/acp/v1/tenants/tenant-1/Roles',
      );
      expect(fixture.client.requests[2].queryParameters[r'$top'], 66);

      expect(fixture.client.requests[3].path, 'core/acp/v1/PermissionObjects');
      expect(
        fixture.client.requests[3].queryParameters[r'$orderby'],
        'Namespace asc,Name asc',
      );

      expect(fixture.client.requests[4].path, 'core/acp/v1/PermissionTypes');
      expect(fixture.client.requests[4].queryParameters[r'$top'], 44);

      expect(
        fixture.client.requests[5].path,
        'core/acp/v1/GlobalPermissionEntries',
      );
      expect(
        fixture.client.requests[5].queryParameters[r'$expand'],
        'GlobalRole,PermissionObject,PermissionType',
      );

      expect(
        fixture.client.requests[6].path,
        'core/acp/v1/tenants/tenant-1/PermissionEntries',
      );
      expect(
        fixture.client.requests[6].queryParameters[r'$expand'],
        'Role,PermissionObject,PermissionType',
      );

      expect(
        fixture.client.requests[7].path,
        'core/acp/v1/tenants/tenant-1/RoleMemberships',
      );
      expect(fixture.client.requests[7].queryParameters[r'$top'], 11);
      expect(
        fixture.client.requests[7].queryParameters[r'$orderby'],
        'CreatedAt desc',
      );
      expect(
        fixture.client.requests[7].queryParameters[r'$expand'],
        'Role,User',
      );

      expect(
        fixture.client.requests[8].path,
        'core/acp/v1/tenants/tenant-1/TenantMemberships',
      );
      expect(fixture.client.requests[8].queryParameters[r'$top'], 10);
      expect(fixture.client.requests[8].queryParameters[r'$expand'], 'User');
    });
  });

  group('RbacAdminRepositoryImpl fetch failure branches', () {
    test('returns API failures for each fetch endpoint', () async {
      final fixture = _RbacAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 429,
            body: jsonEncode(<String, dynamic>{
              'detail': 'Tenant query throttled',
            }),
          ),
          (_) => _response(
            statusCode: 400,
            body: jsonEncode(<String, dynamic>{
              'error': 'Tenant role lookup failed',
            }),
          ),
          (_) => _response(
            statusCode: 403,
            body: jsonEncode(<String, dynamic>{
              'description': 'Permission type access denied',
            }),
          ),
          (_) => _response(
            statusCode: 500,
            body: jsonEncode(<String, dynamic>{
              'message': 'Global permission entry read failed',
            }),
          ),
          (_) => _response(
            statusCode: 503,
            body: jsonEncode(<String, dynamic>{
              'message': 'Tenant permission entry read failed',
            }),
          ),
          (_) => _response(
            statusCode: 409,
            body: jsonEncode(<String, dynamic>{
              'message': 'Role membership read conflict',
            }),
          ),
          (_) => _response(
            statusCode: 500,
            body: jsonEncode(<String, dynamic>{
              'message': 'Tenant member read failed',
            }),
          ),
        ],
      );

      final tenants = await fixture.repository.fetchTenants();
      final tenantRoles = await fixture.repository.fetchTenantRoles(
        tenantId: 'tenant-1',
      );
      final permissionTypes = await fixture.repository.fetchPermissionTypes();
      final globalEntries = await fixture.repository
          .fetchGlobalPermissionEntries();
      final tenantEntries = await fixture.repository
          .fetchTenantPermissionEntries(tenantId: 'tenant-1');
      final roleMemberships = await fixture.repository
          .fetchTenantRoleMemberships(tenantId: 'tenant-1');
      final tenantMembers = await fixture.repository.fetchTenantMembers(
        tenantId: 'tenant-1',
      );

      expect(tenants.isFailure, isTrue);
      expect(tenants.failure, isA<ApiFailure>());
      expect((tenants.failure as ApiFailure).statusCode, 429);
      expect(tenants.failure!.message, 'Tenant query throttled');

      expect(tenantRoles.isFailure, isTrue);
      expect(tenantRoles.failure, isA<ApiFailure>());
      expect(tenantRoles.failure!.message, 'Tenant role lookup failed');

      expect(permissionTypes.isFailure, isTrue);
      expect(permissionTypes.failure, isA<ApiFailure>());
      expect(permissionTypes.failure!.message, 'Permission type access denied');

      expect(globalEntries.isFailure, isTrue);
      expect(globalEntries.failure, isA<ApiFailure>());
      expect(
        globalEntries.failure!.message,
        'Global permission entry read failed',
      );

      expect(tenantEntries.isFailure, isTrue);
      expect(tenantEntries.failure, isA<ApiFailure>());
      expect(
        tenantEntries.failure!.message,
        'Tenant permission entry read failed',
      );

      expect(roleMemberships.isFailure, isTrue);
      expect(roleMemberships.failure, isA<ApiFailure>());
      expect(roleMemberships.failure!.message, 'Role membership read conflict');

      expect(tenantMembers.isFailure, isTrue);
      expect(tenantMembers.failure, isA<ApiFailure>());
      expect(tenantMembers.failure!.message, 'Tenant member read failed');
    });

    test('maps RFC dates and numeric/string coercions', () async {
      final fixture = _RbacAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'pt-coerce',
                  'Namespace': 'acp',
                  'Name': 'manage',
                  'Status': 'active',
                  'RowVersion': 7.75,
                  'CreatedAt': 'Wed, 01 Jan 2025 00:00:00 GMT',
                  'UpdatedAt': 'invalid-date',
                  'DeletedAt': null,
                  'SeedData': 1,
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'po-coerce',
                  'Namespace': 'acp',
                  'Name': 'tenant',
                  'Status': 'active',
                  'RowVersion': 2,
                  'CreatedAt': 12345,
                  'UpdatedAt': null,
                  'DeletedAt': null,
                  'SeedData': 0,
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'gpe-coerce',
                  'GlobalRoleId': 'gr-1',
                  'PermissionObjectId': 'po-1',
                  'PermissionTypeId': 'pt-1',
                  'Permitted': '1',
                  'RowVersion': '9',
                  'CreatedAt': '',
                  'UpdatedAt': '',
                  'DeletedAt': null,
                  'SeedData': 'true',
                  'GlobalRole': <String, dynamic>{
                    'Namespace': '',
                    'Name': 'auditor',
                    'DisplayName': '',
                  },
                  'PermissionObject': <String, dynamic>{
                    'Namespace': '',
                    'Name': 'tenant',
                  },
                  'PermissionType': <String, dynamic>{
                    'Namespace': '',
                    'Name': 'manage',
                  },
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'rm-coerce',
                  'TenantId': '',
                  'RoleId': 'role-fallback',
                  'UserId': 'user-fallback',
                  'RowVersion': '11',
                  'CreatedAt': '',
                  'UpdatedAt': '',
                  'DeletedAt': null,
                  'SeedData': 'false',
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'tm-coerce',
                  'TenantId': '',
                  'UserId': 'tenant-user-fallback',
                  'Status': 'active',
                  'DeletedAt': null,
                },
              ],
            }),
          ),
        ],
      );

      final permissionTypes = await fixture.repository.fetchPermissionTypes();
      final permissionObjects = await fixture.repository
          .fetchPermissionObjects();
      final globalEntries = await fixture.repository
          .fetchGlobalPermissionEntries();
      final roleMemberships = await fixture.repository
          .fetchTenantRoleMemberships(tenantId: 'tenant-1');
      final tenantMembers = await fixture.repository.fetchTenantMembers(
        tenantId: 'tenant-1',
      );

      expect(permissionTypes.isSuccess, isTrue);
      final type = permissionTypes.data!.single;
      expect(type.rowVersion, 7);
      expect(type.dateCreated, DateTime.utc(2025, 1, 1));
      expect(
        type.dateLastModified,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(type.seedData, isTrue);

      expect(permissionObjects.isSuccess, isTrue);
      final object = permissionObjects.data!.single;
      expect(
        object.dateCreated,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(
        object.dateLastModified,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(object.seedData, isFalse);

      expect(globalEntries.isSuccess, isTrue);
      final entry = globalEntries.data!.single;
      expect(entry.permitted, isTrue);
      expect(entry.seedData, isTrue);
      expect(entry.roleDisplayName, 'auditor');
      expect(entry.permissionObjectDisplayName, 'tenant');
      expect(entry.permissionTypeDisplayName, 'manage');
      expect(
        entry.dateCreated,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(
        entry.dateLastModified,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

      expect(roleMemberships.isSuccess, isTrue);
      final membership = roleMemberships.data!.single;
      expect(membership.tenantId, 'tenant-1');
      expect(membership.roleDisplayName, 'role-fallback');
      expect(membership.roleKey, 'role-fallback');
      expect(membership.userDisplayName, 'user-fallback');
      expect(membership.rowVersion, 11);

      expect(tenantMembers.isSuccess, isTrue);
      final member = tenantMembers.data!.single;
      expect(member.tenantId, 'tenant-1');
      expect(member.displayName, 'tenant-user-fallback');
    });
  });

  group('RbacAdminRepositoryImpl mutations', () {
    test('sends expected CRUD and action requests', () async {
      final fixture = _RbacAdminFixture(
        handlers: List<_AuthHandler>.filled(
          20,
          (_) => _response(statusCode: 204),
        ),
      );

      await fixture.repository.createGlobalRole(
        const RbacCreateGlobalRoleInput(
          namespace: 'acp',
          name: 'auditor',
          displayName: 'Auditor',
        ),
      );
      await fixture.repository.updateGlobalRole(
        const RbacUpdateGlobalRoleInput(
          roleId: 'gr-1',
          displayName: 'Auditor Plus',
          rowVersion: 1,
        ),
      );

      await fixture.repository.createTenantRole(
        const RbacCreateTenantRoleInput(
          tenantId: 'tenant-1',
          namespace: 'acp',
          name: 'member',
          displayName: 'Member',
        ),
      );
      await fixture.repository.updateTenantRole(
        const RbacUpdateTenantRoleInput(
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          displayName: 'Member Plus',
          rowVersion: 2,
        ),
      );
      await fixture.repository.deprecateTenantRole(
        const RbacTenantRoleLifecycleInput(
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          rowVersion: 3,
        ),
      );
      await fixture.repository.reactivateTenantRole(
        const RbacTenantRoleLifecycleInput(
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          rowVersion: 4,
        ),
      );

      await fixture.repository.createPermissionObject(
        const RbacCreatePermissionObjectInput(namespace: 'acp', name: 'tenant'),
      );
      await fixture.repository.deprecatePermissionObject(
        const RbacPermissionObjectLifecycleInput(
          permissionObjectId: 'po-1',
          rowVersion: 5,
        ),
      );
      await fixture.repository.reactivatePermissionObject(
        const RbacPermissionObjectLifecycleInput(
          permissionObjectId: 'po-1',
          rowVersion: 6,
        ),
      );

      await fixture.repository.createPermissionType(
        const RbacCreatePermissionTypeInput(namespace: 'acp', name: 'manage'),
      );
      await fixture.repository.deprecatePermissionType(
        const RbacPermissionTypeLifecycleInput(
          permissionTypeId: 'pt-1',
          rowVersion: 7,
        ),
      );
      await fixture.repository.reactivatePermissionType(
        const RbacPermissionTypeLifecycleInput(
          permissionTypeId: 'pt-1',
          rowVersion: 8,
        ),
      );

      await fixture.repository.createGlobalPermissionEntry(
        const RbacCreateGlobalPermissionEntryInput(
          globalRoleId: 'gr-1',
          permissionObjectId: 'po-1',
          permissionTypeId: 'pt-1',
          permitted: true,
        ),
      );
      await fixture.repository.updateGlobalPermissionEntry(
        const RbacUpdateGlobalPermissionEntryInput(
          entryId: 'gpe-1',
          rowVersion: 9,
          permitted: false,
        ),
      );
      await fixture.repository.deleteGlobalPermissionEntry(
        const RbacDeleteGlobalPermissionEntryInput(
          entryId: 'gpe-1',
          rowVersion: 10,
        ),
      );

      await fixture.repository.createTenantPermissionEntry(
        const RbacCreateTenantPermissionEntryInput(
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          permissionObjectId: 'po-1',
          permissionTypeId: 'pt-1',
          permitted: true,
        ),
      );
      await fixture.repository.updateTenantPermissionEntry(
        const RbacUpdateTenantPermissionEntryInput(
          tenantId: 'tenant-1',
          entryId: 'tpe-1',
          rowVersion: 11,
          permitted: false,
        ),
      );
      await fixture.repository.deleteTenantPermissionEntry(
        const RbacDeleteTenantPermissionEntryInput(
          tenantId: 'tenant-1',
          entryId: 'tpe-1',
          rowVersion: 12,
        ),
      );
      await fixture.repository.createTenantRoleMembership(
        const RbacCreateRoleMembershipInput(
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          userId: 'user-1',
        ),
      );
      await fixture.repository.deleteTenantRoleMembership(
        const RbacDeleteRoleMembershipInput(
          tenantId: 'tenant-1',
          membershipId: 'rm-1',
          rowVersion: 13,
        ),
      );

      expect(fixture.client.requests, hasLength(20));
      expect(fixture.client.requests[0].path, 'core/acp/v1/GlobalRoles');
      expect(fixture.client.requests[0].body, <String, dynamic>{
        'Namespace': 'acp',
        'Name': 'auditor',
        'DisplayName': 'Auditor',
      });

      expect(fixture.client.requests[1].method, HttpMethod.patch);
      expect(fixture.client.requests[1].path, 'core/acp/v1/GlobalRoles/gr-1');
      expect(fixture.client.requests[1].body, <String, dynamic>{
        'DisplayName': 'Auditor Plus',
        'RowVersion': 1,
      });

      expect(
        fixture.client.requests[2].path,
        'core/acp/v1/tenants/tenant-1/Roles',
      );
      expect(
        fixture.client.requests[4].path,
        r'core/acp/v1/tenants/tenant-1/Roles/tr-1/$action/deprecate',
      );
      expect(
        fixture.client.requests[5].path,
        r'core/acp/v1/tenants/tenant-1/Roles/tr-1/$action/reactivate',
      );

      expect(fixture.client.requests[6].path, 'core/acp/v1/PermissionObjects');
      expect(
        fixture.client.requests[7].path,
        r'core/acp/v1/PermissionObjects/po-1/$action/deprecate',
      );
      expect(
        fixture.client.requests[8].path,
        r'core/acp/v1/PermissionObjects/po-1/$action/reactivate',
      );

      expect(fixture.client.requests[9].path, 'core/acp/v1/PermissionTypes');
      expect(
        fixture.client.requests[10].path,
        r'core/acp/v1/PermissionTypes/pt-1/$action/deprecate',
      );
      expect(
        fixture.client.requests[11].path,
        r'core/acp/v1/PermissionTypes/pt-1/$action/reactivate',
      );

      expect(
        fixture.client.requests[12].path,
        'core/acp/v1/GlobalPermissionEntries',
      );
      expect(
        fixture.client.requests[13].path,
        'core/acp/v1/GlobalPermissionEntries/gpe-1',
      );
      expect(fixture.client.requests[14].method, HttpMethod.delete);
      expect(fixture.client.requests[14].body, <String, dynamic>{
        'RowVersion': 10,
      });

      expect(
        fixture.client.requests[15].path,
        'core/acp/v1/tenants/tenant-1/PermissionEntries',
      );
      expect(
        fixture.client.requests[16].path,
        'core/acp/v1/tenants/tenant-1/PermissionEntries/tpe-1',
      );
      expect(fixture.client.requests[17].method, HttpMethod.delete);
      expect(fixture.client.requests[17].body, <String, dynamic>{
        'RowVersion': 12,
      });

      expect(
        fixture.client.requests[18].path,
        'core/acp/v1/tenants/tenant-1/RoleMemberships',
      );
      expect(fixture.client.requests[18].body, <String, dynamic>{
        'TenantId': 'tenant-1',
        'RoleId': 'tr-1',
        'UserId': 'user-1',
      });
      expect(fixture.client.requests[19].method, HttpMethod.delete);
      expect(
        fixture.client.requests[19].path,
        'core/acp/v1/tenants/tenant-1/RoleMemberships/rm-1',
      );
      expect(fixture.client.requests[19].body, <String, dynamic>{
        'RowVersion': 13,
      });
    });
  });

  group('RbacAdminRepositoryImpl failures', () {
    test(
      'maps API failure message, session expiration, and network failure',
      () async {
        final apiFixture = _RbacAdminFixture(
          handlers: <_AuthHandler>[
            (_) => _response(
              statusCode: 400,
              body: jsonEncode(<String, dynamic>{
                'message': 'Bad request payload',
              }),
            ),
          ],
        );
        final api = await apiFixture.repository.createGlobalRole(
          const RbacCreateGlobalRoleInput(
            namespace: 'acp',
            name: 'bad',
            displayName: 'Bad',
          ),
        );
        expect(api.isFailure, isTrue);
        expect(api.failure, isA<ApiFailure>());
        expect((api.failure as ApiFailure).statusCode, 400);
        expect(api.failure!.message, 'Bad request payload');

        final textApiFixture = _RbacAdminFixture(
          handlers: <_AuthHandler>[
            (_) => _response(statusCode: 405, body: 'Method not allowed'),
          ],
        );
        final textApi = await textApiFixture.repository.deprecatePermissionType(
          const RbacPermissionTypeLifecycleInput(
            permissionTypeId: 'pt-1',
            rowVersion: 1,
          ),
        );
        expect(textApi.isFailure, isTrue);
        expect(textApi.failure, isA<ApiFailure>());
        expect(textApi.failure!.message, 'Method not allowed');

        final sessionFixture = _RbacAdminFixture(
          handlers: <_AuthHandler>[
            (_) => _response(statusCode: 401, sessionExpired: true),
          ],
        );
        final session = await sessionFixture.repository.fetchGlobalRoles();
        expect(session.isFailure, isTrue);
        expect(session.failure, isA<SessionExpiredFailure>());
        expect(sessionFixture.cookieStore.removed, contains('auth:/'));

        final networkFixture = _RbacAdminFixture(
          handlers: <_AuthHandler>[(_) => throw Exception('boom')],
        );
        final network = await networkFixture.repository
            .fetchPermissionObjects();
        expect(network.isFailure, isTrue);
        expect(network.failure, isA<NetworkFailure>());
      },
    );

    test('maps session expiration during mutation calls', () async {
      final fixture = _RbacAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );

      final result = await fixture.repository.createGlobalRole(
        const RbacCreateGlobalRoleInput(
          namespace: 'acp',
          name: 'member',
          displayName: 'Member',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<SessionExpiredFailure>());
      expect(fixture.cookieStore.removed, contains('auth:/'));
    });
  });
}

class _RbacAdminFixture {
  _RbacAdminFixture({List<_AuthHandler>? handlers})
    : cookieStore = _MemoryCookieStore(),
      client = _QueueAuthenticatedHttpClient(
        handlers ?? const <_AuthHandler>[],
      ) {
    repository = RbacAdminRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      authenticatedHttpClient: client,
    );
  }

  final _MemoryCookieStore cookieStore;
  final _QueueAuthenticatedHttpClient client;
  late final RbacAdminRepositoryImpl repository;
}

typedef _AuthHandler = FutureOr<AuthenticatedResponse> Function(AcpRequest);

class _QueueAuthenticatedHttpClient extends AuthenticatedHttpClient {
  _QueueAuthenticatedHttpClient(List<_AuthHandler> handlers)
    : _handlers = Queue<_AuthHandler>.from(handlers),
      super(
        httpClient: AcpHttpClient(
          baseUrl: 'https://example.com/api',
          transport: _NoopHttpTransport(),
        ),
        cookieStore: _MemoryCookieStore(),
        refreshPath: 'core/acp/v1/auth/refresh',
      );

  final Queue<_AuthHandler> _handlers;
  final List<AcpRequest> requests = <AcpRequest>[];

  @override
  Future<AuthenticatedResponse> send(AcpRequest request) async {
    requests.add(request);
    if (_handlers.isEmpty) {
      throw StateError('No queued response for request: ${request.path}');
    }

    return await _handlers.removeFirst().call(request);
  }
}

class _MemoryCookieStore implements CookieStore {
  final Map<String, String> _cookies = <String, String>{};
  final List<String> removed = <String>[];

  @override
  String? getCookie(String key) => _cookies[key];

  @override
  void removeCookie(String key, String path) {
    removed.add('$key:$path');
    _cookies.remove(key);
  }

  @override
  void setCookie(String key, String value, int maxAge, String path) {
    _cookies[key] = value;
  }
}

class _NoopHttpTransport implements HttpTransport {
  @override
  void close() {}

  @override
  Future<HttpResponse> execute(HttpRequest request) async {
    throw UnimplementedError('Noop transport should not be called in tests.');
  }
}

AuthenticatedResponse _response({
  required int statusCode,
  String body = '',
  bool sessionExpired = false,
}) {
  return AuthenticatedResponse(
    response: HttpResponse(
      statusCode: statusCode,
      body: body,
      headers: const <String, String>{},
    ),
    sessionExpired: sessionExpired,
  );
}
