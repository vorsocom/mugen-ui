import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/features/billing_catalog/application/dto/billing_catalog_inputs.dart';
import 'package:mugen_ui/features/billing_catalog/domain/entities/billing_catalog_entities.dart';
import 'package:mugen_ui/features/billing_catalog/domain/repositories/billing_catalog_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

enum BillingCatalogTab { products, prices }

class BillingCatalogState {
  const BillingCatalogState({
    required this.activeTab,
    required this.lifecycleView,
    required this.products,
    required this.prices,
    required this.productOptions,
    required this.productSearchTerm,
    required this.priceSearchTerm,
    required this.isLoading,
    required this.isMutating,
    this.selectedProductId,
    this.errorMessage,
  });

  factory BillingCatalogState.initial() {
    return const BillingCatalogState(
      activeTab: BillingCatalogTab.products,
      lifecycleView: BillingCatalogLifecycleView.active,
      products: PageResult<BillingProductEntity>(
        items: <BillingProductEntity>[],
        total: 0,
        page: 1,
        pageSize: 15,
      ),
      prices: PageResult<BillingPriceEntity>(
        items: <BillingPriceEntity>[],
        total: 0,
        page: 1,
        pageSize: 15,
      ),
      productOptions: <BillingProductEntity>[],
      productSearchTerm: '',
      priceSearchTerm: '',
      isLoading: false,
      isMutating: false,
    );
  }

  final BillingCatalogTab activeTab;
  final BillingCatalogLifecycleView lifecycleView;
  final PageResult<BillingProductEntity> products;
  final PageResult<BillingPriceEntity> prices;
  final List<BillingProductEntity> productOptions;
  final String productSearchTerm;
  final String priceSearchTerm;
  final String? selectedProductId;
  final bool isLoading;
  final bool isMutating;
  final String? errorMessage;

  String get activeSearchTerm => activeTab == BillingCatalogTab.products
      ? productSearchTerm
      : priceSearchTerm;

  BillingCatalogState copyWith({
    BillingCatalogTab? activeTab,
    BillingCatalogLifecycleView? lifecycleView,
    PageResult<BillingProductEntity>? products,
    PageResult<BillingPriceEntity>? prices,
    List<BillingProductEntity>? productOptions,
    String? productSearchTerm,
    String? priceSearchTerm,
    String? selectedProductId,
    bool clearSelectedProduct = false,
    bool? isLoading,
    bool? isMutating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BillingCatalogState(
      activeTab: activeTab ?? this.activeTab,
      lifecycleView: lifecycleView ?? this.lifecycleView,
      products: products ?? this.products,
      prices: prices ?? this.prices,
      productOptions: productOptions ?? this.productOptions,
      productSearchTerm: productSearchTerm ?? this.productSearchTerm,
      priceSearchTerm: priceSearchTerm ?? this.priceSearchTerm,
      selectedProductId: clearSelectedProduct
          ? null
          : (selectedProductId ?? this.selectedProductId),
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class BillingCatalogController extends StateNotifier<BillingCatalogState> {
  BillingCatalogController({
    required this.repository,
    required this.onSessionExpired,
  }) : super(BillingCatalogState.initial());

  final BillingCatalogRepository repository;
  final void Function() onSessionExpired;

  Future<void> loadInitialData() async {
    await Future.wait(<Future<void>>[loadActiveTab(), loadProductOptions()]);
  }

  Future<void> refresh() async {
    await Future.wait(<Future<void>>[loadActiveTab(), loadProductOptions()]);
  }

  Future<void> loadActiveTab() async {
    state = state.copyWith(isLoading: true, clearError: true);
    if (state.activeTab == BillingCatalogTab.products) {
      final result = await repository.fetchProducts(_productQuery());
      if (result.isFailure) {
        _applyLoadFailure(result.failure!, 'Could not load Billing Products.');
        return;
      }
      state = state.copyWith(
        products: result.data!,
        isLoading: false,
        clearError: true,
      );
      return;
    }

    final result = await repository.fetchPrices(_priceQuery());
    if (result.isFailure) {
      _applyLoadFailure(result.failure!, 'Could not load Billing Prices.');
      return;
    }
    state = state.copyWith(
      prices: result.data!,
      isLoading: false,
      clearError: true,
    );
  }

  Future<void> loadProductOptions() async {
    final result = await repository.fetchProducts(
      const BillingCatalogListQuery(
        pageRequest: PageRequest(page: 1, pageSize: 500),
        lifecycleView: BillingCatalogLifecycleView.active,
      ),
    );
    if (result.isFailure) {
      _handleSessionFailure(result.failure!);
      return;
    }
    state = state.copyWith(productOptions: result.data!.items);
  }

  Future<Result<List<BillingProductEntity>>> searchAvailableProducts(
    String searchTerm,
  ) async {
    final result = await repository.fetchProducts(
      BillingCatalogListQuery(
        pageRequest: const PageRequest(page: 1, pageSize: 50),
        lifecycleView: BillingCatalogLifecycleView.active,
        searchTerm: searchTerm,
      ),
    );
    if (result.isFailure) {
      _handleSessionFailure(result.failure!);
      return Result<List<BillingProductEntity>>.failure(result.failure!);
    }
    return Result<List<BillingProductEntity>>.success(result.data!.items);
  }

  Future<void> selectTab(BillingCatalogTab tab) async {
    if (tab == state.activeTab) {
      return;
    }
    state = state.copyWith(activeTab: tab, clearError: true);
    await loadActiveTab();
  }

  Future<void> selectLifecycleView(
    BillingCatalogLifecycleView lifecycleView,
  ) async {
    if (lifecycleView == state.lifecycleView) {
      return;
    }
    state = state.copyWith(
      lifecycleView: lifecycleView,
      products: _withProductPage(state.products, 1),
      prices: _withPricePage(state.prices, 1),
      clearError: true,
    );
    await loadActiveTab();
  }

  Future<void> setSearchTerm(String value) async {
    final normalized = value.trim();
    if (state.activeTab == BillingCatalogTab.products) {
      state = state.copyWith(
        productSearchTerm: normalized,
        products: _withProductPage(state.products, 1),
      );
    } else {
      state = state.copyWith(
        priceSearchTerm: normalized,
        prices: _withPricePage(state.prices, 1),
      );
    }
    await loadActiveTab();
  }

  Future<void> selectProductFilter(String? productId) async {
    final normalized = productId?.trim();
    state = state.copyWith(
      selectedProductId: normalized,
      clearSelectedProduct: normalized == null || normalized.isEmpty,
      prices: _withPricePage(state.prices, 1),
    );
    if (state.activeTab == BillingCatalogTab.prices) {
      await loadActiveTab();
    }
  }

  Future<void> setPage(int page) async {
    if (state.activeTab == BillingCatalogTab.products) {
      state = state.copyWith(products: _withProductPage(state.products, page));
    } else {
      state = state.copyWith(prices: _withPricePage(state.prices, page));
    }
    await loadActiveTab();
  }

  Future<void> setRowsPerPage(int pageSize) async {
    if (state.activeTab == BillingCatalogTab.products) {
      state = state.copyWith(
        products: PageResult<BillingProductEntity>(
          items: state.products.items,
          total: state.products.total,
          page: 1,
          pageSize: pageSize,
        ),
      );
    } else {
      state = state.copyWith(
        prices: PageResult<BillingPriceEntity>(
          items: state.prices.items,
          total: state.prices.total,
          page: 1,
          pageSize: pageSize,
        ),
      );
    }
    await loadActiveTab();
  }

  Future<Result<void>> createProduct(BillingProductCreateInput input) {
    return _runMutation(
      () => repository.createProduct(input),
      conflictMessage: 'A Product with this code already exists.',
    );
  }

  Future<Result<void>> updateProduct(BillingProductUpdateInput input) {
    return _runMutation(
      () => repository.updateProduct(input),
      conflictMessage: 'A Product with this code already exists.',
    );
  }

  Future<Result<void>> archiveProduct(BillingProductEntity product) {
    return _runMutation(
      () => repository.archiveProduct(
        BillingCatalogLifecycleInput(
          id: product.id,
          rowVersion: product.rowVersion,
        ),
      ),
    );
  }

  Future<Result<void>> restoreProduct(BillingProductEntity product) {
    return _runMutation(
      () => repository.restoreProduct(
        BillingCatalogLifecycleInput(
          id: product.id,
          rowVersion: product.rowVersion,
        ),
      ),
    );
  }

  Future<Result<void>> createPrice(BillingPriceCreateInput input) {
    return _runMutation(
      () => repository.createPrice(input),
      conflictMessage:
          'A Price with this code already exists for the selected Product.',
    );
  }

  Future<Result<void>> updatePrice(BillingPriceUpdateInput input) {
    return _runMutation(
      () => repository.updatePrice(input),
      conflictMessage:
          'A Price with this code already exists for the selected Product.',
    );
  }

  Future<Result<void>> archivePrice(BillingPriceEntity price) {
    return _runMutation(
      () => repository.archivePrice(
        BillingCatalogLifecycleInput(
          id: price.id,
          rowVersion: price.rowVersion,
        ),
      ),
    );
  }

  Future<Result<void>> restorePrice(BillingPriceEntity price) {
    return _runMutation(
      () => repository.restorePrice(
        BillingCatalogLifecycleInput(
          id: price.id,
          rowVersion: price.rowVersion,
        ),
      ),
    );
  }

  Future<Result<void>> _runMutation(
    Future<Result<void>> Function() action, {
    String? conflictMessage,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await action();
    state = state.copyWith(isMutating: false);
    if (result.isSuccess) {
      await refresh();
      return result;
    }

    final failure = result.failure!;
    _handleSessionFailure(failure);
    final message = _mutationMessage(failure, conflictMessage: conflictMessage);
    state = state.copyWith(errorMessage: message);
    return Result<void>.failure(_failureWithMessage(failure, message));
  }

  BillingCatalogListQuery _productQuery() {
    return BillingCatalogListQuery(
      pageRequest: PageRequest(
        page: state.products.page,
        pageSize: state.products.pageSize,
      ),
      lifecycleView: state.lifecycleView,
      searchTerm: state.productSearchTerm,
    );
  }

  BillingCatalogListQuery _priceQuery() {
    return BillingCatalogListQuery(
      pageRequest: PageRequest(
        page: state.prices.page,
        pageSize: state.prices.pageSize,
      ),
      lifecycleView: state.lifecycleView,
      searchTerm: state.priceSearchTerm,
      productId: state.selectedProductId,
    );
  }

  void _applyLoadFailure(Failure failure, String fallback) {
    _handleSessionFailure(failure);
    state = state.copyWith(
      isLoading: false,
      errorMessage: failure.message.trim().isEmpty ? fallback : failure.message,
    );
  }

  void _handleSessionFailure(Failure failure) {
    if (failure is SessionExpiredFailure || failure is UnauthorizedFailure) {
      onSessionExpired();
    }
  }

  String _mutationMessage(Failure failure, {String? conflictMessage}) {
    if (failure is ApiFailure && failure.statusCode == 403) {
      return 'You do not have permission to modify the Billing Catalog.';
    }
    if (failure is ApiFailure && failure.statusCode == 409) {
      final backendMessage = failure.message.trim();
      if (backendMessage.toLowerCase().contains('rowversion')) {
        return backendMessage.isEmpty
            ? 'RowVersion conflict. Refresh and retry.'
            : backendMessage;
      }
      if (backendMessage.contains('Referenced Prices')) {
        return backendMessage;
      }
      if (conflictMessage != null) {
        return conflictMessage;
      }
    }
    return failure.message.trim().isEmpty
        ? 'Billing Catalog request failed.'
        : failure.message;
  }

  Failure _failureWithMessage(Failure failure, String message) {
    if (failure is ApiFailure) {
      return ApiFailure(failure.statusCode, message);
    }
    if (failure is ValidationFailure) {
      return ValidationFailure(message);
    }
    if (failure is NetworkFailure) {
      return NetworkFailure(message);
    }
    if (failure is SessionExpiredFailure) {
      return SessionExpiredFailure(message);
    }
    if (failure is UnauthorizedFailure) {
      return UnauthorizedFailure(message);
    }
    return UnexpectedFailure(message);
  }

  PageResult<BillingProductEntity> _withProductPage(
    PageResult<BillingProductEntity> page,
    int nextPage,
  ) {
    return PageResult<BillingProductEntity>(
      items: page.items,
      total: page.total,
      page: nextPage,
      pageSize: page.pageSize,
    );
  }

  PageResult<BillingPriceEntity> _withPricePage(
    PageResult<BillingPriceEntity> page,
    int nextPage,
  ) {
    return PageResult<BillingPriceEntity>(
      items: page.items,
      total: page.total,
      page: nextPage,
      pageSize: page.pageSize,
    );
  }
}
