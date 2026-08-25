import 'package:mugen_ui/features/billing_catalog/application/dto/billing_catalog_inputs.dart';
import 'package:mugen_ui/features/billing_catalog/domain/entities/billing_catalog_entities.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';

abstract class BillingCatalogRepository {
  Future<Result<BillingExtensionStatusEntity>> fetchBillingExtensionStatus();

  Future<Result<void>> verifyCatalogReadAccess();

  Future<Result<PageResult<BillingProductEntity>>> fetchProducts(
    BillingCatalogListQuery query,
  );

  Future<Result<PageResult<BillingPriceEntity>>> fetchPrices(
    BillingCatalogListQuery query,
  );

  Future<Result<void>> createProduct(BillingProductCreateInput input);

  Future<Result<void>> updateProduct(BillingProductUpdateInput input);

  Future<Result<void>> archiveProduct(BillingCatalogLifecycleInput input);

  Future<Result<void>> restoreProduct(BillingCatalogLifecycleInput input);

  Future<Result<void>> createPrice(BillingPriceCreateInput input);

  Future<Result<void>> updatePrice(BillingPriceUpdateInput input);

  Future<Result<void>> archivePrice(BillingCatalogLifecycleInput input);

  Future<Result<void>> restorePrice(BillingCatalogLifecycleInput input);
}
