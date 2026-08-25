// coverage:ignore-file

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_access_service.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_controller.dart';
import 'package:mugen_ui/features/billing_catalog/application/dto/billing_catalog_inputs.dart';
import 'package:mugen_ui/features/billing_catalog/domain/entities/billing_catalog_entities.dart';
import 'package:mugen_ui/features/billing_catalog/presentation/providers/billing_catalog_providers.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/forms/app_searchable_select_field.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const Duration _searchDebounce = Duration(milliseconds: 300);
const double _catalogTableMinWidth = 1380;

class BillingCatalogPanel extends ConsumerStatefulWidget {
  const BillingCatalogPanel({super.key});

  @override
  ConsumerState<BillingCatalogPanel> createState() =>
      _BillingCatalogPanelState();
}

class _BillingCatalogPanelState extends ConsumerState<BillingCatalogPanel> {
  Timer? _searchTimer;
  bool _hasLoadedCatalog = false;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(billingCatalogAccessProvider);
    return access.when(
      loading: () => const _BillingAccessState(
        icon: Icons.hourglass_top,
        title: 'Checking Billing availability',
        message:
            'Runtime extension and catalog permissions are being verified.',
        loading: true,
      ),
      error: (_, _) => const _BillingAccessState(
        icon: Icons.error_outline,
        title: 'Billing extension unavailable',
        message: 'Billing extension status could not be loaded.',
      ),
      data: (value) {
        if (!value.isAvailable) {
          return _BillingAccessState(
            icon: value.status == BillingCatalogAccessStatus.permissionDenied
                ? Icons.lock_outline
                : Icons.extension_off_outlined,
            title: value.status == BillingCatalogAccessStatus.permissionDenied
                ? 'Catalog read permission required'
                : 'Billing extension unavailable',
            message: value.message,
          );
        }
        if (!_hasLoadedCatalog) {
          _hasLoadedCatalog = true;
          Future<void>.microtask(
            ref.read(billingCatalogControllerProvider.notifier).loadInitialData,
          );
        }
        return _buildCatalog(context);
      },
    );
  }

  Widget _buildCatalog(BuildContext context) {
    final state = ref.watch(billingCatalogControllerProvider);
    final controller = ref.read(billingCatalogControllerProvider.notifier);
    final isAdministrator =
        ref
            .watch(authControllerProvider)
            .session
            ?.roles
            .contains('$acpNamespace:administrator') ??
        false;
    final isProducts = state.activeTab == BillingCatalogTab.products;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Billing Catalog',
          subtitle:
              'Define the global Products and Prices offered by the platform. This catalog never follows tenant selection.',
          primaryAction: isAdministrator
              ? FilledButton.icon(
                  key: const Key('billing-catalog-create-button'),
                  onPressed: state.isMutating
                      ? null
                      : () => isProducts
                            ? _showProductForm(context)
                            : _showPriceForm(context),
                  icon: const Icon(Icons.add),
                  label: Text(isProducts ? 'New Product' : 'New Price'),
                )
              : null,
        ),
        AdminTabs(
          items: [
            AdminTabItem(
              key: const Key('billing-catalog-tab-products'),
              label: 'Products',
              count: state.products.total,
              selected: isProducts,
              onSelected: () =>
                  unawaited(controller.selectTab(BillingCatalogTab.products)),
            ),
            AdminTabItem(
              key: const Key('billing-catalog-tab-prices'),
              label: 'Prices',
              count: state.prices.total,
              selected: !isProducts,
              onSelected: () =>
                  unawaited(controller.selectTab(BillingCatalogTab.prices)),
            ),
          ],
        ),
        _CatalogToolbar(
          state: state,
          onSearchChanged: (value) {
            _searchTimer?.cancel();
            _searchTimer = Timer(
              _searchDebounce,
              () => controller.setSearchTerm(value),
            );
          },
        ),
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppErrorAlert(message: state.errorMessage!),
          ),
        Expanded(
          child: AdminSurface(
            padding: EdgeInsets.zero,
            child: isProducts
                ? _buildProductsGrid(state, isAdministrator)
                : _buildPricesGrid(state, isAdministrator),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsGrid(BillingCatalogState state, bool isAdministrator) {
    final page = state.products;
    return AdminDataGrid<BillingProductEntity>(
      rows: page.items,
      columns: <AdminGridColumn<BillingProductEntity>>[
        AdminGridColumn(
          key: 'Code',
          label: 'Code',
          flex: 2,
          cell: (_, row) => AdminCellText(row.code),
        ),
        AdminGridColumn(
          key: 'Name',
          label: 'Name',
          flex: 2,
          cell: (_, row) => AdminCellText(row.name),
        ),
        AdminGridColumn(
          key: 'Description',
          label: 'Description',
          flex: 3,
          cell: (_, row) => AdminCellText(row.description ?? '', maxLines: 2),
        ),
        AdminGridColumn(
          key: 'State',
          label: 'State',
          cell: (_, row) => _lifecycleChip(row.isArchived),
        ),
        AdminGridColumn(
          key: 'UpdatedAt',
          label: 'Updated',
          flex: 2,
          cell: (_, row) => AdminCellText(_formatDateTime(row.updatedAt)),
        ),
        AdminGridColumn(
          key: 'RowVersion',
          label: 'RowVersion',
          cell: (_, row) => AdminCellText('${row.rowVersion}'),
        ),
      ],
      actionsBuilder: (context, row) => _ProductActions(
        product: row,
        isAdministrator: isAdministrator,
        onView: () => _showProductDetails(context, row),
        onEdit: () => _showProductForm(context, product: row),
        onArchive: () => _archiveProduct(context, row),
        onRestore: () => _restoreProduct(context, row),
      ),
      actionsWidth: isAdministrator ? 172 : 64,
      rowKey: (row) => row.id,
      onRowSelected: (row) => _showProductDetails(context, row),
      isLoading: state.isLoading,
      hasActiveFilter:
          state.productSearchTerm.isNotEmpty ||
          state.lifecycleView != BillingCatalogLifecycleView.active,
      emptyState: AdminEmptyStateData(
        title: state.lifecycleView == BillingCatalogLifecycleView.archived
            ? 'No archived Products.'
            : 'No Products yet.',
        message: state.lifecycleView == BillingCatalogLifecycleView.archived
            ? 'Archived Products will appear here and can be restored.'
            : 'Create the first global Product offered by the platform.',
        primaryAction:
            isAdministrator &&
                state.lifecycleView != BillingCatalogLifecycleView.archived
            ? FilledButton.icon(
                onPressed: () => _showProductForm(context),
                icon: const Icon(Icons.add),
                label: const Text('New Product'),
              )
            : null,
      ),
      filteredEmptyState: const AdminEmptyStateData(
        title: 'No matching Products.',
        message: 'Clear the search or adjust the lifecycle view.',
      ),
      minWidth: _catalogTableMinWidth,
      footer: _CatalogPaginator<BillingProductEntity>(page: page),
    );
  }

  Widget _buildPricesGrid(BillingCatalogState state, bool isAdministrator) {
    final page = state.prices;
    final productLabels = <String, String>{
      for (final product in state.productOptions)
        product.id: product.selectorLabel,
    };
    return AdminDataGrid<BillingPriceEntity>(
      rows: page.items,
      columns: <AdminGridColumn<BillingPriceEntity>>[
        AdminGridColumn(
          key: 'Product',
          label: 'Product',
          flex: 3,
          cell: (_, row) =>
              AdminCellText(productLabels[row.productId] ?? row.productId),
        ),
        AdminGridColumn(
          key: 'Code',
          label: 'Code',
          flex: 2,
          cell: (_, row) => AdminCellText(row.code),
        ),
        AdminGridColumn(
          key: 'PriceType',
          label: 'Type',
          cell: (_, row) => AdminCellText(row.priceType),
        ),
        AdminGridColumn(
          key: 'Currency',
          label: 'Currency',
          cell: (_, row) => AdminCellText(row.currency),
        ),
        AdminGridColumn(
          key: 'UnitAmount',
          label: 'Unit Amount',
          cell: (_, row) => AdminCellText('${row.unitAmount ?? ''}'),
        ),
        AdminGridColumn(
          key: 'Interval',
          label: 'Billing Interval',
          flex: 2,
          cell: (_, row) => AdminCellText(row.billingInterval),
        ),
        AdminGridColumn(
          key: 'MeterCode',
          label: 'Meter',
          flex: 2,
          cell: (_, row) => AdminCellText(row.meterCode ?? ''),
        ),
        AdminGridColumn(
          key: 'State',
          label: 'State',
          cell: (_, row) => _lifecycleChip(row.isArchived),
        ),
        AdminGridColumn(
          key: 'RowVersion',
          label: 'RowVersion',
          cell: (_, row) => AdminCellText('${row.rowVersion}'),
        ),
      ],
      actionsBuilder: (context, row) => _PriceActions(
        price: row,
        isAdministrator: isAdministrator,
        onView: () => _showPriceDetails(context, row, productLabels),
        onEdit: () => _showPriceForm(context, price: row),
        onArchive: () => _archivePrice(context, row),
        onRestore: () => _restorePrice(context, row),
      ),
      actionsWidth: isAdministrator ? 172 : 64,
      rowKey: (row) => row.id,
      onRowSelected: (row) => _showPriceDetails(context, row, productLabels),
      isLoading: state.isLoading,
      hasActiveFilter:
          state.priceSearchTerm.isNotEmpty ||
          state.selectedProductId != null ||
          state.lifecycleView != BillingCatalogLifecycleView.active,
      emptyState: AdminEmptyStateData(
        title: state.selectedProductId == null
            ? 'No Prices yet.'
            : 'This Product has no Prices.',
        message: state.lifecycleView == BillingCatalogLifecycleView.archived
            ? 'Archived Prices will appear here and can be restored.'
            : 'Create a global Price for an available Product.',
        primaryAction:
            isAdministrator &&
                state.lifecycleView != BillingCatalogLifecycleView.archived &&
                state.productOptions.isNotEmpty
            ? FilledButton.icon(
                onPressed: () => _showPriceForm(context),
                icon: const Icon(Icons.add),
                label: const Text('New Price'),
              )
            : null,
      ),
      filteredEmptyState: const AdminEmptyStateData(
        title: 'No matching Prices.',
        message: 'Clear the search or adjust Product and lifecycle filters.',
      ),
      minWidth: 1780,
      footer: _CatalogPaginator<BillingPriceEntity>(page: page),
    );
  }

  Future<void> _showProductForm(
    BuildContext context, {
    BillingProductEntity? product,
  }) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductFormDialog(product: product),
    );
    if (changed == true && context.mounted) {
      _showSuccess(
        context,
        product == null ? 'Product created.' : 'Product updated.',
      );
    }
  }

  Future<void> _showPriceForm(
    BuildContext context, {
    BillingPriceEntity? price,
  }) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PriceFormDialog(price: price),
    );
    if (changed == true && context.mounted) {
      _showSuccess(
        context,
        price == null ? 'Price created.' : 'Price updated.',
      );
    }
  }

  Future<void> _archiveProduct(
    BuildContext context,
    BillingProductEntity product,
  ) async {
    if (!await _confirmLifecycle(
      context,
      title: 'Archive Product',
      message:
          'Archive ${product.code}? It will no longer be available for new subscriptions.',
      label: 'Archive',
    )) {
      return;
    }
    final result = await ref
        .read(billingCatalogControllerProvider.notifier)
        .archiveProduct(product);
    if (result.isSuccess && context.mounted) {
      _showSuccess(context, 'Product archived.');
    }
  }

  Future<void> _restoreProduct(
    BuildContext context,
    BillingProductEntity product,
  ) async {
    if (!await _confirmLifecycle(
      context,
      title: 'Restore Product',
      message: 'Restore ${product.code} to the active catalog?',
      label: 'Restore',
    )) {
      return;
    }
    final result = await ref
        .read(billingCatalogControllerProvider.notifier)
        .restoreProduct(product);
    if (result.isSuccess && context.mounted) {
      _showSuccess(context, 'Product restored.');
    }
  }

  Future<void> _archivePrice(
    BuildContext context,
    BillingPriceEntity price,
  ) async {
    if (!await _confirmLifecycle(
      context,
      title: 'Archive Price',
      message:
          'Archive ${price.code}? Existing subscriptions remain unchanged.',
      label: 'Archive',
    )) {
      return;
    }
    final result = await ref
        .read(billingCatalogControllerProvider.notifier)
        .archivePrice(price);
    if (result.isSuccess && context.mounted) {
      _showSuccess(context, 'Price archived.');
    }
  }

  Future<void> _restorePrice(
    BuildContext context,
    BillingPriceEntity price,
  ) async {
    if (!await _confirmLifecycle(
      context,
      title: 'Restore Price',
      message: 'Restore ${price.code} to the active catalog?',
      label: 'Restore',
    )) {
      return;
    }
    final result = await ref
        .read(billingCatalogControllerProvider.notifier)
        .restorePrice(price);
    if (result.isSuccess && context.mounted) {
      _showSuccess(context, 'Price restored.');
    }
  }

  Future<bool> _confirmLifecycle(
    BuildContext context, {
    required String title,
    required String message,
    required String label,
  }) async {
    return await showAppConfirmationDialog(
          context: context,
          title: title,
          message: message,
          confirmLabel: label,
          icon: label == 'Archive' ? Icons.archive_outlined : Icons.restore,
        ) ==
        true;
  }

  void _showProductDetails(BuildContext context, BillingProductEntity product) {
    _showDetails(
      context,
      title: 'Product ${product.code}',
      fields: <(String, String)>[
        ('Id', product.id),
        ('Code', product.code),
        ('Name', product.name),
        ('Description', product.description ?? ''),
        ('Attributes', _prettyJson(product.attributes)),
        ('Created', _formatDateTime(product.createdAt)),
        ('Updated', _formatDateTime(product.updatedAt)),
        ('Archived', product.isArchived ? 'Yes' : 'No'),
        ('Deleted At', _formatDateTime(product.deletedAt)),
        ('RowVersion', '${product.rowVersion}'),
      ],
    );
  }

  void _showPriceDetails(
    BuildContext context,
    BillingPriceEntity price,
    Map<String, String> productLabels,
  ) {
    _showDetails(
      context,
      title: 'Price ${price.code}',
      fields: <(String, String)>[
        ('Id', price.id),
        ('Product', productLabels[price.productId] ?? price.productId),
        ('Code', price.code),
        ('Price Type', price.priceType),
        ('Currency', price.currency),
        ('Unit Amount', '${price.unitAmount ?? ''}'),
        ('Billing Interval', price.billingInterval),
        ('Trial Period Days', '${price.trialPeriodDays ?? ''}'),
        ('Usage Unit', price.usageUnit ?? ''),
        ('Meter Code', price.meterCode ?? ''),
        ('Attributes', _prettyJson(price.attributes)),
        ('Created', _formatDateTime(price.createdAt)),
        ('Updated', _formatDateTime(price.updatedAt)),
        ('Archived', price.isArchived ? 'Yes' : 'No'),
        ('Deleted At', _formatDateTime(price.deletedAt)),
        ('RowVersion', '${price.rowVersion}'),
      ],
    );
  }

  void _showDetails(
    BuildContext context, {
    required String title,
    required List<(String, String)> fields,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.$1,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppUiPalette.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(field.$2.isEmpty ? '—' : field.$2),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CatalogToolbar extends ConsumerStatefulWidget {
  const _CatalogToolbar({required this.state, required this.onSearchChanged});

  final BillingCatalogState state;
  final ValueChanged<String> onSearchChanged;

  @override
  ConsumerState<_CatalogToolbar> createState() => _CatalogToolbarState();
}

class _CatalogToolbarState extends ConsumerState<_CatalogToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.state.activeSearchTerm,
    );
  }

  @override
  void didUpdateWidget(covariant _CatalogToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.activeTab != widget.state.activeTab) {
      _searchController.text = widget.state.activeSearchTerm;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(billingCatalogControllerProvider.notifier);
    final state = widget.state;
    return AdminToolbar(
      children: [
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<BillingCatalogLifecycleView>(
            key: const Key('billing-catalog-lifecycle-filter'),
            initialValue: state.lifecycleView,
            decoration: appFormInputDecoration(labelText: 'Lifecycle'),
            items: const [
              DropdownMenuItem(
                value: BillingCatalogLifecycleView.active,
                child: Text('Active'),
              ),
              DropdownMenuItem(
                value: BillingCatalogLifecycleView.archived,
                child: Text('Archived'),
              ),
              DropdownMenuItem(
                value: BillingCatalogLifecycleView.all,
                child: Text('All'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                unawaited(controller.selectLifecycleView(value));
              }
            },
          ),
        ),
        if (state.activeTab == BillingCatalogTab.prices) ...[
          SizedBox(
            width: 330,
            child: AppSearchableSelectField<BillingProductEntity>(
              fieldKey: const Key('billing-catalog-price-product-filter'),
              optionKeyPrefix: 'billing-catalog-price-product-filter-option',
              labelText: 'Product',
              hintText: 'Filter by Product',
              options: state.productOptions,
              selectedOptionKey: state.selectedProductId,
              optionKey: (item) => item.id,
              optionTitle: (item) => item.selectorLabel,
              optionSubtitle: (item) => item.id,
              optionSearchText: (item) =>
                  '${item.code} ${item.name} ${item.id}',
              onSelected: (item) =>
                  unawaited(controller.selectProductFilter(item.id)),
            ),
          ),
          if (state.selectedProductId != null)
            TextButton.icon(
              key: const Key('billing-catalog-clear-product-filter'),
              onPressed: () => unawaited(controller.selectProductFilter(null)),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('All Products'),
            ),
        ],
        SizedBox(
          width: 300,
          child: TextFormField(
            key: ValueKey<String>(
              'billing-catalog-search-${state.activeTab.name}',
            ),
            controller: _searchController,
            decoration: appFormInputDecoration(
              labelText: 'Search',
              hintText: state.activeTab == BillingCatalogTab.products
                  ? 'Code, name, or description'
                  : 'Code, type, currency, or meter',
              suffixIcon: const Icon(Icons.search),
            ),
            onChanged: widget.onSearchChanged,
          ),
        ),
        TextButton.icon(
          key: const Key('billing-catalog-refresh-button'),
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _CatalogPaginator<T> extends ConsumerWidget {
  const _CatalogPaginator({required this.page});

  final PageResult<T> page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(billingCatalogControllerProvider.notifier);
    final pages = page.pages <= 0 ? 1 : page.pages;
    return AdminGridFooter(
      state: AdminPaginationState(
        visibleCount: page.items.length,
        totalCount: page.total,
        page: page.page,
        pages: pages,
        pageSize: page.pageSize,
        pageSizes: const <int>[10, 15, 25, 50],
        onPageSizeChanged: (value) =>
            unawaited(controller.setRowsPerPage(value)),
        onFirstPage: page.page <= 1
            ? null
            : () => unawaited(controller.setPage(1)),
        onPreviousPage: page.page <= 1
            ? null
            : () => unawaited(controller.setPage(page.page - 1)),
        onNextPage: page.page >= pages
            ? null
            : () => unawaited(controller.setPage(page.page + 1)),
        onLastPage: page.page >= pages
            ? null
            : () => unawaited(controller.setPage(pages)),
      ),
    );
  }
}

class _ProductActions extends StatelessWidget {
  const _ProductActions({
    required this.product,
    required this.isAdministrator,
    required this.onView,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final BillingProductEntity product;
  final bool isAdministrator;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminIconButton(
          key: Key('billing-product-view-${product.id}'),
          tooltip: 'View Product',
          icon: Icons.visibility_outlined,
          onPressed: onView,
        ),
        if (isAdministrator && !product.isArchived) ...[
          AdminIconButton(
            key: Key('billing-product-edit-${product.id}'),
            tooltip: 'Edit Product',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          AdminIconButton(
            key: Key('billing-product-archive-${product.id}'),
            tooltip: 'Archive Product',
            icon: Icons.archive_outlined,
            destructive: true,
            onPressed: onArchive,
          ),
        ],
        if (isAdministrator && product.isArchived)
          AdminIconButton(
            key: Key('billing-product-restore-${product.id}'),
            tooltip: 'Restore Product',
            icon: Icons.restore,
            onPressed: onRestore,
          ),
      ],
    );
  }
}

class _PriceActions extends StatelessWidget {
  const _PriceActions({
    required this.price,
    required this.isAdministrator,
    required this.onView,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final BillingPriceEntity price;
  final bool isAdministrator;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminIconButton(
          key: Key('billing-price-view-${price.id}'),
          tooltip: 'View Price',
          icon: Icons.visibility_outlined,
          onPressed: onView,
        ),
        if (isAdministrator && !price.isArchived) ...[
          AdminIconButton(
            key: Key('billing-price-edit-${price.id}'),
            tooltip: 'Edit Price',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          AdminIconButton(
            key: Key('billing-price-archive-${price.id}'),
            tooltip: 'Archive Price',
            icon: Icons.archive_outlined,
            destructive: true,
            onPressed: onArchive,
          ),
        ],
        if (isAdministrator && price.isArchived)
          AdminIconButton(
            key: Key('billing-price-restore-${price.id}'),
            tooltip: 'Restore Price',
            icon: Icons.restore,
            onPressed: onRestore,
          ),
      ],
    );
  }
}

class _ProductFormDialog extends ConsumerStatefulWidget {
  const _ProductFormDialog({this.product});

  final BillingProductEntity? product;

  @override
  ConsumerState<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<_ProductFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _attributesController;
  String? _errorMessage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _codeController = TextEditingController(text: product?.code ?? '');
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _attributesController = TextEditingController(
      text: _prettyJson(product?.attributes),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _attributesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUpdate = widget.product != null;
    return _CatalogFormDialog(
      title: isUpdate ? 'Update Product' : 'Create Product',
      errorMessage: _errorMessage,
      submitting: _submitting,
      submitLabel: isUpdate ? 'Save' : 'Create',
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              key: const Key('billing-product-code-field'),
              controller: _codeController,
              decoration: appFormInputDecoration(labelText: 'Code'),
              validator: _requiredText,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('billing-product-name-field'),
              controller: _nameController,
              decoration: appFormInputDecoration(labelText: 'Name'),
              validator: _requiredText,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('billing-product-description-field'),
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: appFormInputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('billing-product-attributes-field'),
              controller: _attributesController,
              minLines: 4,
              maxLines: 8,
              decoration: appFormInputDecoration(
                labelText: 'Attributes (JSON object)',
              ),
              validator: _validateJsonObject,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final attributes = _decodeJsonObject(_attributesController.text);
    final product = widget.product;
    final controller = ref.read(billingCatalogControllerProvider.notifier);
    final Result<void> result;
    if (product == null) {
      result = await controller.createProduct(
        BillingProductCreateInput(
          code: _codeController.text,
          name: _nameController.text,
          description: _descriptionController.text,
          attributes: attributes,
        ),
      );
    } else {
      result = await controller.updateProduct(
        BillingProductUpdateInput(
          id: product.id,
          rowVersion: product.rowVersion,
          code: _codeController.text,
          name: _nameController.text,
          description: _descriptionController.text,
          attributes: attributes,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _errorMessage = result.failure?.message ?? 'Product request failed.';
    });
  }
}

class _PriceFormDialog extends ConsumerStatefulWidget {
  const _PriceFormDialog({this.price});

  final BillingPriceEntity? price;

  @override
  ConsumerState<_PriceFormDialog> createState() => _PriceFormDialogState();
}

class _PriceFormDialogState extends ConsumerState<_PriceFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _currencyController;
  late final TextEditingController _unitAmountController;
  late final TextEditingController _intervalCountController;
  late final TextEditingController _trialDaysController;
  late final TextEditingController _usageUnitController;
  late final TextEditingController _meterCodeController;
  late final TextEditingController _attributesController;
  String? _productId;
  String _priceType = 'one_time';
  String? _intervalUnit;
  String? _errorMessage;
  bool _submitting = false;
  bool _commercialLocked = false;

  @override
  void initState() {
    super.initState();
    _resetFromPrice();
  }

  void _resetFromPrice() {
    final price = widget.price;
    _productId = price?.productId;
    _priceType = price?.priceType ?? 'one_time';
    _intervalUnit = price?.intervalUnit;
    _codeController = TextEditingController(text: price?.code ?? '');
    _currencyController = TextEditingController(text: price?.currency ?? 'USD');
    _unitAmountController = TextEditingController(
      text: price?.unitAmount?.toString() ?? '',
    );
    _intervalCountController = TextEditingController(
      text: price?.intervalCount?.toString() ?? '',
    );
    _trialDaysController = TextEditingController(
      text: price?.trialPeriodDays?.toString() ?? '',
    );
    _usageUnitController = TextEditingController(text: price?.usageUnit ?? '');
    _meterCodeController = TextEditingController(text: price?.meterCode ?? '');
    _attributesController = TextEditingController(
      text: _prettyJson(price?.attributes),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _currencyController.dispose();
    _unitAmountController.dispose();
    _intervalCountController.dispose();
    _trialDaysController.dispose();
    _usageUnitController.dispose();
    _meterCodeController.dispose();
    _attributesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingCatalogControllerProvider);
    final options = <BillingProductEntity>[...state.productOptions];
    if (_productId != null && !options.any((item) => item.id == _productId)) {
      options.add(
        BillingProductEntity(
          id: _productId!,
          code: _productId!,
          name: 'Archived or unavailable Product',
          rowVersion: 0,
          isArchived: true,
        ),
      );
    }
    final isUpdate = widget.price != null;
    return _CatalogFormDialog(
      title: isUpdate ? 'Update Price' : 'Create Price',
      errorMessage: _errorMessage,
      submitting: _submitting,
      submitLabel: isUpdate ? 'Save' : 'Create',
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (isUpdate)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _CommercialChangeNotice(),
              ),
            if (_commercialLocked)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AppErrorAlert(
                  message:
                      'This Price is referenced. Commercial fields are locked; create a new Price for commercial changes. Code and Attributes remain editable.',
                ),
              ),
            AppSearchableSelectField<BillingProductEntity>(
              fieldKey: const Key('billing-price-product-field'),
              optionKeyPrefix: 'billing-price-product-option',
              labelText: 'Product',
              hintText: 'Search the global Product catalog',
              options: options,
              selectedOptionKey: _productId,
              optionKey: (item) => item.id,
              optionTitle: (item) => item.selectorLabel,
              optionSubtitle: (item) => item.id,
              optionSearchText: (item) =>
                  '${item.code} ${item.name} ${item.id}',
              enabled: !_commercialLocked,
              onSelected: (item) => setState(() => _productId = item.id),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('billing-price-code-field'),
              controller: _codeController,
              decoration: appFormInputDecoration(labelText: 'Code'),
              validator: _requiredText,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('billing-price-type-field'),
              initialValue: _priceType,
              decoration: appFormInputDecoration(labelText: 'Price Type'),
              items: const [
                DropdownMenuItem(value: 'one_time', child: Text('One-time')),
                DropdownMenuItem(value: 'recurring', child: Text('Recurring')),
                DropdownMenuItem(value: 'metered', child: Text('Metered')),
              ],
              onChanged: _commercialLocked
                  ? null
                  : (value) => setState(() => _priceType = value ?? 'one_time'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('billing-price-currency-field'),
                    controller: _currencyController,
                    enabled: !_commercialLocked,
                    decoration: appFormInputDecoration(labelText: 'Currency'),
                    validator: (value) {
                      final required = _requiredText(value);
                      if (required != null) {
                        return required;
                      }
                      return value!.trim().length == 3
                          ? null
                          : 'Use a three-letter currency code.';
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('billing-price-unit-amount-field'),
                    controller: _unitAmountController,
                    enabled: !_commercialLocked,
                    keyboardType: TextInputType.number,
                    decoration: appFormInputDecoration(
                      labelText: 'Unit Amount (minor units)',
                    ),
                    validator: (value) => _optionalInteger(
                      value,
                      minimum: 0,
                      message: 'Enter zero or a positive integer.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const Key('billing-price-interval-unit-field'),
                    initialValue: _intervalUnit,
                    decoration: appFormInputDecoration(
                      labelText: 'Billing Interval',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'day', child: Text('Day')),
                      DropdownMenuItem(value: 'week', child: Text('Week')),
                      DropdownMenuItem(value: 'month', child: Text('Month')),
                      DropdownMenuItem(value: 'year', child: Text('Year')),
                    ],
                    onChanged: _commercialLocked
                        ? null
                        : (value) => setState(() => _intervalUnit = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('billing-price-interval-count-field'),
                    controller: _intervalCountController,
                    enabled: !_commercialLocked,
                    keyboardType: TextInputType.number,
                    decoration: appFormInputDecoration(
                      labelText: 'Interval Count',
                    ),
                    validator: (value) => _optionalInteger(
                      value,
                      minimum: 1,
                      message: 'Enter a positive integer.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('billing-price-trial-days-field'),
              controller: _trialDaysController,
              enabled: !_commercialLocked,
              keyboardType: TextInputType.number,
              decoration: appFormInputDecoration(
                labelText: 'Trial Period Days',
              ),
              validator: (value) => _optionalInteger(
                value,
                minimum: 0,
                message: 'Enter zero or a positive integer.',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('billing-price-usage-unit-field'),
                    controller: _usageUnitController,
                    enabled: !_commercialLocked,
                    decoration: appFormInputDecoration(labelText: 'Usage Unit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('billing-price-meter-code-field'),
                    controller: _meterCodeController,
                    enabled: !_commercialLocked,
                    decoration: appFormInputDecoration(labelText: 'Meter Code'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('billing-price-attributes-field'),
              controller: _attributesController,
              minLines: 4,
              maxLines: 8,
              decoration: appFormInputDecoration(
                labelText: 'Attributes (JSON object)',
              ),
              validator: _validateJsonObject,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (_productId == null || _productId!.trim().isEmpty) {
      setState(() => _errorMessage = 'Select a global Product.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final usageUnit = _usageUnitController.text.trim();
    final meterCode = _meterCodeController.text.trim();
    if ((usageUnit.isEmpty) != (meterCode.isEmpty)) {
      setState(
        () => _errorMessage =
            'Meter Code and Usage Unit must be provided together.',
      );
      return;
    }
    if (_priceType == 'metered' && meterCode.isEmpty) {
      setState(
        () =>
            _errorMessage = 'Metered Prices require Meter Code and Usage Unit.',
      );
      return;
    }

    setState(() => _submitting = true);
    final price = widget.price;
    final input = BillingPriceCreateInput(
      productId: _productId!,
      code: _codeController.text,
      priceType: _priceType,
      currency: _currencyController.text,
      unitAmount: _parseOptionalInt(_unitAmountController.text),
      intervalUnit: _intervalUnit,
      intervalCount: _parseOptionalInt(_intervalCountController.text),
      trialPeriodDays: _parseOptionalInt(_trialDaysController.text),
      usageUnit: usageUnit,
      meterCode: meterCode,
      attributes: _decodeJsonObject(_attributesController.text),
    );
    final controller = ref.read(billingCatalogControllerProvider.notifier);
    final Result<void> result;
    if (price == null) {
      result = await controller.createPrice(input);
    } else {
      result = await controller.updatePrice(
        BillingPriceUpdateInput(
          id: price.id,
          rowVersion: price.rowVersion,
          productId: input.productId,
          code: input.code,
          priceType: input.priceType,
          currency: input.currency,
          unitAmount: input.unitAmount,
          intervalUnit: input.intervalUnit,
          intervalCount: input.intervalCount,
          trialPeriodDays: input.trialPeriodDays,
          usageUnit: input.usageUnit,
          meterCode: input.meterCode,
          attributes: input.attributes,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    final message = result.failure?.message ?? 'Price request failed.';
    if (message.contains('Referenced Prices')) {
      _restoreCommercialFields(price!);
    }
    setState(() {
      _submitting = false;
      _errorMessage = message;
      if (message.contains('Referenced Prices')) {
        _commercialLocked = true;
      }
    });
  }

  void _restoreCommercialFields(BillingPriceEntity price) {
    _productId = price.productId;
    _priceType = price.priceType;
    _intervalUnit = price.intervalUnit;
    _currencyController.text = price.currency;
    _unitAmountController.text = price.unitAmount?.toString() ?? '';
    _intervalCountController.text = price.intervalCount?.toString() ?? '';
    _trialDaysController.text = price.trialPeriodDays?.toString() ?? '';
    _usageUnitController.text = price.usageUnit ?? '';
    _meterCodeController.text = price.meterCode ?? '';
  }
}

class _CatalogFormDialog extends StatelessWidget {
  const _CatalogFormDialog({
    required this.title,
    required this.child,
    required this.submitting,
    required this.submitLabel,
    required this.onSubmit,
    this.errorMessage,
  });

  final String title;
  final Widget child;
  final bool submitting;
  final String submitLabel;
  final Future<void> Function() onSubmit;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                      AppErrorAlert(message: errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    child,
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('billing-catalog-form-submit'),
                    onPressed: submitting ? null : onSubmit,
                    child: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(submitLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommercialChangeNotice extends StatelessWidget {
  const _CommercialChangeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUiPalette.warningSoft,
        border: Border.all(color: AppUiPalette.warning),
        borderRadius: BorderRadius.circular(adminRadius),
      ),
      child: const Text(
        'Commercial fields become immutable after a Price is referenced. Create a new Price for commercial changes.',
      ),
    );
  }
}

class _BillingAccessState extends StatelessWidget {
  const _BillingAccessState({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AdminSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 36, color: AppUiPalette.textSecondary),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _lifecycleChip(bool archived) {
  return AdminStatusChip(
    label: archived ? 'Archived' : 'Active',
    kind: archived ? AdminStatusKind.warning : AdminStatusKind.success,
  );
}

String? _requiredText(String? value) {
  return value == null || value.trim().isEmpty
      ? 'This field is required.'
      : null;
}

String? _optionalInteger(
  String? value, {
  required int minimum,
  required String message,
}) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(normalized);
  return parsed != null && parsed >= minimum ? null : message;
}

int? _parseOptionalInt(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : int.tryParse(normalized);
}

String? _validateJsonObject(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  try {
    return jsonDecode(normalized) is Map ? null : 'Enter a JSON object.';
  } catch (_) {
    return 'Enter valid JSON.';
  }
}

Object? _decodeJsonObject(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : jsonDecode(normalized);
}

String _prettyJson(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(normalized));
    } catch (_) {
      return value;
    }
  }
  return const JsonEncoder.withIndent('  ').convert(value);
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '';
  }
  return DateFormat('yyyy-MM-dd HH:mm:ss \'UTC\'').format(value.toUtc());
}
