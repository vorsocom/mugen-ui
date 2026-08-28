import 'package:mugen_ui/features/core_provisioning/application/core_provisioning_descriptors.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

const List<String> _formulaTypes = <String>[
  'count_rows',
  'sum_column',
  'avg_column',
  'min_column',
  'max_column',
];

const List<String> _valueFormulaTypes = <String>[
  'sum_column',
  'avg_column',
  'min_column',
  'max_column',
];
const List<String> _reportingSourceTables = <String>[
  'billing_account',
  'billing_subscription',
  'billing_usage_event',
  'billing_usage_allocation',
  'billing_run',
  'billing_invoice',
  'billing_invoice_line',
  'billing_payment',
  'billing_ledger_entry',
  'channel_orchestration_conversation_state',
  'channel_orchestration_human_handoff_session',
  'channel_orchestration_work_item',
  'knowledge_pack_knowledge_entry_revision',
  'knowledge_pack_knowledge_scope',
  'ops_connector_call_log',
  'ops_sla_clock',
  'ops_sla_breach_event',
  'ops_workflow_workflow_instance',
  'ops_workflow_workflow_task',
];
const List<String> _reportingTimeColumns = <String>[
  'created_at',
  'updated_at',
  'occurred_at',
  'started_at',
  'completed_at',
  'issued_at',
  'paid_at',
  'last_activity_at',
];
const List<String> _reportingValueColumns = <String>[
  'amount',
  'amount_due',
  'subtotal_amount',
  'tax_amount',
  'total_amount',
  'quantity',
  'duration_ms',
  'value_numeric',
];
const List<String> _reportingDimensionColumns = <String>[
  'tenant_id',
  'account_id',
  'subscription_id',
  'status',
  'currency',
  'platform',
  'service_route_key',
  'assigned_queue_name',
  'assigned_service_key',
];

final List<AcpResourceDescriptor> reportingResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'ops-reporting-metric-definitions',
    title: 'Metric Definitions',
    entitySet: 'OpsReportingMetricDefinitions',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description: 'Reusable typed aggregation formulas and source bindings.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('Name', 'Name', flex: 2),
      coreColumn('FormulaType', 'Formula'),
      coreColumn('SourceTable', 'Source Table'),
      coreColumn('IsActive', 'Active'),
    ],
    createFields: _metricFields(create: true),
    updateFields: _metricFields(create: false),
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'run_aggregation',
        label: 'Run Aggregation',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Run aggregation for this metric definition?',
        successMessage: 'Aggregation completed.',
        visibleWhenEquals: const <String, List<Object>>{
          'IsActive': <Object>[true],
        },
        fields: _windowFields(requireWindow: false),
      ),
      AcpActionDescriptor(
        name: 'recompute_window',
        label: 'Recompute Window',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage:
            'Recompute this window and replace existing series values?',
        successMessage: 'Metric window recomputed.',
        visibleWhenEquals: const <String, List<Object>>{
          'IsActive': <Object>[true],
        },
        fields: _windowFields(requireWindow: true),
      ),
    ],
    searchFields: const <String>['Code', 'Name', 'SourceTable'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'ops-reporting-report-definitions',
    title: 'Report Definitions',
    entitySet: 'OpsReportingReportDefinitions',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Reusable report definitions with searchable metric-code selection.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('Name', 'Name', flex: 2),
      coreColumn('MetricCodes', 'Metric Codes', flex: 2),
      coreColumn('IsActive', 'Active'),
    ],
    createFields: _reportFields(create: true),
    updateFields: _reportFields(create: false),
    searchFields: const <String>['Code', 'Name', 'Description'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  _diagnostic(
    key: 'ops-reporting-metric-series',
    title: 'Metric Series',
    entitySet: 'OpsReportingMetricSeries',
    columns: <AcpColumnDescriptor>[
      coreColumn(
        'MetricDefinitionId',
        'Metric',
        flex: 2,
        reference: _metricDisplay('MetricDefinition'),
      ),
      coreColumn('WindowStart', 'Window Start', flex: 2),
      coreColumn('WindowEnd', 'Window End', flex: 2),
      coreColumn('ScopeKey', 'Scope'),
      coreColumn('Value', 'Value'),
    ],
  ),
  _diagnostic(
    key: 'ops-reporting-aggregation-jobs',
    title: 'Run History',
    entitySet: 'OpsReportingAggregationJobs',
    columns: <AcpColumnDescriptor>[
      coreColumn('Status', 'Status'),
      coreColumn(
        'MetricDefinitionId',
        'Metric',
        flex: 2,
        reference: _metricDisplay('MetricDefinition'),
      ),
      coreColumn('WindowStart', 'Window Start', flex: 2),
      coreColumn('WindowEnd', 'Window End', flex: 2),
      coreColumn('ErrorMessage', 'Error', flex: 2),
    ],
  ),
  _diagnostic(
    key: 'ops-reporting-report-snapshots',
    title: 'Report Snapshots',
    entitySet: 'OpsReportingReportSnapshots',
    columns: <AcpColumnDescriptor>[
      coreColumn('Status', 'Status'),
      coreColumn(
        'ReportDefinitionId',
        'Report',
        flex: 2,
        reference: _reportDisplay,
      ),
      coreColumn('WindowStart', 'Window Start', flex: 2),
      coreColumn('WindowEnd', 'Window End', flex: 2),
      coreColumn('CreatedAt', 'Created', flex: 2),
    ],
  ),
];

AcpColumnReferenceDescriptor _metricDisplay(String navigationPath) {
  return coreBatchReference(
    navigationPath: navigationPath,
    entitySet: 'OpsReportingMetricDefinitions',
    scopeMode: AcpScopeMode.required,
    literalType: AcpFilterLiteralType.guid,
    selectFields: const <String>['Name', 'Code', 'FormulaType'],
    titleFields: const <AcpReferenceFieldDescriptor>[
      AcpReferenceFieldDescriptor('Name'),
      AcpReferenceFieldDescriptor('Code'),
    ],
    subtitleFields: const <AcpReferenceFieldDescriptor>[
      AcpReferenceFieldDescriptor('Code'),
      AcpReferenceFieldDescriptor('FormulaType'),
    ],
  );
}

final AcpColumnReferenceDescriptor _reportDisplay = coreBatchReference(
  navigationPath: 'ReportDefinition',
  entitySet: 'OpsReportingReportDefinitions',
  scopeMode: AcpScopeMode.required,
  literalType: AcpFilterLiteralType.guid,
  selectFields: const <String>['Name', 'Code'],
  titleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('Name'),
    AcpReferenceFieldDescriptor('Code'),
  ],
  subtitleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('Code'),
  ],
);

List<AcpFieldDescriptor> _metricFields({required bool create}) {
  return <AcpFieldDescriptor>[
    coreText('Code', 'Code', required: create),
    coreText('Name', 'Name', required: create),
    coreText(
      'FormulaType',
      'Formula Type',
      required: create,
      initialValue: create ? 'count_rows' : null,
      options: _formulaTypes,
    ),
    coreText(
      'SourceTable',
      'Source Table',
      required: create,
      options: _reportingSourceTables,
      searchableOptions: true,
      allowCustomOption: true,
    ),
    coreText(
      'SourceTimeColumn',
      'Source Time Column',
      options: _reportingTimeColumns,
      searchableOptions: true,
      allowCustomOption: true,
    ),
    coreText(
      'SourceValueColumn',
      'Source Value Column',
      requiredWhenEquals: const <String, List<String>>{
        'FormulaType': _valueFormulaTypes,
      },
      options: _reportingValueColumns,
      searchableOptions: true,
      allowCustomOption: true,
    ),
    coreText(
      'ScopeColumn',
      'Scope Column',
      options: _reportingDimensionColumns,
      searchableOptions: true,
      allowCustomOption: true,
    ),
    coreJson('SourceFilter', 'Source Filter'),
    coreMultiline('Description', 'Description'),
    coreBool('IsActive', 'Is Active', initialValue: create ? true : null),
    coreJson('Attributes', 'Attributes'),
  ];
}

List<AcpFieldDescriptor> _windowFields({required bool requireWindow}) {
  return <AcpFieldDescriptor>[
    coreDateTime('WindowStart', 'Window Start', required: requireWindow),
    coreDateTime('WindowEnd', 'Window End', required: requireWindow),
    coreInteger(
      'BucketMinutes',
      'Bucket Minutes',
      minimumValue: 1,
      initialValue: 60,
    ),
    coreText('ScopeKey', 'Scope Key'),
    coreMultiline('Note', 'Note'),
  ];
}

List<AcpFieldDescriptor> _reportFields({required bool create}) {
  return <AcpFieldDescriptor>[
    coreText('Code', 'Code', required: create),
    coreText('Name', 'Name', required: create),
    coreMultiline('Description', 'Description'),
    coreStringList(
      'MetricCodes',
      'Metric Codes',
      reference: const AcpFieldReferenceDescriptor(
        entitySet: 'OpsReportingMetricDefinitions',
        scopeMode: AcpScopeMode.required,
        title: 'Metric Definitions',
        valueField: 'Code',
        multiSelect: true,
        searchFields: <String>['Code', 'Name'],
        titleFields: <String>['Name', 'Code'],
        subtitleFields: <String>['Code', 'FormulaType', 'SourceTable'],
        defaultOrderBy: 'Code asc',
        extraFilters: <String>["IsActive eq true"],
      ),
    ),
    coreJson('FiltersJson', 'Filters JSON'),
    coreStringList(
      'GroupByJson',
      'Group By Fields',
      options: _reportingDimensionColumns,
      multiSelectOptions: true,
      allowCustomOption: true,
    ),
    coreBool('IsActive', 'Is Active', initialValue: create ? true : null),
    coreJson('Attributes', 'Attributes'),
  ];
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
    keyLiteralType: AcpFilterLiteralType.guid,
    description: 'Read-only reporting operations and generated data.',
    columns: columns,
    defaultOrderBy: 'CreatedAt desc',
  );
}
