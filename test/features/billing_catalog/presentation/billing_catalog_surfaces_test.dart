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
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_json_editor_field.dart';

void main() {
  test('repository provider builds the production implementation', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(billingCatalogRepositoryProvider),
      isA<BillingCatalogRepositoryImpl>(),
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

  test('access and controller providers refresh an expired session', () async {
    final repository = _SurfaceRepository()
      ..readResult = const Result<void>.failure(SessionExpiredFailure())
      ..productResult = const Result<PageResult<BillingProductEntity>>.failure(
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
  });

  test(
    'shell availability remains pending, then maps errors and states',
    () async {
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
      final errorAvailability = pendingContainer.read(
        billingCatalogShellAvailabilityProvider,
      );
      expect(
        errorAvailability.status,
        ShellRouteAvailabilityStatus.unavailable,
      );
      expect(
        errorAvailability.message,
        'Billing extension status could not be loaded.',
      );

      final unavailableContainer = ProviderContainer(
        overrides: <Override>[
          billingCatalogAccessProvider.overrideWith(
            (ref) async => const BillingCatalogAccessState(
              status: BillingCatalogAccessStatus.extensionUnavailable,
              message: 'Billing extension is disabled.',
            ),
          ),
        ],
      );
      addTearDown(unavailableContainer.dispose);
      await unavailableContainer.read(billingCatalogAccessProvider.future);
      expect(
        unavailableContainer
            .read(billingCatalogShellAvailabilityProvider)
            .message,
        'Billing extension is disabled.',
      );

      final availableContainer = ProviderContainer(
        overrides: <Override>[
          billingCatalogAccessProvider.overrideWith(
            (ref) async => const BillingCatalogAccessState.available(),
          ),
        ],
      );
      addTearDown(availableContainer.dispose);
      await availableContainer.read(billingCatalogAccessProvider.future);
      expect(
        availableContainer.read(billingCatalogShellAvailabilityProvider).status,
        ShellRouteAvailabilityStatus.available,
      );
    },
  );

  testWidgets('does not load or flash catalog while discovery is pending', (
    tester,
  ) async {
    final repository = _SurfaceRepository();
    final pending = Completer<BillingCatalogAccessState>();

    await _pumpPanel(
      tester,
      repository: repository,
      session: _readerSession,
      accessBuilder: (ref) => pending.future,
    );

    expect(find.text('Checking Billing availability'), findsOneWidget);
    expect(find.text('Billing Catalog'), findsNothing);
    expect(repository.productCalls, 0);
    expect(repository.priceCalls, 0);

    pending.complete(
      const BillingCatalogAccessState(
        status: BillingCatalogAccessStatus.extensionUnavailable,
        message: 'Billing extension is disabled.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Billing extension unavailable'), findsOneWidget);
    expect(find.text('Billing extension is disabled.'), findsOneWidget);
    expect(repository.productCalls, 0);
    expect(repository.priceCalls, 0);
  });

  testWidgets('shows clear permission and bootstrap failure states', (
    tester,
  ) async {
    final repository = _SurfaceRepository();

    await _pumpPanel(
      tester,
      repository: repository,
      session: _readerSession,
      accessBuilder: (ref) async => const BillingCatalogAccessState(
        status: BillingCatalogAccessStatus.permissionDenied,
        message: 'You do not have permission to view the Billing Catalog.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catalog read permission required'), findsOneWidget);
    expect(repository.productCalls, 0);

    await _pumpPanel(
      tester,
      repository: repository,
      session: _readerSession,
      accessBuilder: (ref) async => const BillingCatalogAccessState(
        status: BillingCatalogAccessStatus.extensionUnavailable,
        message: 'Billing extension bootstrap failed.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Billing extension bootstrap failed.'), findsOneWidget);
  });

  testWidgets('readers see global Products and Prices without mutations', (
    tester,
  ) async {
    final repository = _SurfaceRepository();

    await _pumpAvailablePanel(
      tester,
      repository: repository,
      session: _readerSession,
    );

    expect(find.text('Billing Catalog'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(
      find.byKey(const Key('billing-product-view-product-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('billing-catalog-create-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('billing-product-edit-product-1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('billing-product-archive-product-1')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('billing-catalog-tab-prices')));
    await tester.pumpAndSettle();
    expect(find.text('MONTHLY'), findsOneWidget);
    expect(find.byKey(const Key('billing-price-view-price-1')), findsOneWidget);
    expect(find.byKey(const Key('billing-price-edit-price-1')), findsNothing);
    expect(find.text('month'), findsWidgets);
  });

  testWidgets('administrators can create, edit, and archive Products', (
    tester,
  ) async {
    final repository = _SurfaceRepository();

    await _pumpAvailablePanel(
      tester,
      repository: repository,
      session: _adminSession,
    );

    expect(
      find.byKey(const Key('billing-catalog-create-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('billing-product-edit-product-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('billing-product-archive-product-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('billing-catalog-create-button')));
    await tester.pumpAndSettle();
    expect(find.byType(AcpJsonEditorField), findsOneWidget);
    for (final key in const <String>[
      'billing-product-code-help',
      'billing-product-name-help',
      'billing-product-description-help',
      'billing-product-attributes-help',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(find.byTooltip('Format JSON'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('billing-product-code-field')),
      ' starter ',
    );
    await tester.enterText(
      find.byKey(const Key('billing-product-name-field')),
      'Starter',
    );
    await tester.enterText(
      find.byKey(const Key('billing-product-attributes-field')),
      '{invalid',
    );
    await tester.tap(find.byKey(const Key('billing-catalog-form-submit')));
    await tester.pump();
    expect(find.text('Enter valid JSON.'), findsOneWidget);
    expect(repository.createdProduct, isNull);

    await tester.enterText(
      find.byKey(const Key('billing-product-attributes-field')),
      '{"tier":1}',
    );
    await tester.tap(find.byKey(const Key('billing-catalog-form-submit')));
    await tester.pumpAndSettle();

    expect(repository.createdProduct!.code, ' starter ');
    expect(repository.createdProduct!.attributes, <String, dynamic>{'tier': 1});
    expect(find.text('Product created.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('billing-product-edit-product-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('billing-product-name-field')),
      'Pro Updated',
    );
    await tester.tap(find.byKey(const Key('billing-catalog-form-submit')));
    await tester.pumpAndSettle();
    expect(repository.updatedProduct!.rowVersion, 7);
    expect(repository.updatedProduct!.name, 'Pro Updated');

    await tester.tap(
      find.byKey(const Key('billing-product-archive-product-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(repository.archivedProduct!.id, 'product-1');
    expect(repository.archivedProduct!.rowVersion, 7);
  });

  testWidgets(
    'Price form uses the global Product selector and validates meter data',
    (tester) async {
      final repository = _SurfaceRepository();

      await _pumpAvailablePanel(
        tester,
        repository: repository,
        session: _adminSession,
      );
      await tester.tap(find.byKey(const Key('billing-catalog-tab-prices')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('billing-catalog-create-button')));
      await tester.pumpAndSettle();

      expect(find.byType(AcpJsonEditorField), findsOneWidget);
      for (final key in const <String>[
        'billing-price-product-help',
        'billing-price-code-help',
        'billing-price-type-help',
        'billing-price-currency-help',
        'billing-price-unit-amount-help',
        'billing-price-interval-unit-help',
        'billing-price-interval-count-help',
        'billing-price-trial-days-help',
        'billing-price-usage-unit-help',
        'billing-price-meter-code-help',
        'billing-price-attributes-help',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('billing-catalog-form-submit')));
      await tester.pump();
      expect(find.text('Select a global Product.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('billing-price-product-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('billing-price-product-option-product-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('billing-price-code-field')),
        'metered-api',
      );
      await tester.enterText(
        find.byKey(const Key('billing-price-usage-unit-field')),
        'request',
      );
      await tester.tap(find.byKey(const Key('billing-catalog-form-submit')));
      await tester.pump();
      expect(
        find.text('Meter Code and Usage Unit must be provided together.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('billing-price-meter-code-field')),
        'api_calls',
      );
      await tester.tap(find.byKey(const Key('billing-catalog-form-submit')));
      await tester.pumpAndSettle();

      expect(repository.createdPrice!.productId, 'product-1');
      expect(repository.createdPrice!.code, 'metered-api');
      expect(repository.createdPrice!.usageUnit, 'request');
      expect(repository.createdPrice!.meterCode, 'api_calls');

      await tester.tap(
        find.byKey(const Key('billing-catalog-price-product-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key('billing-catalog-price-product-filter-option-product-1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.lastPriceQuery!.productId, 'product-1');
    },
  );

  testWidgets('administrators can restore archived Products and Prices', (
    tester,
  ) async {
    final repository = _SurfaceRepository()
      ..productResult = const Result<PageResult<BillingProductEntity>>.success(
        PageResult<BillingProductEntity>(
          items: <BillingProductEntity>[_archivedProduct],
          total: 1,
          page: 1,
          pageSize: 15,
        ),
      )
      ..priceResult = const Result<PageResult<BillingPriceEntity>>.success(
        PageResult<BillingPriceEntity>(
          items: <BillingPriceEntity>[_archivedPrice],
          total: 1,
          page: 1,
          pageSize: 15,
        ),
      );

    await _pumpAvailablePanel(
      tester,
      repository: repository,
      session: _adminSession,
    );

    await tester.tap(
      find.byKey(const Key('billing-product-restore-product-archived')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();
    expect(repository.restoredProduct!.id, 'product-archived');
    expect(repository.restoredProduct!.rowVersion, 8);

    await tester.tap(find.byKey(const Key('billing-catalog-tab-prices')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('billing-price-restore-price-archived')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();
    expect(repository.restoredPrice!.id, 'price-archived');
    expect(repository.restoredPrice!.rowVersion, 5);
  });
}

Future<void> _pumpAvailablePanel(
  WidgetTester tester, {
  required _SurfaceRepository repository,
  required AuthSession session,
}) async {
  await _pumpPanel(
    tester,
    repository: repository,
    session: session,
    accessBuilder: (ref) async => const BillingCatalogAccessState.available(),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required _SurfaceRepository repository,
  required AuthSession session,
  required Future<BillingCatalogAccessState> Function(Ref ref) accessBuilder,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        billingCatalogRepositoryProvider.overrideWithValue(repository),
        billingCatalogAccessProvider.overrideWith(accessBuilder),
        authControllerProvider.overrideWith(
          () => _SurfaceAuthController(session: session),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: BillingCatalogPanel(),
          ),
        ),
      ),
    ),
  );
}

const AuthSession _readerSession = AuthSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  userId: 'reader',
  roles: <String>['com.vorsocomputing.mugen.acp:authenticated'],
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
  AuthControllerState build() {
    return AuthControllerState(isLoading: false, session: session);
  }

  @override
  void refreshSession() {
    refreshCalls += 1;
  }
}

class _SurfaceRepository implements BillingCatalogRepository {
  int extensionCalls = 0;
  int productCalls = 0;
  int priceCalls = 0;
  Result<void> readResult = const Result<void>.success(null);
  Result<PageResult<BillingProductEntity>> productResult =
      const Result<PageResult<BillingProductEntity>>.success(_productPage);
  Result<PageResult<BillingPriceEntity>> priceResult =
      const Result<PageResult<BillingPriceEntity>>.success(_pricePage);
  BillingProductCreateInput? createdProduct;
  BillingProductUpdateInput? updatedProduct;
  BillingCatalogLifecycleInput? archivedProduct;
  BillingCatalogLifecycleInput? restoredProduct;
  BillingPriceCreateInput? createdPrice;
  BillingCatalogLifecycleInput? restoredPrice;
  BillingCatalogListQuery? lastPriceQuery;

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
  ) async {
    productCalls += 1;
    return productResult;
  }

  @override
  Future<Result<PageResult<BillingPriceEntity>>> fetchPrices(
    BillingCatalogListQuery query,
  ) async {
    priceCalls += 1;
    lastPriceQuery = query;
    return priceResult;
  }

  @override
  Future<Result<void>> createProduct(BillingProductCreateInput input) async {
    createdProduct = input;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> updateProduct(BillingProductUpdateInput input) async {
    updatedProduct = input;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> archiveProduct(
    BillingCatalogLifecycleInput input,
  ) async {
    archivedProduct = input;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> restoreProduct(
    BillingCatalogLifecycleInput input,
  ) async {
    restoredProduct = input;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> createPrice(BillingPriceCreateInput input) async {
    createdPrice = input;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> updatePrice(BillingPriceUpdateInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> archivePrice(BillingCatalogLifecycleInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> restorePrice(BillingCatalogLifecycleInput input) async {
    restoredPrice = input;
    return const Result<void>.success(null);
  }
}

const BillingProductEntity _product = BillingProductEntity(
  id: 'product-1',
  code: 'PRO',
  name: 'Pro',
  description: 'Professional plan',
  rowVersion: 7,
  isArchived: false,
);

const BillingPriceEntity _price = BillingPriceEntity(
  id: 'price-1',
  productId: 'product-1',
  code: 'MONTHLY',
  priceType: 'recurring',
  currency: 'USD',
  unitAmount: 1999,
  intervalUnit: 'month',
  intervalCount: 1,
  rowVersion: 4,
  isArchived: false,
);

const BillingProductEntity _archivedProduct = BillingProductEntity(
  id: 'product-archived',
  code: 'LEGACY',
  name: 'Legacy',
  rowVersion: 8,
  isArchived: true,
);

const BillingPriceEntity _archivedPrice = BillingPriceEntity(
  id: 'price-archived',
  productId: 'product-archived',
  code: 'LEGACY-MONTHLY',
  priceType: 'recurring',
  currency: 'USD',
  rowVersion: 5,
  isArchived: true,
);

const PageResult<BillingProductEntity> _productPage =
    PageResult<BillingProductEntity>(
      items: <BillingProductEntity>[_product],
      total: 1,
      page: 1,
      pageSize: 15,
    );

const PageResult<BillingPriceEntity> _pricePage =
    PageResult<BillingPriceEntity>(
      items: <BillingPriceEntity>[_price],
      total: 1,
      page: 1,
      pageSize: 15,
    );
