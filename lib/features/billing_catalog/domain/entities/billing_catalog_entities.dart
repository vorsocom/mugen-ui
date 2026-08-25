enum BillingCatalogLifecycleView { active, archived, all }

class BillingExtensionStatusEntity {
  const BillingExtensionStatusEntity({
    required this.token,
    required this.extensionType,
    required this.configured,
    required this.enabled,
    required this.available,
    required this.status,
    this.reason,
  });

  final String token;
  final String extensionType;
  final bool configured;
  final bool enabled;
  final bool available;
  final String status;
  final String? reason;

  bool get isRegistered => available && status == 'registered';
}

class BillingProductEntity {
  const BillingProductEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.rowVersion,
    required this.isArchived,
    this.description,
    this.attributes,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final Object? attributes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int rowVersion;
  final bool isArchived;

  String get selectorLabel => '$code — $name';
}

class BillingPriceEntity {
  const BillingPriceEntity({
    required this.id,
    required this.productId,
    required this.code,
    required this.priceType,
    required this.currency,
    required this.rowVersion,
    required this.isArchived,
    this.unitAmount,
    this.intervalUnit,
    this.intervalCount,
    this.trialPeriodDays,
    this.usageUnit,
    this.meterCode,
    this.attributes,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int rowVersion;
  final bool isArchived;

  String get billingInterval {
    final unit = intervalUnit?.trim();
    if (unit == null || unit.isEmpty) {
      return '';
    }
    final count = intervalCount;
    return count == null || count == 1 ? unit : '$count $unit';
  }
}
