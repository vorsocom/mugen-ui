import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class BillingAcpAdminRepository implements AcpAdminRepository {
  BillingAcpAdminRepository(this.delegate);

  final AcpAdminRepository delegate;
  Map<String, int>? _minorUnitsById;
  Map<String, int>? _minorUnitsByCode;
  Map<String, String>? _priceCurrenciesById;
  final Map<String, Map<String, AcpRow>> _tenantInvoices =
      <String, Map<String, AcpRow>>{};

  @override
  Future<Result<List<AcpTenantOption>>> fetchTenants({int top = 200}) {
    return delegate.fetchTenants(top: top);
  }

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
    final result = await delegate.listRows(
      descriptor: descriptor,
      pageRequest: pageRequest,
      tenantId: tenantId,
      searchTerm: searchTerm,
      extraFilters: extraFilters,
      deletedView: deletedView,
      enrichReferences: enrichReferences,
    );
    if (result.isFailure) {
      return result;
    }
    await _ensureGlobalMetadata();
    if (tenantId != null &&
        (descriptor.entitySet == 'BillingInvoiceLines' ||
            descriptor.entitySet == 'BillingPaymentAllocations')) {
      await _ensureTenantInvoices(tenantId);
    }
    final page = result.data!;
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: page.items
            .map((row) => _withCurrencyMetadata(row, tenantId: tenantId))
            .toList(growable: false),
        total: page.total,
        page: page.page,
        pageSize: page.pageSize,
      ),
    );
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    final result = await delegate.fetchRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
    );
    if (result.isFailure) {
      return result;
    }
    await _ensureGlobalMetadata();
    if (tenantId != null &&
        (descriptor.entitySet == 'BillingInvoiceLines' ||
            descriptor.entitySet == 'BillingPaymentAllocations')) {
      await _ensureTenantInvoices(tenantId);
    }
    return Result<AcpRow>.success(
      _withCurrencyMetadata(result.data!, tenantId: tenantId),
    );
  }

  @override
  Future<Result<Object?>> createRow({
    required AcpResourceDescriptor descriptor,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    final result = await delegate.createRow(
      descriptor: descriptor,
      values: values,
      tenantId: tenantId,
    );
    _invalidate(descriptor.entitySet, tenantId);
    return result;
  }

  @override
  Future<Result<Object?>> updateRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    final result = await delegate.updateRow(
      descriptor: descriptor,
      rowId: rowId,
      values: values,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
    _invalidate(descriptor.entitySet, tenantId);
    return result;
  }

  @override
  Future<Result<void>> deleteRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    final result = await delegate.deleteRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
    _invalidate(descriptor.entitySet, tenantId);
    return result;
  }

  @override
  Future<Result<void>> restoreRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    final result = await delegate.restoreRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
    _invalidate(descriptor.entitySet, tenantId);
    return result;
  }

  @override
  Future<Result<Object?>> runCollectionAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    final result = await delegate.runCollectionAction(
      descriptor: descriptor,
      action: action,
      values: values,
      tenantId: tenantId,
    );
    _invalidate(descriptor.entitySet, tenantId);
    return result;
  }

  @override
  Future<Result<Object?>> runEntityAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    final result = await delegate.runEntityAction(
      descriptor: descriptor,
      action: action,
      rowId: rowId,
      values: values,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
    _invalidate(descriptor.entitySet, tenantId);
    return result;
  }

  Future<void> _ensureGlobalMetadata() async {
    if (_minorUnitsById != null && _priceCurrenciesById != null) {
      return;
    }
    final currencies = await delegate.listRows(
      descriptor: const AcpResourceDescriptor(
        key: 'billing-money-currencies',
        title: 'Currencies',
        entitySet: 'BillingCurrencyDefinitions',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[],
        defaultOrderBy: 'Code asc',
        pageSize: 500,
      ),
      pageRequest: const PageRequest(page: 1, pageSize: 500),
      deletedView: AcpDeletedView.all,
    );
    if (currencies.isSuccess) {
      _minorUnitsById = <String, int>{};
      _minorUnitsByCode = <String, int>{};
      for (final row in currencies.data!.items) {
        final id = row.id;
        final code = row['Code']?.toString().trim().toUpperCase();
        final minorUnit = int.tryParse(row['MinorUnit']?.toString() ?? '') ?? 2;
        if (id != null) {
          _minorUnitsById![id] = minorUnit;
        }
        if (code != null && code.isNotEmpty) {
          _minorUnitsByCode![code] = minorUnit;
        }
      }
    } else {
      _minorUnitsById = <String, int>{};
      _minorUnitsByCode = <String, int>{};
    }

    final prices = await delegate.listRows(
      descriptor: const AcpResourceDescriptor(
        key: 'billing-money-prices',
        title: 'Prices',
        entitySet: 'BillingPrices',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[],
        defaultOrderBy: 'Code asc',
        pageSize: 500,
      ),
      pageRequest: const PageRequest(page: 1, pageSize: 500),
      deletedView: AcpDeletedView.all,
    );
    _priceCurrenciesById = <String, String>{};
    if (prices.isSuccess) {
      for (final row in prices.data!.items) {
        final id = row.id;
        final currencyId = row['CurrencyDefinitionId']?.toString().trim();
        if (id != null && currencyId != null && currencyId.isNotEmpty) {
          _priceCurrenciesById![id] = currencyId;
        }
      }
    }
  }

  Future<void> _ensureTenantInvoices(String tenantId) async {
    if (_tenantInvoices.containsKey(tenantId)) {
      return;
    }
    final invoices = await delegate.listRows(
      descriptor: const AcpResourceDescriptor(
        key: 'billing-money-invoices',
        title: 'Invoices',
        entitySet: 'BillingInvoices',
        scopeMode: AcpScopeMode.required,
        columns: <AcpColumnDescriptor>[],
        defaultOrderBy: 'CreatedAt desc',
        pageSize: 500,
      ),
      pageRequest: const PageRequest(page: 1, pageSize: 500),
      tenantId: tenantId,
      deletedView: AcpDeletedView.all,
    );
    _tenantInvoices[tenantId] = invoices.isSuccess
        ? <String, AcpRow>{
            for (final row in invoices.data!.items)
              if (row.id != null) row.id!: row,
          }
        : <String, AcpRow>{};
  }

  AcpRow _withCurrencyMetadata(AcpRow row, {String? tenantId}) {
    final enriched = <String, dynamic>{...row};
    String? currencyId = row['CurrencyDefinitionId']?.toString().trim();
    var currencyCode = row['Currency']?.toString().trim().toUpperCase();
    final priceId = row['PriceId']?.toString().trim();
    if ((currencyId == null || currencyId.isEmpty) &&
        priceId != null &&
        priceId.isNotEmpty) {
      currencyId = _priceCurrenciesById == null
          ? null
          : _priceCurrenciesById![priceId];
    }
    final invoiceId = row['InvoiceId']?.toString().trim();
    final needsInvoiceCurrency = currencyId == null || currencyId.isEmpty;
    if (tenantId != null &&
        invoiceId != null &&
        invoiceId.isNotEmpty &&
        needsInvoiceCurrency) {
      final invoice = _tenantInvoices[tenantId]?[invoiceId];
      currencyId = invoice?['CurrencyDefinitionId']?.toString().trim();
      currencyCode ??= invoice?['Currency']?.toString().trim().toUpperCase();
    }
    final minorUnit = currencyId == null || currencyId.isEmpty
        ? (_minorUnitsByCode == null ? null : _minorUnitsByCode![currencyCode])
        : (_minorUnitsById == null ? null : _minorUnitsById![currencyId]);
    if (minorUnit != null) {
      enriched['_CurrencyMinorUnit'] = minorUnit;
    }
    if (currencyCode != null && currencyCode.isNotEmpty) {
      enriched['_CurrencyCode'] = currencyCode;
    }
    return enriched;
  }

  void _invalidate(String entitySet, String? tenantId) {
    if (entitySet == 'BillingCurrencyDefinitions' ||
        entitySet == 'BillingPrices') {
      _minorUnitsById = null;
      _minorUnitsByCode = null;
      _priceCurrenciesById = null;
    }
    if (tenantId != null) {
      _tenantInvoices.remove(tenantId);
    }
  }
}
