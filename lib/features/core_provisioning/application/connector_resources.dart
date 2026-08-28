import 'dart:convert';

import 'package:mugen_ui/features/core_provisioning/application/core_provisioning_descriptors.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

final List<AcpResourceDescriptor> connectorResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'ops-connector-types',
    title: 'Connector Types',
    entitySet: 'OpsConnectorTypes',
    scopeMode: AcpScopeMode.none,
    description:
        'Global HTTP/JSON adapter types and reusable capability contracts.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Key', 'Key'),
      coreColumn('DisplayName', 'Display Name', flex: 2),
      coreColumn('AdapterKind', 'Adapter'),
      coreColumn('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      coreText('Key', 'Key', required: true),
      coreText('DisplayName', 'Display Name', required: true),
      coreText(
        'AdapterKind',
        'Adapter Kind',
        required: true,
        initialValue: 'http_json',
        options: const <String>['http_json'],
      ),
      coreJson(
        'CapabilitiesJson',
        'Capabilities JSON',
        required: true,
        initialValue: const <String, dynamic>{},
      ),
      coreBool('IsActive', 'Is Active', initialValue: true),
      coreJson('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      coreText('Key', 'Key'),
      coreText('DisplayName', 'Display Name'),
      coreText(
        'AdapterKind',
        'Adapter Kind',
        options: const <String>['http_json'],
      ),
      coreJson('CapabilitiesJson', 'Capabilities JSON'),
      coreBool('IsActive', 'Is Active'),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Key', 'DisplayName', 'AdapterKind'],
    defaultOrderBy: 'Key asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'ops-connector-instances',
    title: 'Connector Instances',
    entitySet: 'OpsConnectorInstances',
    scopeMode: AcpScopeMode.required,
    description:
        'Tenant connector configuration using managed KeyRef identifiers; secret material is never retrieved.',
    columns: <AcpColumnDescriptor>[
      coreColumn('DisplayName', 'Display Name', flex: 2),
      coreColumn('Status', 'Status'),
      coreColumn(
        'ConnectorTypeId',
        'Connector Type',
        flex: 2,
        reference: _connectorTypeDisplay,
      ),
      coreColumn('SecretRef', 'Managed Key ID', flex: 2),
      coreColumn('EscalationPolicyKey', 'Escalation Policy'),
    ],
    createFields: _instanceFields(create: true),
    updateFields: _instanceFields(create: false),
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'test_connection',
        label: 'Test Connection',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Run the connector test-connection probe?',
        successMessage: 'Connection test completed.',
        fields: <AcpFieldDescriptor>[coreText('TraceId', 'Trace ID')],
      ),
      AcpActionDescriptor(
        name: 'invoke',
        label: 'Invoke',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage:
            'Invoke this connector capability now? This can call an external service.',
        successMessage: 'Connector invocation completed.',
        visibleWhenEquals: const <String, List<Object>>{
          'Status': <Object>['active'],
        },
        fields: <AcpFieldDescriptor>[
          coreText(
            'CapabilityName',
            'Capability Name',
            required: true,
            optionsBuilder: _capabilityOptionsFor,
            searchableOptions: true,
            allowCustomOption: true,
            hintText: 'Select a capability declared by this connector type',
          ),
          coreJson(
            'InputJson',
            'Input JSON',
            required: true,
            initialValue: const <String, dynamic>{},
          ),
          coreText('TraceId', 'Trace ID'),
          coreText('ClientActionKey', 'Client Action Key'),
        ],
      ),
    ],
    searchFields: const <String>['DisplayName', 'Status', 'SecretRef'],
    defaultOrderBy: 'DisplayName asc',
    allowCreate: true,
    allowUpdate: true,
    expansions: const <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'ConnectorType',
        selectFields: <String>['CapabilitiesJson'],
      ),
    ],
  ),
  AcpResourceDescriptor(
    key: 'ops-connector-call-logs',
    title: 'Connector Call Logs',
    entitySet: 'OpsConnectorCallLogs',
    scopeMode: AcpScopeMode.required,
    description:
        'Read-only redacted connector invocation provenance and outcome diagnostics.',
    columns: <AcpColumnDescriptor>[
      coreColumn('CapabilityName', 'Capability'),
      coreColumn('Status', 'Status'),
      coreColumn('HttpStatus', 'HTTP Status'),
      coreColumn('DurationMs', 'Duration (ms)'),
      coreColumn(
        'ConnectorInstanceId',
        'Connector',
        flex: 2,
        reference: _connectorInstanceDisplay,
      ),
      coreColumn('CreatedAt', 'Created', flex: 2),
    ],
    searchFields: const <String>['CapabilityName', 'Status', 'TraceId'],
    defaultOrderBy: 'CreatedAt desc',
  ),
];

final AcpColumnReferenceDescriptor _connectorTypeDisplay = coreBatchReference(
  navigationPath: 'ConnectorType',
  entitySet: 'OpsConnectorTypes',
  scopeMode: AcpScopeMode.none,
  selectFields: const <String>['DisplayName', 'Key', 'AdapterKind'],
  titleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('DisplayName'),
    AcpReferenceFieldDescriptor('Key'),
  ],
  subtitleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('Key'),
    AcpReferenceFieldDescriptor('AdapterKind'),
  ],
);

final AcpColumnReferenceDescriptor _connectorInstanceDisplay =
    coreBatchReference(
      navigationPath: 'ConnectorInstance',
      entitySet: 'OpsConnectorInstances',
      scopeMode: AcpScopeMode.required,
      selectFields: const <String>['DisplayName', 'Status'],
      titleFields: const <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('DisplayName'),
      ],
      subtitleFields: const <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Status'),
      ],
    );

List<AcpFieldDescriptor> _instanceFields({required bool create}) {
  return <AcpFieldDescriptor>[
    coreReference(
      'ConnectorTypeId',
      'Connector Type',
      entitySet: 'OpsConnectorTypes',
      scopeMode: AcpScopeMode.none,
      required: create,
      searchFields: const <String>['Key', 'DisplayName'],
      titleFields: const <String>['DisplayName', 'Key'],
      subtitleFields: const <String>['Key', 'AdapterKind', 'IsActive', 'Id'],
      defaultOrderBy: 'Key asc',
      extraFilters: const <String>["IsActive eq true"],
    ),
    coreText('DisplayName', 'Display Name', required: create),
    coreJson(
      'ConfigJson',
      'Configuration JSON',
      required: create,
      initialValue: create ? const <String, dynamic>{} : null,
    ),
    coreReference(
      'SecretRef',
      'Managed Secret Key',
      entitySet: 'KeyRefs',
      scopeMode: AcpScopeMode.required,
      required: create,
      valueField: 'KeyId',
      searchFields: const <String>['Purpose', 'KeyId', 'Provider', 'Status'],
      titleFields: const <String>['Purpose', 'KeyId'],
      subtitleFields: const <String>[
        'KeyId',
        'Status',
        'Provider',
        'HasMaterial',
      ],
      defaultOrderBy: 'Purpose asc, KeyId asc',
      extraFilters: const <String>["Status eq 'active'"],
    ),
    coreText(
      'Status',
      'Status',
      initialValue: create ? 'active' : null,
      options: const <String>['active', 'disabled', 'error'],
    ),
    coreReference(
      'EscalationPolicyKey',
      'Escalation Policy',
      entitySet: 'OpsSlaEscalationPolicies',
      scopeMode: AcpScopeMode.required,
      valueField: 'PolicyKey',
      searchFields: const <String>['PolicyKey', 'Name', 'Description'],
      titleFields: const <String>['Name', 'PolicyKey'],
      subtitleFields: const <String>['PolicyKey', 'Priority', 'IsActive', 'Id'],
      defaultOrderBy: 'IsActive desc, Priority asc, PolicyKey asc',
      retainHistoricalSelection: true,
    ),
    coreJson('RetryPolicyJson', 'Retry Policy JSON'),
    coreJson('Attributes', 'Attributes'),
  ];
}

List<String> _capabilityOptionsFor(AcpRow values) {
  final connectorType = values['ConnectorType'];
  if (connectorType is! Map) {
    return const <String>[];
  }
  Object? capabilities = connectorType['CapabilitiesJson'];
  if (capabilities is String) {
    try {
      capabilities = jsonDecode(capabilities);
    } catch (_) {
      return const <String>[];
    }
  }
  if (capabilities is! Map) {
    return const <String>[];
  }
  return capabilities.keys
      .map((key) => key.toString().trim())
      .where((key) => key.isNotEmpty)
      .toList(growable: false)
    ..sort();
}
