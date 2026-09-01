import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_standard_options.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_projection_status.dart';

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
        'Relational Version',
        reference: _currentVersionDisplay,
      ),
      _column('Searchability', 'Searchability'),
      _column('PendingReplacement', 'Pending Replacement'),
      _column('ProjectionAttention', 'Attention'),
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
        selectFields: <String>['Id', 'VersionNumber', 'Status'],
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
        'Version lifecycle and active-gateway search projection readiness for knowledge packs.',
    columns: <AcpColumnDescriptor>[
      _column('VersionNumber', 'Version'),
      _column('Status', 'Lifecycle'),
      _column('IsCurrentVersion', 'Current'),
      _column('ProjectionStatus', 'Searchability'),
      _column('ProjectionTarget', 'Provider / Target'),
      _column('ProjectionDocumentCount', 'Documents'),
      _column('ProjectionLastAt', 'Completed / Failed'),
      _column('ProjectionFailure', 'Failure'),
      _column('ProjectionMatchesActive', 'Active Target'),
      _column('KnowledgePackId', 'Pack', reference: _knowledgePackDisplay),
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
        confirmMessage:
            'Publish this approved version? Publication may remain queued until indexing completes.',
        successMessage: 'Published.',
        successMessageBuilder: _publishSuccessMessage,
        visibleWhenEquals: const <String, List<Object>>{
          'Status': <Object>['approved'],
          'HasActiveProjection': <Object>[false],
        },
      ),
      _versionAction(
        name: 'archive',
        label: 'Archive',
        confirmMessage: 'Archive this version?',
        successMessage: 'Knowledge pack version archived.',
        confirmMessageBuilder: _archiveConfirmation,
        fields: <AcpFieldDescriptor>[
          _multiline('Reason', 'Reason'),
          _multiline('Note', 'Note'),
        ],
      ),
      _versionAction(
        name: 'rollback_version',
        label: 'Rollback Version',
        confirmMessage:
            'Rollback publication to this historical version? The change may remain staged until indexing completes.',
        successMessage: 'Knowledge pack publication rolled back.',
        successMessageBuilder: _rollbackSuccessMessage,
        visibleWhenEquals: const <String, List<Object>>{
          'CanRollback': <Object>[true],
        },
      ),
      _versionAction(
        name: 'reindex',
        label: 'Reindex',
        confirmMessage:
            'Queue a fresh search projection for this published version?',
        successMessage: 'Reindex queued.',
        successMessageBuilder: _queuedActionSuccessMessage,
        visibleWhenEquals: const <String, List<Object>>{
          'CanReindex': <Object>[true],
        },
      ),
    ],
    searchFields: const <String>['Status', 'Note'],
    defaultOrderBy: 'VersionNumber desc',
    allowCreate: true,
    allowUpdate: true,
    expansions: const <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'KnowledgePack',
        selectFields: <String>['Name', 'Key', 'CurrentVersionId'],
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
    key: 'knowledge-index-projections',
    title: 'Projections',
    entitySet: 'KnowledgeIndexProjections',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    optionalApiSurface: true,
    description:
        'System-created search projection attempts. Retry failures here; reindex published versions from Versions.',
    columns: <AcpColumnDescriptor>[
      _column('Status', 'Status', valueBuilder: knowledgeProjectionStateLabel),
      _column('Operation', 'Operation'),
      _column('KnowledgePackId', 'Pack', reference: _knowledgePackDisplay),
      _column(
        'KnowledgePackVersionId',
        'Version',
        reference: _knowledgeVersionDisplay('KnowledgePackVersion'),
      ),
      _column('Provider', 'Provider'),
      _column(
        'TargetFingerprint',
        'Target Fingerprint',
        flex: 2,
        opaqueIdentifier: true,
      ),
      _column(
        'ContentChecksum',
        'Content Checksum',
        flex: 2,
        opaqueIdentifier: true,
      ),
      _column('ProjectionSchemaVersion', 'Schema'),
      _column('DocumentCount', 'Documents'),
      _column('AttemptSummary', 'Attempts'),
      _column('RequestedAt', 'Requested'),
      _column('StartedAt', 'Started'),
      _column('LastCompletedOrFailedAt', 'Completed / Failed'),
      _column('FailureCode', 'Failure Code'),
      _column('FailureDetail', 'Failure', flex: 2),
      _column('ActiveTargetMatch', 'Active Target'),
    ],
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'retry',
        label: 'Retry',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Retry this failed projection attempt?',
        successMessage: 'Projection retry queued.',
        successMessageBuilder: _queuedActionSuccessMessage,
        visibleWhenEquals: const <String, List<Object>>{
          'Status': <Object>['failed'],
        },
        refreshResourceKeys: const <String>[
          'knowledge-pack-versions',
          'knowledge-packs',
        ],
      ),
    ],
    searchFields: const <String>[
      'Status',
      'Operation',
      'Provider',
      'FailureCode',
      'FailureDetail',
    ],
    filters: const <AcpFilterDescriptor>[
      AcpFilterDescriptor(
        key: 'KnowledgePackId',
        label: 'Pack ID',
        literalType: AcpFilterLiteralType.guid,
        hintText: 'Exact pack ID',
      ),
      AcpFilterDescriptor(
        key: 'KnowledgePackVersionId',
        label: 'Version ID',
        literalType: AcpFilterLiteralType.guid,
        hintText: 'Exact version ID',
      ),
      AcpFilterDescriptor(
        key: 'Status',
        label: 'Status',
        options: <String>[
          'queued',
          'processing',
          'ready',
          'failed',
          'cancelled',
        ],
        optionLabels: <String, String>{
          'queued': 'Queued',
          'processing': 'Indexing',
          'ready': 'Ready',
          'failed': 'Failed',
          'cancelled': 'Cancelled',
        },
      ),
      AcpFilterDescriptor(
        key: 'Provider',
        label: 'Provider',
        hintText: 'Exact provider label',
      ),
    ],
    defaultOrderBy: 'RequestedAt desc',
    emptyMessage: 'No search projections found.',
    expansions: const <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'KnowledgePack',
        selectFields: <String>['Name', 'Key', 'CurrentVersionId'],
      ),
      AcpExpandDescriptor(
        navigation: 'KnowledgePackVersion',
        selectFields: <String>['VersionNumber', 'Status', 'KnowledgePackId'],
        expands: <AcpExpandDescriptor>[
          AcpExpandDescriptor(
            navigation: 'KnowledgePack',
            selectFields: <String>['Name', 'Key', 'CurrentVersionId'],
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

List<AcpResourceDescriptor> buildKnowledgePackAdminResources({
  required bool serviceProfilesEnabled,
}) {
  if (!serviceProfilesEnabled) {
    return knowledgePackAdminResources;
  }
  return knowledgePackAdminResources
      .map(
        (descriptor) => descriptor.entitySet == 'KnowledgeScopes'
            ? _knowledgeScopeWithServiceProfile(descriptor)
            : descriptor,
      )
      .toList(growable: false);
}

AcpResourceDescriptor _knowledgeScopeWithServiceProfile(
  AcpResourceDescriptor source,
) {
  return AcpResourceDescriptor(
    key: source.key,
    title: source.title,
    entitySet: source.entitySet,
    scopeMode: source.scopeMode,
    columns: <AcpColumnDescriptor>[
      ...source.columns,
      const AcpColumnDescriptor(
        key: 'ServiceProfileId',
        label: 'Service Profile',
        flex: 2,
        reference: AcpColumnReferenceDescriptor(
          navigationPath: 'ServiceProfile',
          titleFields: <AcpReferenceFieldDescriptor>[
            AcpReferenceFieldDescriptor('DisplayName'),
            AcpReferenceFieldDescriptor('Key'),
          ],
          subtitleFields: <AcpReferenceFieldDescriptor>[
            AcpReferenceFieldDescriptor('Key'),
          ],
          batchLookup: AcpBatchReferenceDescriptor(
            entitySet: 'ServiceProfiles',
            scopeMode: AcpScopeMode.required,
            selectFields: <String>['DisplayName', 'Key', 'Status'],
            literalType: AcpFilterLiteralType.guid,
            deletedView: AcpDeletedView.all,
          ),
          unassignedLabel: 'All service profiles',
          targetRouteId: 'service-profiles',
          targetResourceKey: 'service-profiles',
        ),
      ),
    ],
    description: source.description,
    createFields: <AcpFieldDescriptor>[
      ...source.createFields,
      _knowledgeScopeServiceProfileField,
    ],
    updateFields: <AcpFieldDescriptor>[
      ...source.updateFields,
      _knowledgeScopeServiceProfileField,
    ],
    collectionActions: source.collectionActions,
    entityActions: source.entityActions,
    searchFields: source.searchFields,
    filters: <AcpFilterDescriptor>[
      ...source.filters,
      const AcpFilterDescriptor(
        key: 'ServiceProfileId',
        label: 'Service Profile',
        literalType: AcpFilterLiteralType.guid,
        hintText: 'Search Service Profiles',
        reference: AcpFieldReferenceDescriptor(
          entitySet: 'ServiceProfiles',
          scopeMode: AcpScopeMode.required,
          title: 'Service Profiles',
          searchFields: <String>['Key', 'DisplayName', 'Status'],
          titleFields: <String>['DisplayName', 'Key'],
          subtitleFields: <String>['Key', 'Status'],
          retainHistoricalSelection: true,
        ),
      ),
    ],
    defaultOrderBy: source.defaultOrderBy,
    emptyMessage: source.emptyMessage,
    allowCreate: source.allowCreate,
    allowUpdate: source.allowUpdate,
    allowDelete: source.allowDelete,
    allowRestore: source.allowRestore,
    pageSize: source.pageSize,
    actionsColumnLeading: source.actionsColumnLeading,
    updateWhenEquals: source.updateWhenEquals,
    group: source.group,
    refreshResourceKeys: source.refreshResourceKeys,
    payloadValidator: source.payloadValidator,
    deletedViews: source.deletedViews,
    expansions: source.expansions,
    keyLiteralType: source.keyLiteralType,
    optionalApiSurface: source.optionalApiSurface,
    detailSections: const <AcpDetailSectionDescriptor>[
      AcpDetailSectionDescriptor(
        title: 'Knowledge Scope targeting',
        fields: <AcpDetailFieldDescriptor>[
          AcpDetailFieldDescriptor(key: 'Channel', label: 'Channel'),
          AcpDetailFieldDescriptor(key: 'Locale', label: 'Locale'),
          AcpDetailFieldDescriptor(key: 'Category', label: 'Category'),
          AcpDetailFieldDescriptor(
            key: 'ServiceProfileLabel',
            label: 'Service Profile',
          ),
          AcpDetailFieldDescriptor(
            key: 'ServiceRouteKey',
            label: 'Service Route',
          ),
          AcpDetailFieldDescriptor(
            key: 'ClientProfileKey',
            label: 'Client Profile',
          ),
          AcpDetailFieldDescriptor(key: 'IsActive', label: 'Active'),
        ],
      ),
    ],
  );
}

const AcpFieldDescriptor
_knowledgeScopeServiceProfileField = AcpFieldDescriptor(
  key: 'ServiceProfileId',
  label: 'Service Profile',
  hintText:
      'Optional stable service identity. Leave empty to allow every Service Profile. Service Route selects behavior; Client Profile selects channel-client configuration.',
  reference: AcpFieldReferenceDescriptor(
    entitySet: 'ServiceProfiles',
    scopeMode: AcpScopeMode.required,
    title: 'Service Profiles',
    searchFields: <String>['Key', 'DisplayName', 'Status'],
    titleFields: <String>['DisplayName', 'Key'],
    subtitleFields: <String>['Key', 'Status'],
    retainHistoricalSelection: true,
  ),
);

AcpColumnDescriptor _column(
  String key,
  String label, {
  AcpColumnReferenceDescriptor? reference,
  bool opaqueIdentifier = false,
  int flex = 1,
  AcpColumnValueBuilder? valueBuilder,
}) {
  return AcpColumnDescriptor(
    key: key,
    label: label,
    flex: flex,
    valueBuilder: valueBuilder,
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
      targetResourceKey: 'knowledge-pack-versions',
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
      targetResourceKey: 'knowledge-packs',
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
    targetResourceKey: 'knowledge-pack-versions',
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
  AcpActionMessageBuilder? confirmMessageBuilder,
  AcpActionSuccessMessageBuilder? successMessageBuilder,
  Map<String, List<Object>> visibleWhenEquals = const <String, List<Object>>{},
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
    confirmMessageBuilder: confirmMessageBuilder,
    successMessage: successMessage,
    successMessageBuilder: successMessageBuilder,
    visibleWhenEquals: visibleWhenEquals,
    refreshResourceKeys: const <String>[
      'knowledge-packs',
      'knowledge-index-projections',
    ],
    fields: fields,
  );
}

String _publishSuccessMessage(Object? result) =>
    _isQueuedResult(result) ? 'Publication queued.' : 'Published.';

String _rollbackSuccessMessage(Object? result) => _isQueuedResult(result)
    ? 'Rollback queued.'
    : 'Knowledge pack publication rolled back.';

String _queuedActionSuccessMessage(Object? result) =>
    _isQueuedResult(result) ? 'Projection queued.' : 'Action completed.';

bool _isQueuedResult(Object? result) {
  if (result is! Map) {
    return false;
  }
  return result['ProjectionId']?.toString().trim().isNotEmpty == true &&
      const <String>{
        'queued',
        'processing',
      }.contains(result['Status']?.toString().trim().toLowerCase());
}

String _archiveConfirmation(AcpRow? row) {
  if (row?['IsPublishedOrIndexing'] == true) {
    return 'Archive this version? It is currently published or indexing; '
        'search availability may change.';
  }
  return 'Archive this version?';
}
