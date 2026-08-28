import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_standard_options.dart';

final List<AcpResourceDescriptor>
knowledgePackAdminResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'knowledge-packs',
    title: 'Packs',
    entitySet: 'KnowledgePacks',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Tenant-scoped knowledge-pack containers for approved response governance.',
    columns: <AcpColumnDescriptor>[
      _column('Key', 'Key'),
      _column('Name', 'Name'),
      _column('IsActive', 'Active'),
      _column(
        'CurrentVersionId',
        'Current Version',
        reference: _currentVersionDisplay,
      ),
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
    expansions: const <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'CurrentVersion',
        selectFields: <String>['VersionNumber', 'Status'],
      ),
    ],
  ),
  AcpResourceDescriptor(
    key: 'knowledge-pack-versions',
    title: 'Versions',
    entitySet: 'KnowledgePackVersions',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Draft, review, approved, published, and archived lifecycle records for knowledge packs.',
    columns: <AcpColumnDescriptor>[
      _column('VersionNumber', 'Version'),
      _column('Status', 'Status'),
      _column('KnowledgePackId', 'Pack', reference: _knowledgePackDisplay),
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
    expansions: const <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'KnowledgePack',
        selectFields: <String>['Name', 'Key'],
      ),
    ],
  ),
  AcpResourceDescriptor(
    key: 'knowledge-entries',
    title: 'Entries',
    entitySet: 'KnowledgeEntries',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description: 'Knowledge items owned by a specific pack version.',
    columns: <AcpColumnDescriptor>[
      _column('EntryKey', 'Entry Key'),
      _column('Title', 'Title'),
      _column(
        'KnowledgePackVersionId',
        'Version',
        reference: _knowledgeVersionDisplay('KnowledgePackVersion'),
      ),
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
    expansions: const <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'KnowledgePackVersion',
        selectFields: <String>['VersionNumber', 'Status'],
        expands: <AcpExpandDescriptor>[
          AcpExpandDescriptor(
            navigation: 'KnowledgePack',
            selectFields: <String>['Name', 'Key'],
          ),
        ],
      ),
    ],
  ),
  AcpResourceDescriptor(
    key: 'knowledge-entry-revisions',
    title: 'Entry Revisions',
    entitySet: 'KnowledgeEntryRevisions',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
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
      _channel(),
      _locale(),
      _text('Category', 'Category'),
      _json('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      _multiline('Body', 'Body'),
      _json('BodyJson', 'Body JSON', initialValue: null),
      _channel(),
      _locale(),
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
    keyLiteralType: AcpFilterLiteralType.guid,
    description: 'Append-only governance approvals and publish decisions.',
    columns: <AcpColumnDescriptor>[
      _column('Action', 'Action'),
      _column(
        'KnowledgePackVersionId',
        'Version',
        reference: _knowledgeVersionDisplay('KnowledgePackVersion'),
      ),
      _column(
        'KnowledgeEntryRevisionId',
        'Entry Revision',
        reference: _entryRevisionDisplay,
      ),
      _column('ActorUserId', 'Actor', reference: _actorUserDisplay),
      _column('OccurredAt', 'Occurred'),
    ],
    searchFields: const <String>['Action', 'Note'],
    defaultOrderBy: 'OccurredAt desc',
    emptyMessage: 'No approvals found.',
    expansions: const <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'KnowledgePackVersion',
        selectFields: <String>['VersionNumber', 'Status'],
        expands: <AcpExpandDescriptor>[
          AcpExpandDescriptor(
            navigation: 'KnowledgePack',
            selectFields: <String>['Name', 'Key'],
          ),
        ],
      ),
      AcpExpandDescriptor(
        navigation: 'KnowledgeEntryRevision',
        selectFields: <String>['RevisionNumber', 'Status'],
        expands: <AcpExpandDescriptor>[
          AcpExpandDescriptor(
            navigation: 'KnowledgeEntry',
            selectFields: <String>['Title', 'EntryKey'],
          ),
        ],
      ),
    ],
  ),
  AcpResourceDescriptor(
    key: 'knowledge-scopes',
    title: 'Scopes',
    entitySet: 'KnowledgeScopes',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
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
      _channel(),
      _locale(),
      _text('Category', 'Category'),
      _serviceRouteKey(),
      _clientProfileKey(),
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
      _channel(),
      _locale(),
      _text('Category', 'Category'),
      _serviceRouteKey(),
      _clientProfileKey(),
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

const AcpColumnReferenceDescriptor _currentVersionDisplay =
    AcpColumnReferenceDescriptor(
      navigationPath: 'CurrentVersion',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('VersionNumber', prefix: 'v'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Status'),
      ],
    );

const AcpColumnReferenceDescriptor _knowledgePackDisplay =
    AcpColumnReferenceDescriptor(
      navigationPath: 'KnowledgePack',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Name'),
        AcpReferenceFieldDescriptor('Key'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Key'),
      ],
    );

AcpColumnReferenceDescriptor _knowledgeVersionDisplay(String navigationPath) {
  return AcpColumnReferenceDescriptor(
    navigationPath: navigationPath,
    titleFields: const <AcpReferenceFieldDescriptor>[
      AcpReferenceFieldDescriptor('KnowledgePack.Name'),
      AcpReferenceFieldDescriptor('KnowledgePack.Key'),
      AcpReferenceFieldDescriptor('VersionNumber', prefix: 'v'),
    ],
    subtitleFields: const <AcpReferenceFieldDescriptor>[
      AcpReferenceFieldDescriptor('VersionNumber', prefix: 'v'),
      AcpReferenceFieldDescriptor('Status'),
    ],
  );
}

const AcpColumnReferenceDescriptor _entryRevisionDisplay =
    AcpColumnReferenceDescriptor(
      navigationPath: 'KnowledgeEntryRevision',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('KnowledgeEntry.Title'),
        AcpReferenceFieldDescriptor('KnowledgeEntry.EntryKey'),
        AcpReferenceFieldDescriptor('RevisionNumber', prefix: 'r'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('RevisionNumber', prefix: 'r'),
        AcpReferenceFieldDescriptor('Status'),
      ],
    );

const AcpColumnReferenceDescriptor _actorUserDisplay =
    AcpColumnReferenceDescriptor(
      navigationPath: 'ActorUser',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('LoginEmail'),
        AcpReferenceFieldDescriptor('Username'),
      ],
      batchLookup: AcpBatchReferenceDescriptor(
        entitySet: 'Users',
        scopeMode: AcpScopeMode.none,
        selectFields: <String>['LoginEmail', 'Username'],
        literalType: AcpFilterLiteralType.guid,
        deletedView: AcpDeletedView.all,
      ),
    );

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

AcpFieldDescriptor _channel() {
  return const AcpFieldDescriptor(
    key: 'Channel',
    label: 'Channel',
    options: acpMessagingPlatformOptions,
    searchableOptions: true,
    allowCustomOption: true,
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
