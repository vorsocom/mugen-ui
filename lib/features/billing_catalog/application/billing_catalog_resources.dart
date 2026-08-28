import 'package:mugen_ui/features/core_provisioning/application/core_provisioning_descriptors.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

final List<AcpResourceDescriptor>
billingCatalogResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'billing-products',
    group: 'Products & Prices',
    title: 'Products',
    entitySet: 'BillingProducts',
    scopeMode: AcpScopeMode.none,
    description: 'Global billable products and platform SKUs.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('Name', 'Name', flex: 2),
      coreColumn('Description', 'Description', flex: 3),
      coreColumn('RowVersion', 'Row Version'),
    ],
    createFields: _productFields,
    updateFields: _productFields,
    entityActions: <AcpActionDescriptor>[_archiveAction('Product')],
    searchFields: const <String>['Code', 'Name'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
    allowRestore: true,
    payloadValidator: validateGlobalBillingPayload,
    deletedViews: const <AcpDeletedView>[
      AcpDeletedView.active,
      AcpDeletedView.all,
      AcpDeletedView.archived,
    ],
  ),
  AcpResourceDescriptor(
    key: 'billing-prices',
    group: 'Products & Prices',
    title: 'Prices',
    entitySet: 'BillingPrices',
    scopeMode: AcpScopeMode.none,
    description:
        'Global one-time, recurring, and metered Prices. Referenced commercial contracts must be versioned with a new Price.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('PriceType', 'Type'),
      coreColumn('Currency', 'Currency'),
      coreColumn('UnitAmount', 'Unit Amount', money: true),
      coreColumn('IntervalUnit', 'Interval'),
      coreColumn('MeterCode', 'Meter Code'),
      coreColumn('UsageUnit', 'Usage Unit'),
      coreColumn('RowVersion', 'Row Version'),
    ],
    createFields: _priceCreateFields,
    updateFields: _priceUpdateFields,
    entityActions: <AcpActionDescriptor>[_archiveAction('Price')],
    searchFields: const <String>['Code', 'Currency', 'MeterCode'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
    allowRestore: true,
    payloadValidator: validateBillingPricePayload,
    refreshResourceKeys: const <String>['billing-price-entitlements'],
    deletedViews: const <AcpDeletedView>[
      AcpDeletedView.active,
      AcpDeletedView.all,
      AcpDeletedView.archived,
    ],
  ),
  AcpResourceDescriptor(
    key: 'billing-meter-definitions',
    group: 'Metering & Entitlements',
    title: 'Meter Definitions',
    entitySet: 'BillingMeterDefinitions',
    scopeMode: AcpScopeMode.none,
    description:
        'Canonical global meter semantics. Code, unit, and aggregation changes can be rejected after use.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('Unit', 'Unit'),
      coreColumn('AggregationMode', 'Aggregation'),
      coreColumn('Description', 'Description', flex: 3),
      coreColumn('IsActive', 'Active'),
      coreColumn('RowVersion', 'Row Version'),
    ],
    createFields: _meterFields,
    updateFields: _meterFields,
    entityActions: _activationActions('Meter Definition'),
    searchFields: const <String>['Code', 'Unit', 'Description'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
    payloadValidator: validateGlobalBillingPayload,
    refreshResourceKeys: const <String>[
      'billing-prices',
      'billing-price-entitlements',
    ],
  ),
  AcpResourceDescriptor(
    key: 'billing-price-entitlements',
    group: 'Metering & Entitlements',
    title: 'Price Entitlements',
    entitySet: 'BillingPriceEntitlements',
    scopeMode: AcpScopeMode.none,
    description:
        'Included-usage rules for active recurring package Prices. Changes do not rewrite generated historical buckets.',
    columns: <AcpColumnDescriptor>[
      coreColumn(
        'PriceId',
        'Price',
        flex: 2,
        reference: _catalogPriceReference,
      ),
      coreColumn(
        'MeterDefinitionId',
        'Meter',
        flex: 2,
        reference: _catalogMeterReference,
      ),
      coreColumn('IncludedQuantity', 'Included'),
      coreColumn('RolloverPolicy', 'Rollover'),
      coreColumn('RowVersion', 'Row Version'),
    ],
    createFields: _priceEntitlementFields,
    updateFields: _priceEntitlementFields,
    entityActions: <AcpActionDescriptor>[_archiveAction('Price Entitlement')],
    defaultOrderBy: 'CreatedAt desc',
    allowCreate: true,
    allowUpdate: true,
    payloadValidator: validateGlobalBillingPayload,
    deletedViews: const <AcpDeletedView>[
      AcpDeletedView.active,
      AcpDeletedView.all,
      AcpDeletedView.archived,
    ],
    expansions: const <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'Price',
        selectFields: <String>['Code', 'PriceType', 'Currency'],
      ),
      AcpExpandDescriptor(
        navigation: 'MeterDefinition',
        selectFields: <String>['Code', 'Unit'],
      ),
    ],
  ),
  AcpResourceDescriptor(
    key: 'billing-run-definitions',
    group: 'Scheduling',
    title: 'Run Definitions',
    entitySet: 'BillingRunDefinitions',
    scopeMode: AcpScopeMode.none,
    description:
        'Reusable global billing schedules. Tenant executions are managed in Billing Operations.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('DisplayName', 'Display Name', flex: 2),
      coreColumn('Frequency', 'Frequency'),
      coreColumn('IntervalCount', 'Interval'),
      coreColumn('Timezone', 'Timezone', flex: 2),
      coreColumn('IsActive', 'Active'),
      coreColumn('RowVersion', 'Row Version'),
    ],
    createFields: _runDefinitionFields,
    updateFields: _runDefinitionFields,
    entityActions: _activationActions('Run Definition'),
    searchFields: const <String>['Code', 'DisplayName', 'Timezone'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
    payloadValidator: validateGlobalBillingPayload,
  ),
  AcpResourceDescriptor(
    key: 'billing-currency-definitions',
    group: 'Financial References',
    title: 'Currencies',
    entitySet: 'BillingCurrencyDefinitions',
    scopeMode: AcpScopeMode.none,
    description:
        'Vendored ISO 4217 currencies. Definitions are read-only; lifecycle actions control new assignment.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('NumericCode', 'Numeric Code'),
      coreColumn('DisplayName', 'Display Name', flex: 2),
      coreColumn('MinorUnit', 'Minor Unit'),
      coreColumn('IsActive', 'Active'),
      coreColumn('RowVersion', 'Row Version'),
    ],
    entityActions: _activationActions('Currency'),
    searchFields: const <String>['Code', 'NumericCode', 'DisplayName'],
    defaultOrderBy: 'Code asc',
  ),
  AcpResourceDescriptor(
    key: 'billing-tax-codes',
    group: 'Financial References',
    title: 'Tax Codes',
    entitySet: 'BillingTaxCodes',
    scopeMode: AcpScopeMode.none,
    description: 'Reusable global tax classifications.',
    columns: _namedDefinitionColumns,
    createFields: _namedDefinitionFields,
    updateFields: _namedDefinitionFields,
    entityActions: _activationActions('Tax Code'),
    searchFields: const <String>['Code', 'DisplayName', 'Description'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
    payloadValidator: validateGlobalBillingPayload,
  ),
  AcpResourceDescriptor(
    key: 'billing-tax-rates',
    group: 'Financial References',
    title: 'Tax Rates',
    entitySet: 'BillingTaxRates',
    scopeMode: AcpScopeMode.none,
    description: 'Effective-dated global jurisdiction tax rates.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('JurisdictionCode', 'Jurisdiction'),
      coreColumn('RateBasisPoints', 'Basis Points'),
      coreColumn('EffectiveFrom', 'Effective From', flex: 2),
      coreColumn('EffectiveTo', 'Effective To', flex: 2),
      coreColumn('IsActive', 'Active'),
      coreColumn('RowVersion', 'Row Version'),
    ],
    createFields: _taxRateFields,
    updateFields: _taxRateFields,
    entityActions: _activationActions('Tax Rate'),
    searchFields: const <String>['Code', 'JurisdictionCode'],
    defaultOrderBy: 'Code asc, EffectiveFrom desc',
    allowCreate: true,
    allowUpdate: true,
    payloadValidator: validateTaxRatePayload,
  ),
  AcpResourceDescriptor(
    key: 'billing-payment-terms',
    group: 'Financial References',
    title: 'Payment Terms',
    entitySet: 'BillingPaymentTerms',
    scopeMode: AcpScopeMode.none,
    description: 'Reusable global invoice payment terms.',
    columns: <AcpColumnDescriptor>[
      ..._namedDefinitionColumns.take(3),
      coreColumn('DueDays', 'Due Days'),
      ..._namedDefinitionColumns.skip(3),
    ],
    createFields: <AcpFieldDescriptor>[
      ..._namedDefinitionFields,
      coreInteger('DueDays', 'Due Days', required: true, minimumValue: 0),
    ],
    updateFields: <AcpFieldDescriptor>[
      ..._namedDefinitionFields,
      coreInteger('DueDays', 'Due Days', required: true, minimumValue: 0),
    ],
    entityActions: _activationActions('Payment Terms'),
    searchFields: const <String>['Code', 'DisplayName', 'Description'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
    payloadValidator: validateGlobalBillingPayload,
  ),
  AcpResourceDescriptor(
    key: 'billing-invoice-templates',
    group: 'Financial References',
    title: 'Invoice Templates',
    entitySet: 'BillingInvoiceTemplates',
    scopeMode: AcpScopeMode.none,
    description: 'Reusable global invoice rendering templates.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('DisplayName', 'Display Name', flex: 2),
      coreColumn('Locale', 'Locale'),
      coreColumn('TemplateFormat', 'Format'),
      coreColumn('IsActive', 'Active'),
      coreColumn('RowVersion', 'Row Version'),
    ],
    createFields: _invoiceTemplateFields,
    updateFields: _invoiceTemplateFields,
    entityActions: _activationActions('Invoice Template'),
    searchFields: const <String>['Code', 'DisplayName', 'Locale'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
    payloadValidator: validateGlobalBillingPayload,
  ),
  AcpResourceDescriptor(
    key: 'billing-discount-definitions',
    group: 'Financial References',
    title: 'Discounts',
    entitySet: 'BillingDiscountDefinitions',
    scopeMode: AcpScopeMode.none,
    description: 'Reusable percentage and fixed-amount discounts/coupons.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('DisplayName', 'Display Name', flex: 2),
      coreColumn('Kind', 'Kind'),
      coreColumn('CouponCode', 'Coupon'),
      coreColumn('PercentageBasisPoints', 'Basis Points'),
      coreColumn('Amount', 'Amount', money: true),
      coreColumn('IsActive', 'Active'),
      coreColumn('RowVersion', 'Row Version'),
    ],
    createFields: _discountCreateFields,
    updateFields: _discountUpdateFields,
    entityActions: _activationActions('Discount'),
    searchFields: const <String>['Code', 'DisplayName', 'CouponCode'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
    payloadValidator: validateDiscountPayload,
  ),
];

const AcpColumnReferenceDescriptor _catalogPriceReference =
    AcpColumnReferenceDescriptor(
      navigationPath: 'Price',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Code'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('PriceType'),
        AcpReferenceFieldDescriptor('Currency'),
      ],
    );

const AcpColumnReferenceDescriptor _catalogMeterReference =
    AcpColumnReferenceDescriptor(
      navigationPath: 'MeterDefinition',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Code'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Unit'),
      ],
    );

final List<AcpFieldDescriptor> _productFields = <AcpFieldDescriptor>[
  coreText('Code', 'Code', required: true),
  coreText('Name', 'Name', required: true),
  coreMultiline('Description', 'Description'),
  coreJson('Attributes', 'Attributes'),
];

final List<AcpFieldDescriptor> _priceCreateFields = <AcpFieldDescriptor>[
  _productReference(required: true),
  coreText('Code', 'Code', required: true),
  coreText(
    'PriceType',
    'Price Type',
    required: true,
    options: const <String>['one_time', 'recurring', 'metered'],
  ),
  _currencyReference(required: true),
  ..._currencyInternals,
  _meterReference(),
  coreMoney('UnitAmount', 'Unit Amount'),
  coreText(
    'IntervalUnit',
    'Interval Unit',
    options: const <String>['day', 'week', 'month', 'year'],
  ),
  coreInteger('IntervalCount', 'Interval Count', minimumValue: 1),
  coreInteger('TrialPeriodDays', 'Trial Period Days', minimumValue: 0),
  coreJson('Attributes', 'Attributes'),
];

final List<AcpFieldDescriptor> _priceUpdateFields = _priceCreateFields;

final List<AcpFieldDescriptor> _meterFields = <AcpFieldDescriptor>[
  coreText('Code', 'Code', required: true),
  coreText(
    'Unit',
    'Unit',
    required: true,
    options: const <String>['minute', 'unit', 'task'],
  ),
  coreText(
    'AggregationMode',
    'Aggregation Mode',
    required: true,
    initialValue: 'sum',
    options: const <String>['sum', 'max', 'latest'],
  ),
  coreMultiline('Description', 'Description'),
  coreJson('Attributes', 'Attributes'),
];

final List<AcpFieldDescriptor> _priceEntitlementFields = <AcpFieldDescriptor>[
  coreReference(
    'PriceId',
    'Recurring Price',
    entitySet: 'BillingPrices',
    scopeMode: AcpScopeMode.none,
    required: true,
    searchFields: const <String>['Code', 'Currency'],
    titleFields: const <String>['Code'],
    subtitleFields: const <String>['PriceType', 'Currency', 'IntervalUnit'],
    defaultOrderBy: 'Code asc',
    extraFilters: const <String>["PriceType eq 'recurring'"],
    retainHistoricalSelection: true,
  ),
  _meterReference(alwaysVisible: true, required: true),
  coreInteger(
    'IncludedQuantity',
    'Included Quantity',
    required: true,
    minimumValue: 0,
  ),
  coreText(
    'RolloverPolicy',
    'Rollover Policy',
    required: true,
    initialValue: 'none',
    options: const <String>['none'],
  ),
  coreJson('Attributes', 'Attributes'),
];

final List<AcpFieldDescriptor> _runDefinitionFields = <AcpFieldDescriptor>[
  ..._namedDefinitionFields,
  coreText(
    'Frequency',
    'Frequency',
    required: true,
    options: const <String>['manual', 'daily', 'weekly', 'monthly', 'yearly'],
  ),
  coreInteger(
    'IntervalCount',
    'Interval Count',
    required: true,
    minimumValue: 1,
    initialValue: 1,
  ),
  coreText(
    'Timezone',
    'Timezone',
    required: true,
    hintText: 'IANA timezone, for example America/Guyana',
  ),
];

final List<AcpColumnDescriptor> _namedDefinitionColumns = <AcpColumnDescriptor>[
  coreColumn('Code', 'Code'),
  coreColumn('DisplayName', 'Display Name', flex: 2),
  coreColumn('Description', 'Description', flex: 3),
  coreColumn('IsActive', 'Active'),
  coreColumn('RowVersion', 'Row Version'),
];

final List<AcpFieldDescriptor> _namedDefinitionFields = <AcpFieldDescriptor>[
  coreText('Code', 'Code', required: true),
  coreText('DisplayName', 'Display Name', required: true),
  coreMultiline('Description', 'Description'),
  coreJson('Attributes', 'Attributes'),
];

final List<AcpFieldDescriptor> _taxRateFields = <AcpFieldDescriptor>[
  coreText('Code', 'Code', required: true),
  coreReference(
    'TaxCodeId',
    'Tax Code',
    entitySet: 'BillingTaxCodes',
    scopeMode: AcpScopeMode.none,
    required: true,
    searchFields: const <String>['Code', 'DisplayName'],
    titleFields: const <String>['Code', 'DisplayName'],
    subtitleFields: const <String>['DisplayName', 'IsActive'],
    defaultOrderBy: 'Code asc',
    extraFilters: const <String>['IsActive eq true'],
    retainHistoricalSelection: true,
  ),
  coreText('JurisdictionCode', 'Jurisdiction Code', required: true),
  coreInteger(
    'RateBasisPoints',
    'Rate Basis Points',
    required: true,
    minimumValue: 0,
    maximumValue: 10000,
  ),
  coreDateTime('EffectiveFrom', 'Effective From', required: true),
  coreDateTime('EffectiveTo', 'Effective To'),
  coreJson('Attributes', 'Attributes'),
];

final List<AcpFieldDescriptor> _invoiceTemplateFields = <AcpFieldDescriptor>[
  ..._namedDefinitionFields,
  coreText('Locale', 'Locale', required: true),
  coreText(
    'TemplateFormat',
    'Template Format',
    required: true,
    options: const <String>['html', 'text'],
  ),
  coreMultiline('SubjectTemplate', 'Subject Template'),
  coreMultiline('BodyTemplate', 'Body Template', required: true),
];

final List<AcpFieldDescriptor> _discountCreateFields = <AcpFieldDescriptor>[
  ..._namedDefinitionFields,
  coreText(
    'Kind',
    'Kind',
    required: true,
    options: const <String>['percentage', 'fixed_amount'],
  ),
  const AcpFieldDescriptor(
    key: 'PercentageBasisPoints',
    label: 'Percentage Basis Points',
    kind: AcpFieldKind.integer,
    minimumValue: 0,
    maximumValue: 10000,
    visibleWhenEquals: <String, List<Object>>{
      'Kind': <Object>['percentage'],
    },
    clearWhenHidden: true,
  ),
  _currencyReference(
    visibleWhenEquals: const <String, List<Object>>{
      'Kind': <Object>['fixed_amount'],
    },
    clearWhenHidden: true,
  ),
  ..._currencyInternals,
  AcpFieldDescriptor(
    key: 'Amount',
    label: 'Fixed Amount',
    kind: AcpFieldKind.money,
    minorUnitFieldKey: '_CurrencyMinorUnit',
    currencyCodeFieldKey: '_CurrencyCode',
    visibleWhenEquals: const <String, List<Object>>{
      'Kind': <Object>['fixed_amount'],
    },
    clearWhenHidden: true,
  ),
  coreText('CouponCode', 'Coupon Code'),
  coreDateTime('ValidFrom', 'Valid From'),
  coreDateTime('ValidUntil', 'Valid Until'),
];

final List<AcpFieldDescriptor> _discountUpdateFields = <AcpFieldDescriptor>[
  coreText('DisplayName', 'Display Name', required: true),
  coreMultiline('Description', 'Description'),
  coreText('CouponCode', 'Coupon Code'),
  coreDateTime('ValidFrom', 'Valid From'),
  coreDateTime('ValidUntil', 'Valid Until'),
  coreJson('Attributes', 'Attributes'),
];

final List<AcpFieldDescriptor> _currencyInternals = <AcpFieldDescriptor>[
  coreInternalText('_CurrencyMinorUnit'),
  coreInternalText('_CurrencyCode'),
];

AcpFieldDescriptor _productReference({bool required = false}) {
  return coreReference(
    'ProductId',
    'Product',
    entitySet: 'BillingProducts',
    scopeMode: AcpScopeMode.none,
    required: required,
    searchFields: const <String>['Code', 'Name'],
    titleFields: const <String>['Name', 'Code'],
    subtitleFields: const <String>['Code', 'Description'],
    defaultOrderBy: 'Code asc',
    retainHistoricalSelection: true,
  );
}

AcpFieldDescriptor _currencyReference({
  bool required = false,
  Map<String, List<Object>> visibleWhenEquals = const <String, List<Object>>{},
  bool clearWhenHidden = false,
}) {
  return coreReference(
    'CurrencyDefinitionId',
    'Currency',
    entitySet: 'BillingCurrencyDefinitions',
    scopeMode: AcpScopeMode.none,
    required: required,
    searchFields: const <String>['Code', 'NumericCode', 'DisplayName'],
    titleFields: const <String>['Code', 'DisplayName'],
    subtitleFields: const <String>['DisplayName', 'MinorUnit', 'IsActive'],
    defaultOrderBy: 'Code asc',
    extraFilters: const <String>['IsActive eq true'],
    copyFieldsFromSelection: const <String, String>{
      'MinorUnit': '_CurrencyMinorUnit',
      'Code': '_CurrencyCode',
    },
    retainHistoricalSelection: true,
    visibleWhenEquals: visibleWhenEquals,
    clearWhenHidden: clearWhenHidden,
  );
}

AcpFieldDescriptor _meterReference({
  bool alwaysVisible = false,
  bool required = false,
}) {
  return coreReference(
    'MeterDefinitionId',
    'Meter Definition',
    entitySet: 'BillingMeterDefinitions',
    scopeMode: AcpScopeMode.none,
    required: required,
    searchFields: const <String>['Code', 'Unit', 'Description'],
    titleFields: const <String>['Code'],
    subtitleFields: const <String>['Unit', 'AggregationMode', 'IsActive'],
    defaultOrderBy: 'Code asc',
    extraFilters: const <String>['IsActive eq true'],
    retainHistoricalSelection: true,
    visibleWhenEquals: alwaysVisible
        ? const <String, List<Object>>{}
        : const <String, List<Object>>{
            'PriceType': <Object>['metered'],
          },
    clearWhenHidden: !alwaysVisible,
    submitNullWhenHidden: !alwaysVisible,
  );
}

AcpActionDescriptor _archiveAction(String noun) {
  return AcpActionDescriptor(
    name: 'archive',
    label: 'Archive',
    target: AcpActionTarget.entity,
    includeRowVersion: true,
    confirmMessage: 'Archive this $noun?',
    successMessage: '$noun archived.',
  );
}

List<AcpActionDescriptor> _activationActions(String noun) {
  return <AcpActionDescriptor>[
    AcpActionDescriptor(
      name: 'activate',
      label: 'Activate',
      target: AcpActionTarget.entity,
      includeRowVersion: true,
      confirmMessage: 'Activate this $noun?',
      successMessage: '$noun activated.',
      visibleWhenEquals: const <String, List<Object>>{
        'IsActive': <Object>[false],
      },
    ),
    AcpActionDescriptor(
      name: 'deactivate',
      label: 'Deactivate',
      target: AcpActionTarget.entity,
      includeRowVersion: true,
      confirmMessage:
          'Deactivate this $noun? Existing historical references remain visible.',
      successMessage: '$noun deactivated.',
      visibleWhenEquals: const <String, List<Object>>{
        'IsActive': <Object>[true],
      },
    ),
  ];
}

String? validateBillingPricePayload(Map<String, dynamic> payload) {
  final globalError = validateGlobalBillingPayload(payload);
  if (globalError != null) {
    return globalError;
  }
  final priceType = payload['PriceType']?.toString();
  final meterId = payload['MeterDefinitionId'];
  if (priceType == 'metered' &&
      (meterId == null || '$meterId'.trim().isEmpty)) {
    return 'Metered Prices require an active global Meter Definition.';
  }
  if (priceType != null && priceType != 'metered' && meterId != null) {
    return 'Unmetered Prices must not retain a Meter Definition.';
  }
  final attributes = payload['Attributes'];
  if (attributes is Map &&
      attributes.keys.any((key) => '$key' == 'included_usage')) {
    return 'Package allowances belong in Price Entitlements, not Attributes.included_usage.';
  }
  return null;
}

String? validateTaxRatePayload(Map<String, dynamic> payload) {
  final globalError = validateGlobalBillingPayload(payload);
  if (globalError != null) {
    return globalError;
  }
  return _validateDateOrder(payload, 'EffectiveFrom', 'EffectiveTo');
}

String? validateDiscountPayload(Map<String, dynamic> payload) {
  final globalError = validateGlobalBillingPayload(payload);
  if (globalError != null) {
    return globalError;
  }
  final dateError = _validateDateOrder(payload, 'ValidFrom', 'ValidUntil');
  if (dateError != null) {
    return dateError;
  }
  final kind = payload['Kind']?.toString();
  if (kind == 'percentage' && payload['PercentageBasisPoints'] == null) {
    return 'Percentage discounts require Percentage Basis Points.';
  }
  if (kind == 'percentage' &&
      (payload['Amount'] != null || payload['CurrencyDefinitionId'] != null)) {
    return 'Percentage discounts must omit Amount and Currency.';
  }
  if (kind == 'fixed_amount' &&
      (payload['Amount'] == null || payload['CurrencyDefinitionId'] == null)) {
    return 'Fixed-amount discounts require an Amount and Currency.';
  }
  if (kind == 'fixed_amount' && payload['PercentageBasisPoints'] != null) {
    return 'Fixed-amount discounts must omit Percentage Basis Points.';
  }
  return null;
}

String? validateGlobalBillingPayload(Map<String, dynamic> payload) {
  if (payload.containsKey('TenantId')) {
    return 'Global billing definitions cannot contain TenantId.';
  }
  final attributes = payload['Attributes'];
  if (attributes == null) {
    return null;
  }
  final unsafe = <String>[];
  void walk(Object? value, String path) {
    if (value is Map) {
      for (final entry in value.entries) {
        final label = entry.key.toString().trim();
        final normalized = label.toLowerCase().replaceAll(
          RegExp('[^a-z0-9]'),
          '',
        );
        final childPath = path.isEmpty ? label : '$path.$label';
        if (_forbiddenAttributeKeys.contains(normalized) ||
            _forbiddenAttributeFragments.any(normalized.contains)) {
          unsafe.add(childPath);
        }
        walk(entry.value, childPath);
      }
    } else if (value is List) {
      for (var index = 0; index < value.length; index++) {
        walk(value[index], '$path[$index]');
      }
    }
  }

  walk(attributes, '');
  return unsafe.isEmpty
      ? null
      : 'Attributes contain tenant/customer-sensitive keys: ${unsafe.join(', ')}';
}

String? _validateDateOrder(
  Map<String, dynamic> payload,
  String startKey,
  String endKey,
) {
  final start = DateTime.tryParse(payload[startKey]?.toString() ?? '');
  final end = DateTime.tryParse(payload[endKey]?.toString() ?? '');
  if (start != null && end != null && !end.isAfter(start)) {
    return '$endKey must be later than $startKey.';
  }
  return null;
}

const Set<String> _forbiddenAttributeKeys = <String>{
  'accountid',
  'bankaccount',
  'cardnumber',
  'contact',
  'credential',
  'customerid',
  'email',
  'financialtransaction',
  'paymentmethod',
  'phone',
  'secret',
  'tenantid',
  'token',
};

const Set<String> _forbiddenAttributeFragments = <String>{
  'bankaccount',
  'cardnumber',
  'contact',
  'credential',
  'email',
  'financialtransaction',
  'paymentmethod',
  'phone',
  'secret',
  'tenant',
  'token',
};
