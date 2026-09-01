import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/definition/core_modules.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/core_provisioning/domain/entities/core_plugin_access.dart';
import 'package:mugen_ui/features/core_provisioning/presentation/providers/core_provisioning_providers.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_admin_resources.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/presentation/providers/knowledge_pack_admin_providers.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/presentation/widgets/knowledge_pack_panel.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/infrastructure/knowledge_pack_admin_repository.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/features/shell/application/shell_route_access.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_workspace_navigation.dart';

import '../../../test_support/acp_workspace_target_controller.dart';
import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test(
    'Knowledge Pack route visibility follows core.fw.knowledge_pack',
    () async {
      final route = buildDefaultAppDefinition().shellRoutes.firstWhere(
        (item) => item.id == RouteIds.knowledgePacks,
      );
      expect(
        route.availabilityProvider,
        same(knowledgePackShellAvailabilityProvider),
      );
      final roles = <String>[knowledgePackConfiguratorRole];
      expect(
        resolveShellRouteAccess(
          shellRoutes: <ShellRouteDefinition>[route],
          defaultShellRouteId: route.id,
          sessionRoles: roles,
          requestedRoute: route.id,
          routeAvailabilities: <String, ShellRouteAvailability>{
            route.id: const ShellRouteAvailability.unavailable('disabled'),
          },
        ).allowedRoutes,
        isEmpty,
      );
      expect(
        resolveShellRouteAccess(
          shellRoutes: <ShellRouteDefinition>[route],
          defaultShellRouteId: route.id,
          sessionRoles: roles,
          requestedRoute: route.id,
          routeAvailabilities: <String, ShellRouteAvailability>{
            route.id: const ShellRouteAvailability.available(),
          },
        ).allowedRouteIds,
        <String>{route.id},
      );

      final pending = Completer<CorePluginAccess>();
      final container = ProviderContainer(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith((ref, token) => pending.future),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        knowledgePackShellAvailabilityProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      expect(
        container.read(knowledgePackShellAvailabilityProvider).status,
        ShellRouteAvailabilityStatus.pending,
      );
      pending.completeError(StateError('unavailable'));
      await expectLater(
        container.read(
          corePluginAccessProvider(knowledgePackPluginToken).future,
        ),
        throwsStateError,
      );
      await pumpEventQueue();
      expect(
        container.read(knowledgePackShellAvailabilityProvider).status,
        ShellRouteAvailabilityStatus.unavailable,
      );

      for (final access in const <CorePluginAccess>[
        CorePluginAccess.available(),
        CorePluginAccess(
          status: CorePluginAccessStatus.unavailable,
          message: 'disabled',
        ),
      ]) {
        final resolved = ProviderContainer(
          overrides: <Override>[
            corePluginAccessProvider.overrideWith((ref, token) async => access),
          ],
        );
        final listener = resolved.listen(
          knowledgePackShellAvailabilityProvider,
          (_, _) {},
          fireImmediately: true,
        );
        await pumpEventQueue();
        expect(
          resolved.read(knowledgePackShellAvailabilityProvider).status,
          access.isAvailable
              ? ShellRouteAvailabilityStatus.available
              : ShellRouteAvailabilityStatus.unavailable,
        );
        listener.close();
        resolved.dispose();
      }
    },
  );

  test('knowledge pack providers expose descriptor-backed controller', () {
    final repositoryContainer = ProviderContainer();
    addTearDown(repositoryContainer.dispose);
    expect(
      repositoryContainer.read(knowledgePackAdminRepositoryProvider),
      isA<KnowledgePackAdminRepository>(),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        knowledgePackAdminRepositoryProvider.overrideWithValue(
          FakeAcpAdminRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      knowledgePackAdminControllerProvider.notifier,
    );
    expect(controller.descriptors, hasLength(7));
    expect(controller.descriptors.first.title, 'Packs');
    expect(controller.descriptors[1].entityActions, hasLength(7));
    expect(controller.descriptors[4].allowCreate, isFalse);
    expect(controller.descriptors[5].title, 'Projections');
    expect(controller.descriptors.last.title, 'Scopes');
  });

  testWidgets('KnowledgePackPanel renders description and tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          knowledgePackAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: KnowledgePackPanel())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Packs'), findsWidgets);
    expect(find.text('Versions'), findsOneWidget);
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Entry Revisions'), findsOneWidget);
    expect(find.text('Approvals'), findsOneWidget);
    expect(find.text('Projections'), findsOneWidget);
    expect(find.text('Scopes'), findsOneWidget);
    expect(
      find.textContaining('Manage knowledge packs, lifecycle versions'),
      findsOneWidget,
    );
  });

  testWidgets('Knowledge Packs consume a scoped workspace target', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          knowledgePackAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
          acpWorkspaceNavigationProvider.overrideWith(
            () => FixedAcpWorkspaceNavigationController(
              AcpWorkspaceTarget(
                routeId: RouteIds.knowledgePacks,
                resourceKey: 'knowledge-scopes',
                tenantId: 'tenant-1',
                rowId: 'scope-1',
                filterValues: const <String, String>{
                  'ServiceProfileId': 'profile-1',
                },
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: KnowledgePackPanel())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scopes'), findsWidgets);
    expect(find.text('scope-1'), findsWidgets);
  });

  testWidgets('Knowledge Scope reference opens its Service Profile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith(
            (ref, token) async => const CorePluginAccess.available(),
          ),
          knowledgePackAdminRepositoryProvider.overrideWithValue(
            _KnowledgeScopeServiceProfileRepository(),
          ),
          knowledgePackAdminResourcesProvider.overrideWithValue(
            buildKnowledgePackAdminResources(serviceProfilesEnabled: true),
          ),
          acpWorkspaceNavigationProvider.overrideWith(
            () => FixedAcpWorkspaceNavigationController(
              AcpWorkspaceTarget(
                routeId: RouteIds.knowledgePacks,
                resourceKey: 'knowledge-scopes',
                tenantId: 'tenant-1',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: KnowledgePackPanel())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile One · profile-one'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KnowledgePackPanel)),
    );
    final target = container.read(acpWorkspaceNavigationProvider);
    expect(target?.routeId, RouteIds.serviceProfiles);
    expect(target?.resourceKey, 'service-profiles');
    expect(target?.rowId, 'profile-1');
  });

  testWidgets(
    'knowledge packs show current version labels and retain raw IDs in details',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            knowledgePackAdminRepositoryProvider.overrideWithValue(
              _KnowledgePackEnrichmentRepository(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: KnowledgePackPanel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('v7 · published'), findsOneWidget);
      expect(
        find.byKey(const Key('acp-admin-reference-warning')),
        findsNothing,
      );
      expect(find.text(_currentVersionId), findsNothing);

      await tester.tap(find.byTooltip('View row'));
      await tester.pumpAndSettle();

      expect(find.text(_currentVersionId), findsOneWidget);
    },
  );

  test(
    'knowledge pack create requirements match backend validation surface',
    () {
      final packsDescriptor = _descriptor('KnowledgePacks');
      final versionsDescriptor = _descriptor('KnowledgePackVersions');
      final entriesDescriptor = _descriptor('KnowledgeEntries');
      final revisionsDescriptor = _descriptor('KnowledgeEntryRevisions');
      final approvalsDescriptor = _descriptor('KnowledgeApprovals');
      final projectionsDescriptor = _descriptor('KnowledgeIndexProjections');
      final scopesDescriptor = _descriptor('KnowledgeScopes');

      expect(_requiredFieldKeys(packsDescriptor.createFields), <String>[
        'Key',
        'Name',
      ]);
      expect(_requiredFieldKeys(versionsDescriptor.createFields), <String>[
        'KnowledgePackId',
        'VersionNumber',
      ]);
      expect(_requiredFieldKeys(entriesDescriptor.createFields), <String>[
        'KnowledgePackId',
        'KnowledgePackVersionId',
        'EntryKey',
        'Title',
      ]);
      expect(_requiredFieldKeys(revisionsDescriptor.createFields), <String>[
        'KnowledgeEntryId',
        'KnowledgePackVersionId',
        'RevisionNumber',
      ]);
      expect(approvalsDescriptor.createFields, isEmpty);
      expect(projectionsDescriptor.createFields, isEmpty);
      expect(_requiredFieldKeys(scopesDescriptor.createFields), <String>[
        'KnowledgePackVersionId',
        'KnowledgeEntryRevisionId',
      ]);
    },
  );

  test('knowledge pack version actions require row versions', () {
    final versionDescriptor = _descriptor('KnowledgePackVersions');
    final actionNames = versionDescriptor.entityActions
        .map((action) => action.name)
        .toList(growable: false);

    expect(actionNames, <String>[
      'submit_for_review',
      'approve',
      'reject',
      'publish',
      'archive',
      'rollback_version',
      'reindex',
    ]);
    expect(
      versionDescriptor.entityActions.every(
        (action) => action.includeRowVersion,
      ),
      isTrue,
    );
    expect(
      versionDescriptor.entityActions
          .firstWhere((action) => action.name == 'reject')
          .fields
          .map((field) => field.key),
      <String>['Reason', 'Note'],
    );
    expect(
      versionDescriptor.entityActions
          .firstWhere((action) => action.name == 'archive')
          .fields
          .map((field) => field.key),
      <String>['Reason', 'Note'],
    );
  });

  test(
    'projection descriptor is read-only, filterable, linked, and retry-safe',
    () {
      final projection = _descriptor('KnowledgeIndexProjections');
      expect(projection.optionalApiSurface, isTrue);
      expect(projection.allowCreate, isFalse);
      expect(projection.allowUpdate, isFalse);
      expect(projection.allowDelete, isFalse);
      expect(
        projection.columns.map((column) => column.key),
        containsAll(<String>[
          'Status',
          'KnowledgePackId',
          'KnowledgePackVersionId',
          'Provider',
          'TargetFingerprint',
          'ContentChecksum',
          'DocumentCount',
          'AttemptSummary',
          'LastCompletedOrFailedAt',
          'FailureDetail',
          'ActiveTargetMatch',
        ]),
      );
      expect(projection.filters.map((filter) => filter.key), <String>[
        'KnowledgePackId',
        'KnowledgePackVersionId',
        'Status',
        'Provider',
      ]);
      expect(
        projection.columns
            .firstWhere((column) => column.key == 'KnowledgePackId')
            .reference
            ?.targetResourceKey,
        'knowledge-packs',
      );
      expect(
        projection.columns
            .firstWhere((column) => column.key == 'KnowledgePackVersionId')
            .reference
            ?.targetResourceKey,
        'knowledge-pack-versions',
      );
      final retry = projection.entityActions.single;
      expect(retry.name, 'retry');
      expect(retry.includeRowVersion, isTrue);
      expect(
        retry.isVisibleFor(const <String, Object?>{'Status': 'failed'}),
        isTrue,
      );
      expect(
        retry.isVisibleFor(const <String, Object?>{'Status': 'ready'}),
        isFalse,
      );
    },
  );

  test(
    'publication actions derive safe availability, warnings, and outcomes',
    () {
      final actions = _descriptor('KnowledgePackVersions').entityActions;
      final publish = actions.firstWhere((action) => action.name == 'publish');
      final reindex = actions.firstWhere((action) => action.name == 'reindex');
      final rollback = actions.firstWhere(
        (action) => action.name == 'rollback_version',
      );
      final archive = actions.firstWhere((action) => action.name == 'archive');
      expect(
        publish.isVisibleFor(const <String, Object?>{
          'Status': 'approved',
          'HasActiveProjection': false,
        }),
        isTrue,
      );
      expect(
        publish.isVisibleFor(const <String, Object?>{
          'Status': 'approved',
          'HasActiveProjection': true,
        }),
        isFalse,
      );
      expect(
        reindex.isVisibleFor(const <String, Object?>{'CanReindex': true}),
        isTrue,
      );
      expect(
        rollback.isVisibleFor(const <String, Object?>{'CanRollback': false}),
        isFalse,
      );
      const queued = <String, Object?>{
        'ProjectionId': 'projection-1',
        'Status': 'queued',
      };
      expect(publish.successMessageFor(queued), 'Publication queued.');
      expect(publish.successMessageFor(null), 'Published.');
      expect(rollback.successMessageFor(queued), 'Rollback queued.');
      expect(
        rollback.successMessageFor(null),
        'Knowledge pack publication rolled back.',
      );
      expect(reindex.successMessageFor(queued), 'Projection queued.');
      expect(reindex.successMessageFor(null), 'Action completed.');
      expect(
        archive.confirmationFor(const <String, Object?>{
          'IsPublishedOrIndexing': true,
        }),
        contains('currently published or indexing'),
      );
      expect(
        archive.confirmationFor(const <String, Object?>{}),
        'Archive this version?',
      );
    },
  );

  testWidgets('projection filters remain usable on a compact web layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          knowledgePackAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: KnowledgePackPanel())),
      ),
    );
    await tester.pumpAndSettle();
    final projectionsTab = find.byKey(
      const Key('acp-admin-tab-knowledge-index-projections'),
    );
    await tester.ensureVisible(projectionsTab);
    await tester.pumpAndSettle();
    await tester.tap(projectionsTab);
    await tester.pumpAndSettle();
    for (final key in const <String>[
      'KnowledgePackId',
      'KnowledgePackVersionId',
      'Status',
      'Provider',
    ]) {
      expect(
        find.byKey(
          ValueKey<String>('acp-admin-filter-knowledge-index-projections-$key'),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('projection references navigate to version and pack safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final delegate = _ProjectionNavigationRepository();
    final repository = KnowledgePackAdminRepository(
      delegate: delegate,
      projectionDescriptor: _descriptor('KnowledgeIndexProjections'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          knowledgePackAdminRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: Scaffold(body: KnowledgePackPanel())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('acp-admin-tab-knowledge-index-projections')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('[credential redacted]'), findsOneWidget);
    expect(find.textContaining('super-secret'), findsNothing);

    await tester.tap(find.text('Version Pack · v9 · approved'));
    await tester.pumpAndSettle();
    expect(delegate.fetchedEntitySets.last, 'KnowledgePackVersions');

    await tester.tap(
      find.byKey(const Key('acp-admin-tab-knowledge-index-projections')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pack Display · pack-key'));
    await tester.pumpAndSettle();
    expect(delegate.fetchedEntitySets.last, 'KnowledgePacks');
  });

  testWidgets('projection tab stays hidden when the API surface is absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          knowledgePackAdminRepositoryProvider.overrideWithValue(
            _MissingProjectionRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: KnowledgePackPanel())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Packs'), findsWidgets);
    expect(find.text('Projections'), findsNothing);
  });

  test('knowledge pack admin refreshes auth on session expiry', () async {
    final repository = FakeAcpAdminRepository()
      ..entityActionResult = const Result<Object?>.failure(
        SessionExpiredFailure(),
      );
    final authController = RecordingAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => authController),
        knowledgePackAdminRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      knowledgePackAdminControllerProvider.notifier,
    );
    await controller.loadInitialData();
    await controller.selectResource('knowledge-pack-versions');
    final result = await controller.runEntityAction(
      action: controller.activeDescriptor.entityActions.first,
      rowId: 'version-1',
      values: const <String, dynamic>{},
      rowVersion: 1,
    );

    expect(result.isFailure, isTrue);
    expect(authController.refreshCount, 1);
  });
}

AcpResourceDescriptor _descriptor(String entitySet) {
  return knowledgePackAdminResources.firstWhere(
    (descriptor) => descriptor.entitySet == entitySet,
  );
}

List<String> _requiredFieldKeys(List<AcpFieldDescriptor> fields) {
  return fields
      .where((field) => field.required)
      .map((field) => field.key)
      .toList(growable: false);
}

const String _currentVersionId = '60000000-0000-4000-8000-000000000001';

class _KnowledgePackEnrichmentRepository extends FakeAcpAdminRepository {
  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
  }) async {
    if (descriptor.entitySet != 'KnowledgePacks') {
      return super.listRows(
        descriptor: descriptor,
        pageRequest: pageRequest,
        tenantId: tenantId,
        searchTerm: searchTerm,
        extraFilters: extraFilters,
        deletedView: deletedView,
        enrichReferences: enrichReferences,
      );
    }

    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: const <AcpRow>[
          <String, Object?>{
            'Id': '50000000-0000-4000-8000-000000000001',
            'TenantId': 'tenant-1',
            'RowVersion': 1,
            'Key': 'support',
            'Name': 'Support Knowledge',
            'IsActive': true,
            'CurrentVersionId': _currentVersionId,
            'CurrentVersion': <String, Object?>{
              'Id': _currentVersionId,
              'VersionNumber': 7,
              'Status': 'published',
            },
          },
        ],
        total: 1,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }
}

class _KnowledgeScopeServiceProfileRepository extends FakeAcpAdminRepository {
  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
  }) async {
    final rows = descriptor.entitySet == 'KnowledgeScopes'
        ? const <AcpRow>[
            <String, Object?>{
              'Id': 'scope-1',
              'TenantId': 'tenant-1',
              'ServiceProfileId': 'profile-1',
              'ServiceProfile': <String, Object?>{
                'Id': 'profile-1',
                'DisplayName': 'Profile One',
                'Key': 'profile-one',
              },
            },
          ]
        : const <AcpRow>[];
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: rows,
        total: rows.length,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }
}

class _ProjectionNavigationRepository extends FakeAcpAdminRepository {
  final List<String> fetchedEntitySets = <String>[];

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
  }) async {
    final rows = descriptor.entitySet == 'KnowledgeIndexProjections'
        ? const <AcpRow>[
            <String, Object?>{
              'Id': 'projection-1',
              'RowVersion': 2,
              'KnowledgePackId': 'pack-1',
              'KnowledgePackVersionId': 'version-9',
              'Status': 'failed',
              'Operation': 'publish',
              'Provider': 'generic',
              'TargetFingerprint': '1234567890123456',
              'ContentChecksum': 'abcdef',
              'AttemptCount': 3,
              'MaxAttempts': 3,
              'FailureDetail': 'token=super-secret',
              'KnowledgePack': <String, Object?>{
                'Name': 'Pack Display',
                'Key': 'pack-key',
              },
              'KnowledgePackVersion': <String, Object?>{
                'VersionNumber': 9,
                'Status': 'approved',
                'KnowledgePack': <String, Object?>{'Name': 'Version Pack'},
              },
            },
          ]
        : const <AcpRow>[];
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: rows,
        total: rows.length,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    fetchedEntitySets.add(descriptor.entitySet);
    return Result<AcpRow>.success(<String, Object?>{
      'Id': rowId,
      'RowVersion': 1,
      'Name': descriptor.title,
    });
  }
}

class _MissingProjectionRepository extends FakeAcpAdminRepository {
  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
  }) {
    if (descriptor.entitySet == 'KnowledgeIndexProjections') {
      return Future<Result<AcpRowPage>>.value(
        const Result<AcpRowPage>.failure(ApiFailure(404, 'Not found.')),
      );
    }
    return super.listRows(
      descriptor: descriptor,
      pageRequest: pageRequest,
      tenantId: tenantId,
      searchTerm: searchTerm,
      extraFilters: extraFilters,
      deletedView: deletedView,
      enrichReferences: enrichReferences,
    );
  }
}
