import 'package:mugen_ui/features/core_provisioning/application/core_provisioning_descriptors.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

final List<AcpResourceDescriptor> workflowResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'ops-workflow-definitions',
    title: 'Workflow Definitions',
    entitySet: 'OpsWorkflowDefinitions',
    scopeMode: AcpScopeMode.required,
    description: 'Tenant workflow identities and activation settings.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Key', 'Key'),
      coreColumn('Name', 'Name', flex: 2),
      coreColumn('IsActive', 'Active'),
      coreColumn('UpdatedAt', 'Updated', flex: 2),
    ],
    createFields: <AcpFieldDescriptor>[
      coreText('Key', 'Key', required: true),
      coreText('Name', 'Name', required: true),
      coreMultiline('Description', 'Description', applyAfterCreate: true),
      coreBool(
        'IsActive',
        'Is Active',
        initialValue: true,
        applyAfterCreate: true,
      ),
      coreJson('Attributes', 'Attributes', applyAfterCreate: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      coreText('Key', 'Key'),
      coreText('Name', 'Name'),
      coreMultiline('Description', 'Description'),
      coreBool('IsActive', 'Is Active'),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Key', 'Name', 'Description'],
    defaultOrderBy: 'Key asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'ops-workflow-versions',
    title: 'Workflow Versions',
    entitySet: 'OpsWorkflowVersions',
    scopeMode: AcpScopeMode.required,
    description:
        'Constrained draft, published, and retired versions with an explicit default contract.',
    columns: <AcpColumnDescriptor>[
      coreColumn('VersionNumber', 'Version'),
      coreColumn('Status', 'Status'),
      coreColumn('IsDefault', 'Default'),
      coreColumn(
        'WorkflowDefinitionId',
        'Definition',
        flex: 2,
        reference: _workflowDefinitionDisplay,
      ),
      coreColumn('PublishedAt', 'Published At', flex: 2),
    ],
    createFields: <AcpFieldDescriptor>[
      _workflowDefinition(required: true),
      coreInteger(
        'VersionNumber',
        'Version Number',
        required: true,
        minimumValue: 1,
      ),
      coreText(
        'Status',
        'Status',
        options: const <String>['draft', 'published', 'retired'],
        initialValue: 'draft',
        applyAfterCreate: true,
      ),
      coreDateTime('PublishedAt', 'Published At', applyAfterCreate: true),
      _userReference(
        'PublishedByUserId',
        'Published By User',
        applyAfterCreate: true,
      ),
      coreBool('IsDefault', 'Is Default', applyAfterCreate: true),
      coreJson('Attributes', 'Attributes', applyAfterCreate: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      coreText(
        'Status',
        'Status',
        options: const <String>['draft', 'published', 'retired'],
      ),
      coreDateTime('PublishedAt', 'Published At'),
      _userReference('PublishedByUserId', 'Published By User'),
      coreBool('IsDefault', 'Is Default'),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Status'],
    defaultOrderBy: 'CreatedAt desc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'ops-workflow-states',
    title: 'Workflow States',
    entitySet: 'OpsWorkflowStates',
    scopeMode: AcpScopeMode.required,
    description: 'Named states with explicit initial and terminal behavior.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Key', 'Key'),
      coreColumn('Name', 'Name', flex: 2),
      coreColumn('IsInitial', 'Initial'),
      coreColumn('IsTerminal', 'Terminal'),
      coreColumn(
        'WorkflowVersionId',
        'Version',
        flex: 2,
        reference: _workflowVersionDisplay,
      ),
    ],
    createFields: <AcpFieldDescriptor>[
      _workflowVersion(required: true),
      coreText('Key', 'Key', required: true),
      coreText('Name', 'Name', required: true),
      coreBool('IsInitial', 'Is Initial', applyAfterCreate: true),
      coreBool('IsTerminal', 'Is Terminal', applyAfterCreate: true),
      coreJson('Attributes', 'Attributes', applyAfterCreate: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      coreText('Key', 'Key'),
      coreText('Name', 'Name'),
      coreBool('IsInitial', 'Is Initial'),
      coreBool('IsTerminal', 'Is Terminal'),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Key', 'Name'],
    defaultOrderBy: 'WorkflowVersionId asc, Key asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'ops-workflow-transitions',
    title: 'Workflow Transitions',
    entitySet: 'OpsWorkflowTransitions',
    scopeMode: AcpScopeMode.required,
    description:
        'Searchable source-to-target state transitions within a workflow version.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Key', 'Key'),
      coreColumn(
        'FromStateId',
        'From State',
        flex: 2,
        reference: _workflowStateDisplay('FromState'),
      ),
      coreColumn(
        'ToStateId',
        'To State',
        flex: 2,
        reference: _workflowStateDisplay('ToState'),
      ),
      coreColumn('RequiresApproval', 'Approval'),
      coreColumn('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _workflowVersion(required: true),
      coreText('Key', 'Key', required: true),
      _workflowState('FromStateId', 'Source State', required: true),
      _workflowState('ToStateId', 'Target State', required: true),
      coreBool('RequiresApproval', 'Requires Approval', applyAfterCreate: true),
      _userReference(
        'AutoAssignUserId',
        'Auto-assign User',
        applyAfterCreate: true,
      ),
      _queueReference(applyAfterCreate: true),
      coreJson('CompensationJson', 'Compensation JSON', applyAfterCreate: true),
      coreBool(
        'IsActive',
        'Is Active',
        initialValue: true,
        applyAfterCreate: true,
      ),
      coreJson('Attributes', 'Attributes', applyAfterCreate: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      coreText('Key', 'Key'),
      _workflowState('FromStateId', 'Source State'),
      _workflowState('ToStateId', 'Target State'),
      coreBool('RequiresApproval', 'Requires Approval'),
      _userReference('AutoAssignUserId', 'Auto-assign User'),
      _queueReference(),
      coreJson('CompensationJson', 'Compensation JSON'),
      coreBool('IsActive', 'Is Active'),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Key', 'AutoAssignQueue'],
    defaultOrderBy: 'WorkflowVersionId asc, Key asc',
    allowCreate: true,
    allowUpdate: true,
  ),
];

final AcpColumnReferenceDescriptor _workflowDefinitionDisplay =
    coreBatchReference(
      navigationPath: 'WorkflowDefinition',
      entitySet: 'OpsWorkflowDefinitions',
      scopeMode: AcpScopeMode.required,
      selectFields: const <String>['Name', 'Key'],
      titleFields: const <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Name'),
        AcpReferenceFieldDescriptor('Key'),
      ],
      subtitleFields: const <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Key'),
      ],
    );

final AcpColumnReferenceDescriptor _workflowVersionDisplay = coreBatchReference(
  navigationPath: 'WorkflowVersion',
  entitySet: 'OpsWorkflowVersions',
  scopeMode: AcpScopeMode.required,
  selectFields: const <String>['VersionNumber', 'Status'],
  titleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('VersionNumber', prefix: 'v'),
  ],
  subtitleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('Status'),
  ],
);

AcpColumnReferenceDescriptor _workflowStateDisplay(String navigationPath) {
  return coreBatchReference(
    navigationPath: navigationPath,
    entitySet: 'OpsWorkflowStates',
    scopeMode: AcpScopeMode.required,
    selectFields: const <String>['Name', 'Key'],
    titleFields: const <AcpReferenceFieldDescriptor>[
      AcpReferenceFieldDescriptor('Name'),
      AcpReferenceFieldDescriptor('Key'),
    ],
    subtitleFields: const <AcpReferenceFieldDescriptor>[
      AcpReferenceFieldDescriptor('Key'),
    ],
  );
}

AcpFieldDescriptor _workflowDefinition({bool required = false}) {
  return coreReference(
    'WorkflowDefinitionId',
    'Workflow Definition',
    entitySet: 'OpsWorkflowDefinitions',
    scopeMode: AcpScopeMode.required,
    required: required,
    searchFields: const <String>['Key', 'Name'],
    titleFields: const <String>['Name', 'Key'],
    subtitleFields: const <String>['Key', 'IsActive', 'Id'],
    defaultOrderBy: 'Key asc',
  );
}

AcpFieldDescriptor _userReference(
  String key,
  String label, {
  bool applyAfterCreate = false,
}) {
  return coreReference(
    key,
    label,
    entitySet: 'Users',
    scopeMode: AcpScopeMode.none,
    applyAfterCreate: applyAfterCreate,
    searchFields: const <String>['LoginEmail', 'Username'],
    titleFields: const <String>['LoginEmail', 'Username'],
    subtitleFields: const <String>['Username', 'LoginEmail', 'Id'],
    defaultOrderBy: 'Username asc',
    retainHistoricalSelection: true,
  );
}

AcpFieldDescriptor _queueReference({bool applyAfterCreate = false}) {
  return coreReference(
    'AutoAssignQueue',
    'Auto-assign Queue',
    entitySet: 'RoutingRules',
    scopeMode: AcpScopeMode.required,
    applyAfterCreate: applyAfterCreate,
    valueField: 'TargetQueueName',
    searchFields: const <String>['TargetQueueName', 'RouteKey'],
    titleFields: const <String>['TargetQueueName', 'RouteKey'],
    subtitleFields: const <String>['RouteKey', 'IsActive', 'Id'],
    defaultOrderBy: 'TargetQueueName asc, RouteKey asc',
    extraFilters: const <String>['TargetQueueName ne null'],
    retainHistoricalSelection: true,
  );
}

AcpFieldDescriptor _workflowVersion({bool required = false}) {
  return coreReference(
    'WorkflowVersionId',
    'Workflow Version',
    entitySet: 'OpsWorkflowVersions',
    scopeMode: AcpScopeMode.required,
    required: required,
    searchFields: const <String>['Status'],
    titleFields: const <String>['VersionNumber'],
    subtitleFields: const <String>[
      'Status',
      'IsDefault',
      'WorkflowDefinitionId',
      'Id',
    ],
    defaultOrderBy: 'CreatedAt desc',
  );
}

AcpFieldDescriptor _workflowState(
  String key,
  String label, {
  bool required = false,
}) {
  return coreReference(
    key,
    label,
    entitySet: 'OpsWorkflowStates',
    scopeMode: AcpScopeMode.required,
    required: required,
    searchFields: const <String>['Key', 'Name'],
    titleFields: const <String>['Name', 'Key'],
    subtitleFields: const <String>['Key', 'IsInitial', 'IsTerminal', 'Id'],
    defaultOrderBy: 'Key asc',
    filterFieldsFromForm: const <String, String>{
      'WorkflowVersionId': 'WorkflowVersionId',
    },
  );
}
