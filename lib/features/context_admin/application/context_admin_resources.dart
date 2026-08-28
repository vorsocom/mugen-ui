import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_standard_options.dart';

final List<AcpResourceDescriptor>
contextAdminResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'context-profiles',
    title: 'Profiles',
    entitySet: 'ContextProfiles',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Scope-aware context profile selection for platform, channel, route, and client profile combinations.',
    columns: <AcpColumnDescriptor>[
      _column('Name', 'Name'),
      _column('Platform', 'Platform'),
      _column('ChannelKey', 'Channel'),
      _column('ServiceRouteKey', 'Service Route'),
      _column('IsDefault', 'Default'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('Name', 'Name', required: true),
      _multiline('Description', 'Description'),
      _platform(),
      _text('ChannelKey', 'Channel Key'),
      _serviceRouteKey(),
      _clientProfileKey(),
      _policyReference(),
      _multiline('Persona', 'Persona'),
      _bool('IsActive', 'Is Active', initialValue: true),
      _bool('IsDefault', 'Is Default', initialValue: false),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _multiline('Description', 'Description'),
      _platform(),
      _text('ChannelKey', 'Channel Key'),
      _serviceRouteKey(),
      _clientProfileKey(),
      _policyReference(),
      _multiline('Persona', 'Persona'),
      _bool('IsActive', 'Is Active', initialValue: true),
      _bool('IsDefault', 'Is Default', initialValue: false),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>[
      'Name',
      'Platform',
      'ChannelKey',
      'ServiceRouteKey',
      'ClientProfileKey',
    ],
    defaultOrderBy: 'IsDefault desc, IsActive desc, Name asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'context-policies',
    title: 'Policies',
    entitySet: 'ContextPolicies',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Budget, redaction, retention, allow/deny, trace, and cache settings for the context engine.',
    columns: <AcpColumnDescriptor>[
      _column('PolicyKey', 'Policy Key'),
      _column('IsDefault', 'Default'),
      _column('IsActive', 'Active'),
      _column('TraceEnabled', 'Trace'),
      _column('CacheEnabled', 'Cache'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('PolicyKey', 'Policy Key', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _multiline('Description', 'Description'),
      _json('BudgetJson', 'Budget JSON'),
      _json('RedactionJson', 'Redaction JSON'),
      _json('RetentionJson', 'Retention JSON'),
      _json('ContributorAllow', 'Contributor Allow', initialValue: const []),
      _json('ContributorDeny', 'Contributor Deny', initialValue: const []),
      _json('SourceAllow', 'Source Allow', initialValue: const []),
      _json('SourceDeny', 'Source Deny', initialValue: const []),
      _bool('TraceEnabled', 'Trace Enabled', initialValue: true),
      _bool('CacheEnabled', 'Cache Enabled', initialValue: true),
      _bool('IsActive', 'Is Active', initialValue: true),
      _bool('IsDefault', 'Is Default', initialValue: false),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['PolicyKey', 'Description'],
    defaultOrderBy: 'IsDefault desc, IsActive desc, PolicyKey asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'context-contributor-bindings',
    title: 'Contributor Bindings',
    entitySet: 'ContextContributorBindings',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Contributor activation and priority bindings used by the context runtime.',
    columns: <AcpColumnDescriptor>[
      _column('BindingKey', 'Binding Key'),
      _column('ContributorKey', 'Contributor'),
      _column('Platform', 'Platform'),
      _column('Priority', 'Priority'),
      _column('IsEnabled', 'Enabled'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('BindingKey', 'Binding Key', required: true),
      _text(
        'ContributorKey',
        'Contributor Key',
        required: true,
        options: _contributorOptions,
        searchableOptions: true,
        allowCustomOption: true,
      ),
      _platform(),
      _text('ChannelKey', 'Channel Key'),
      _serviceRouteKey(),
      _int('Priority', 'Priority', initialValue: 0),
      _bool('IsEnabled', 'Is Enabled', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _platform(),
      _text('ChannelKey', 'Channel Key'),
      _serviceRouteKey(),
      _int('Priority', 'Priority'),
      _bool('IsEnabled', 'Is Enabled', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>[
      'BindingKey',
      'ContributorKey',
      'Platform',
      'ChannelKey',
    ],
    defaultOrderBy: 'IsEnabled desc, Priority asc, BindingKey asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'context-source-bindings',
    title: 'Source Bindings',
    entitySet: 'ContextSourceBindings',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Source selection overlays that contribute allow rules to the context runtime.',
    columns: <AcpColumnDescriptor>[
      _column('SourceKind', 'Source Kind'),
      _column('SourceKey', 'Source Key'),
      _column('Platform', 'Platform'),
      _column('Locale', 'Locale'),
      _column('Category', 'Category'),
      _column('IsEnabled', 'Enabled'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text(
        'SourceKind',
        'Source Kind',
        required: true,
        options: _sourceKindOptions,
        searchableOptions: true,
        allowCustomOption: true,
      ),
      _text('SourceKey', 'Source Key', required: true),
      _platform(),
      _text('ChannelKey', 'Channel Key'),
      _serviceRouteKey(),
      _locale(),
      _text('Category', 'Category'),
      _bool('IsEnabled', 'Is Enabled', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _platform(),
      _text('ChannelKey', 'Channel Key'),
      _serviceRouteKey(),
      _locale(),
      _text('Category', 'Category'),
      _bool('IsEnabled', 'Is Enabled', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>[
      'SourceKind',
      'SourceKey',
      'Platform',
      'Locale',
      'Category',
    ],
    defaultOrderBy: 'IsEnabled desc, SourceKind asc, SourceKey asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'context-trace-policies',
    title: 'Trace Policies',
    entitySet: 'ContextTracePolicies',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Trace capture policy rows controlling prepare/commit and selected/dropped item detail.',
    columns: <AcpColumnDescriptor>[
      _column('Name', 'Name'),
      _column('CapturePrepare', 'Prepare'),
      _column('CaptureCommit', 'Commit'),
      _column('CaptureSelectedItems', 'Selected Items'),
      _column('CaptureDroppedItems', 'Dropped Items'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[_text('Name', 'Name', required: true)],
    updateFields: <AcpFieldDescriptor>[
      _bool('CapturePrepare', 'Capture Prepare', initialValue: true),
      _bool('CaptureCommit', 'Capture Commit', initialValue: true),
      _bool(
        'CaptureSelectedItems',
        'Capture Selected Items',
        initialValue: true,
      ),
      _bool('CaptureDroppedItems', 'Capture Dropped Items', initialValue: true),
      _bool('IsActive', 'Is Active', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Name'],
    defaultOrderBy: 'IsActive desc, Name asc',
    allowCreate: true,
    allowUpdate: true,
  ),
];

AcpColumnDescriptor _column(String key, String label) {
  return AcpColumnDescriptor(key: key, label: label);
}

const List<String> _platformOptions = <String>[
  'line',
  'matrix',
  'signal',
  'telegram',
  'wechat',
  'whatsapp',
];
const List<String> _contributorOptions = <String>[
  'persona_policy',
  'state',
  'recent_turns',
  'knowledge_pack',
  'channel_orchestration',
  'ops_case',
  'audit',
  'memory',
];
const List<String> _sourceKindOptions = <String>[
  'context_policy',
  'state_snapshot',
  'event_log',
  'knowledge_pack_revision',
  'channel_orchestration',
  'ops_case',
  'audit_biz_trace',
  'memory_record',
  'turn_commit',
];

AcpFieldDescriptor _text(
  String key,
  String label, {
  bool required = false,
  List<String> options = const <String>[],
  bool searchableOptions = false,
  bool allowCustomOption = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    required: required,
    options: options,
    searchableOptions: searchableOptions,
    allowCustomOption: allowCustomOption,
  );
}

AcpFieldDescriptor _policyReference() {
  return const AcpFieldDescriptor(
    key: 'PolicyId',
    label: 'Context Policy',
    reference: AcpFieldReferenceDescriptor(
      entitySet: 'ContextPolicies',
      scopeMode: AcpScopeMode.required,
      title: 'Context Policies',
      searchFields: <String>['PolicyKey', 'Description'],
      titleFields: <String>['PolicyKey', 'Description', 'Id'],
      subtitleFields: <String>['Description', 'IsDefault', 'IsActive', 'Id'],
      defaultOrderBy: 'IsDefault desc, IsActive desc, PolicyKey asc',
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _clientProfileKey() {
  return const AcpFieldDescriptor(
    key: 'ClientProfileKey',
    label: 'Client Profile',
    reference: AcpFieldReferenceDescriptor(
      entitySet: 'MessagingClientProfiles',
      scopeMode: AcpScopeMode.optional,
      title: 'Messaging Client Profiles',
      valueField: 'ProfileKey',
      searchFields: <String>['PlatformKey', 'ProfileKey', 'DisplayName'],
      titleFields: <String>['DisplayName', 'ProfileKey', 'Id'],
      subtitleFields: <String>['PlatformKey', 'ProfileKey', 'IsActive', 'Id'],
      defaultOrderBy: 'PlatformKey asc, ProfileKey asc',
      filterFieldsFromForm: <String, String>{'PlatformKey': 'Platform'},
      retainHistoricalSelection: true,
    ),
  );
}

AcpFieldDescriptor _serviceRouteKey() {
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

AcpFieldDescriptor _locale() {
  return const AcpFieldDescriptor(
    key: 'Locale',
    label: 'Locale',
    options: acpBcp47LocaleOptions,
    searchableOptions: true,
    allowCustomOption: true,
  );
}

AcpFieldDescriptor _platform() {
  return _text('Platform', 'Platform', options: _platformOptions);
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
    maxLines: 6,
  );
}

AcpFieldDescriptor _bool(
  String key,
  String label, {
  required Object initialValue,
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
