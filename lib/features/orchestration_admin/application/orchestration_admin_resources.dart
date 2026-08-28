import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_standard_options.dart';

final List<AcpResourceDescriptor>
orchestrationAdminResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'channel-profiles',
    title: 'Channel Profiles',
    entitySet: 'ChannelProfiles',
    scopeMode: AcpScopeMode.required,
    description:
        'Tenant-scoped channel profile registry used by intake, routing, and fallback policies.',
    columns: <AcpColumnDescriptor>[
      _column('ChannelKey', 'Channel'),
      _column('ProfileKey', 'Profile Key'),
      _column('DisplayName', 'Display Name'),
      _column(
        'ClientProfileId',
        'Client Profile',
        reference: _clientProfileDisplay,
      ),
      _column('ServiceRouteDefaultKey', 'Service Route'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _clientProfileId(),
      _channelKey(required: true),
      _text('ProfileKey', 'Profile Key', required: true),
      _text('ServiceRouteDefaultKey', 'Service Route Default Key'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _clientProfileId(),
      _text('ChannelKey', 'Channel Key', readOnly: true),
      _text('ProfileKey', 'Profile Key', readOnly: true),
      _text('DisplayName', 'Display Name'),
      _text('ServiceRouteDefaultKey', 'Service Route Default Key'),
      _routeReference(key: 'RouteDefaultKey', label: 'Default Route'),
      _policyReference(),
      _bool('IsActive', 'Is Active'),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>[
      'ChannelKey',
      'ProfileKey',
      'DisplayName',
      'ServiceRouteDefaultKey',
    ],
    defaultOrderBy: 'IsActive desc, ChannelKey asc, ProfileKey asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'ingress-bindings',
    title: 'Ingress Bindings',
    entitySet: 'IngressBindings',
    scopeMode: AcpScopeMode.required,
    description:
        'Inbound identifier bindings used to resolve tenant and channel context.',
    columns: <AcpColumnDescriptor>[
      _column('ChannelKey', 'Channel'),
      _column('IdentifierType', 'Identifier Type'),
      _column('IdentifierValue', 'Identifier Value'),
      _column('ServiceRouteKey', 'Service Route'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _channelProfileId(),
      _channelKey(required: true),
      _identifierType(required: true),
      _text('IdentifierValue', 'Identifier Value', required: true),
      _serviceRouteReference(),
    ],
    updateFields: <AcpFieldDescriptor>[
      _channelProfileId(),
      _channelKey(),
      _identifierType(),
      _text('IdentifierValue', 'Identifier Value'),
      _serviceRouteReference(),
      _bool('IsActive', 'Is Active'),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>[
      'ChannelKey',
      'IdentifierType',
      'IdentifierValue',
      'ServiceRouteKey',
    ],
    defaultOrderBy:
        'IsActive desc, ChannelKey asc, IdentifierType asc, IdentifierValue asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'intake-rules',
    title: 'Intake Rules',
    entitySet: 'IntakeRules',
    scopeMode: AcpScopeMode.required,
    description:
        'Keyword, menu, or intent rules with explicit precedence metadata.',
    columns: <AcpColumnDescriptor>[
      _column('Name', 'Name'),
      _column('MatchKind', 'Match Kind'),
      _column('MatchValue', 'Match Value'),
      _column('RouteKey', 'Route Key'),
      _column('Priority', 'Priority'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('Name', 'Name', required: true),
      _matchKind(required: true),
      _text('MatchValue', 'Match Value', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _channelProfileId(),
      _text('Name', 'Name'),
      _matchKind(),
      _text('MatchValue', 'Match Value'),
      _routeReference(),
      _int('Priority', 'Priority'),
      _bool('IsActive', 'Is Active'),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Name', 'MatchKind', 'MatchValue', 'RouteKey'],
    defaultOrderBy: 'IsActive desc, Priority asc, Name asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'routing-rules',
    title: 'Routing Rules',
    entitySet: 'RoutingRules',
    scopeMode: AcpScopeMode.required,
    description:
        'Queue, owner, and service targets for resolved orchestration routes.',
    columns: <AcpColumnDescriptor>[
      _column('RouteKey', 'Route Key'),
      _column('TargetQueueName', 'Queue'),
      _column('OwnerUserId', 'Owner', reference: _ownerUserDisplay),
      _column('TargetServiceKey', 'Service Key'),
      _column('Priority', 'Priority'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('RouteKey', 'Route Key', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _channelProfileId(),
      _text('RouteKey', 'Route Key'),
      _text('TargetQueueName', 'Target Queue Name'),
      _userReference('OwnerUserId', 'Owner'),
      _text('TargetServiceKey', 'Target Service Key'),
      _text('TargetNamespace', 'Target Namespace'),
      _int('Priority', 'Priority'),
      _bool('IsActive', 'Is Active'),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>[
      'RouteKey',
      'TargetQueueName',
      'TargetServiceKey',
      'TargetNamespace',
    ],
    defaultOrderBy: 'IsActive desc, Priority asc, RouteKey asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'orchestration-policies',
    title: 'Policies',
    entitySet: 'OrchestrationPolicies',
    scopeMode: AcpScopeMode.required,
    description:
        'Shared hours, escalation, and fallback defaults for channel-agnostic orchestration.',
    columns: <AcpColumnDescriptor>[
      _column('Code', 'Code'),
      _column('Name', 'Name'),
      _column('HoursMode', 'Hours Mode'),
      _column('EscalationMode', 'Escalation Mode'),
      _column('FallbackPolicy', 'Fallback Policy'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('Code', 'Code', required: true),
      _text('Name', 'Name', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('Code', 'Code'),
      _text('Name', 'Name'),
      _text('HoursMode', 'Hours Mode', initialValue: 'always_on'),
      _text('EscalationMode', 'Escalation Mode', initialValue: 'manual'),
      _text('FallbackPolicy', 'Fallback Policy', initialValue: 'default_route'),
      _text('FallbackTarget', 'Fallback Target'),
      _text('EscalationTarget', 'Escalation Target'),
      _int('EscalationAfterSeconds', 'Escalation After Seconds'),
      _bool('IsActive', 'Is Active'),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Code', 'Name', 'HoursMode'],
    defaultOrderBy: 'IsActive desc, Name asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'throttle-rules',
    title: 'Throttle Rules',
    entitySet: 'ThrottleRules',
    scopeMode: AcpScopeMode.required,
    description:
        'Sender throttling windows, limits, and optional auto-block behavior.',
    columns: <AcpColumnDescriptor>[
      _column('Code', 'Code'),
      _column('SenderScope', 'Sender Scope'),
      _column('WindowSeconds', 'Window Seconds'),
      _column('MaxMessages', 'Max Messages'),
      _column('BlockOnViolation', 'Block'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[_text('Code', 'Code', required: true)],
    updateFields: <AcpFieldDescriptor>[
      _channelProfileId(),
      _text('Code', 'Code'),
      _text('SenderScope', 'Sender Scope', initialValue: 'sender'),
      _int('WindowSeconds', 'Window Seconds', initialValue: 60),
      _int('MaxMessages', 'Max Messages', initialValue: 20),
      _bool('BlockOnViolation', 'Block On Violation'),
      _int('BlockDurationSeconds', 'Block Duration Seconds'),
      _int('Priority', 'Priority', initialValue: 100),
      _bool('IsActive', 'Is Active'),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Code', 'SenderScope'],
    defaultOrderBy: 'IsActive desc, Priority asc, Code asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'blocklist-entries',
    title: 'Blocklist',
    entitySet: 'BlocklistEntries',
    scopeMode: AcpScopeMode.required,
    description:
        'Sender-level blocklist rows and moderation actions for channel operations.',
    columns: <AcpColumnDescriptor>[
      _column('SenderKey', 'Sender Key'),
      _column('Reason', 'Reason'),
      _column('ExpiresAt', 'Expires'),
      _column('BlockedAt', 'Blocked At'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('SenderKey', 'Sender Key', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _channelProfileId(),
      _text('SenderKey', 'Sender Key'),
      _multiline('Reason', 'Reason'),
      _dateTime('ExpiresAt', 'Expires At'),
      _bool('IsActive', 'Is Active'),
      _json('Attributes', 'Attributes'),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'block_sender',
        label: 'Block Sender',
        target: AcpActionTarget.collection,
        confirmMessage: 'Create or refresh a sender blocklist entry?',
        successMessage: 'Sender blocked.',
        fields: <AcpFieldDescriptor>[
          _text('SenderKey', 'Sender Key', required: true),
          _channelProfileId(),
          _multiline('Reason', 'Reason'),
          _dateTime('ExpiresAt', 'Expires At'),
          _json('Attributes', 'Attributes'),
        ],
      ),
      AcpActionDescriptor(
        name: 'unblock_sender',
        label: 'Unblock Sender',
        target: AcpActionTarget.collection,
        confirmMessage: 'Unblock this sender?',
        successMessage: 'Sender unblocked.',
        fields: <AcpFieldDescriptor>[
          _text('SenderKey', 'Sender Key', required: true),
          _channelProfileId(),
          _multiline('Reason', 'Reason'),
        ],
      ),
    ],
    searchFields: const <String>['SenderKey', 'Reason'],
    defaultOrderBy: 'IsActive desc, BlockedAt desc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'conversation-states',
    title: 'Conversation State',
    entitySet: 'ConversationStates',
    scopeMode: AcpScopeMode.required,
    description:
        'Operational conversation snapshots for intake, routing, throttle, escalation, and fallback.',
    columns: <AcpColumnDescriptor>[
      _column('SenderKey', 'Sender Key'),
      _column('Status', 'Status'),
      _column('RouteKey', 'Route Key'),
      _column('AssignedQueueName', 'Queue'),
      _column('IsEscalated', 'Escalated'),
      _column('IsThrottled', 'Throttled'),
      _column('LastActivityAt', 'Last Activity'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('SenderKey', 'Sender Key', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _channelProfileId(),
      _policyReference(),
      _text('SenderKey', 'Sender Key'),
      _text('ExternalConversationRef', 'External Conversation Ref'),
      _text('Status', 'Status', initialValue: 'open'),
      _serviceRouteReference(),
      _routeReference(),
      _queueReference('AssignedQueueName', 'Assigned Queue'),
      _userReference('AssignedOwnerUserId', 'Assigned Owner'),
      _serviceReference('AssignedServiceKey', 'Assigned Service'),
      _text('FallbackMode', 'Fallback Mode'),
      _text('FallbackTarget', 'Fallback Target'),
      _multiline('FallbackReason', 'Fallback Reason'),
      _bool('IsFallbackActive', 'Is Fallback Active'),
      _json('Attributes', 'Attributes'),
    ],
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'evaluate_intake',
        label: 'Evaluate Intake',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Evaluate intake rules for this conversation?',
        successMessage: 'Intake evaluation completed.',
        fields: <AcpFieldDescriptor>[
          _text('Keyword', 'Keyword'),
          _text('MenuOption', 'Menu Option'),
          _text('Intent', 'Intent'),
        ],
      ),
      AcpActionDescriptor(
        name: 'route',
        label: 'Route',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Resolve routing for this conversation?',
        successMessage: 'Routing completed.',
        fields: <AcpFieldDescriptor>[
          _routeReference(),
          _queueReference('QueueName', 'Queue'),
          _userReference('OwnerUserId', 'Owner'),
          _serviceReference('ServiceKey', 'Service'),
        ],
      ),
      AcpActionDescriptor(
        name: 'escalate',
        label: 'Escalate',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Escalate this conversation?',
        successMessage: 'Escalation recorded.',
        fields: <AcpFieldDescriptor>[
          _int('EscalationLevel', 'Escalation Level'),
          _multiline('Reason', 'Reason'),
        ],
      ),
      AcpActionDescriptor(
        name: 'apply_throttle',
        label: 'Apply Throttle',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Apply throttle policy for this conversation?',
        successMessage: 'Throttle applied.',
        fields: <AcpFieldDescriptor>[
          _int(
            'IncrementCount',
            'Increment Count',
            required: true,
            initialValue: 1,
          ),
        ],
      ),
      AcpActionDescriptor(
        name: 'set_fallback',
        label: 'Set Fallback',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Set fallback mode for this conversation?',
        successMessage: 'Fallback updated.',
        fields: <AcpFieldDescriptor>[
          _text('FallbackMode', 'Fallback Mode', required: true),
          _text('FallbackTarget', 'Fallback Target'),
          _multiline('Reason', 'Reason'),
        ],
      ),
    ],
    searchFields: const <String>[
      'SenderKey',
      'Status',
      'RouteKey',
      'AssignedQueueName',
      'ExternalConversationRef',
    ],
    defaultOrderBy: 'LastActivityAt desc, SenderKey asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'work-items',
    title: 'Work Items',
    entitySet: 'WorkItems',
    scopeMode: AcpScopeMode.required,
    description:
        'Canonical channel intake envelopes used for replay, workflow, and case linkage.',
    columns: <AcpColumnDescriptor>[
      _column('TraceId', 'Trace ID', opaqueIdentifier: true),
      _column('Source', 'Source'),
      _column('LinkedCaseId', 'Linked Case', reference: _linkedCaseDisplay),
      _column(
        'LinkedWorkflowInstanceId',
        'Workflow',
        reference: _linkedWorkflowDisplay,
      ),
      _column('ReplayCount', 'Replay Count'),
      _column('LastReplayedAt', 'Last Replayed'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('TraceId', 'Trace ID', required: true),
      _text('Source', 'Source', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('Source', 'Source'),
      _json('Participants', 'Participants', initialValue: const []),
      _json('Content', 'Content'),
      _json('Attachments', 'Attachments', initialValue: const []),
      _json('Signals', 'Signals', initialValue: const []),
      _json('Extractions', 'Extractions', initialValue: const []),
      _linkedCaseReference(),
      _linkedWorkflowReference(),
      _json('Attributes', 'Attributes'),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'create_from_channel',
        label: 'Create From Channel',
        target: AcpActionTarget.collection,
        confirmMessage:
            'Create a canonical work item from channel payload data?',
        successMessage: 'Work item created from channel payload.',
        fields: <AcpFieldDescriptor>[
          _text('TraceId', 'Trace ID'),
          _text('Source', 'Source', required: true),
          _json('Participants', 'Participants', initialValue: const []),
          _json('Content', 'Content'),
          _json('Attachments', 'Attachments', initialValue: const []),
          _json('Signals', 'Signals', initialValue: const []),
          _json('Extractions', 'Extractions', initialValue: const []),
          _linkedCaseReference(),
          _linkedWorkflowReference(),
          _multiline('Note', 'Note'),
        ],
      ),
    ],
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'link_to_case',
        label: 'Link To Case',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Link this work item to case or workflow records?',
        successMessage: 'Work item linkage updated.',
        fields: <AcpFieldDescriptor>[
          _linkedCaseReference(),
          _linkedWorkflowReference(),
          _multiline('Note', 'Note'),
        ],
      ),
      AcpActionDescriptor(
        name: 'replay',
        label: 'Replay',
        target: AcpActionTarget.entity,
        confirmMessage: 'Replay the canonical work item envelope?',
        successMessage: 'Replay request submitted.',
        fields: <AcpFieldDescriptor>[
          _bool('IncludeMetadata', 'Include Metadata'),
        ],
      ),
    ],
    searchFields: const <String>['TraceId', 'Source'],
    defaultOrderBy: 'UpdatedAt desc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'orchestration-events',
    title: 'Events',
    entitySet: 'OrchestrationEvents',
    scopeMode: AcpScopeMode.required,
    description:
        'Append-only decision timeline for intake, routing, escalation, and throttle operations.',
    columns: <AcpColumnDescriptor>[
      _column('OccurredAt', 'Occurred'),
      _column('EventType', 'Event Type'),
      _column('Decision', 'Decision'),
      _column('SenderKey', 'Sender'),
      _column('Source', 'Source'),
      _column('Reason', 'Reason'),
    ],
    searchFields: const <String>[
      'TraceId',
      'SenderKey',
      'EventType',
      'Decision',
      'Source',
    ],
    defaultOrderBy: 'OccurredAt desc',
  ),
];

AcpColumnDescriptor _column(
  String key,
  String label, {
  AcpColumnReferenceDescriptor? reference,
  bool opaqueIdentifier = false,
}) {
  return AcpColumnDescriptor(
    key: key,
    label: label,
    reference: reference,
    opaqueIdentifier: opaqueIdentifier,
  );
}

const AcpColumnReferenceDescriptor _clientProfileDisplay =
    AcpColumnReferenceDescriptor(
      navigationPath: 'ClientProfile',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('DisplayName'),
        AcpReferenceFieldDescriptor('ProfileKey'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('PlatformKey'),
        AcpReferenceFieldDescriptor('ProfileKey'),
      ],
      batchLookup: AcpBatchReferenceDescriptor(
        entitySet: 'MessagingClientProfiles',
        scopeMode: AcpScopeMode.optional,
        selectFields: <String>['DisplayName', 'PlatformKey', 'ProfileKey'],
      ),
    );

const AcpColumnReferenceDescriptor _ownerUserDisplay =
    AcpColumnReferenceDescriptor(
      navigationPath: 'OwnerUser',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('LoginEmail'),
        AcpReferenceFieldDescriptor('Username'),
      ],
      batchLookup: AcpBatchReferenceDescriptor(
        entitySet: 'Users',
        scopeMode: AcpScopeMode.none,
        selectFields: <String>['LoginEmail', 'Username'],
        deletedView: AcpDeletedView.all,
      ),
    );

const AcpColumnReferenceDescriptor _linkedCaseDisplay =
    AcpColumnReferenceDescriptor(
      navigationPath: 'LinkedCase',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('CaseNumber'),
        AcpReferenceFieldDescriptor('Title'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Title'),
        AcpReferenceFieldDescriptor('Status'),
      ],
      batchLookup: AcpBatchReferenceDescriptor(
        entitySet: 'OpsCases',
        scopeMode: AcpScopeMode.required,
        selectFields: <String>['CaseNumber', 'Title', 'Status'],
        deletedView: AcpDeletedView.all,
      ),
    );

const AcpColumnReferenceDescriptor _linkedWorkflowDisplay =
    AcpColumnReferenceDescriptor(
      navigationPath: 'LinkedWorkflowInstance',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Title'),
        AcpReferenceFieldDescriptor('ExternalRef'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('ExternalRef'),
        AcpReferenceFieldDescriptor('Status'),
      ],
      batchLookup: AcpBatchReferenceDescriptor(
        entitySet: 'OpsWorkflowInstances',
        scopeMode: AcpScopeMode.required,
        selectFields: <String>['Title', 'ExternalRef', 'Status'],
      ),
    );

const List<String> _intakeMatchKindOptions = <String>[
  'intent',
  'keyword',
  'menu',
];

AcpFieldDescriptor _text(
  String key,
  String label, {
  bool required = false,
  Object? initialValue,
  bool readOnly = false,
  List<String> options = const <String>[],
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    required: required,
    initialValue: initialValue,
    readOnly: readOnly,
    options: options,
  );
}

AcpFieldDescriptor _clientProfileId() {
  return const AcpFieldDescriptor(
    key: 'ClientProfileId',
    label: 'Client Profile ID',
    hintText: 'Search messaging client profiles in this tenant',
    reference: AcpFieldReferenceDescriptor(
      entitySet: 'MessagingClientProfiles',
      scopeMode: AcpScopeMode.optional,
      title: 'Messaging Client Profiles',
      searchFields: <String>[
        'PlatformKey',
        'ProfileKey',
        'DisplayName',
        'Provider',
        'PathToken',
      ],
      titleFields: <String>['DisplayName', 'ProfileKey', 'PathToken', 'Id'],
      subtitleFields: <String>[
        'PlatformKey',
        'ProfileKey',
        'Provider',
        'PathToken',
        'Id',
      ],
      defaultOrderBy: 'PlatformKey asc, ProfileKey asc',
      filterFieldsFromForm: <String, String>{'PlatformKey': 'ChannelKey'},
      copyFieldsFromSelection: <String, String>{'PlatformKey': 'ChannelKey'},
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _channelProfileId() {
  return const AcpFieldDescriptor(
    key: 'ChannelProfileId',
    label: 'Channel Profile ID',
    hintText: 'Search channel profiles in this tenant',
    reference: AcpFieldReferenceDescriptor(
      entitySet: 'ChannelProfiles',
      scopeMode: AcpScopeMode.required,
      title: 'Channel Profiles',
      searchFields: <String>[
        'ChannelKey',
        'ProfileKey',
        'DisplayName',
        'ServiceRouteDefaultKey',
      ],
      titleFields: <String>['DisplayName', 'ProfileKey', 'ChannelKey', 'Id'],
      subtitleFields: <String>[
        'ChannelKey',
        'ProfileKey',
        'ServiceRouteDefaultKey',
        'Id',
      ],
      defaultOrderBy: 'IsActive desc, ChannelKey asc, ProfileKey asc',
      copyFieldsFromSelection: <String, String>{'ChannelKey': 'ChannelKey'},
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _channelKey({bool required = false}) {
  return AcpFieldDescriptor(
    key: 'ChannelKey',
    label: 'Channel',
    required: required,
    options: acpMessagingPlatformOptions,
    searchableOptions: true,
    allowCustomOption: true,
  );
}

AcpFieldDescriptor _policyReference() {
  return const AcpFieldDescriptor(
    key: 'PolicyId',
    label: 'Orchestration Policy',
    reference: AcpFieldReferenceDescriptor(
      entitySet: 'OrchestrationPolicies',
      scopeMode: AcpScopeMode.required,
      title: 'Orchestration Policies',
      searchFields: <String>['Code', 'Name', 'HoursMode'],
      titleFields: <String>['Name', 'Code', 'Id'],
      subtitleFields: <String>['Code', 'HoursMode', 'IsActive', 'Id'],
      defaultOrderBy: 'IsActive desc, Name asc',
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _userReference(String key, String label) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    reference: const AcpFieldReferenceDescriptor(
      entitySet: 'Users',
      scopeMode: AcpScopeMode.none,
      title: 'Users',
      searchFields: <String>['LoginEmail', 'Username'],
      titleFields: <String>['LoginEmail', 'Username', 'Id'],
      subtitleFields: <String>['Username', 'LoginEmail', 'Id'],
      defaultOrderBy: 'Username asc',
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _routeReference({
  String key = 'RouteKey',
  String label = 'Route',
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    reference: const AcpFieldReferenceDescriptor(
      entitySet: 'RoutingRules',
      scopeMode: AcpScopeMode.required,
      title: 'Routing Rules',
      valueField: 'RouteKey',
      searchFields: <String>['RouteKey', 'TargetQueueName', 'TargetServiceKey'],
      titleFields: <String>['RouteKey', 'TargetQueueName', 'Id'],
      subtitleFields: <String>[
        'TargetQueueName',
        'TargetServiceKey',
        'IsActive',
        'Id',
      ],
      defaultOrderBy: 'IsActive desc, Priority asc, RouteKey asc',
      filterFieldsFromForm: <String, String>{
        'ChannelProfileId': 'ChannelProfileId',
      },
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _queueReference(String key, String label) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    reference: const AcpFieldReferenceDescriptor(
      entitySet: 'RoutingRules',
      scopeMode: AcpScopeMode.required,
      title: 'Routing Queues',
      valueField: 'TargetQueueName',
      searchFields: <String>['TargetQueueName', 'RouteKey'],
      titleFields: <String>['TargetQueueName', 'RouteKey', 'Id'],
      subtitleFields: <String>['RouteKey', 'IsActive', 'Id'],
      defaultOrderBy: 'TargetQueueName asc, RouteKey asc',
      extraFilters: <String>['TargetQueueName ne null'],
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _serviceReference(String key, String label) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    reference: const AcpFieldReferenceDescriptor(
      entitySet: 'RoutingRules',
      scopeMode: AcpScopeMode.required,
      title: 'Routing Services',
      valueField: 'TargetServiceKey',
      searchFields: <String>['TargetServiceKey', 'RouteKey'],
      titleFields: <String>['TargetServiceKey', 'RouteKey', 'Id'],
      subtitleFields: <String>['TargetNamespace', 'RouteKey', 'IsActive', 'Id'],
      defaultOrderBy: 'TargetServiceKey asc, RouteKey asc',
      extraFilters: <String>['TargetServiceKey ne null'],
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _serviceRouteReference() {
  return const AcpFieldDescriptor(
    key: 'ServiceRouteKey',
    label: 'Service Route',
    reference: AcpFieldReferenceDescriptor(
      entitySet: 'ChannelProfiles',
      scopeMode: AcpScopeMode.required,
      title: 'Service Routes',
      valueField: 'ServiceRouteDefaultKey',
      searchFields: <String>[
        'ServiceRouteDefaultKey',
        'DisplayName',
        'ChannelKey',
        'ProfileKey',
      ],
      titleFields: <String>['ServiceRouteDefaultKey', 'DisplayName', 'Id'],
      subtitleFields: <String>['ChannelKey', 'ProfileKey', 'IsActive', 'Id'],
      defaultOrderBy: 'ServiceRouteDefaultKey asc',
      extraFilters: <String>['ServiceRouteDefaultKey ne null'],
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _linkedCaseReference() {
  return const AcpFieldDescriptor(
    key: 'LinkedCaseId',
    label: 'Linked Case',
    reference: AcpFieldReferenceDescriptor(
      entitySet: 'OpsCases',
      scopeMode: AcpScopeMode.required,
      title: 'Cases',
      searchFields: <String>['CaseNumber', 'Title', 'Status'],
      titleFields: <String>['CaseNumber', 'Title', 'Id'],
      subtitleFields: <String>['Title', 'Status', 'Id'],
      defaultOrderBy: 'UpdatedAt desc',
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _linkedWorkflowReference() {
  return const AcpFieldDescriptor(
    key: 'LinkedWorkflowInstanceId',
    label: 'Linked Workflow',
    reference: AcpFieldReferenceDescriptor(
      entitySet: 'OpsWorkflowInstances',
      scopeMode: AcpScopeMode.required,
      title: 'Workflow Instances',
      searchFields: <String>['Title', 'ExternalRef', 'Status'],
      titleFields: <String>['Title', 'ExternalRef', 'Id'],
      subtitleFields: <String>['ExternalRef', 'Status', 'Id'],
      defaultOrderBy: 'UpdatedAt desc',
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _identifierType({bool required = false}) {
  return AcpFieldDescriptor(
    key: 'IdentifierType',
    label: 'Identifier Type',
    required: required,
    hintText: 'Select the adapter identifier used for ingress routing',
    options: const <String>[
      'path_token',
      'phone_number_id',
      'recipient_user_id',
      'account_number',
      'tenant_slug',
    ],
  );
}

AcpFieldDescriptor _matchKind({bool required = false}) {
  return _text(
    'MatchKind',
    'Match Kind',
    required: required,
    options: _intakeMatchKindOptions,
  );
}

AcpFieldDescriptor _multiline(
  String key,
  String label, {
  bool required = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.multiline,
    required: required,
    minLines: 3,
    maxLines: 5,
  );
}

AcpFieldDescriptor _bool(
  String key,
  String label, {
  Object? initialValue = true,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.boolean,
    initialValue: initialValue,
  );
}

AcpFieldDescriptor _int(
  String key,
  String label, {
  bool required = false,
  Object? initialValue,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.integer,
    required: required,
    initialValue: initialValue,
  );
}

AcpFieldDescriptor _dateTime(String key, String label) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.dateTime,
  );
}

AcpFieldDescriptor _json(
  String key,
  String label, {
  Object? initialValue = const <String, dynamic>{},
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.json,
    minLines: 6,
    maxLines: 10,
    initialValue: initialValue,
  );
}
