import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

final List<AcpResourceDescriptor> acpConsoleResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'schemas',
    title: 'Schemas',
    entitySet: 'Schemas',
    scopeMode: AcpScopeMode.optional,
    description:
        'Schema registry definitions for validating and coercing ACP payload contracts.',
    columns: <AcpColumnDescriptor>[
      _column('Key', 'Key'),
      _column('Version', 'Version'),
      _column('Title', 'Title'),
      _column('SchemaKind', 'Kind'),
      _column('Status', 'Status'),
      _column('ActivatedAt', 'Activated'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('Key', 'Key', required: true),
      _int('Version', 'Version', required: true),
      _text('Title', 'Title'),
      _multiline('Description', 'Description'),
      _schemaKind(),
      _json('SchemaJson', 'Schema JSON', required: true),
      _schemaStatus(initialValue: 'draft'),
      _dateTime('ActivatedAt', 'Activated At'),
      _text('ActivatedByUserId', 'Activated By User ID'),
      _text('ChecksumSha256', 'Checksum SHA-256'),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('Title', 'Title'),
      _multiline('Description', 'Description'),
      _schemaKind(),
      _schemaStatus(),
      _dateTime('ActivatedAt', 'Activated At'),
      _text('ActivatedByUserId', 'Activated By User ID'),
      _text('ChecksumSha256', 'Checksum SHA-256'),
      _json('Attributes', 'Attributes'),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'validate',
        label: 'Validate',
        target: AcpActionTarget.collection,
        successMessage: 'Validation completed.',
        fields: <AcpFieldDescriptor>[
          _text('SchemaDefinitionId', 'Schema Definition ID'),
          _text('Key', 'Key'),
          _int('Version', 'Version'),
          _json('Payload', 'Payload', required: true, initialValue: const {}),
        ],
      ),
      AcpActionDescriptor(
        name: 'coerce',
        label: 'Coerce',
        target: AcpActionTarget.collection,
        successMessage: 'Coercion completed.',
        fields: <AcpFieldDescriptor>[
          _text('SchemaDefinitionId', 'Schema Definition ID'),
          _text('Key', 'Key'),
          _int('Version', 'Version'),
          _json('Payload', 'Payload', required: true, initialValue: const {}),
        ],
      ),
      AcpActionDescriptor(
        name: 'activate_version',
        label: 'Activate Version',
        target: AcpActionTarget.collection,
        successMessage: 'Schema version activated.',
        fields: <AcpFieldDescriptor>[
          _text('Key', 'Key', required: true),
          _int('Version', 'Version', required: true),
        ],
      ),
    ],
    searchFields: const <String>['Key', 'Title', 'Status'],
    defaultOrderBy: 'Key asc, Version desc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'schema-bindings',
    title: 'Schema Bindings',
    entitySet: 'SchemaBindings',
    scopeMode: AcpScopeMode.optional,
    description:
        'Schema binding contracts targeting ACP resources or resource actions.',
    columns: <AcpColumnDescriptor>[
      _column('TargetNamespace', 'Namespace'),
      _column('TargetEntitySet', 'Entity Set'),
      _column('TargetAction', 'Action'),
      _column('BindingKind', 'Binding Kind'),
      _column('IsRequired', 'Required'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('SchemaDefinitionId', 'Schema Definition ID', required: true),
      _text('TargetNamespace', 'Target Namespace', required: true),
      _text('TargetEntitySet', 'Target Entity Set', required: true),
      _text('TargetAction', 'Target Action'),
      _text('BindingKind', 'Binding Kind', required: true),
      _bool('IsRequired', 'Is Required', initialValue: true),
      _bool('IsActive', 'Is Active', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('TargetAction', 'Target Action'),
      _bool('IsRequired', 'Is Required', initialValue: true),
      _bool('IsActive', 'Is Active', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>[
      'TargetNamespace',
      'TargetEntitySet',
      'TargetAction',
      'BindingKind',
    ],
    defaultOrderBy: 'TargetNamespace asc, TargetEntitySet asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'plugin-capability-grants',
    title: 'Plugin Capability Grants',
    entitySet: 'PluginCapabilityGrants',
    scopeMode: AcpScopeMode.optional,
    description:
        'Runtime capability grants evaluated by ACP sandbox enforcement.',
    columns: <AcpColumnDescriptor>[
      _column('PluginKey', 'Plugin Key'),
      _column('Capabilities', 'Capabilities'),
      _column('GrantedAt', 'Granted'),
      _column('ExpiresAt', 'Expires'),
      _column('RevokedAt', 'Revoked'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('PluginKey', 'Plugin Key', required: true),
      _json(
        'Capabilities',
        'Capabilities',
        required: true,
        initialValue: const [],
      ),
      _dateTime('ExpiresAt', 'Expires At'),
      _json('Attributes', 'Attributes'),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'grant',
        label: 'Grant',
        target: AcpActionTarget.collection,
        successMessage: 'Capability grant recorded.',
        fields: <AcpFieldDescriptor>[
          _text('PluginKey', 'Plugin Key', required: true),
          _json(
            'Capabilities',
            'Capabilities',
            required: true,
            initialValue: const [],
          ),
          _dateTime('ExpiresAt', 'Expires At'),
          _json('Attributes', 'Attributes'),
        ],
      ),
    ],
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'revoke',
        label: 'Revoke',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Revoke this capability grant?',
        successMessage: 'Capability grant revoked.',
        fields: <AcpFieldDescriptor>[_multiline('Reason', 'Reason')],
      ),
    ],
    searchFields: const <String>['PluginKey'],
    defaultOrderBy: 'GrantedAt desc',
    allowCreate: true,
  ),
  AcpResourceDescriptor(
    key: 'dedup-records',
    title: 'Dedup Records',
    entitySet: 'DedupRecords',
    scopeMode: AcpScopeMode.none,
    description: 'Shared idempotency ledger for ACP create/action requests.',
    columns: <AcpColumnDescriptor>[
      _column('Scope', 'Scope'),
      _column('IdempotencyKey', 'Idempotency Key'),
      _column('Status', 'Status'),
      _column('ResponseCode', 'Response'),
      _column('OwnerInstance', 'Owner'),
      _column('ExpiresAt', 'Expires'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('Scope', 'Scope', required: true),
      _text('IdempotencyKey', 'Idempotency Key', required: true),
      _text('RequestHash', 'Request Hash'),
      _dedupStatus(initialValue: 'in_progress'),
      _text('ResultRef', 'Result Ref'),
      _int('ResponseCode', 'Response Code'),
      _json('ResponsePayload', 'Response Payload'),
      _text('ErrorCode', 'Error Code'),
      _multiline('ErrorMessage', 'Error Message'),
      _text('OwnerInstance', 'Owner Instance'),
      _dateTime('LeaseExpiresAt', 'Lease Expires At'),
      _dateTime('ExpiresAt', 'Expires At', required: true),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'acquire',
        label: 'Acquire',
        target: AcpActionTarget.collection,
        successMessage: 'Acquire completed.',
        fields: <AcpFieldDescriptor>[
          _text('Scope', 'Scope', required: true),
          _text('IdempotencyKey', 'Idempotency Key', required: true),
          _text('RequestHash', 'Request Hash'),
          _text('OwnerInstance', 'Owner Instance'),
          _int('TtlSeconds', 'TTL Seconds'),
          _int('LeaseSeconds', 'Lease Seconds'),
        ],
      ),
      AcpActionDescriptor(
        name: 'sweep_expired',
        label: 'Sweep Expired',
        target: AcpActionTarget.collection,
        successMessage: 'Sweep completed.',
        fields: <AcpFieldDescriptor>[_int('BatchSize', 'Batch Size')],
      ),
    ],
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'commit_success',
        label: 'Commit Success',
        target: AcpActionTarget.entity,
        successMessage: 'Success result committed.',
        fields: <AcpFieldDescriptor>[
          _int('ResponseCode', 'Response Code', initialValue: 200),
          _json('ResponsePayload', 'Response Payload'),
          _text('ResultRef', 'Result Ref'),
          _int('TtlSeconds', 'TTL Seconds'),
        ],
      ),
      AcpActionDescriptor(
        name: 'commit_failure',
        label: 'Commit Failure',
        target: AcpActionTarget.entity,
        successMessage: 'Failure result committed.',
        fields: <AcpFieldDescriptor>[
          _int('ResponseCode', 'Response Code', initialValue: 500),
          _json('ResponsePayload', 'Response Payload'),
          _text('ErrorCode', 'Error Code'),
          _multiline('ErrorMessage', 'Error Message'),
          _int('TtlSeconds', 'TTL Seconds'),
        ],
      ),
    ],
    searchFields: const <String>['Scope', 'IdempotencyKey', 'Status'],
    defaultOrderBy: 'CreatedAt desc',
    allowCreate: true,
  ),
  AcpResourceDescriptor(
    key: 'evidence-blobs',
    title: 'Evidence Blobs',
    entitySet: 'EvidenceBlobs',
    scopeMode: AcpScopeMode.optional,
    description:
        'Metadata-first evidence records with hash verification and lifecycle controls.',
    columns: <AcpColumnDescriptor>[
      _column('TraceId', 'Trace ID'),
      _column('SourcePlugin', 'Source Plugin'),
      _column('SubjectNamespace', 'Subject Namespace'),
      _column('StorageUri', 'Storage URI'),
      _column('VerificationStatus', 'Verification'),
      _column('RetentionUntil', 'Retention Until'),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'register',
        label: 'Register',
        target: AcpActionTarget.collection,
        successMessage: 'Evidence registered.',
        fields: <AcpFieldDescriptor>[
          _text('TraceId', 'Trace ID'),
          _text('SourcePlugin', 'Source Plugin'),
          _text('SubjectNamespace', 'Subject Namespace'),
          _text('SubjectId', 'Subject ID'),
          _text('StorageUri', 'Storage URI', required: true),
          _text('ContentHash', 'Content Hash', required: true),
          _hashAlgorithm('HashAlg', 'Hash Algorithm'),
          _int('ContentLength', 'Content Length'),
          _immutability(),
          _dateTime('RetentionUntil', 'Retention Until'),
          _dateTime('RedactionDueAt', 'Redaction Due At'),
          _json('Meta', 'Meta'),
        ],
      ),
    ],
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'verify_hash',
        label: 'Verify Hash',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        successMessage: 'Hash verification completed.',
        fields: <AcpFieldDescriptor>[
          _text('ObservedHash', 'Observed Hash', required: true),
          _hashAlgorithm('ObservedHashAlg', 'Observed Hash Algorithm'),
        ],
      ),
      AcpActionDescriptor(
        name: 'place_legal_hold',
        label: 'Place Legal Hold',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        successMessage: 'Legal hold placed.',
        fields: <AcpFieldDescriptor>[
          _multiline('Reason', 'Reason', required: true),
          _dateTime('LegalHoldUntil', 'Legal Hold Until'),
        ],
      ),
      AcpActionDescriptor(
        name: 'release_legal_hold',
        label: 'Release Legal Hold',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        successMessage: 'Legal hold released.',
        fields: <AcpFieldDescriptor>[
          _multiline('Reason', 'Reason', required: true),
        ],
      ),
      AcpActionDescriptor(
        name: 'redact',
        label: 'Redact',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        successMessage: 'Evidence redacted.',
        fields: <AcpFieldDescriptor>[
          _multiline('Reason', 'Reason', required: true),
        ],
      ),
      AcpActionDescriptor(
        name: 'tombstone',
        label: 'Tombstone',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        successMessage: 'Evidence tombstoned.',
        fields: <AcpFieldDescriptor>[
          _multiline('Reason', 'Reason', required: true),
          _int('PurgeAfterDays', 'Purge After Days'),
        ],
      ),
      AcpActionDescriptor(
        name: 'purge',
        label: 'Purge',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        successMessage: 'Evidence marked as purged.',
        fields: <AcpFieldDescriptor>[
          _multiline('Reason', 'Reason', required: true),
        ],
      ),
    ],
    searchFields: const <String>[
      'TraceId',
      'SourcePlugin',
      'SubjectNamespace',
      'StorageUri',
      'VerificationStatus',
    ],
    defaultOrderBy: 'CreatedAt desc',
  ),
  AcpResourceDescriptor(
    key: 'audit-correlation-links',
    title: 'Audit Correlation Links',
    entitySet: 'AuditCorrelationLinks',
    scopeMode: AcpScopeMode.optional,
    description:
        'Resolved trace and correlation graph edges emitted from ACP request handling.',
    columns: <AcpColumnDescriptor>[
      _column('OccurredAt', 'Occurred'),
      _column('TraceId', 'Trace ID'),
      _column('CorrelationId', 'Correlation ID'),
      _column('EntitySet', 'Entity Set'),
      _column('Operation', 'Operation'),
      _column('ActionName', 'Action'),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'resolve_trace',
        label: 'Resolve Trace',
        target: AcpActionTarget.collection,
        successMessage: 'Trace resolution completed.',
        fields: <AcpFieldDescriptor>[
          _text('TraceId', 'Trace ID'),
          _text('CorrelationId', 'Correlation ID'),
          _text('RequestId', 'Request ID'),
          _int('MaxRows', 'Max Rows'),
        ],
      ),
    ],
    searchFields: const <String>[
      'TraceId',
      'CorrelationId',
      'RequestId',
      'EntitySet',
      'Operation',
      'ActionName',
    ],
    defaultOrderBy: 'OccurredAt desc',
  ),
  AcpResourceDescriptor(
    key: 'audit-biz-trace-events',
    title: 'Audit Biz Trace Events',
    entitySet: 'AuditBizTraceEvents',
    scopeMode: AcpScopeMode.optional,
    description:
        'Business-trace observability timeline events emitted for ACP handlers.',
    columns: <AcpColumnDescriptor>[
      _column('OccurredAt', 'Occurred'),
      _column('TraceId', 'Trace ID'),
      _column('Stage', 'Stage'),
      _column('StatusCode', 'Status'),
      _column('SourcePlugin', 'Source Plugin'),
      _column('EntitySet', 'Entity Set'),
    ],
    collectionActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'inspect_trace',
        label: 'Inspect Trace',
        target: AcpActionTarget.collection,
        successMessage: 'Trace inspection completed.',
        fields: <AcpFieldDescriptor>[
          _text('TraceId', 'Trace ID'),
          _text('CorrelationId', 'Correlation ID'),
          _text('RequestId', 'Request ID'),
          _text('Stage', 'Stage'),
          _int('MaxRows', 'Max Rows'),
        ],
      ),
    ],
    searchFields: const <String>[
      'TraceId',
      'CorrelationId',
      'RequestId',
      'Stage',
      'SourcePlugin',
      'EntitySet',
    ],
    defaultOrderBy: 'OccurredAt desc',
  ),
];

AcpColumnDescriptor _column(String key, String label) {
  return AcpColumnDescriptor(key: key, label: label);
}

const List<String> _schemaKindOptions = <String>['json_schema'];
const List<String> _schemaStatusOptions = <String>[
  'draft',
  'active',
  'inactive',
];
const List<String> _dedupStatusOptions = <String>[
  'in_progress',
  'succeeded',
  'failed',
];
const List<String> _hashAlgorithmOptions = <String>['sha256'];
const List<String> _immutabilityOptions = <String>['immutable'];

AcpFieldDescriptor _text(
  String key,
  String label, {
  bool required = false,
  Object? initialValue,
  List<String> options = const <String>[],
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    required: required,
    initialValue: initialValue,
    options: options,
  );
}

AcpFieldDescriptor _schemaKind() {
  return _text(
    'SchemaKind',
    'Schema Kind',
    initialValue: 'json_schema',
    options: _schemaKindOptions,
  );
}

AcpFieldDescriptor _schemaStatus({Object? initialValue}) {
  return _text(
    'Status',
    'Status',
    initialValue: initialValue,
    options: _schemaStatusOptions,
  );
}

AcpFieldDescriptor _dedupStatus({Object? initialValue}) {
  return _text(
    'Status',
    'Status',
    initialValue: initialValue,
    options: _dedupStatusOptions,
  );
}

AcpFieldDescriptor _hashAlgorithm(String key, String label) {
  return _text(
    key,
    label,
    initialValue: 'sha256',
    options: _hashAlgorithmOptions,
  );
}

AcpFieldDescriptor _immutability() {
  return _text(
    'Immutability',
    'Immutability',
    initialValue: 'immutable',
    options: _immutabilityOptions,
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

AcpFieldDescriptor _dateTime(
  String key,
  String label, {
  bool required = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.dateTime,
    required: required,
  );
}

AcpFieldDescriptor _json(
  String key,
  String label, {
  bool required = false,
  Object? initialValue = const <String, dynamic>{},
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.json,
    required: required,
    minLines: 6,
    maxLines: 10,
    initialValue: initialValue,
  );
}
