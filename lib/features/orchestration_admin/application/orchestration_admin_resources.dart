import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

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
      _column('ClientProfileId', 'Client Profile'),
      _column('ServiceRouteDefaultKey', 'Service Route'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _clientProfileId(),
      _text('ChannelKey', 'Channel Key', required: true),
      _text('ProfileKey', 'Profile Key', required: true),
      _text('ServiceRouteDefaultKey', 'Service Route Default Key'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _clientProfileId(),
      _text('ChannelKey', 'Channel Key', readOnly: true),
      _text('ProfileKey', 'Profile Key', readOnly: true),
      _text('DisplayName', 'Display Name'),
      _text('ServiceRouteDefaultKey', 'Service Route Default Key'),
      _text('RouteDefaultKey', 'Route Default Key'),
      _text('PolicyId', 'Policy ID'),
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
      _text('ChannelKey', 'Channel Key', required: true),
      _identifierType(required: true),
      _text('IdentifierValue', 'Identifier Value', required: true),
      _text('ServiceRouteKey', 'Service Route Key'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _channelProfileId(),
      _text('ChannelKey', 'Channel Key'),
      _identifierType(),
      _text('IdentifierValue', 'Identifier Value'),
      _text('ServiceRouteKey', 'Service Route Key'),
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
      _text('MatchKind', 'Match Kind', required: true),
      _text('MatchValue', 'Match Value', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('ChannelProfileId', 'Channel Profile ID'),
      _text('Name', 'Name'),
      _text('MatchKind', 'Match Kind'),
      _text('MatchValue', 'Match Value'),
      _text('RouteKey', 'Route Key'),
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
      _column('OwnerUserId', 'Owner'),
      _column('TargetServiceKey', 'Service Key'),
      _column('Priority', 'Priority'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('RouteKey', 'Route Key', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('ChannelProfileId', 'Channel Profile ID'),
      _text('RouteKey', 'Route Key'),
      _text('TargetQueueName', 'Target Queue Name'),
      _text('OwnerUserId', 'Owner User ID'),
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
      _text('ChannelProfileId', 'Channel Profile ID'),
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
      _text('ChannelProfileId', 'Channel Profile ID'),
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
          _text('ChannelProfileId', 'Channel Profile ID'),
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
          _text('ChannelProfileId', 'Channel Profile ID'),
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
      _text('ChannelProfileId', 'Channel Profile ID'),
      _text('PolicyId', 'Policy ID'),
      _text('SenderKey', 'Sender Key'),
      _text('ExternalConversationRef', 'External Conversation Ref'),
      _text('Status', 'Status', initialValue: 'open'),
      _text('ServiceRouteKey', 'Service Route Key'),
      _text('RouteKey', 'Route Key'),
      _text('AssignedQueueName', 'Assigned Queue Name'),
      _text('AssignedOwnerUserId', 'Assigned Owner User ID'),
      _text('AssignedServiceKey', 'Assigned Service Key'),
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
          _text('RouteKey', 'Route Key'),
          _text('QueueName', 'Queue Name'),
          _text('OwnerUserId', 'Owner User ID'),
          _text('ServiceKey', 'Service Key'),
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
      _column('TraceId', 'Trace ID'),
      _column('Source', 'Source'),
      _column('LinkedCaseId', 'Linked Case'),
      _column('LinkedWorkflowInstanceId', 'Workflow'),
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
      _text('LinkedCaseId', 'Linked Case ID'),
      _text('LinkedWorkflowInstanceId', 'Linked Workflow Instance ID'),
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
          _text('LinkedCaseId', 'Linked Case ID'),
          _text('LinkedWorkflowInstanceId', 'Linked Workflow Instance ID'),
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
          _text('LinkedCaseId', 'Linked Case ID'),
          _text('LinkedWorkflowInstanceId', 'Linked Workflow Instance ID'),
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

AcpColumnDescriptor _column(String key, String label) {
  return AcpColumnDescriptor(key: key, label: label);
}

AcpFieldDescriptor _text(
  String key,
  String label, {
  bool required = false,
  Object? initialValue,
  bool readOnly = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    required: required,
    initialValue: initialValue,
    readOnly: readOnly,
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
