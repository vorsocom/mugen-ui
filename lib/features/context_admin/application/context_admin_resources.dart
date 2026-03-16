import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

final List<AcpResourceDescriptor>
contextAdminResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'context-profiles',
    title: 'Profiles',
    entitySet: 'ContextProfiles',
    scopeMode: AcpScopeMode.required,
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
      _multiline('Description', 'Description', required: true),
      _text('Platform', 'Platform', required: true),
      _text('ChannelKey', 'Channel Key', required: true),
      _text('ServiceRouteKey', 'Service Route Key', required: true),
      _text('ClientProfileKey', 'Client Profile Key', required: true),
      _text('PolicyId', 'Policy ID', required: true),
      _multiline('Persona', 'Persona', required: true),
      _bool('IsActive', 'Is Active', initialValue: true),
      _bool('IsDefault', 'Is Default', initialValue: false),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _multiline('Description', 'Description'),
      _text('Platform', 'Platform'),
      _text('ChannelKey', 'Channel Key'),
      _text('ServiceRouteKey', 'Service Route Key'),
      _text('ClientProfileKey', 'Client Profile Key'),
      _text('PolicyId', 'Policy ID'),
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
      _text('ContributorKey', 'Contributor Key', required: true),
      _text('Platform', 'Platform', required: true),
      _text('ChannelKey', 'Channel Key', required: true),
      _text('ServiceRouteKey', 'Service Route Key', required: true),
      _int('Priority', 'Priority', required: true, initialValue: 0),
      _bool('IsEnabled', 'Is Enabled', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('Platform', 'Platform'),
      _text('ChannelKey', 'Channel Key'),
      _text('ServiceRouteKey', 'Service Route Key'),
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
      _text('SourceKind', 'Source Kind', required: true),
      _text('SourceKey', 'Source Key', required: true),
      _text('Platform', 'Platform', required: true),
      _text('ChannelKey', 'Channel Key', required: true),
      _text('ServiceRouteKey', 'Service Route Key', required: true),
      _text('Locale', 'Locale', required: true),
      _text('Category', 'Category', required: true),
      _bool('IsEnabled', 'Is Enabled', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('Platform', 'Platform'),
      _text('ChannelKey', 'Channel Key'),
      _text('ServiceRouteKey', 'Service Route Key'),
      _text('Locale', 'Locale'),
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

AcpFieldDescriptor _text(String key, String label, {bool required = false}) {
  return AcpFieldDescriptor(key: key, label: label, required: required);
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
