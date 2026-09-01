import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/definition/core_modules.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/core_provisioning/domain/entities/core_plugin_access.dart';
import 'package:mugen_ui/features/core_provisioning/presentation/providers/core_provisioning_providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/service_profile_admin/application/service_profile_admin_resources.dart';
import 'package:mugen_ui/features/service_profile_admin/infrastructure/service_profile_admin_repository.dart';
import 'package:mugen_ui/features/service_profile_admin/presentation/providers/service_profile_admin_providers.dart';
import 'package:mugen_ui/features/service_profile_admin/presentation/widgets/service_profile_panel.dart';
import 'package:mugen_ui/features/shell/application/shell_route_access.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_workspace_navigation.dart';

import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test('Service Profile route is capability and administrator gated', () async {
    final route = buildDefaultAppDefinition().shellRoutes.firstWhere(
      (item) => item.id == RouteIds.serviceProfiles,
    );
    expect(
      route.availabilityProvider,
      same(serviceProfileShellAvailabilityProvider),
    );
    expect(route.requiredRoles, <String>['$acpNamespace:administrator']);
    expect(
      resolveShellRouteAccess(
        shellRoutes: <ShellRouteDefinition>[route],
        defaultShellRouteId: route.id,
        sessionRoles: route.requiredRoles,
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
        sessionRoles: const <String>[],
        requestedRoute: route.id,
        routeAvailabilities: <String, ShellRouteAvailability>{
          route.id: const ShellRouteAvailability.available(),
        },
      ).allowedRoutes,
      isEmpty,
    );
    expect(
      resolveShellRouteAccess(
        shellRoutes: <ShellRouteDefinition>[route],
        defaultShellRouteId: route.id,
        sessionRoles: route.requiredRoles,
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
    final listener = container.listen(
      serviceProfileShellAvailabilityProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(listener.close);
    expect(
      container.read(serviceProfileShellAvailabilityProvider).status,
      ShellRouteAvailabilityStatus.pending,
    );
    pending.completeError(StateError('missing'));
    await expectLater(
      container.read(
        corePluginAccessProvider(serviceProfilePluginToken).future,
      ),
      throwsStateError,
    );
    await pumpEventQueue();
    expect(
      container.read(serviceProfileShellAvailabilityProvider).status,
      ShellRouteAvailabilityStatus.unavailable,
    );
  });

  test(
    'dependent capabilities fail closed and add tabs when available',
    () async {
      final unavailable = ProviderContainer(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith(
            (ref, token) async => const CorePluginAccess(
              status: CorePluginAccessStatus.unavailable,
              message: 'off',
            ),
          ),
        ],
      );
      addTearDown(unavailable.dispose);
      await pumpEventQueue();
      expect(
        unavailable.read(serviceProfileAdminResourcesProvider),
        hasLength(1),
      );

      final available = ProviderContainer(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith(
            (ref, token) async => const CorePluginAccess.available(),
          ),
          serviceProfileAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
      );
      addTearDown(available.dispose);
      await available.read(
        corePluginAccessProvider(channelOrchestrationPluginToken).future,
      );
      await available.read(corePluginAccessProvider(billingPluginToken).future);
      await pumpEventQueue();
      expect(
        available
            .read(serviceProfileAdminResourcesProvider)
            .map((item) => item.entitySet),
        <String>[
          'ServiceProfiles',
          'ServiceProfileIngressBindings',
          'ServiceProfileSubscriptions',
        ],
      );
      expect(
        available
            .read(serviceProfileAdminControllerProvider.notifier)
            .descriptors,
        hasLength(3),
      );
    },
  );

  test('default repository is decorated', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(serviceProfileAdminRepositoryProvider),
      isA<ServiceProfileAdminRepository>(),
    );
  });

  test('controller refreshes an expired administrator session', () async {
    final auth = RecordingAuthController();
    final expiredRepository = _ExpiredTenantRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => auth),
        serviceProfileAdminRepositoryProvider.overrideWithValue(
          expiredRepository,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(serviceProfileAdminControllerProvider.notifier)
        .loadInitialData();
    expect(auth.refreshCount, 1);
  });

  testWidgets('workspace navigation opens a route and can be cleared', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final target = AcpWorkspaceTarget(
      routeId: RouteIds.dashboard,
      resourceKey: 'profiles',
      tenantId: 'tenant-1',
      rowId: 'profile-1',
      filterValues: const <String, String>{'Status': 'active'},
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: _OpenWorkspaceButton(target: target)),
      ),
    );
    await tester.tap(find.text('Open workspace'));
    await tester.pump();
    expect(container.read(acpWorkspaceNavigationProvider), same(target));
    container.read(acpWorkspaceNavigationProvider.notifier).clear();
    expect(container.read(acpWorkspaceNavigationProvider), isNull);
  });

  testWidgets('Service Profile panel renders accessible responsive tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith(
            (ref, token) async => const CorePluginAccess.available(),
          ),
          serviceProfileAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ServiceProfilePanel())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('Ingress Bindings'), findsOneWidget);
    expect(find.text('Subscriptions'), findsOneWidget);
    expect(
      find.textContaining('Manage stable service identities'),
      findsOneWidget,
    );
    await tester.binding.setSurfaceSize(const Size(720, 900));
    await tester.pumpAndSettle();
    expect(find.text('Profiles'), findsOneWidget);
  });

  testWidgets('workspace target preserves tenant and opens the requested tab', (
    tester,
  ) async {
    final repository = FakeAcpAdminRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith(
            (ref, token) async => const CorePluginAccess.available(),
          ),
          serviceProfileAdminRepositoryProvider.overrideWithValue(repository),
          acpWorkspaceNavigationProvider.overrideWith(
            () => _TargetNavigationController(
              const AcpWorkspaceTarget(
                routeId: RouteIds.serviceProfiles,
                resourceKey: 'service-profile-subscriptions',
                tenantId: 'tenant-1',
                filterValues: <String, String>{'ServiceProfileId': 'profile-1'},
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ServiceProfilePanel())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Billing Subscription'), findsWidgets);
    expect(find.byKey(const Key('acp-admin-tenant-selector')), findsOneWidget);
  });

  testWidgets('profile detail navigation opens matching Knowledge Scopes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          corePluginAccessProvider.overrideWith(
            (ref, token) async => const CorePluginAccess.available(),
          ),
          serviceProfileAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
          serviceProfileAdminResourcesProvider.overrideWithValue(
            buildServiceProfileAdminResources(
              channelOrchestrationEnabled: true,
              billingEnabled: true,
              knowledgePackEnabled: true,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ServiceProfilePanel())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View row').first);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServiceProfilePanel)),
    );
    expect(
      container
          .read(serviceProfileAdminControllerProvider.notifier)
          .descriptors
          .first
          .detailSections
          .expand((section) => section.links)
          .map((link) => link.label),
      contains('View matching Knowledge Scopes'),
    );
    expect(find.text('Assignments'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View matching Knowledge Scopes'));
    await tester.pumpAndSettle();
    final target = container.read(acpWorkspaceNavigationProvider);
    expect(target?.routeId, RouteIds.knowledgePacks);
    expect(target?.filterValues['ServiceProfileId'], 'ServiceProfiles-1');
  });
}

class _TargetNavigationController extends AcpWorkspaceNavigationController {
  _TargetNavigationController(this.target);

  final AcpWorkspaceTarget target;

  @override
  AcpWorkspaceTarget? build() => target;
}

class _OpenWorkspaceButton extends ConsumerWidget {
  const _OpenWorkspaceButton({required this.target});

  final AcpWorkspaceTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => openAcpWorkspace(ref, target),
      child: const Text('Open workspace'),
    );
  }
}

class _ExpiredTenantRepository extends FakeAcpAdminRepository {
  @override
  Future<Result<List<AcpTenantOption>>> fetchTenants({int top = 200}) async =>
      const Result<List<AcpTenantOption>>.failure(SessionExpiredFailure());
}
