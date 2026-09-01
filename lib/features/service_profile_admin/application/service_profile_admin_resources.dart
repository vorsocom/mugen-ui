import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

const String serviceProfilePluginToken = 'core.fw.service_profile';
const String channelOrchestrationPluginToken = 'core.fw.channel_orchestration';

List<AcpResourceDescriptor> buildServiceProfileAdminResources({
  required bool channelOrchestrationEnabled,
  required bool billingEnabled,
  required bool knowledgePackEnabled,
}) {
  return <AcpResourceDescriptor>[
    _profiles(
      includeIngressLinks: channelOrchestrationEnabled,
      includeSubscriptionLinks: billingEnabled,
      includeKnowledgeLinks: knowledgePackEnabled,
    ),
    if (channelOrchestrationEnabled) _ingressAssignments,
    if (billingEnabled) _subscriptionAssignments,
  ];
}

AcpResourceDescriptor _profiles({
  required bool includeIngressLinks,
  required bool includeSubscriptionLinks,
  required bool includeKnowledgeLinks,
}) {
  return AcpResourceDescriptor(
    key: 'service-profiles',
    title: 'Profiles',
    entitySet: 'ServiceProfiles',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Stable, channel-neutral service identities. A profile is routable only when it is active and has a live ingress endpoint assignment.',
    columns: const <AcpColumnDescriptor>[
      AcpColumnDescriptor(key: 'Key', label: 'Key'),
      AcpColumnDescriptor(key: 'DisplayName', label: 'Display Name', flex: 2),
      AcpColumnDescriptor(
        key: 'Status',
        label: 'Status',
        presentation: AcpColumnPresentation.status,
      ),
      AcpColumnDescriptor(
        key: 'Readiness',
        label: 'Readiness',
        flex: 2,
        presentation: AcpColumnPresentation.status,
      ),
      AcpColumnDescriptor(key: 'ActiveIngressCount', label: 'Active Ingress'),
      AcpColumnDescriptor(key: 'ActiveProductCount', label: 'Active Products'),
      AcpColumnDescriptor(key: 'ActivatedAt', label: 'Activated', flex: 2),
      AcpColumnDescriptor(key: 'DisabledAt', label: 'Disabled', flex: 2),
      AcpColumnDescriptor(key: 'UpdatedAt', label: 'Updated', flex: 2),
    ],
    createFields: const <AcpFieldDescriptor>[
      AcpFieldDescriptor(key: 'Key', label: 'Key', required: true),
      AcpFieldDescriptor(
        key: 'DisplayName',
        label: 'Display Name',
        required: true,
      ),
      _attributes,
    ],
    updateFields: const <AcpFieldDescriptor>[
      AcpFieldDescriptor(
        key: 'Key',
        label: 'Key',
        readOnly: true,
        includeInPayload: false,
        hintText:
            'Stable identity. Create a new profile to use a different key.',
      ),
      AcpFieldDescriptor(
        key: 'DisplayName',
        label: 'Display Name',
        required: true,
      ),
      _attributes,
    ],
    entityActions: const <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'activate',
        label: 'Activate',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage:
            'Activate this Service Profile? It must have at least one active, valid ingress assignment.',
        successMessage: 'Service Profile activated.',
        showInToolbar: false,
        showInRowMenu: true,
        visibleWhenEquals: <String, List<Object>>{
          'Status': <Object>['draft'],
        },
        refreshResourceKeys: <String>['service-profile-ingress-bindings'],
      ),
      AcpActionDescriptor(
        name: 'disable',
        label: 'Disable',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage:
            'Disable this Service Profile? It will stop being routable for downstream services.',
        successMessage: 'Service Profile disabled.',
        showInToolbar: false,
        showInRowMenu: true,
        visibleWhenEquals: <String, List<Object>>{
          'Status': <Object>['active'],
        },
      ),
    ],
    filters: const <AcpFilterDescriptor>[
      AcpFilterDescriptor(
        key: 'Status',
        label: 'Status',
        options: <String>['draft', 'active', 'disabled'],
        optionLabels: <String, String>{
          'draft': 'Draft',
          'active': 'Active',
          'disabled': 'Disabled',
        },
      ),
    ],
    searchFields: const <String>['Key', 'DisplayName', 'Status'],
    defaultOrderBy: 'UpdatedAt desc',
    allowCreate: true,
    allowUpdate: true,
    payloadValidator: validateServiceProfileAttributes,
    detailSections: <AcpDetailSectionDescriptor>[
      const AcpDetailSectionDescriptor(
        title: 'Identity and readiness',
        fields: <AcpDetailFieldDescriptor>[
          AcpDetailFieldDescriptor(key: 'Key', label: 'Key'),
          AcpDetailFieldDescriptor(key: 'DisplayName', label: 'Display name'),
          AcpDetailFieldDescriptor(
            key: 'Status',
            label: 'Lifecycle',
            presentation: AcpColumnPresentation.status,
          ),
          AcpDetailFieldDescriptor(
            key: 'Readiness',
            label: 'Routability',
            presentation: AcpColumnPresentation.status,
          ),
          AcpDetailFieldDescriptor(
            key: 'ActiveIngressCount',
            label: 'Active ingress count',
          ),
          AcpDetailFieldDescriptor(
            key: 'ActiveProductCount',
            label: 'Active Product count',
          ),
        ],
      ),
      AcpDetailSectionDescriptor(
        title: 'Assignments',
        fields: const <AcpDetailFieldDescriptor>[
          AcpDetailFieldDescriptor(
            key: 'IngressSummary',
            label: 'Ingress endpoints and routes',
          ),
          AcpDetailFieldDescriptor(
            key: 'ProductSummary',
            label: 'Allocated Products',
          ),
          AcpDetailFieldDescriptor(
            key: 'KnowledgeScopeSummary',
            label: 'Knowledge Pack scopes',
          ),
        ],
        links: <AcpNavigationDescriptor>[
          if (includeIngressLinks)
            const AcpNavigationDescriptor(
              label: 'View ingress assignments',
              targetResourceKey: 'service-profile-ingress-bindings',
              targetFilterKey: 'ServiceProfileId',
            ),
          if (includeSubscriptionLinks)
            const AcpNavigationDescriptor(
              label: 'View Subscription assignments',
              targetResourceKey: 'service-profile-subscriptions',
              targetFilterKey: 'ServiceProfileId',
            ),
          if (includeKnowledgeLinks)
            const AcpNavigationDescriptor(
              label: 'View matching Knowledge Scopes',
              targetRouteId: RouteIds.knowledgePacks,
              targetResourceKey: 'knowledge-scopes',
              targetFilterKey: 'ServiceProfileId',
            ),
        ],
      ),
      const AcpDetailSectionDescriptor(
        title: 'Lifecycle timestamps',
        fields: <AcpDetailFieldDescriptor>[
          AcpDetailFieldDescriptor(key: 'ActivatedAt', label: 'Activated'),
          AcpDetailFieldDescriptor(key: 'DisabledAt', label: 'Disabled'),
          AcpDetailFieldDescriptor(key: 'UpdatedAt', label: 'Updated'),
        ],
      ),
    ],
  );
}

const AcpResourceDescriptor _ingressAssignments = AcpResourceDescriptor(
  key: 'service-profile-ingress-bindings',
  title: 'Ingress Bindings',
  entitySet: 'ServiceProfileIngressBindings',
  scopeMode: AcpScopeMode.required,
  keyLiteralType: AcpFilterLiteralType.guid,
  description:
      'An Ingress Binding is a concrete endpoint. A Service Profile is the stable service identity that can receive traffic through several endpoints.',
  columns: <AcpColumnDescriptor>[
    AcpColumnDescriptor(
      key: 'ServiceProfileId',
      label: 'Service Profile',
      flex: 2,
      reference: _profileColumnReference,
    ),
    AcpColumnDescriptor(
      key: 'IngressBindingId',
      label: 'Ingress Binding',
      flex: 2,
      reference: AcpColumnReferenceDescriptor(
        navigationPath: 'IngressBinding',
        titleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('EndpointLabel'),
          AcpReferenceFieldDescriptor('IdentifierValue'),
        ],
        subtitleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('IdentifierType'),
        ],
        targetRouteId: RouteIds.channelOrchestration,
        targetResourceKey: 'ingress-bindings',
      ),
    ),
    AcpColumnDescriptor(key: 'PlatformChannel', label: 'Platform / Channel'),
    AcpColumnDescriptor(key: 'ClientProfileLabel', label: 'Client Profile'),
    AcpColumnDescriptor(key: 'ServiceRoute', label: 'Service Route'),
    AcpColumnDescriptor(
      key: 'AssignmentState',
      label: 'Active State',
      presentation: AcpColumnPresentation.status,
    ),
    AcpColumnDescriptor(key: 'UpdatedAt', label: 'Updated', flex: 2),
  ],
  createFields: <AcpFieldDescriptor>[
    _profileField,
    AcpFieldDescriptor(
      key: 'IngressBindingId',
      label: 'Ingress Binding',
      required: true,
      hintText:
          'Choose an active endpoint in this tenant. Endpoints assigned elsewhere remain visible with an explanation.',
      reference: AcpFieldReferenceDescriptor(
        entitySet: 'IngressBindings',
        scopeMode: AcpScopeMode.required,
        title: 'Ingress Bindings',
        searchFields: <String>[
          'ChannelKey',
          'IdentifierType',
          'IdentifierValue',
          'ServiceRouteKey',
        ],
        titleFields: <String>['EndpointLabel', 'IdentifierValue'],
        subtitleFields: <String>['EndpointContext', 'AssignmentAvailability'],
        extraFilters: <String>['IsActive eq true'],
        contextFieldsFromForm: <String, String>{
          'ServiceProfileId': 'ServiceProfileId',
        },
        disabledReasonField: 'SelectionBlockedReason',
      ),
    ),
    AcpFieldDescriptor(
      key: 'IsActive',
      label: 'Active',
      kind: AcpFieldKind.boolean,
      initialValue: true,
      hintText:
          'Active assignments make the endpoint available to the profile.',
    ),
    _attributes,
  ],
  updateFields: <AcpFieldDescriptor>[
    _readOnlyProfileField,
    AcpFieldDescriptor(
      key: 'IngressBindingId',
      label: 'Ingress Binding',
      readOnly: true,
      includeInPayload: false,
      reference: AcpFieldReferenceDescriptor(
        entitySet: 'IngressBindings',
        scopeMode: AcpScopeMode.required,
        title: 'Ingress Bindings',
        searchFields: <String>['IdentifierValue'],
        titleFields: <String>['EndpointLabel', 'IdentifierValue'],
        subtitleFields: <String>['EndpointContext'],
        retainHistoricalSelection: true,
      ),
    ),
    AcpFieldDescriptor(
      key: 'IsActive',
      label: 'Active',
      kind: AcpFieldKind.boolean,
    ),
    _attributes,
  ],
  filters: <AcpFilterDescriptor>[
    AcpFilterDescriptor(
      key: 'ServiceProfileId',
      label: 'Service Profile',
      literalType: AcpFilterLiteralType.guid,
      hintText: 'Search profiles',
      reference: _profileFilterReference,
    ),
    AcpFilterDescriptor(
      key: 'IsActive',
      label: 'Active',
      options: <String>['true', 'false'],
      optionLabels: <String, String>{'true': 'Active', 'false': 'Inactive'},
    ),
  ],
  defaultOrderBy: 'UpdatedAt desc',
  allowCreate: true,
  allowUpdate: true,
  payloadValidator: validateServiceProfileAttributes,
  detailSections: <AcpDetailSectionDescriptor>[
    AcpDetailSectionDescriptor(
      title: 'Endpoint assignment',
      fields: <AcpDetailFieldDescriptor>[
        AcpDetailFieldDescriptor(key: 'ServiceProfileLabel', label: 'Profile'),
        AcpDetailFieldDescriptor(
          key: 'EndpointLabel',
          label: 'Ingress endpoint',
        ),
        AcpDetailFieldDescriptor(
          key: 'PlatformChannel',
          label: 'Platform / channel',
        ),
        AcpDetailFieldDescriptor(
          key: 'ClientProfileLabel',
          label: 'Client Profile',
        ),
        AcpDetailFieldDescriptor(key: 'ServiceRoute', label: 'Service Route'),
        AcpDetailFieldDescriptor(
          key: 'AssignmentState',
          label: 'Assignment state',
          presentation: AcpColumnPresentation.status,
        ),
      ],
      links: <AcpNavigationDescriptor>[
        AcpNavigationDescriptor(
          label: 'Open Service Profile',
          targetResourceKey: 'service-profiles',
          sourceField: 'ServiceProfileId',
        ),
        AcpNavigationDescriptor(
          label: 'Open underlying Ingress Binding',
          targetRouteId: RouteIds.channelOrchestration,
          targetResourceKey: 'ingress-bindings',
          sourceField: 'IngressBindingId',
        ),
      ],
    ),
  ],
);

const AcpResourceDescriptor _subscriptionAssignments = AcpResourceDescriptor(
  key: 'service-profile-subscriptions',
  title: 'Subscriptions',
  entitySet: 'ServiceProfileSubscriptions',
  scopeMode: AcpScopeMode.required,
  keyLiteralType: AcpFilterLiteralType.guid,
  description:
      'The Billing Account owns the Subscription. This assignment enables its Product for one Service Profile.',
  columns: <AcpColumnDescriptor>[
    AcpColumnDescriptor(
      key: 'ServiceProfileId',
      label: 'Service Profile',
      flex: 2,
      reference: _profileColumnReference,
    ),
    AcpColumnDescriptor(
      key: 'BillingSubscriptionId',
      label: 'Billing Subscription',
      flex: 2,
      reference: AcpColumnReferenceDescriptor(
        navigationPath: 'BillingSubscription',
        titleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('SubscriptionLabel'),
          AcpReferenceFieldDescriptor('ExternalRef'),
        ],
        subtitleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('Status'),
        ],
        targetRouteId: RouteIds.billingOperations,
        targetResourceKey: 'billing-subscriptions',
      ),
    ),
    AcpColumnDescriptor(
      key: '_ProductId',
      label: 'Derived Product',
      flex: 2,
      reference: AcpColumnReferenceDescriptor(
        navigationPath: 'BillingSubscription.Price.Product',
        titleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('Name'),
          AcpReferenceFieldDescriptor('Code'),
        ],
        subtitleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('Code'),
        ],
        targetRouteId: RouteIds.billingCatalog,
        targetResourceKey: 'billing-products',
      ),
    ),
    AcpColumnDescriptor(
      key: '_PriceId',
      label: 'Price',
      reference: AcpColumnReferenceDescriptor(
        navigationPath: 'BillingSubscription.Price',
        titleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('Code'),
        ],
        subtitleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('Currency'),
          AcpReferenceFieldDescriptor('PriceType'),
        ],
        targetRouteId: RouteIds.billingCatalog,
        targetResourceKey: 'billing-prices',
      ),
    ),
    AcpColumnDescriptor(
      key: '_AccountId',
      label: 'Billing Account',
      flex: 2,
      reference: AcpColumnReferenceDescriptor(
        navigationPath: 'BillingSubscription.Account',
        titleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('DisplayName'),
          AcpReferenceFieldDescriptor('Code'),
        ],
        subtitleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('Code'),
        ],
        targetRouteId: RouteIds.billingOperations,
        targetResourceKey: 'billing-accounts',
      ),
    ),
    AcpColumnDescriptor(
      key: 'SubscriptionStatus',
      label: 'Subscription Status',
      presentation: AcpColumnPresentation.status,
    ),
    AcpColumnDescriptor(
      key: 'Status',
      label: 'Assignment Status',
      presentation: AcpColumnPresentation.status,
    ),
    AcpColumnDescriptor(
      key: 'AccessState',
      label: 'Product Access',
      flex: 2,
      presentation: AcpColumnPresentation.status,
    ),
    AcpColumnDescriptor(key: 'CurrentPeriod', label: 'Current Period', flex: 2),
    AcpColumnDescriptor(key: 'ActivatedAt', label: 'Activated', flex: 2),
    AcpColumnDescriptor(key: 'DisabledAt', label: 'Disabled', flex: 2),
  ],
  createFields: <AcpFieldDescriptor>[
    _profileField,
    AcpFieldDescriptor(
      key: 'BillingSubscriptionId',
      label: 'Billing Subscription',
      required: true,
      hintText:
          'The Billing Account keeps ownership. This assignment enables the derived Product only for the selected Service Profile.',
      reference: AcpFieldReferenceDescriptor(
        entitySet: 'BillingSubscriptions',
        scopeMode: AcpScopeMode.required,
        title: 'Billing Subscriptions',
        searchFields: <String>['ExternalRef', 'Status'],
        titleFields: <String>['SubscriptionLabel', 'ExternalRef', 'Id'],
        subtitleFields: <String>[
          'SubscriptionContext',
          'AssignmentAvailability',
        ],
        contextFieldsFromForm: <String, String>{
          'ServiceProfileId': 'ServiceProfileId',
        },
        expansions: <AcpExpandDescriptor>[
          AcpExpandDescriptor(
            navigation: 'Account',
            selectFields: <String>['Id', 'TenantId', 'DisplayName', 'Code'],
          ),
          AcpExpandDescriptor(
            navigation: 'Price',
            selectFields: <String>[
              'Id',
              'Code',
              'Currency',
              'PriceType',
              'ProductId',
              'DeletedAt',
            ],
            expands: <AcpExpandDescriptor>[
              AcpExpandDescriptor(
                navigation: 'Product',
                selectFields: <String>['Id', 'Code', 'Name', 'DeletedAt'],
              ),
            ],
          ),
        ],
        disabledReasonField: 'SelectionBlockedReason',
      ),
    ),
    _attributes,
  ],
  updateFields: <AcpFieldDescriptor>[
    _readOnlyProfileField,
    AcpFieldDescriptor(
      key: 'BillingSubscriptionId',
      label: 'Billing Subscription',
      readOnly: true,
      includeInPayload: false,
      reference: AcpFieldReferenceDescriptor(
        entitySet: 'BillingSubscriptions',
        scopeMode: AcpScopeMode.required,
        title: 'Billing Subscriptions',
        searchFields: <String>['ExternalRef', 'Status'],
        titleFields: <String>['SubscriptionLabel', 'ExternalRef', 'Id'],
        subtitleFields: <String>['SubscriptionContext'],
        retainHistoricalSelection: true,
        expansions: <AcpExpandDescriptor>[
          AcpExpandDescriptor(
            navigation: 'Account',
            selectFields: <String>['Id', 'DisplayName', 'Code'],
          ),
          AcpExpandDescriptor(
            navigation: 'Price',
            selectFields: <String>['Id', 'Code', 'ProductId'],
            expands: <AcpExpandDescriptor>[
              AcpExpandDescriptor(
                navigation: 'Product',
                selectFields: <String>['Id', 'Code', 'Name'],
              ),
            ],
          ),
        ],
      ),
    ),
    _attributes,
  ],
  entityActions: <AcpActionDescriptor>[
    AcpActionDescriptor(
      name: 'activate',
      label: 'Activate',
      target: AcpActionTarget.entity,
      includeRowVersion: true,
      confirmMessage:
          'Activate this Product assignment? Current Subscription, Account, Price, and Product readiness will be validated.',
      successMessage: 'Service Profile Product access activated.',
      showInToolbar: false,
      showInRowMenu: true,
      visibleWhenEquals: <String, List<Object>>{
        'Status': <Object>['draft'],
      },
    ),
    AcpActionDescriptor(
      name: 'disable',
      label: 'Disable',
      target: AcpActionTarget.entity,
      includeRowVersion: true,
      confirmMessage:
          'Disable this Product assignment? The Billing Account will continue to own the Subscription.',
      successMessage: 'Service Profile Product access disabled.',
      showInToolbar: false,
      showInRowMenu: true,
      visibleWhenEquals: <String, List<Object>>{
        'Status': <Object>['active'],
      },
    ),
  ],
  filters: <AcpFilterDescriptor>[
    AcpFilterDescriptor(
      key: 'ServiceProfileId',
      label: 'Service Profile',
      literalType: AcpFilterLiteralType.guid,
      hintText: 'Search profiles',
      reference: _profileFilterReference,
    ),
    AcpFilterDescriptor(
      key: 'Status',
      label: 'Assignment Status',
      options: <String>['draft', 'active', 'disabled'],
      optionLabels: <String, String>{
        'draft': 'Draft',
        'active': 'Active',
        'disabled': 'Disabled',
      },
    ),
  ],
  defaultOrderBy: 'UpdatedAt desc',
  allowCreate: true,
  allowUpdate: true,
  payloadValidator: validateServiceProfileAttributes,
  detailSections: <AcpDetailSectionDescriptor>[
    AcpDetailSectionDescriptor(
      title: 'Product access',
      fields: <AcpDetailFieldDescriptor>[
        AcpDetailFieldDescriptor(key: 'ServiceProfileLabel', label: 'Profile'),
        AcpDetailFieldDescriptor(
          key: 'SubscriptionLabel',
          label: 'Billing Subscription',
        ),
        AcpDetailFieldDescriptor(key: 'ProductLabel', label: 'Derived Product'),
        AcpDetailFieldDescriptor(key: 'PriceLabel', label: 'Price'),
        AcpDetailFieldDescriptor(key: 'AccountLabel', label: 'Billing Account'),
        AcpDetailFieldDescriptor(
          key: 'SubscriptionStatus',
          label: 'Subscription status',
          presentation: AcpColumnPresentation.status,
        ),
        AcpDetailFieldDescriptor(
          key: 'Status',
          label: 'Assignment status',
          presentation: AcpColumnPresentation.status,
        ),
        AcpDetailFieldDescriptor(
          key: 'AccessState',
          label: 'Access readiness',
          presentation: AcpColumnPresentation.status,
        ),
        AcpDetailFieldDescriptor(key: 'CurrentPeriod', label: 'Current period'),
      ],
      links: <AcpNavigationDescriptor>[
        AcpNavigationDescriptor(
          label: 'Open Service Profile',
          targetResourceKey: 'service-profiles',
          sourceField: 'ServiceProfileId',
        ),
        AcpNavigationDescriptor(
          label: 'Open Billing Subscription',
          targetRouteId: RouteIds.billingOperations,
          targetResourceKey: 'billing-subscriptions',
          sourceField: 'BillingSubscriptionId',
        ),
        AcpNavigationDescriptor(
          label: 'Open Billing Account',
          targetRouteId: RouteIds.billingOperations,
          targetResourceKey: 'billing-accounts',
          sourceField: '_AccountId',
        ),
        AcpNavigationDescriptor(
          label: 'Open Price',
          targetRouteId: RouteIds.billingCatalog,
          targetResourceKey: 'billing-prices',
          sourceField: '_PriceId',
        ),
        AcpNavigationDescriptor(
          label: 'Open Product',
          targetRouteId: RouteIds.billingCatalog,
          targetResourceKey: 'billing-products',
          sourceField: '_ProductId',
        ),
      ],
    ),
  ],
);

const AcpColumnReferenceDescriptor _profileColumnReference =
    AcpColumnReferenceDescriptor(
      navigationPath: 'ServiceProfile',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('DisplayName'),
        AcpReferenceFieldDescriptor('Key'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Key'),
      ],
      targetResourceKey: 'service-profiles',
    );

const AcpFieldReferenceDescriptor _profileFilterReference =
    AcpFieldReferenceDescriptor(
      entitySet: 'ServiceProfiles',
      scopeMode: AcpScopeMode.required,
      title: 'Service Profiles',
      searchFields: <String>['Key', 'DisplayName', 'Status'],
      titleFields: <String>['DisplayName', 'Key'],
      subtitleFields: <String>['Key', 'Status'],
      retainHistoricalSelection: true,
    );

const AcpFieldDescriptor _profileField = AcpFieldDescriptor(
  key: 'ServiceProfileId',
  label: 'Service Profile',
  required: true,
  reference: AcpFieldReferenceDescriptor(
    entitySet: 'ServiceProfiles',
    scopeMode: AcpScopeMode.required,
    title: 'Service Profiles',
    searchFields: <String>['Key', 'DisplayName', 'Status'],
    titleFields: <String>['DisplayName', 'Key'],
    subtitleFields: <String>['Key', 'Status'],
    extraFilters: <String>["Status ne 'disabled'"],
  ),
);

const AcpFieldDescriptor _readOnlyProfileField = AcpFieldDescriptor(
  key: 'ServiceProfileId',
  label: 'Service Profile',
  readOnly: true,
  includeInPayload: false,
  reference: AcpFieldReferenceDescriptor(
    entitySet: 'ServiceProfiles',
    scopeMode: AcpScopeMode.required,
    title: 'Service Profiles',
    searchFields: <String>['Key', 'DisplayName'],
    titleFields: <String>['DisplayName', 'Key'],
    subtitleFields: <String>['Key', 'Status'],
    retainHistoricalSelection: true,
  ),
);

const AcpFieldDescriptor _attributes = AcpFieldDescriptor(
  key: 'Attributes',
  label: 'Attributes',
  kind: AcpFieldKind.json,
  minLines: 5,
  maxLines: 9,
  hintText:
      'Optional non-secret metadata only. Do not enter credentials, secret references, environment values, or machine-specific configuration.',
);

String? validateServiceProfileAttributes(Map<String, dynamic> payload) {
  final attributes = payload['Attributes'];
  if (attributes == null) {
    return null;
  }
  if (attributes is! Map) {
    return 'Attributes must be a JSON object.';
  }
  final unsafe = <String>[];

  void walk(Object? value, String path) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
        if (_unsafeAttributeFragments.any(normalized.contains)) {
          unsafe.add(path.isEmpty ? key : '$path.$key');
        }
        walk(entry.value, path.isEmpty ? key : '$path.$key');
      }
    } else if (value is List) {
      for (var index = 0; index < value.length; index++) {
        walk(value[index], '$path[$index]');
      }
    }
  }

  walk(attributes, '');
  return unsafe.isEmpty
      ? null
      : 'Attributes contain restricted configuration keys: ${unsafe.join(', ')}.';
}

const Set<String> _unsafeAttributeFragments = <String>{
  'apikey',
  'authorization',
  'credential',
  'environment',
  'keyref',
  'machine',
  'password',
  'secret',
  'token',
};
