import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class BillingCatalogAdminController extends AcpAdminController {
  BillingCatalogAdminController({
    required super.repository,
    required super.onSessionExpired,
  }) : super(descriptors: billingCatalogResources);

  @override
  Future<Result<Object?>> createRow(
    Map<String, dynamic> values, {
    bool deferRefresh = false,
  }) async {
    final duplicate = await _validateEntitlementUniqueness(values);
    if (duplicate != null) {
      return Result<Object?>.failure(duplicate);
    }
    return super.createRow(values, deferRefresh: deferRefresh);
  }

  @override
  Future<Result<Object?>> updateRow({
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantIdOverride,
    bool useTenantIdOverride = false,
    int? rowVersion,
  }) async {
    final duplicate = await _validateEntitlementUniqueness(
      values,
      excludingRowId: rowId,
    );
    if (duplicate != null) {
      return Result<Object?>.failure(duplicate);
    }
    return super.updateRow(
      rowId: rowId,
      values: values,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
      rowVersion: rowVersion,
    );
  }

  Future<ValidationFailure?> _validateEntitlementUniqueness(
    Map<String, dynamic> values, {
    String? excludingRowId,
  }) async {
    if (activeDescriptor.entitySet != 'BillingPriceEntitlements') {
      return null;
    }
    final priceId = values['PriceId']?.toString().trim();
    final meterId = values['MeterDefinitionId']?.toString().trim();
    if (priceId == null ||
        priceId.isEmpty ||
        meterId == null ||
        meterId.isEmpty) {
      return null;
    }
    final result = await repository.listRows(
      descriptor: activeDescriptor,
      pageRequest: const PageRequest(page: 1, pageSize: 2),
      extraFilters: <String>[
        "PriceId eq '${_escapeFilterValue(priceId)}'",
        "MeterDefinitionId eq '${_escapeFilterValue(meterId)}'",
      ],
    );
    if (result.isFailure) {
      return null;
    }
    final hasDuplicate = result.data!.items.any(
      (row) => excludingRowId == null || row.id != excludingRowId,
    );
    return hasDuplicate
        ? const ValidationFailure(
            'An active Price Entitlement already exists for this Price and Meter.',
          )
        : null;
  }

  String _escapeFilterValue(String value) => value.replaceAll("'", "''");
}
