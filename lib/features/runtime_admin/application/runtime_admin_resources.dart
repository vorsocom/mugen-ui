import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

final List<AcpResourceDescriptor>
runtimeAdminResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'messaging-client-profiles',
    title: 'Messaging Client Profiles',
    entitySet: 'MessagingClientProfiles',
    scopeMode: AcpScopeMode.optional,
    description:
        'Messaging transport client accounts, webhook identifiers, and secret references.',
    columns: <AcpColumnDescriptor>[
      _column('PlatformKey', 'Platform'),
      _column('ProfileKey', 'Profile Key'),
      _column('DisplayName', 'Display Name'),
      _column('Provider', 'Provider'),
      _column('PathToken', 'Path Token'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text(
        'PlatformKey',
        'Platform Key',
        required: true,
        submitEmptyValueWhenBlank: true,
      ),
      _text(
        'ProfileKey',
        'Profile Key',
        required: true,
        submitEmptyValueWhenBlank: true,
      ),
      _text('DisplayName', 'Display Name', submitEmptyValueWhenBlank: true),
      _bool('IsActive', 'Is Active', initialValue: true),
      _json('Settings', 'Settings'),
      _json('SecretRefs', 'Secret References'),
      _text(
        'PathToken',
        'Path Token',
        submitEmptyValueWhenBlank: true,
        requiredWhenEquals: <String, List<String>>{
          'PlatformKey': <String>['line', 'telegram', 'wechat', 'whatsapp'],
        },
      ),
      _text(
        'RecipientUserId',
        'Recipient User ID',
        submitEmptyValueWhenBlank: true,
        requiredWhenEquals: <String, List<String>>{
          'PlatformKey': <String>['matrix'],
        },
      ),
      _text(
        'AccountNumber',
        'Account Number',
        submitEmptyValueWhenBlank: true,
        requiredWhenEquals: <String, List<String>>{
          'PlatformKey': <String>['signal'],
        },
      ),
      _text(
        'PhoneNumberId',
        'Phone Number ID',
        submitEmptyValueWhenBlank: true,
        requiredWhenEquals: <String, List<String>>{
          'PlatformKey': <String>['whatsapp'],
        },
      ),
      _text(
        'Provider',
        'Provider',
        submitEmptyValueWhenBlank: true,
        requiredWhenEquals: <String, List<String>>{
          'PlatformKey': <String>['wechat'],
        },
      ),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('PlatformKey', 'Platform Key'),
      _text('ProfileKey', 'Profile Key'),
      _text('DisplayName', 'Display Name'),
      _bool('IsActive', 'Is Active'),
      _json('Settings', 'Settings'),
      _json('SecretRefs', 'Secret References'),
      _text('PathToken', 'Path Token'),
      _text('RecipientUserId', 'Recipient User ID'),
      _text('AccountNumber', 'Account Number'),
      _text('PhoneNumberId', 'Phone Number ID'),
      _text('Provider', 'Provider'),
    ],
    searchFields: const <String>[
      'PlatformKey',
      'ProfileKey',
      'DisplayName',
      'Provider',
      'PathToken',
    ],
    defaultOrderBy: 'PlatformKey asc, ProfileKey asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'runtime-config-profiles',
    title: 'Runtime Config Profiles',
    entitySet: 'RuntimeConfigProfiles',
    scopeMode: AcpScopeMode.optional,
    description:
        'Non-secret runtime configuration overlays for messaging and operational defaults.',
    columns: <AcpColumnDescriptor>[
      _column('Category', 'Category'),
      _column('ProfileKey', 'Profile Key'),
      _column('DisplayName', 'Display Name'),
      _column('IsActive', 'Active'),
      _column('UpdatedAt', 'Updated'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('Category', 'Category', required: true),
      _text('ProfileKey', 'Profile Key', required: true),
      _text('DisplayName', 'Display Name', required: true),
      _bool('IsActive', 'Is Active', initialValue: true),
      _json('SettingsJson', 'Settings JSON', required: true),
      _json('Attributes', 'Attributes', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('Category', 'Category'),
      _text('ProfileKey', 'Profile Key'),
      _text('DisplayName', 'Display Name'),
      _bool('IsActive', 'Is Active'),
      _json('SettingsJson', 'Settings JSON'),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Category', 'ProfileKey', 'DisplayName'],
    defaultOrderBy: 'Category asc, ProfileKey asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'key-refs',
    title: 'Key References',
    entitySet: 'KeyRefs',
    scopeMode: AcpScopeMode.optional,
    description:
        'Managed key-reference metadata for runtime secret rotation and lifecycle actions.',
    columns: <AcpColumnDescriptor>[
      _column('Purpose', 'Purpose'),
      _column('KeyId', 'Key ID'),
      _column('Provider', 'Provider'),
      _column('Status', 'Status'),
      _column('HasMaterial', 'Has Material'),
      _column('ActivatedAt', 'Activated'),
      _column('RetiredAt', 'Retired'),
      _column('DestroyedAt', 'Destroyed'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('Purpose', 'Purpose', required: true),
      _text('KeyId', 'Key ID', required: true),
      _text('Provider', 'Provider', initialValue: 'local'),
      _text('Status', 'Status', initialValue: 'active'),
      _json('Attributes', 'Attributes'),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'rotate',
        label: 'Rotate',
        target: AcpActionTarget.collection,
        confirmMessage: 'Rotate key material for this purpose/key pair?',
        successMessage: 'Key rotation completed.',
        fields: <AcpFieldDescriptor>[
          _text('Purpose', 'Purpose', required: true),
          _text('KeyId', 'Key ID', required: true),
          _text('Provider', 'Provider', initialValue: 'local'),
          _text('SecretValue', 'Secret Value', obscureText: true),
          _json('Attributes', 'Attributes'),
        ],
      ),
    ],
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'retire',
        label: 'Retire',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Retire this key reference?',
        successMessage: 'Key retired.',
        fields: <AcpFieldDescriptor>[_multiline('Reason', 'Reason')],
      ),
      AcpActionDescriptor(
        name: 'destroy',
        label: 'Destroy',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Destroy this key reference?',
        successMessage: 'Key destroyed.',
        fields: <AcpFieldDescriptor>[_multiline('Reason', 'Reason')],
      ),
    ],
    searchFields: const <String>['Purpose', 'KeyId', 'Provider', 'Status'],
    defaultOrderBy: 'Purpose asc, ActivatedAt desc',
    allowCreate: true,
  ),
  AcpResourceDescriptor(
    key: 'system-flags',
    title: 'System Flags',
    entitySet: 'SystemFlags',
    scopeMode: AcpScopeMode.none,
    description:
        'System-wide feature flags and runtime reload controls. The current backend exposes read/list plus reload action.',
    columns: <AcpColumnDescriptor>[
      _column('Namespace', 'Namespace'),
      _column('Name', 'Name'),
      _column('Description', 'Description'),
      _column('IsSet', 'Is Set'),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'reloadPlatformProfiles',
        label: 'Reload Platform Profiles',
        target: AcpActionTarget.collection,
        confirmMessage: 'Reload live runtime platform profiles now?',
        successMessage: 'Platform profiles reloaded.',
      ),
    ],
    searchFields: const <String>['Namespace', 'Name', 'Description'],
    defaultOrderBy: 'Namespace asc, Name asc',
  ),
];

AcpColumnDescriptor _column(String key, String label) {
  return AcpColumnDescriptor(key: key, label: label);
}

AcpFieldDescriptor _text(
  String key,
  String label, {
  bool required = false,
  Map<String, List<String>> requiredWhenEquals = const <String, List<String>>{},
  bool submitEmptyValueWhenBlank = false,
  String? hintText,
  bool obscureText = false,
  Object? initialValue,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    required: required,
    requiredWhenEquals: requiredWhenEquals,
    submitEmptyValueWhenBlank: submitEmptyValueWhenBlank,
    hintText: hintText,
    obscureText: obscureText,
    initialValue: initialValue,
  );
}

AcpFieldDescriptor _multiline(
  String key,
  String label, {
  bool required = false,
  Map<String, List<String>> requiredWhenEquals = const <String, List<String>>{},
  bool submitEmptyValueWhenBlank = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.multiline,
    required: required,
    requiredWhenEquals: requiredWhenEquals,
    submitEmptyValueWhenBlank: submitEmptyValueWhenBlank,
    minLines: 3,
    maxLines: 5,
  );
}

AcpFieldDescriptor _bool(String key, String label, {Object? initialValue}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.boolean,
    initialValue: initialValue,
  );
}

AcpFieldDescriptor _json(
  String key,
  String label, {
  bool required = false,
  Map<String, List<String>> requiredWhenEquals = const <String, List<String>>{},
  bool submitEmptyValueWhenBlank = false,
  Object? initialValue = const <String, dynamic>{},
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.json,
    required: required,
    requiredWhenEquals: requiredWhenEquals,
    submitEmptyValueWhenBlank: submitEmptyValueWhenBlank,
    minLines: 6,
    maxLines: 10,
    initialValue: initialValue,
  );
}
