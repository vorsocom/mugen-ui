import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_access_service.dart';
import 'package:mugen_ui/features/billing_catalog/application/dto/billing_catalog_inputs.dart';
import 'package:mugen_ui/features/billing_catalog/domain/entities/billing_catalog_entities.dart';
import 'package:mugen_ui/features/billing_catalog/domain/repositories/billing_catalog_repository.dart';
import 'package:mugen_ui/features/billing_catalog/infrastructure/repositories/billing_catalog_repository_impl.dart';
import 'package:mugen_ui/features/billing_catalog/presentation/providers/billing_catalog_providers.dart';
import 'package:mugen_ui/features/billing_catalog/presentation/widgets/billing_catalog_panel.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_workspace_target.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/billing_acp_admin_repository.dart';

import '../../../test_support/fake_acp_admin_repository.dart';

void main() {
  test('repository providers build the production implementations', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(billingCatalogRepositoryProvider),
      isA<BillingCatalogRepositoryImpl>(),
    );
    expect(
      container.read(billingCatalogAdminRepositoryProvider),
      isA<BillingAcpAdminRepository>(),
    );
    expect(
      container
          .read(billingCatalogAdminControllerProvider.notifier)
          .descriptors,
      hasLength(11),
    );
  });

  test('access provider requires an authenticated session', () async {
    final repository = _SurfaceRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        billingCatalogRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => _SurfaceAuthController(session: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(billingCatalogAccessProvider.future);

    expect(state.status, BillingCatalogAccessStatus.permissionDenied);
    expect(state.message, 'Sign in to view the Billing Catalog.');
    expect(repository.extensionCalls, 0);
  });

  test(
    'access and legacy controller providers refresh expired sessions',
    () async {
      final repository = _SurfaceRepository()
        ..readResult = const Result<void>.failure(SessionExpiredFailure())
        ..productResult =
            const Result<PageResult<BillingProductEntity>>.failure(
              UnauthorizedFailure(),
            );
      final authController = _SurfaceAuthController(session: _readerSession);
      final container = ProviderContainer(
        overrides: <Override>[
          billingCatalogRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(() => authController),
        ],
      );
      addTearDown(container.dispose);

      final access = await container.read(billingCatalogAccessProvider.future);
      await container
          .read(billingCatalogControllerProvider.notifier)
          .loadActiveTab();

      expect(access.status, BillingCatalogAccessStatus.error);
      expect(authController.refreshCalls, 2);
    },
  );

  test('admin controller provider refreshes an expired session', () async {
    final repository = FakeAcpAdminRepository()
      ..listRowsResult = const Result<AcpRowPage>.failure(
        SessionExpiredFailure(),
      );
    final authController = _SurfaceAuthController(session: _adminSession);
    final container = ProviderContainer(
      overrides: <Override>[
        billingCatalogAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => authController),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(billingCatalogAdminControllerProvider.notifier)
        .loadInitialData();

    expect(authController.refreshCalls, greaterThan(0));
  });

  test('shell availability maps pending, errors, and access states', () async {
    final pending = Completer<BillingCatalogAccessState>();
    final pendingContainer = ProviderContainer(
      overrides: <Override>[
        billingCatalogAccessProvider.overrideWith((ref) => pending.future),
      ],
    );
    addTearDown(pendingContainer.dispose);
    final subscription = pendingContainer.listen(
      billingCatalogShellAvailabilityProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    expect(
      pendingContainer.read(billingCatalogShellAvailabilityProvider).status,
      ShellRouteAvailabilityStatus.pending,
    );

    pending.completeError(StateError('discovery failed'));
    await expectLater(
      pendingContainer.read(billingCatalogAccessProvider.future),
      throwsStateError,
    );
    await pumpEventQueue();
    expect(
      pendingContainer.read(billingCatalogShellAvailabilityProvider).message,
      'Billing extension status could not be loaded.',
    );

    for (final entry
        in <(BillingCatalogAccessState, ShellRouteAvailabilityStatus)>[
          (
            const BillingCatalogAccessState(
              status: BillingCatalogAccessStatus.extensionUnavailable,
              message: 'Billing extension is disabled.',
            ),
            ShellRouteAvailabilityStatus.unavailable,
          ),
          (
            const BillingCatalogAccessState.available(),
            ShellRouteAvailabilityStatus.available,
          ),
        ]) {
      final container = ProviderContainer(
        overrides: <Override>[
          billingCatalogAccessProvider.overrideWith((ref) async => entry.$1),
        ],
      );
      addTearDown(container.dispose);
      await container.read(billingCatalogAccessProvider.future);
      expect(
        container.read(billingCatalogShellAvailabilityProvider).status,
        entry.$2,
      );
    }
  });

  testWidgets('catalog readers can browse every global section read-only', (
    tester,
  ) async {
    final repository = _AdminRepository();
    await _pumpPanel(tester, repository: repository, session: _readerSession);

    expect(find.text('Billing Catalog'), findsWidgets);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.byKey(const Key('acp-admin-create-button')), findsNothing);
    expect(find.byTooltip('Edit row'), findsNothing);
    expect(find.byTooltip('More actions'), findsNothing);
    expect(find.byKey(const Key('acp-admin-tenant-selector')), findsNothing);

    await tester.tap(
      find.byKey(const Key('acp-admin-tab-billing-meter-definitions')),
    );
    await tester.pumpAndSettle();
    expect(find.text('api_calls'), findsOneWidget);
    expect(repository.scopes.every((scope) => scope == null), isTrue);
  });

  testWidgets('catalog administrators receive typed global mutations', (
    tester,
  ) async {
    final repository = _AdminRepository();
    await _pumpPanel(tester, repository: repository, session: _adminSession);

    expect(find.byKey(const Key('acp-admin-create-button')), findsOneWidget);
    expect(find.byTooltip('Edit row'), findsOneWidget);
    expect(find.byTooltip('More actions'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('acp-admin-tab-billing-price-entitlements')),
    );
    await tester.pumpAndSettle();
    expect(find.text('price-1'), findsOneWidget);
    expect(find.text('meter-1'), findsOneWidget);
  });

  testWidgets('catalog targets open a stable resource and row deep link', (
    tester,
  ) async {
    final repository = _AdminRepository();
    await _pumpPanel(
      tester,
      repository: repository,
      session: _readerSession,
      target: const BillingWorkspaceTarget(
        workspace: BillingWorkspace.catalog,
        resourceKey: 'billing-prices',
        rowId: 'price-1',
      ),
    );

    expect(find.text('Prices'), findsWidgets);
    expect(find.text('MONTHLY'), findsWidgets);
    expect(repository.fetchedRowIds, <String>['price-1']);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required _AdminRepository repository,
  required AuthSession session,
  BillingWorkspaceTarget? target,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        billingCatalogAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(
          () => _SurfaceAuthController(session: session),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: BillingCatalogPanel(target: target)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const AuthSession _readerSession = AuthSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  userId: 'reader',
  roles: <String>['com.vorsocomputing.mugen.acp:catalog_reader'],
);

const AuthSession _adminSession = AuthSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  userId: 'admin',
  roles: <String>['$acpNamespace:administrator'],
);

class _SurfaceAuthController extends AuthController {
  _SurfaceAuthController({required this.session});

  final AuthSession? session;
  int refreshCalls = 0;

  @override
  AuthControllerState build() =>
      AuthControllerState(isLoading: false, session: session);

  @override
  void refreshSession() {
    refreshCalls += 1;
  }
}

class _AdminRepository extends FakeAcpAdminRepository {
  final List<String?> scopes = <String?>[];
  final List<String> fetchedRowIds = <String>[];

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
  }) async {
    scopes.add(tenantId);
    final row = switch (descriptor.entitySet) {
      'BillingProducts' => <String, Object?>{
        'Id': 'product-1',
        'Code': 'PRO',
        'Name': 'Professional',
        'RowVersion': 2,
      },
      'BillingPrices' => <String, Object?>{
        'Id': 'price-1',
        'Code': 'MONTHLY',
        'PriceType': 'recurring',
        'Currency': 'USD',
        'UnitAmount': 1999,
        '_CurrencyMinorUnit': 2,
        'RowVersion': 3,
      },
      'BillingMeterDefinitions' => <String, Object?>{
        'Id': 'meter-1',
        'Code': 'api_calls',
        'Unit': 'unit',
        'AggregationMode': 'sum',
        'IsActive': true,
        'RowVersion': 4,
      },
      'BillingPriceEntitlements' => <String, Object?>{
        'Id': 'entitlement-1',
        'PriceId': 'price-1',
        'MeterDefinitionId': 'meter-1',
        'IncludedQuantity': 100,
        'RolloverPolicy': 'none',
        'RowVersion': 1,
      },
      _ => <String, Object?>{
        'Id': '${descriptor.entitySet}-1',
        'Code': descriptor.entitySet,
        'IsActive': true,
        'RowVersion': 1,
      },
    };
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: <AcpRow>[row],
        total: 1,
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
    fetchedRowIds.add(rowId);
    return const Result<AcpRow>.success(<String, Object?>{
      'Id': 'price-1',
      'Code': 'MONTHLY',
      'PriceType': 'recurring',
      'Currency': 'USD',
      'UnitAmount': 1999,
      '_CurrencyMinorUnit': 2,
      'RowVersion': 3,
    });
  }
}

class _SurfaceRepository implements BillingCatalogRepository {
  int extensionCalls = 0;
  Result<void> readResult = const Result<void>.success(null);
  Result<PageResult<BillingProductEntity>> productResult =
      const Result<PageResult<BillingProductEntity>>.success(
        PageResult<BillingProductEntity>(
          items: <BillingProductEntity>[],
          total: 0,
          page: 1,
          pageSize: 15,
        ),
      );

  @override
  Future<Result<BillingExtensionStatusEntity>>
  fetchBillingExtensionStatus() async {
    extensionCalls += 1;
    return const Result<BillingExtensionStatusEntity>.success(
      BillingExtensionStatusEntity(
        token: 'core.fw.billing',
        extensionType: 'fw',
        configured: true,
        enabled: true,
        available: true,
        status: 'registered',
      ),
    );
  }

  @override
  Future<Result<void>> verifyCatalogReadAccess() async => readResult;

  @override
  Future<Result<PageResult<BillingProductEntity>>> fetchProducts(
    BillingCatalogListQuery query,
  ) async => productResult;

  @override
  Future<Result<PageResult<BillingPriceEntity>>> fetchPrices(
    BillingCatalogListQuery query,
  ) async => const Result<PageResult<BillingPriceEntity>>.success(
    PageResult<BillingPriceEntity>(
      items: <BillingPriceEntity>[],
      total: 0,
      page: 1,
      pageSize: 15,
    ),
  );

  @override
  Future<Result<void>> archivePrice(BillingCatalogLifecycleInput input) async =>
      const Result<void>.success(null);

  @override
  Future<Result<void>> archiveProduct(
    BillingCatalogLifecycleInput input,
  ) async => const Result<void>.success(null);

  @override
  Future<Result<void>> createPrice(BillingPriceCreateInput input) async =>
      const Result<void>.success(null);

  @override
  Future<Result<void>> createProduct(BillingProductCreateInput input) async =>
      const Result<void>.success(null);

  @override
  Future<Result<void>> restorePrice(BillingCatalogLifecycleInput input) async =>
      const Result<void>.success(null);

  @override
  Future<Result<void>> restoreProduct(
    BillingCatalogLifecycleInput input,
  ) async => const Result<void>.success(null);

  @override
  Future<Result<void>> updatePrice(BillingPriceUpdateInput input) async =>
      const Result<void>.success(null);

  @override
  Future<Result<void>> updateProduct(BillingProductUpdateInput input) async =>
      const Result<void>.success(null);
}
