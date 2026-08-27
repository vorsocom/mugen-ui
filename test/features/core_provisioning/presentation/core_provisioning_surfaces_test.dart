import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/core_provisioning/domain/entities/core_plugin_access.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_workspace_target.dart';
import 'package:mugen_ui/features/core_provisioning/domain/repositories/core_plugin_repository.dart';
import 'package:mugen_ui/features/core_provisioning/infrastructure/repositories/core_plugin_repository_impl.dart';
import 'package:mugen_ui/features/core_provisioning/presentation/providers/core_provisioning_providers.dart';
import 'package:mugen_ui/features/core_provisioning/presentation/widgets/core_provisioning_panels.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';

void main() {
  test(
    'production repository providers and descriptor controllers are wired',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(corePluginRepositoryProvider),
        isA<CorePluginRepositoryImpl>(),
      );
      expect(
        container.read(coreProvisioningAdminRepositoryProvider),
        isA<AcpAdminRepositoryImpl>(),
      );
      expect(
        container
            .read(billingOperationsControllerProvider.notifier)
            .descriptors,
        hasLength(14),
      );
      expect(
        container.read(connectorAdminControllerProvider.notifier).descriptors,
        hasLength(3),
      );
      expect(
        container.read(governanceAdminControllerProvider.notifier).descriptors,
        hasLength(1),
      );
      expect(
        container.read(workflowAdminControllerProvider.notifier).descriptors,
        hasLength(4),
      );
      expect(
        container.read(slaAdminControllerProvider.notifier).descriptors,
        hasLength(3),
      );
      expect(
        container.read(reportingAdminControllerProvider.notifier).descriptors,
        hasLength(5),
      );
    },
  );

  test(
    'descriptor controllers refresh expired authentication sessions',
    () async {
      final authController = _AuthController(session: _session);
      final repository = _AdminRepository()
        ..fetchTenantsResult = const Result<List<AcpTenantOption>>.failure(
          SessionExpiredFailure(),
        );
      final container = ProviderContainer(
        overrides: <Override>[
          authControllerProvider.overrideWith(() => authController),
          coreProvisioningAdminRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(billingOperationsControllerProvider.notifier)
          .loadInitialData();

      expect(authController.refreshCount, 1);
    },
  );

  test(
    'plugin access requires authentication and resolves all plugin tokens',
    () async {
      final repository = _PluginRepository();
      final signedOut = ProviderContainer(
        overrides: <Override>[
          corePluginRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(
            () => _AuthController(session: null),
          ),
        ],
      );
      addTearDown(signedOut.dispose);
      final signedOutAccess = await signedOut.read(
        corePluginAccessProvider(billingPluginToken).future,
      );
      expect(signedOutAccess.isAvailable, isFalse);
      expect(repository.tokens, isEmpty);

      final signedIn = ProviderContainer(
        overrides: <Override>[
          corePluginRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(
            () => _AuthController(session: _session),
          ),
        ],
      );
      addTearDown(signedIn.dispose);
      for (final token in const <String>[
        billingPluginToken,
        connectorPluginToken,
        governancePluginToken,
        workflowPluginToken,
        slaPluginToken,
        reportingPluginToken,
      ]) {
        final access = await signedIn.read(
          corePluginAccessProvider(token).future,
        );
        expect(access.isAvailable, isTrue);
      }
      expect(repository.tokens, hasLength(6));
    },
  );

  test(
    'shell availability maps pending, error, available, and unavailable',
    () async {
      final pending = Completer<CorePluginAccess>();
      final pendingContainer = ProviderContainer(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith((ref, token) => pending.future),
        ],
      );
      addTearDown(pendingContainer.dispose);
      final subscription = pendingContainer.listen(
        billingOperationsShellAvailabilityProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      expect(
        pendingContainer
            .read(billingOperationsShellAvailabilityProvider)
            .status,
        ShellRouteAvailabilityStatus.pending,
      );
      pending.completeError(StateError('failed'));
      await expectLater(
        pendingContainer.read(
          corePluginAccessProvider(billingPluginToken).future,
        ),
        throwsStateError,
      );
      await pumpEventQueue();
      expect(
        pendingContainer
            .read(billingOperationsShellAvailabilityProvider)
            .status,
        ShellRouteAvailabilityStatus.unavailable,
      );

      final available = ProviderContainer(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith(
            (ref, token) async => const CorePluginAccess.available(),
          ),
        ],
      );
      addTearDown(available.dispose);
      final availabilityProviders = <Provider<ShellRouteAvailability>>[
        billingOperationsShellAvailabilityProvider,
        connectorsShellAvailabilityProvider,
        governanceShellAvailabilityProvider,
        workflowsShellAvailabilityProvider,
        slaShellAvailabilityProvider,
        reportingShellAvailabilityProvider,
      ];
      for (final provider in availabilityProviders) {
        final listener = available.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(listener.close);
      }
      await pumpEventQueue();
      for (final provider in availabilityProviders) {
        expect(
          available.read(provider).status,
          ShellRouteAvailabilityStatus.available,
        );
      }

      final unavailable = ProviderContainer(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith(
            (ref, token) async => const CorePluginAccess(
              status: CorePluginAccessStatus.unavailable,
              message: 'not installed',
            ),
          ),
        ],
      );
      addTearDown(unavailable.dispose);
      final unavailableListener = unavailable.listen(
        connectorsShellAvailabilityProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(unavailableListener.close);
      await pumpEventQueue();
      expect(
        unavailable.read(connectorsShellAvailabilityProvider).message,
        'not installed',
      );
    },
  );

  testWidgets('reference value fields submit KeyId instead of KeyRef UUID', (
    tester,
  ) async {
    final repository = _AdminRepository();
    await _pumpDescriptorPanel(
      tester,
      repository: repository,
      descriptor: const AcpResourceDescriptor(
        key: 'connectors',
        title: 'Connectors',
        entitySet: 'Connectors',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[
          AcpColumnDescriptor(key: 'SecretRef', label: 'Secret Ref'),
        ],
        createFields: <AcpFieldDescriptor>[
          AcpFieldDescriptor(
            key: 'SecretRef',
            label: 'Managed Secret Key',
            required: true,
            reference: AcpFieldReferenceDescriptor(
              entitySet: 'KeyRefs',
              scopeMode: AcpScopeMode.none,
              title: 'Key References',
              valueField: 'KeyId',
              searchFields: <String>['Purpose', 'KeyId'],
              titleFields: <String>['Purpose'],
              subtitleFields: <String>['KeyId', 'Status'],
              extraFilters: <String>["Status eq 'active'"],
            ),
          ),
        ],
        allowCreate: true,
      ),
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('acp-reference-search-SecretRef')),
      'managed',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('acp-reference-option-SecretRef-managed-key')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(repository.createPayloads.single['SecretRef'], 'managed-key');
    expect(repository.referenceFilters.single, contains("Status eq 'active'"));
  });

  testWidgets('billing operation targets select tenant resource and row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          coreProvisioningAdminRepositoryProvider.overrideWithValue(
            _AdminRepository(),
          ),
          authControllerProvider.overrideWith(
            () => _AuthController(session: _session),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BillingOperationsPanel(
              target: BillingWorkspaceTarget(
                workspace: BillingWorkspace.values.last,
                resourceKey: 'billing-invoices',
                tenantId: 'tenant-1',
                rowId: 'invoice-1',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invoices'), findsWidgets);
    expect(find.text('invoice-1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'nested WhatsApp references merge UUID paths with advanced JSON',
    (tester) async {
      final repository = _AdminRepository();
      await _pumpDescriptorPanel(
        tester,
        repository: repository,
        descriptor: const AcpResourceDescriptor(
          key: 'messaging',
          title: 'Messaging',
          entitySet: 'Messaging',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'PlatformKey', label: 'Platform'),
          ],
          createFields: <AcpFieldDescriptor>[
            AcpFieldDescriptor(
              key: 'PlatformKey',
              label: 'Platform',
              initialValue: 'whatsapp',
              options: <String>['whatsapp'],
            ),
            AcpFieldDescriptor(
              key: 'SecretRefs',
              label: 'Additional Secret References',
              kind: AcpFieldKind.json,
              excludedJsonKeys: <String>['graphapi.access_token'],
            ),
            AcpFieldDescriptor(
              key: 'AccessTokenRef',
              label: 'Access Token KeyRef',
              payloadContainerKey: 'SecretRefs',
              payloadMapKey: 'graphapi.access_token',
              visibleWhenEquals: <String, List<Object>>{
                'PlatformKey': <Object>['whatsapp'],
              },
              reference: AcpFieldReferenceDescriptor(
                entitySet: 'KeyRefs',
                scopeMode: AcpScopeMode.none,
                title: 'Key References',
                searchFields: <String>['Purpose', 'KeyId'],
                titleFields: <String>['Purpose'],
              ),
            ),
          ],
          allowCreate: true,
        ),
      );

      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('acp-json-editor-text-SecretRefs')),
          matching: find.byType(TextField),
        ),
        '{"custom.path":"other-keyref"}',
      );
      await tester.enterText(
        find.byKey(const Key('acp-reference-search-AccessTokenRef')),
        'access',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final accessTokenOption = find.byKey(
        const Key('acp-reference-option-AccessTokenRef-keyref-uuid'),
      );
      await tester.ensureVisible(accessTokenOption);
      await tester.pumpAndSettle();
      await tester.tap(accessTokenOption);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(repository.createPayloads.single['SecretRefs'], <String, dynamic>{
        'custom.path': 'other-keyref',
        'graphapi.access_token': 'keyref-uuid',
      });
      expect(
        repository.createPayloads.single.toString(),
        isNot(contains('secret material')),
      );
    },
  );

  testWidgets('searchable multi-reference fields submit stable code lists', (
    tester,
  ) async {
    final repository = _AdminRepository();
    await _pumpDescriptorPanel(
      tester,
      repository: repository,
      descriptor: const AcpResourceDescriptor(
        key: 'reports',
        title: 'Reports',
        entitySet: 'Reports',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[
          AcpColumnDescriptor(key: 'MetricCodes', label: 'Metric Codes'),
        ],
        createFields: <AcpFieldDescriptor>[
          AcpFieldDescriptor(
            key: 'MetricCodes',
            label: 'Metric Codes',
            kind: AcpFieldKind.stringList,
            reference: AcpFieldReferenceDescriptor(
              entitySet: 'Metrics',
              scopeMode: AcpScopeMode.none,
              title: 'Metrics',
              valueField: 'Code',
              multiSelect: true,
              searchFields: <String>['Code', 'Name'],
              titleFields: <String>['Name'],
            ),
          ),
        ],
        allowCreate: true,
      ),
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('acp-reference-search-MetricCodes')),
      'ticket',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('acp-reference-option-MetricCodes-ticket_count')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('acp-reference-selected-MetricCodes-ticket_count')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(repository.createPayloads.single['MetricCodes'], <String>[
      'ticket_count',
    ]);
  });

  testWidgets('two-step create retries only the follow-up update', (
    tester,
  ) async {
    final repository = _AdminRepository()
      ..updateResult = const Result<Object?>.failure(
        ApiFailure(422, 'Description is invalid.'),
      );
    await _pumpDescriptorPanel(
      tester,
      repository: repository,
      descriptor: const AcpResourceDescriptor(
        key: 'two-step',
        title: 'Two Step',
        entitySet: 'TwoSteps',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[
          AcpColumnDescriptor(key: 'Key', label: 'Key'),
        ],
        createFields: <AcpFieldDescriptor>[
          AcpFieldDescriptor(key: 'Key', label: 'Key', required: true),
          AcpFieldDescriptor(
            key: 'Description',
            label: 'Description',
            applyAfterCreate: true,
          ),
        ],
        allowCreate: true,
      ),
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-Key')),
      'workflow',
    );
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-Description')),
      'retained description',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(repository.createPayloads, <Map<String, dynamic>>[
      <String, dynamic>{'Key': 'workflow'},
    ]);
    expect(repository.updatePayloads, <Map<String, dynamic>>[
      <String, dynamic>{'Description': 'retained description'},
    ]);
    expect(find.text('Description is invalid.'), findsWidgets);

    repository.updateResult = const Result<Object?>.success(null);
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(repository.createPayloads, hasLength(1));
    expect(repository.updatePayloads, hasLength(2));
    expect(find.text('Create Two Step'), findsNothing);
  });

  for (final entry in <(String, Widget)>[
    ('Billing Operations', const BillingOperationsPanel()),
    ('Connectors', const ConnectorsPanel()),
    ('Governance', const GovernancePanel()),
    ('Workflows', const WorkflowsPanel()),
    ('SLA', const SlaPanel()),
    ('Reporting', const ReportingPanel()),
  ]) {
    testWidgets('${entry.$1} panel renders responsive resource navigation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            coreProvisioningAdminRepositoryProvider.overrideWithValue(
              _AdminRepository(),
            ),
            authControllerProvider.overrideWith(
              () => _AuthController(session: _session),
            ),
          ],
          child: MaterialApp(home: Scaffold(body: entry.$2)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(entry.$1), findsWidgets);
      if (entry.$1 == 'Connectors') {
        await tester.tap(
          find.byKey(const Key('acp-admin-tab-ops-connector-instances')),
        );
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const Key('acp-admin-tenant-selector')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('acp-admin-refresh-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

const AuthSession _session = AuthSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  userId: 'admin',
  roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
);

class _AuthController extends AuthController {
  _AuthController({required this.session});

  final AuthSession? session;
  int refreshCount = 0;

  @override
  AuthControllerState build() =>
      AuthControllerState(isLoading: false, session: session);

  @override
  void refreshSession() {
    refreshCount += 1;
  }
}

class _PluginRepository implements CorePluginRepository {
  final List<String> tokens = <String>[];

  @override
  Future<Result<CorePluginStatus>> fetchStatus(String token) async {
    tokens.add(token);
    return Result<CorePluginStatus>.success(
      CorePluginStatus(token: token, available: true, status: 'registered'),
    );
  }
}

class _AdminRepository implements AcpAdminRepository {
  final List<Map<String, dynamic>> createPayloads = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> updatePayloads = <Map<String, dynamic>>[];
  final List<List<String>> referenceFilters = <List<String>>[];
  Result<Object?> updateResult = const Result<Object?>.success(null);
  Result<List<AcpTenantOption>> fetchTenantsResult =
      const Result<List<AcpTenantOption>>.success(<AcpTenantOption>[
        AcpTenantOption(id: 'tenant-1', name: 'Tenant One'),
      ]);

  @override
  Future<Result<List<AcpTenantOption>>> fetchTenants({int top = 200}) async {
    return fetchTenantsResult;
  }

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
  }) async {
    if (descriptor.entitySet == 'KeyRefs') {
      referenceFilters.add(List<String>.from(extraFilters));
      return Result<AcpRowPage>.success(
        AcpRowPage(
          items: const <AcpRow>[
            <String, dynamic>{
              'Id': 'keyref-uuid',
              'KeyId': 'managed-key',
              'Purpose': 'connector access',
              'Status': 'active',
            },
          ],
          total: 1,
          page: pageRequest.page,
          pageSize: pageRequest.pageSize,
        ),
      );
    }
    if (descriptor.entitySet == 'Metrics') {
      return Result<AcpRowPage>.success(
        AcpRowPage(
          items: const <AcpRow>[
            <String, dynamic>{
              'Id': 'metric-id',
              'Code': 'ticket_count',
              'Name': 'Ticket count',
            },
          ],
          total: 1,
          page: pageRequest.page,
          pageSize: pageRequest.pageSize,
        ),
      );
    }
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: const <AcpRow>[],
        total: 0,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<Object?>> createRow({
    required AcpResourceDescriptor descriptor,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    createPayloads.add(Map<String, dynamic>.from(values));
    return const Result<Object?>.success(<String, dynamic>{
      'Id': 'created-id',
      'RowVersion': 1,
    });
  }

  @override
  Future<Result<void>> deleteRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) => throw UnimplementedError();

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    return Result<AcpRow>.success(<String, dynamic>{
      'Id': rowId,
      'TenantId': tenantId,
      'RowVersion': 1,
    });
  }

  @override
  Future<Result<void>> restoreRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) => throw UnimplementedError();

  @override
  Future<Result<Object?>> runCollectionAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
    String? tenantId,
  }) => throw UnimplementedError();

  @override
  Future<Result<Object?>> runEntityAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) => throw UnimplementedError();

  @override
  Future<Result<Object?>> updateRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    updatePayloads.add(Map<String, dynamic>.from(values));
    return updateResult;
  }
}

Future<void> _pumpDescriptorPanel(
  WidgetTester tester, {
  required AcpAdminRepository repository,
  required AcpResourceDescriptor descriptor,
}) async {
  final provider = StateNotifierProvider<AcpAdminController, AcpAdminState>((
    ref,
  ) {
    return AcpAdminController(
      repository: repository,
      descriptors: <AcpResourceDescriptor>[descriptor],
      onSessionExpired: () {},
    );
  });
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: AcpAdminPanel<AcpAdminController>(controllerProvider: provider),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
