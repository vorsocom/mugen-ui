import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

final List<AcpResourceDescriptor>
knowledgePackAdminResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'knowledge-packs',
    title: 'Packs',
    entitySet: 'KnowledgePacks',
    scopeMode: AcpScopeMode.required,
    description:
        'Tenant-scoped knowledge-pack containers for approved response governance.',
    columns: <AcpColumnDescriptor>[
      _column('Key', 'Key'),
      _column('Name', 'Name'),
      _column('IsActive', 'Active'),
      _column('CurrentVersionId', 'Current Version'),
      _column('UpdatedAt', 'Updated'),
    ],
    createFields: <AcpFieldDescriptor>[
      _text('Key', 'Key', required: true),
      _text('Name', 'Name', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('Key', 'Key'),
      _text('Name', 'Name'),
      _multiline('Description', 'Description'),
      _bool('IsActive', 'Is Active', initialValue: true),
      _knowledgePackVersionId(
        key: 'CurrentVersionId',
        label: 'Current Version ID',
      ),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Key', 'Name', 'Description'],
    defaultOrderBy: 'IsActive desc, Key asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'knowledge-pack-versions',
    title: 'Versions',
    entitySet: 'KnowledgePackVersions',
    scopeMode: AcpScopeMode.required,
    description:
        'Draft, review, approved, published, and archived lifecycle records for knowledge packs.',
    columns: <AcpColumnDescriptor>[
      _column('VersionNumber', 'Version'),
      _column('Status', 'Status'),
      _column('KnowledgePackId', 'Pack'),
      _column('PublishedAt', 'Published'),
      _column('ArchivedAt', 'Archived'),
    ],
    createFields: <AcpFieldDescriptor>[
      _knowledgePackId(required: true),
      _int('VersionNumber', 'Version Number', required: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      _multiline('Note', 'Note'),
      _json('Attributes', 'Attributes'),
    ],
    entityActions: <AcpActionDescriptor>[
      _versionAction(
        name: 'submit_for_review',
        label: 'Submit for Review',
        confirmMessage: 'Submit this version for review?',
        successMessage: 'Knowledge pack version submitted for review.',
      ),
      _versionAction(
        name: 'approve',
        label: 'Approve',
        confirmMessage: 'Approve this version?',
        successMessage: 'Knowledge pack version approved.',
      ),
      _versionAction(
        name: 'reject',
        label: 'Reject',
        confirmMessage: 'Reject this version back to draft?',
        successMessage: 'Knowledge pack version rejected.',
        fields: <AcpFieldDescriptor>[
          _multiline('Reason', 'Reason'),
          _multiline('Note', 'Note'),
        ],
      ),
      _versionAction(
        name: 'publish',
        label: 'Publish',
        confirmMessage: 'Publish this version?',
        successMessage: 'Knowledge pack version published.',
      ),
      _versionAction(
        name: 'archive',
        label: 'Archive',
        confirmMessage: 'Archive this version?',
        successMessage: 'Knowledge pack version archived.',
        fields: <AcpFieldDescriptor>[
          _multiline('Reason', 'Reason'),
          _multiline('Note', 'Note'),
        ],
      ),
      _versionAction(
        name: 'rollback_version',
        label: 'Rollback Version',
        confirmMessage: 'Rollback publication to this version?',
        successMessage: 'Knowledge pack publication rolled back.',
      ),
    ],
    searchFields: const <String>['Status', 'Note'],
    defaultOrderBy: 'VersionNumber desc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'knowledge-entries',
    title: 'Entries',
    entitySet: 'KnowledgeEntries',
    scopeMode: AcpScopeMode.required,
    description: 'Knowledge items owned by a specific pack version.',
    columns: <AcpColumnDescriptor>[
      _column('EntryKey', 'Entry Key'),
      _column('Title', 'Title'),
      _column('KnowledgePackVersionId', 'Version'),
      _column('IsActive', 'Active'),
      _column('UpdatedAt', 'Updated'),
    ],
    createFields: <AcpFieldDescriptor>[
      _knowledgePackId(required: true),
      _knowledgePackVersionId(required: true),
      _text('EntryKey', 'Entry Key', required: true),
      _text('Title', 'Title', required: true),
      _multiline('Summary', 'Summary'),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text('EntryKey', 'Entry Key'),
      _text('Title', 'Title'),
      _multiline('Summary', 'Summary'),
      _bool('IsActive', 'Is Active', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['EntryKey', 'Title', 'Summary'],
    defaultOrderBy: 'IsActive desc, EntryKey asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'knowledge-entry-revisions',
    title: 'Entry Revisions',
    entitySet: 'KnowledgeEntryRevisions',
    scopeMode: AcpScopeMode.required,
    description:
        'Revision records containing publish-state-controlled entry content.',
    columns: <AcpColumnDescriptor>[
      _column('RevisionNumber', 'Revision'),
      _column('Status', 'Status'),
      _column('Channel', 'Channel'),
      _column('Locale', 'Locale'),
      _column('Category', 'Category'),
      _column('PublishedAt', 'Published'),
    ],
    createFields: <AcpFieldDescriptor>[
      _knowledgeEntryId(required: true),
      _knowledgePackVersionId(required: true),
      _int('RevisionNumber', 'Revision Number', required: true),
      _multiline('Body', 'Body'),
      _json('BodyJson', 'Body JSON', initialValue: null),
      _text('Channel', 'Channel'),
      _text('Locale', 'Locale'),
      _text('Category', 'Category'),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _multiline('Body', 'Body'),
      _json('BodyJson', 'Body JSON', initialValue: null),
      _text('Channel', 'Channel'),
      _text('Locale', 'Locale'),
      _text('Category', 'Category'),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Status', 'Channel', 'Locale', 'Category'],
    defaultOrderBy: 'RevisionNumber desc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'knowledge-approvals',
    title: 'Approvals',
    entitySet: 'KnowledgeApprovals',
    scopeMode: AcpScopeMode.required,
    description: 'Append-only governance approvals and publish decisions.',
    columns: <AcpColumnDescriptor>[
      _column('Action', 'Action'),
      _column('KnowledgePackVersionId', 'Version'),
      _column('KnowledgeEntryRevisionId', 'Entry Revision'),
      _column('ActorUserId', 'Actor'),
      _column('OccurredAt', 'Occurred'),
    ],
    searchFields: const <String>['Action', 'Note'],
    defaultOrderBy: 'OccurredAt desc',
    emptyMessage: 'No approvals found.',
  ),
  AcpResourceDescriptor(
    key: 'knowledge-scopes',
    title: 'Scopes',
    entitySet: 'KnowledgeScopes',
    scopeMode: AcpScopeMode.required,
    description:
        'Scoped retrieval constraints for knowledge-pack entry revisions.',
    columns: <AcpColumnDescriptor>[
      _column('Channel', 'Channel'),
      _column('Locale', 'Locale'),
      _column('Category', 'Category'),
      _column('ServiceRouteKey', 'Service Route'),
      _column('ClientProfileKey', 'Client Profile'),
      _column('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      _knowledgePackVersionId(required: true),
      _knowledgeEntryRevisionId(required: true),
      _text('Channel', 'Channel'),
      _text('Locale', 'Locale'),
      _text('Category', 'Category'),
      _text('ServiceRouteKey', 'Service Route Key'),
      _text('ClientProfileKey', 'Client Profile Key'),
      _bool('IsActive', 'Is Active', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _text(
        'KnowledgePackVersionId',
        'Knowledge Pack Version ID',
        readOnly: true,
      ),
      _text(
        'KnowledgeEntryRevisionId',
        'Knowledge Entry Revision ID',
        readOnly: true,
      ),
      _text('Channel', 'Channel'),
      _text('Locale', 'Locale'),
      _text('Category', 'Category'),
      _text('ServiceRouteKey', 'Service Route Key'),
      _text('ClientProfileKey', 'Client Profile Key'),
      _bool('IsActive', 'Is Active', initialValue: true),
      _json('Attributes', 'Attributes'),
    ],
    searchFields: const <String>[
      'Channel',
      'Locale',
      'Category',
      'ServiceRouteKey',
      'ClientProfileKey',
    ],
    defaultOrderBy: 'IsActive desc, Channel asc, Locale asc, Category asc',
    allowCreate: true,
    allowUpdate: true,
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

AcpFieldDescriptor _knowledgePackId({bool required = false}) {
  return AcpFieldDescriptor(
    key: 'KnowledgePackId',
    label: 'Knowledge Pack ID',
    required: required,
    hintText: 'Search knowledge packs in this tenant',
    reference: const AcpFieldReferenceDescriptor(
      entitySet: 'KnowledgePacks',
      scopeMode: AcpScopeMode.required,
      title: 'Knowledge Packs',
      searchFields: <String>['Key', 'Name', 'Description'],
      titleFields: <String>['Name', 'Key', 'Id'],
      subtitleFields: <String>['Key', 'IsActive', 'CurrentVersionId', 'Id'],
      defaultOrderBy: 'IsActive desc, Key asc',
    ),
  );
}

AcpFieldDescriptor _knowledgePackVersionId({
  String key = 'KnowledgePackVersionId',
  String label = 'Knowledge Pack Version ID',
  bool required = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    required: required,
    hintText: 'Search knowledge pack versions in this tenant',
    reference: const AcpFieldReferenceDescriptor(
      entitySet: 'KnowledgePackVersions',
      scopeMode: AcpScopeMode.required,
      title: 'Knowledge Pack Versions',
      searchFields: <String>['Status', 'Note'],
      titleFields: <String>['VersionNumber', 'Status', 'Id'],
      subtitleFields: <String>[
        'KnowledgePackId',
        'Status',
        'PublishedAt',
        'Id',
      ],
      defaultOrderBy: 'VersionNumber desc',
    ),
  );
}

AcpFieldDescriptor _knowledgeEntryId({bool required = false}) {
  return AcpFieldDescriptor(
    key: 'KnowledgeEntryId',
    label: 'Knowledge Entry ID',
    required: required,
    hintText: 'Search knowledge entries in this tenant',
    reference: const AcpFieldReferenceDescriptor(
      entitySet: 'KnowledgeEntries',
      scopeMode: AcpScopeMode.required,
      title: 'Knowledge Entries',
      searchFields: <String>['EntryKey', 'Title', 'Summary'],
      titleFields: <String>['Title', 'EntryKey', 'Id'],
      subtitleFields: <String>[
        'EntryKey',
        'KnowledgePackVersionId',
        'IsActive',
        'Id',
      ],
      defaultOrderBy: 'IsActive desc, EntryKey asc',
    ),
  );
}

AcpFieldDescriptor _knowledgeEntryRevisionId({bool required = false}) {
  return AcpFieldDescriptor(
    key: 'KnowledgeEntryRevisionId',
    label: 'Knowledge Entry Revision ID',
    required: required,
    hintText: 'Search knowledge entry revisions in this tenant',
    reference: const AcpFieldReferenceDescriptor(
      entitySet: 'KnowledgeEntryRevisions',
      scopeMode: AcpScopeMode.required,
      title: 'Knowledge Entry Revisions',
      searchFields: <String>['Status', 'Channel', 'Locale', 'Category'],
      titleFields: <String>['RevisionNumber', 'Status', 'Id'],
      subtitleFields: <String>[
        'KnowledgeEntryId',
        'KnowledgePackVersionId',
        'Channel',
        'Locale',
        'Category',
        'Id',
      ],
      defaultOrderBy: 'RevisionNumber desc',
    ),
  );
}

AcpActionDescriptor _versionAction({
  required String name,
  required String label,
  required String confirmMessage,
  required String successMessage,
  List<AcpFieldDescriptor> fields = const <AcpFieldDescriptor>[
    AcpFieldDescriptor(
      key: 'Note',
      label: 'Note',
      kind: AcpFieldKind.multiline,
      minLines: 3,
      maxLines: 6,
    ),
  ],
}) {
  return AcpActionDescriptor(
    name: name,
    label: label,
    target: AcpActionTarget.entity,
    includeRowVersion: true,
    confirmMessage: confirmMessage,
    successMessage: successMessage,
    fields: fields,
  );
}
