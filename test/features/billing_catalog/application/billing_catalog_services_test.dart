import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_access_service.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_controller.dart';
import 'package:mugen_ui/features/billing_catalog/application/dto/billing_catalog_inputs.dart';
import 'package:mugen_ui/features/billing_catalog/domain/entities/billing_catalog_entities.dart';
import 'package:mugen_ui/features/billing_catalog/domain/repositories/billing_catalog_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

void main() {
  group('Billing catalog entities', () {
    test('derive extension registration, selector labels, and intervals', () {
      expect(_extension().isRegistered, isTrue);
      expect(_extension(available: false).isRegistered, isFalse);
      expect(_extension(status: 'failed').isRegistered, isFalse);
      expect(_product.selectorLabel, 'PRO — Pro');
      expect(_price.billingInterval, 'month');
      expect(
        _priceWith(intervalUnit: 'day', intervalCount: 3).billingInterval,
        '3 day',
      );
      expect(
        _priceWith(intervalUnit: ' ', intervalCount: null).billingInterval,
        '',
      );
      expect(
        _priceWith(intervalUnit: null, intervalCount: null).billingInterval,
        '',
      );
    });
  });

  group('BillingCatalogAccessService', () {
    test('allows registered extension with global read access', () async {
      final repository = _FakeRepository();
      var expired = 0;
      final state = await BillingCatalogAccessService(
        repository: repository,
        onSessionExpired: () => expired += 1,
      ).resolve();

      expect(state.status, BillingCatalogAccessStatus.available);
      expect(state.message, isEmpty);
      expect(state.isAvailable, isTrue);
      expect(repository.verifyReadCalls, 1);
      expect(expired, 0);
    });

    for (final entry in <(String, String)>[
      ('disabled', 'Billing extension is disabled.'),
      ('failed', 'Billing extension bootstrap failed.'),
      ('unsupported', 'Billing extension is unavailable on this platform.'),
      ('absent', 'Billing extension is unavailable.'),
    ]) {
      test('hides an unavailable ${entry.$1} extension', () async {
        final repository = _FakeRepository()
          ..extensionResult = Result<BillingExtensionStatusEntity>.success(
            _extension(status: entry.$1, available: false),
          );

        final state = await BillingCatalogAccessService(
          repository: repository,
          onSessionExpired: () {},
        ).resolve();

        expect(state.status, BillingCatalogAccessStatus.extensionUnavailable);
        expect(state.message, entry.$2);
        expect(state.isAvailable, isFalse);
        expect(repository.verifyReadCalls, 0);
      });
    }

    test(
      'reports extension discovery failure and refreshes expired session',
      () async {
        final repository = _FakeRepository()
          ..extensionResult =
              const Result<BillingExtensionStatusEntity>.failure(
                SessionExpiredFailure(''),
              );
        var expired = 0;

        final state = await BillingCatalogAccessService(
          repository: repository,
          onSessionExpired: () => expired += 1,
        ).resolve();

        expect(state.status, BillingCatalogAccessStatus.error);
        expect(state.message, 'Billing extension status could not be loaded.');
        expect(expired, 1);
      },
    );

    test(
      'preserves discovery errors and refreshes unauthorized session',
      () async {
        final repository = _FakeRepository()
          ..extensionResult =
              const Result<BillingExtensionStatusEntity>.failure(
                UnauthorizedFailure('discovery denied'),
              );
        var expired = 0;

        final state = await BillingCatalogAccessService(
          repository: repository,
          onSessionExpired: () => expired += 1,
        ).resolve();

        expect(state.message, 'discovery denied');
        expect(expired, 1);
      },
    );

    test('distinguishes missing permission from access errors', () async {
      final forbiddenRepository = _FakeRepository()
        ..readResult = const Result<void>.failure(ApiFailure(403, 'Forbidden'));
      final errorRepository = _FakeRepository()
        ..readResult = const Result<void>.failure(NetworkFailure(''));

      final forbidden = await BillingCatalogAccessService(
        repository: forbiddenRepository,
        onSessionExpired: () {},
      ).resolve();
      final error = await BillingCatalogAccessService(
        repository: errorRepository,
        onSessionExpired: () {},
      ).resolve();

      expect(forbidden.status, BillingCatalogAccessStatus.permissionDenied);
      expect(
        forbidden.message,
        'You do not have permission to view the Billing Catalog.',
      );
      expect(error.status, BillingCatalogAccessStatus.error);
      expect(error.message, 'Billing Catalog access could not be verified.');
    });

    test(
      'refreshes session on read probe expiry and preserves message',
      () async {
        final repository = _FakeRepository()
          ..readResult = const Result<void>.failure(
            SessionExpiredFailure('read expired'),
          );
        var expired = 0;

        final state = await BillingCatalogAccessService(
          repository: repository,
          onSessionExpired: () => expired += 1,
        ).resolve();

        expect(state.status, BillingCatalogAccessStatus.error);
        expect(state.message, 'read expired');
        expect(expired, 1);
      },
    );
  });

  group('BillingCatalogController queries', () {
    test('loads both Product page and global Product options', () async {
      final repository = _FakeRepository();
      final controller = _controller(repository);

      expect(controller.state.activeSearchTerm, isEmpty);
      await controller.loadInitialData();

      expect(controller.state.products.items, <BillingProductEntity>[_product]);
      expect(controller.state.productOptions, <BillingProductEntity>[_product]);
      expect(controller.state.isLoading, isFalse);
      expect(repository.productQueries, hasLength(2));
      expect(
        repository.productQueries.map((query) => query.pageRequest.pageSize),
        containsAll(<int>[15, 500]),
      );
    });

    test('supports tab, lifecycle, search, filters, and pagination', () async {
      final repository = _FakeRepository();
      final controller = _controller(repository);

      await controller.selectTab(BillingCatalogTab.products);
      expect(repository.priceQueries, isEmpty);

      await controller.selectTab(BillingCatalogTab.prices);
      expect(controller.state.activeTab, BillingCatalogTab.prices);
      expect(controller.state.activeSearchTerm, isEmpty);
      expect(repository.priceQueries.last.pageRequest.page, 1);

      await controller.setSearchTerm(' monthly ');
      expect(controller.state.priceSearchTerm, 'monthly');
      expect(repository.priceQueries.last.searchTerm, 'monthly');

      await controller.selectProductFilter(' product-1 ');
      expect(controller.state.selectedProductId, 'product-1');
      expect(repository.priceQueries.last.productId, 'product-1');

      await controller.setPage(3);
      expect(repository.priceQueries.last.pageRequest.page, 3);

      await controller.setRowsPerPage(25);
      expect(repository.priceQueries.last.pageRequest.page, 1);
      expect(repository.priceQueries.last.pageRequest.pageSize, 25);

      await controller.selectLifecycleView(
        BillingCatalogLifecycleView.archived,
      );
      expect(
        repository.priceQueries.last.lifecycleView,
        BillingCatalogLifecycleView.archived,
      );
      expect(controller.state.prices.page, 1);

      final queryCount = repository.priceQueries.length;
      await controller.selectLifecycleView(
        BillingCatalogLifecycleView.archived,
      );
      expect(repository.priceQueries, hasLength(queryCount));

      await controller.selectProductFilter(' ');
      expect(controller.state.selectedProductId, isNull);

      await controller.selectTab(BillingCatalogTab.products);
      await controller.setSearchTerm(' pro ');
      await controller.setPage(2);
      await controller.setRowsPerPage(30);
      expect(controller.state.productSearchTerm, 'pro');
      expect(repository.productQueries.last.pageRequest.page, 1);
      expect(repository.productQueries.last.pageRequest.pageSize, 30);

      final priceCallCount = repository.priceQueries.length;
      await controller.selectProductFilter('product-1');
      expect(repository.priceQueries, hasLength(priceCallCount));
      expect(controller.state.selectedProductId, 'product-1');
    });

    test(
      'refresh and available Product search use global active queries',
      () async {
        final repository = _FakeRepository();
        final controller = _controller(repository);

        await controller.refresh();
        final result = await controller.searchAvailableProducts('starter');

        expect(result.data, <BillingProductEntity>[_product]);
        final query = repository.productQueries.last;
        expect(query.pageRequest.pageSize, 50);
        expect(query.lifecycleView, BillingCatalogLifecycleView.active);
        expect(query.searchTerm, 'starter');
      },
    );

    test('applies Product, Price, option, and search load failures', () async {
      var expired = 0;
      final repository = _FakeRepository()
        ..productResult =
            const Result<PageResult<BillingProductEntity>>.failure(
              UnexpectedFailure(''),
            );
      final controller = BillingCatalogController(
        repository: repository,
        onSessionExpired: () => expired += 1,
      );

      await controller.loadActiveTab();
      expect(controller.state.errorMessage, 'Could not load Billing Products.');
      expect(controller.state.isLoading, isFalse);

      repository.productResult =
          const Result<PageResult<BillingProductEntity>>.failure(
            SessionExpiredFailure('options expired'),
          );
      await controller.loadProductOptions();
      expect(expired, 1);

      final search = await controller.searchAvailableProducts('x');
      expect(search.failure, isA<SessionExpiredFailure>());
      expect(expired, 2);

      repository.productResult =
          Result<PageResult<BillingProductEntity>>.success(_productPage);
      repository.priceResult =
          const Result<PageResult<BillingPriceEntity>>.failure(
            UnauthorizedFailure('prices denied'),
          );
      await controller.selectTab(BillingCatalogTab.prices);
      expect(controller.state.errorMessage, 'prices denied');
      expect(expired, 3);
    });
  });

  group('BillingCatalogController mutations', () {
    test('runs all global mutations with RowVersion and refreshes', () async {
      final repository = _FakeRepository();
      final controller = _controller(repository);
      const productCreate = BillingProductCreateInput(code: 'pro', name: 'Pro');
      const productUpdate = BillingProductUpdateInput(
        id: 'product-1',
        rowVersion: 7,
        code: 'pro',
        name: 'Pro',
      );
      const priceCreate = BillingPriceCreateInput(
        productId: 'product-1',
        code: 'monthly',
        priceType: 'recurring',
        currency: 'USD',
      );
      const priceUpdate = BillingPriceUpdateInput(
        id: 'price-1',
        rowVersion: 4,
        productId: 'product-1',
        code: 'monthly',
        priceType: 'recurring',
        currency: 'USD',
      );

      expect((await controller.createProduct(productCreate)).isSuccess, isTrue);
      expect((await controller.updateProduct(productUpdate)).isSuccess, isTrue);
      expect((await controller.archiveProduct(_product)).isSuccess, isTrue);
      expect((await controller.restoreProduct(_product)).isSuccess, isTrue);
      expect((await controller.createPrice(priceCreate)).isSuccess, isTrue);
      expect((await controller.updatePrice(priceUpdate)).isSuccess, isTrue);
      expect((await controller.archivePrice(_price)).isSuccess, isTrue);
      expect((await controller.restorePrice(_price)).isSuccess, isTrue);

      expect(repository.mutationNames, <String>[
        'createProduct',
        'updateProduct',
        'archiveProduct',
        'restoreProduct',
        'createPrice',
        'updatePrice',
        'archivePrice',
        'restorePrice',
      ]);
      expect(
        (repository.mutationInputs[2] as BillingCatalogLifecycleInput).id,
        'product-1',
      );
      expect(
        (repository.mutationInputs[2] as BillingCatalogLifecycleInput)
            .rowVersion,
        7,
      );
      expect(
        (repository.mutationInputs[6] as BillingCatalogLifecycleInput).id,
        'price-1',
      );
      expect(
        (repository.mutationInputs[6] as BillingCatalogLifecycleInput)
            .rowVersion,
        4,
      );
      expect(controller.state.isMutating, isFalse);
      expect(controller.state.errorMessage, isNull);
    });

    test(
      'maps permissions, duplicate codes, RowVersion, and immutable Price conflicts',
      () async {
        final repository = _FakeRepository();
        final controller = _controller(repository);

        repository.mutationResults.addAll(<Result<void>>[
          const Result<void>.failure(ApiFailure(403, 'no')),
          const Result<void>.failure(ApiFailure(409, 'generic conflict')),
          const Result<void>.failure(ApiFailure(409, 'another conflict')),
          const Result<void>.failure(ApiFailure(409, 'RowVersion mismatch')),
          const Result<void>.failure(
            ApiFailure(
              409,
              'Referenced Prices cannot change commercial fields; create a new Price.',
            ),
          ),
        ]);

        final forbidden = await controller.updateProduct(
          const BillingProductUpdateInput(
            id: 'p',
            rowVersion: 1,
            code: 'p',
            name: 'P',
          ),
        );
        final productDuplicate = await controller.createProduct(
          const BillingProductCreateInput(code: 'p', name: 'P'),
        );
        final priceDuplicate = await controller.createPrice(
          const BillingPriceCreateInput(
            productId: 'p',
            code: 'x',
            priceType: 'one_time',
            currency: 'USD',
          ),
        );
        final rowVersion = await controller.archiveProduct(_product);
        final immutable = await controller.updatePrice(
          const BillingPriceUpdateInput(
            id: 'x',
            rowVersion: 1,
            productId: 'p',
            code: 'x',
            priceType: 'recurring',
            currency: 'USD',
          ),
        );

        expect(
          forbidden.failure!.message,
          'You do not have permission to modify the Billing Catalog.',
        );
        expect(
          productDuplicate.failure!.message,
          'A Product with this code already exists.',
        );
        expect(
          priceDuplicate.failure!.message,
          'A Price with this code already exists for the selected Product.',
        );
        expect(rowVersion.failure!.message, 'RowVersion mismatch');
        expect(
          immutable.failure!.message,
          'Referenced Prices cannot change commercial fields; create a new Price.',
        );
      },
    );

    test(
      'preserves failure types, supplies fallbacks, and refreshes sessions',
      () async {
        final failures = <Failure>[
          const ValidationFailure('validation'),
          const NetworkFailure('network'),
          const SessionExpiredFailure('expired'),
          const UnauthorizedFailure('unauthorized'),
          const UnexpectedFailure('unexpected'),
          const UnexpectedFailure(''),
        ];
        final repository = _FakeRepository()
          ..mutationResults.addAll(
            failures.map((failure) => Result<void>.failure(failure)),
          );
        var expired = 0;
        final controller = BillingCatalogController(
          repository: repository,
          onSessionExpired: () => expired += 1,
        );

        final results = <Result<void>>[];
        for (var index = 0; index < failures.length; index += 1) {
          results.add(await controller.restorePrice(_price));
        }

        expect(results[0].failure, isA<ValidationFailure>());
        expect(results[1].failure, isA<NetworkFailure>());
        expect(results[2].failure, isA<SessionExpiredFailure>());
        expect(results[3].failure, isA<UnauthorizedFailure>());
        expect(results[4].failure, isA<UnexpectedFailure>());
        expect(results[5].failure!.message, 'Billing Catalog request failed.');
        expect(expired, 2);
      },
    );
  });

  test('BillingCatalogState copyWith clears selection and errors', () {
    final initial = BillingCatalogState.initial();
    final changed = initial.copyWith(
      activeTab: BillingCatalogTab.prices,
      selectedProductId: 'p',
      productSearchTerm: 'product',
      priceSearchTerm: 'price',
      errorMessage: 'error',
      isLoading: true,
      isMutating: true,
    );
    final cleared = changed.copyWith(
      clearSelectedProduct: true,
      clearError: true,
    );

    expect(changed.activeSearchTerm, 'price');
    expect(cleared.selectedProductId, isNull);
    expect(cleared.errorMessage, isNull);
    expect(cleared.isLoading, isTrue);
    expect(cleared.isMutating, isTrue);
  });
}

BillingCatalogController _controller(_FakeRepository repository) {
  return BillingCatalogController(
    repository: repository,
    onSessionExpired: () {},
  );
}

BillingExtensionStatusEntity _extension({
  String status = 'registered',
  bool available = true,
}) {
  return BillingExtensionStatusEntity(
    token: 'core.fw.billing',
    extensionType: 'fw',
    configured: true,
    enabled: true,
    available: available,
    status: status,
  );
}

const BillingProductEntity _product = BillingProductEntity(
  id: 'product-1',
  code: 'PRO',
  name: 'Pro',
  rowVersion: 7,
  isArchived: false,
);

const BillingPriceEntity _price = BillingPriceEntity(
  id: 'price-1',
  productId: 'product-1',
  code: 'MONTHLY',
  priceType: 'recurring',
  currency: 'USD',
  intervalUnit: 'month',
  intervalCount: 1,
  rowVersion: 4,
  isArchived: false,
);

BillingPriceEntity _priceWith({
  required String? intervalUnit,
  required int? intervalCount,
}) {
  return BillingPriceEntity(
    id: 'price',
    productId: 'product',
    code: 'price',
    priceType: 'recurring',
    currency: 'USD',
    intervalUnit: intervalUnit,
    intervalCount: intervalCount,
    rowVersion: 1,
    isArchived: false,
  );
}

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

class _FakeRepository implements BillingCatalogRepository {
  Result<BillingExtensionStatusEntity> extensionResult =
      Result<BillingExtensionStatusEntity>.success(_extension());
  Result<void> readResult = const Result<void>.success(null);
  Result<PageResult<BillingProductEntity>> productResult =
      const Result<PageResult<BillingProductEntity>>.success(_productPage);
  Result<PageResult<BillingPriceEntity>> priceResult =
      const Result<PageResult<BillingPriceEntity>>.success(_pricePage);
  final Queue<Result<void>> mutationResults = Queue<Result<void>>();
  final List<BillingCatalogListQuery> productQueries =
      <BillingCatalogListQuery>[];
  final List<BillingCatalogListQuery> priceQueries =
      <BillingCatalogListQuery>[];
  final List<String> mutationNames = <String>[];
  final List<Object> mutationInputs = <Object>[];
  int verifyReadCalls = 0;

  Result<void> _recordMutation(String name, Object input) {
    mutationNames.add(name);
    mutationInputs.add(input);
    return mutationResults.isEmpty
        ? const Result<void>.success(null)
        : mutationResults.removeFirst();
  }

  @override
  Future<Result<BillingExtensionStatusEntity>>
  fetchBillingExtensionStatus() async {
    return extensionResult;
  }

  @override
  Future<Result<void>> verifyCatalogReadAccess() async {
    verifyReadCalls += 1;
    return readResult;
  }

  @override
  Future<Result<PageResult<BillingProductEntity>>> fetchProducts(
    BillingCatalogListQuery query,
  ) async {
    productQueries.add(query);
    return productResult;
  }

  @override
  Future<Result<PageResult<BillingPriceEntity>>> fetchPrices(
    BillingCatalogListQuery query,
  ) async {
    priceQueries.add(query);
    return priceResult;
  }

  @override
  Future<Result<void>> createProduct(BillingProductCreateInput input) async {
    return _recordMutation('createProduct', input);
  }

  @override
  Future<Result<void>> updateProduct(BillingProductUpdateInput input) async {
    return _recordMutation('updateProduct', input);
  }

  @override
  Future<Result<void>> archiveProduct(
    BillingCatalogLifecycleInput input,
  ) async {
    return _recordMutation('archiveProduct', input);
  }

  @override
  Future<Result<void>> restoreProduct(
    BillingCatalogLifecycleInput input,
  ) async {
    return _recordMutation('restoreProduct', input);
  }

  @override
  Future<Result<void>> createPrice(BillingPriceCreateInput input) async {
    return _recordMutation('createPrice', input);
  }

  @override
  Future<Result<void>> updatePrice(BillingPriceUpdateInput input) async {
    return _recordMutation('updatePrice', input);
  }

  @override
  Future<Result<void>> archivePrice(BillingCatalogLifecycleInput input) async {
    return _recordMutation('archivePrice', input);
  }

  @override
  Future<Result<void>> restorePrice(BillingCatalogLifecycleInput input) async {
    return _recordMutation('restorePrice', input);
  }
}
