import 'package:mugen_ui/features/billing_catalog/domain/entities/billing_catalog_entities.dart';
import 'package:mugen_ui/shared/application/pagination.dart';

class BillingCatalogListQuery {
  const BillingCatalogListQuery({
    required this.pageRequest,
    required this.lifecycleView,
    this.searchTerm,
    this.productId,
  });

  final PageRequest pageRequest;
  final BillingCatalogLifecycleView lifecycleView;
  final String? searchTerm;
  final String? productId;
}

class BillingProductCreateInput {
  const BillingProductCreateInput({
    required this.code,
    required this.name,
    this.description,
    this.attributes,
  });

  final String code;
  final String name;
  final String? description;
  final Object? attributes;
}

class BillingProductUpdateInput extends BillingProductCreateInput {
  const BillingProductUpdateInput({
    required this.id,
    required this.rowVersion,
    required super.code,
    required super.name,
    super.description,
    super.attributes,
  });

  final String id;
  final int rowVersion;
}

class BillingPriceCreateInput {
  const BillingPriceCreateInput({
    required this.productId,
    required this.code,
    required this.priceType,
    required this.currency,
    this.unitAmount,
    this.intervalUnit,
    this.intervalCount,
    this.trialPeriodDays,
    this.usageUnit,
    this.meterCode,
    this.attributes,
  });

  final String productId;
  final String code;
  final String priceType;
  final String currency;
  final int? unitAmount;
  final String? intervalUnit;
  final int? intervalCount;
  final int? trialPeriodDays;
  final String? usageUnit;
  final String? meterCode;
  final Object? attributes;
}

class BillingPriceUpdateInput extends BillingPriceCreateInput {
  const BillingPriceUpdateInput({
    required this.id,
    required this.rowVersion,
    required super.productId,
    required super.code,
    required super.priceType,
    required super.currency,
    super.unitAmount,
    super.intervalUnit,
    super.intervalCount,
    super.trialPeriodDays,
    super.usageUnit,
    super.meterCode,
    super.attributes,
  });

  final String id;
  final int rowVersion;
}

class BillingCatalogLifecycleInput {
  const BillingCatalogLifecycleInput({
    required this.id,
    required this.rowVersion,
  });

  final String id;
  final int rowVersion;
}
