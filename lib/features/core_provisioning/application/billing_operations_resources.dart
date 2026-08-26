import 'package:mugen_ui/features/core_provisioning/application/core_provisioning_descriptors.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

final List<AcpResourceDescriptor>
billingOperationsResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'billing-entitlement-buckets',
    title: 'Entitlement Buckets',
    entitySet: 'BillingEntitlementBuckets',
    scopeMode: AcpScopeMode.required,
    description:
        'Tenant billing allowances for a metered period. Buckets cannot be deleted.',
    columns: <AcpColumnDescriptor>[
      coreColumn('MeterCode', 'Meter Code'),
      coreColumn('IncludedQuantity', 'Included'),
      coreColumn('PeriodStart', 'Period Start', flex: 2),
      coreColumn('PeriodEnd', 'Period End', flex: 2),
      coreColumn('AccountId', 'Account', flex: 2),
      coreColumn('SubscriptionId', 'Subscription', flex: 2),
    ],
    createFields: <AcpFieldDescriptor>[
      _billingAccount(required: true),
      _billingSubscription(applyAfterCreate: true),
      coreText('MeterCode', 'Meter Code', required: true),
      coreDateTime('PeriodStart', 'Period Start', required: true),
      coreDateTime('PeriodEnd', 'Period End', required: true),
      coreInteger(
        'IncludedQuantity',
        'Included Quantity',
        required: true,
        minimumValue: 0,
      ),
      coreReference(
        'PriceId',
        'Price',
        entitySet: 'BillingPrices',
        scopeMode: AcpScopeMode.none,
        applyAfterCreate: true,
        searchFields: const <String>['Code', 'MeterCode', 'Currency'],
        titleFields: const <String>['Code'],
        subtitleFields: const <String>['PriceType', 'Currency', 'MeterCode'],
        defaultOrderBy: 'Code asc',
      ),
      coreInteger(
        'RolloverQuantity',
        'Rollover Quantity',
        minimumValue: 0,
        applyAfterCreate: true,
      ),
      coreText('ExternalRef', 'External Reference', applyAfterCreate: true),
      coreJson('Attributes', 'Attributes', applyAfterCreate: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _billingAccount(),
      _billingSubscription(),
      coreText('MeterCode', 'Meter Code'),
      coreDateTime('PeriodStart', 'Period Start'),
      coreDateTime('PeriodEnd', 'Period End'),
      coreInteger('IncludedQuantity', 'Included Quantity', minimumValue: 0),
      coreInteger('RolloverQuantity', 'Rollover Quantity', minimumValue: 0),
      coreText('ExternalRef', 'External Reference'),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['MeterCode', 'ExternalRef'],
    defaultOrderBy: 'PeriodStart desc, MeterCode asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'billing-invoices',
    title: 'Invoices',
    entitySet: 'BillingInvoices',
    scopeMode: AcpScopeMode.required,
    description:
        'Create and edit draft invoices, then use guarded lifecycle actions.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Number', 'Number'),
      coreColumn('Status', 'Status'),
      coreColumn('Currency', 'Currency'),
      coreColumn('TotalAmount', 'Total'),
      coreColumn('DueAt', 'Due At', flex: 2),
      coreColumn('AccountId', 'Account', flex: 2),
    ],
    createFields: <AcpFieldDescriptor>[
      _billingAccount(required: true),
      coreText(
        'Currency',
        'Currency',
        required: true,
        initialValue: 'USD',
        options: const <String>['USD', 'EUR', 'GBP', 'GYD'],
      ),
      _billingSubscription(applyAfterCreate: true),
      coreText('Number', 'Invoice Number', applyAfterCreate: true),
      coreDateTime('DueAt', 'Due At', applyAfterCreate: true),
      coreInteger(
        'SubtotalAmount',
        'Subtotal Amount',
        minimumValue: 0,
        applyAfterCreate: true,
      ),
      coreInteger(
        'TaxAmount',
        'Tax Amount',
        minimumValue: 0,
        applyAfterCreate: true,
      ),
      coreInteger(
        'TotalAmount',
        'Total Amount',
        minimumValue: 0,
        applyAfterCreate: true,
      ),
      coreJson('Attributes', 'Attributes', applyAfterCreate: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _billingAccount(),
      _billingSubscription(),
      coreText('Number', 'Invoice Number'),
      coreText(
        'Currency',
        'Currency',
        options: const <String>['USD', 'EUR', 'GBP', 'GYD'],
      ),
      coreDateTime('DueAt', 'Due At'),
      coreInteger('SubtotalAmount', 'Subtotal Amount', minimumValue: 0),
      coreInteger('TaxAmount', 'Tax Amount', minimumValue: 0),
      coreInteger('TotalAmount', 'Total Amount', minimumValue: 0),
      coreJson('Attributes', 'Attributes'),
    ],
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'issue',
        label: 'Issue',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Issue this draft invoice?',
        successMessage: 'Invoice issued.',
        visibleWhenEquals: const <String, List<Object>>{
          'Status': <Object>['draft'],
        },
      ),
      AcpActionDescriptor(
        name: 'void',
        label: 'Void',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Void this invoice? This cannot be undone.',
        successMessage: 'Invoice voided.',
        visibleWhenEquals: const <String, List<Object>>{
          'Status': <Object>['draft', 'issued'],
        },
      ),
      AcpActionDescriptor(
        name: 'mark_paid',
        label: 'Mark Paid',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Mark this invoice as paid?',
        successMessage: 'Invoice marked paid.',
        visibleWhenEquals: const <String, List<Object>>{
          'Status': <Object>['issued'],
        },
      ),
    ],
    searchFields: const <String>['Number', 'Status', 'Currency'],
    defaultOrderBy: 'CreatedAt desc',
    allowCreate: true,
    allowUpdate: true,
    updateWhenEquals: const <String, List<Object>>{
      'Status': <Object>['draft'],
    },
  ),
  AcpResourceDescriptor(
    key: 'billing-invoice-lines',
    title: 'Invoice Lines',
    entitySet: 'BillingInvoiceLines',
    scopeMode: AcpScopeMode.required,
    description:
        'Draft invoice charges, including one-time setup charges without a recurring period.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Description', 'Description', flex: 2),
      coreColumn('Quantity', 'Quantity'),
      coreColumn('UnitAmount', 'Unit Amount'),
      coreColumn('Amount', 'Amount'),
      coreColumn('InvoiceId', 'Invoice', flex: 2),
      coreColumn('PriceId', 'Price', flex: 2),
    ],
    createFields: <AcpFieldDescriptor>[
      _invoice(required: true),
      coreInteger(
        'Quantity',
        'Quantity',
        required: true,
        minimumValue: 1,
        initialValue: 1,
      ),
      coreInteger('Amount', 'Amount', required: true, minimumValue: 0),
      _price(applyAfterCreate: true),
      coreText('Description', 'Description', applyAfterCreate: true),
      coreDateTime('PeriodStart', 'Period Start', applyAfterCreate: true),
      coreDateTime('PeriodEnd', 'Period End', applyAfterCreate: true),
      coreInteger(
        'UnitAmount',
        'Unit Amount',
        minimumValue: 0,
        applyAfterCreate: true,
      ),
      coreJson('Attributes', 'Attributes', applyAfterCreate: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _price(),
      coreText('Description', 'Description'),
      coreDateTime('PeriodStart', 'Period Start'),
      coreDateTime('PeriodEnd', 'Period End'),
      coreInteger('Quantity', 'Quantity', minimumValue: 1),
      coreInteger('UnitAmount', 'Unit Amount', minimumValue: 0),
      coreInteger('Amount', 'Amount', minimumValue: 0),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Description'],
    defaultOrderBy: 'CreatedAt desc',
    allowCreate: true,
    allowUpdate: true,
  ),
  _diagnostic(
    key: 'billing-usage-allocations',
    title: 'Usage Allocations',
    entitySet: 'BillingUsageAllocations',
    columns: <AcpColumnDescriptor>[
      coreColumn('MeterCode', 'Meter Code'),
      coreColumn('Quantity', 'Quantity'),
      coreColumn('AllocatedAt', 'Allocated At', flex: 2),
      coreColumn('AccountId', 'Account', flex: 2),
    ],
  ),
  _diagnostic(
    key: 'billing-runs',
    title: 'Billing Runs',
    entitySet: 'BillingRuns',
    columns: <AcpColumnDescriptor>[
      coreColumn('Status', 'Status'),
      coreColumn('WindowStart', 'Window Start', flex: 2),
      coreColumn('WindowEnd', 'Window End', flex: 2),
      coreColumn('CreatedAt', 'Created At', flex: 2),
    ],
  ),
];

AcpFieldDescriptor _billingAccount({bool required = false}) {
  return coreReference(
    'AccountId',
    'Billing Account',
    entitySet: 'BillingAccounts',
    scopeMode: AcpScopeMode.required,
    required: required,
    searchFields: const <String>['AccountNumber', 'DisplayName', 'ExternalRef'],
    titleFields: const <String>['DisplayName', 'AccountNumber'],
    subtitleFields: const <String>['AccountNumber', 'Status', 'Id'],
    defaultOrderBy: 'DisplayName asc',
  );
}

AcpFieldDescriptor _billingSubscription({bool applyAfterCreate = false}) {
  return coreReference(
    'SubscriptionId',
    'Subscription',
    entitySet: 'BillingSubscriptions',
    scopeMode: AcpScopeMode.required,
    applyAfterCreate: applyAfterCreate,
    searchFields: const <String>['ExternalRef', 'Status'],
    titleFields: const <String>['ExternalRef', 'Id'],
    subtitleFields: const <String>['Status', 'Id'],
    defaultOrderBy: 'CreatedAt desc',
  );
}

AcpFieldDescriptor _invoice({bool required = false}) {
  return coreReference(
    'InvoiceId',
    'Invoice',
    entitySet: 'BillingInvoices',
    scopeMode: AcpScopeMode.required,
    required: required,
    searchFields: const <String>['Number', 'Status', 'Currency'],
    titleFields: const <String>['Number', 'Id'],
    subtitleFields: const <String>['Status', 'Currency', 'Id'],
    defaultOrderBy: 'CreatedAt desc',
    extraFilters: const <String>["Status eq 'draft'"],
  );
}

AcpFieldDescriptor _price({bool applyAfterCreate = false}) {
  return coreReference(
    'PriceId',
    'Price',
    entitySet: 'BillingPrices',
    scopeMode: AcpScopeMode.none,
    applyAfterCreate: applyAfterCreate,
    searchFields: const <String>['Code', 'MeterCode', 'Currency'],
    titleFields: const <String>['Code'],
    subtitleFields: const <String>['PriceType', 'Currency', 'MeterCode', 'Id'],
    defaultOrderBy: 'Code asc',
  );
}

AcpResourceDescriptor _diagnostic({
  required String key,
  required String title,
  required String entitySet,
  required List<AcpColumnDescriptor> columns,
}) {
  return AcpResourceDescriptor(
    key: key,
    title: title,
    entitySet: entitySet,
    scopeMode: AcpScopeMode.required,
    description: 'Read-only operational diagnostics.',
    columns: columns,
    defaultOrderBy: 'CreatedAt desc',
  );
}
