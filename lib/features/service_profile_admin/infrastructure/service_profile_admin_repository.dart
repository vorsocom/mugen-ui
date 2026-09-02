import 'package:mugen_ui/features/service_profile_admin/application/service_profile_status.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class ServiceProfileAdminRepository implements AcpAdminRepository {
  ServiceProfileAdminRepository({
    required this.delegate,
    required this.channelOrchestrationEnabled,
    required this.billingEnabled,
    required this.knowledgePackEnabled,
  });

  final AcpAdminRepository delegate;
  final bool channelOrchestrationEnabled;
  final bool billingEnabled;
  final bool knowledgePackEnabled;

  @override
  Future<Result<List<AcpTenantOption>>> fetchTenants({int top = 200}) =>
      delegate.fetchTenants(top: top);

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
  }) async {
    final result = await delegate.listRows(
      descriptor: descriptor,
      pageRequest: pageRequest,
      tenantId: tenantId,
      searchTerm: searchTerm,
      extraFilters: extraFilters,
      deletedView: deletedView,
      enrichReferences:
          enrichReferences &&
          !_customReferenceEntitySets.contains(descriptor.entitySet),
    );
    if (result.isFailure || result.data!.items.isEmpty) {
      return result;
    }
    return _enrichPage(
      descriptor: descriptor,
      page: result.data!,
      tenantId: tenantId,
    );
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    final result = await delegate.fetchRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
    );
    if (result.isFailure) {
      return result;
    }
    final enriched = await _enrichPage(
      descriptor: descriptor,
      page: AcpRowPage(
        items: <AcpRow>[result.data!],
        total: 1,
        page: 1,
        pageSize: 1,
      ),
      tenantId: tenantId,
    );
    return Result<AcpRow>.success(enriched.data!.items.single);
  }

  Future<Result<AcpRowPage>> _enrichPage({
    required AcpResourceDescriptor descriptor,
    required AcpRowPage page,
    required String? tenantId,
  }) {
    return switch (descriptor.entitySet) {
      'ServiceProfiles' => _enrichProfiles(page: page, tenantId: tenantId),
      'ServiceProfileIngressBindings' => _enrichIngressAssignments(
        page: page,
        tenantId: tenantId,
      ),
      'ServiceProfileSubscriptions' => _enrichSubscriptionAssignments(
        page: page,
        tenantId: tenantId,
      ),
      'IngressBindings' => _enrichIngressSelector(
        page: page,
        tenantId: tenantId,
        context: descriptor.referenceContext,
      ),
      'BillingSubscriptions' => _enrichSubscriptionSelector(
        page: page,
        tenantId: tenantId,
        context: descriptor.referenceContext,
      ),
      _ => Future<Result<AcpRowPage>>.value(Result<AcpRowPage>.success(page)),
    };
  }

  Future<Result<AcpRowPage>> _enrichProfiles({
    required AcpRowPage page,
    required String? tenantId,
  }) async {
    final profileIds = _ids(page.items);
    var warning = page.referenceWarning;

    var ingressAvailable = channelOrchestrationEnabled;
    var ingressAssignments = <AcpRow>[];
    var bindings = <String, AcpRow>{};
    if (channelOrchestrationEnabled) {
      final assignmentResult = await _fetchByIds(
        entitySet: 'ServiceProfileIngressBindings',
        field: 'ServiceProfileId',
        ids: profileIds,
        tenantId: tenantId,
      );
      if (assignmentResult.isFailure) {
        ingressAvailable = false;
        warning = _mergeWarning(
          warning,
          'Ingress readiness could not be determined. Refresh before activation.',
        );
      } else {
        ingressAssignments = assignmentResult.data!;
        final bindingResult = await _fetchByIds(
          entitySet: 'IngressBindings',
          field: 'Id',
          ids: _fieldIds(ingressAssignments, 'IngressBindingId'),
          tenantId: tenantId,
        );
        if (bindingResult.isFailure) {
          ingressAvailable = false;
          warning = _mergeWarning(
            warning,
            'Ingress endpoint status could not be determined. Refresh before activation.',
          );
        } else {
          bindings = _byId(bindingResult.data!);
        }
      }
    }

    var productAvailable = billingEnabled;
    var subscriptionAssignments = <AcpRow>[];
    if (billingEnabled) {
      final subscriptionResult = await _fetchByIds(
        entitySet: 'ServiceProfileSubscriptions',
        field: 'ServiceProfileId',
        ids: profileIds,
        tenantId: tenantId,
      );
      if (subscriptionResult.isFailure) {
        productAvailable = false;
        warning = _mergeWarning(
          warning,
          'Product access could not be determined. Refresh to retry.',
        );
      } else {
        subscriptionAssignments = subscriptionResult.data!;
      }
    }

    var scopesAvailable = knowledgePackEnabled;
    var scopes = <AcpRow>[];
    if (knowledgePackEnabled) {
      final scopeResult = await _fetchByIds(
        entitySet: 'KnowledgeScopes',
        field: 'ServiceProfileId',
        ids: profileIds,
        tenantId: tenantId,
      );
      if (scopeResult.isFailure) {
        scopesAvailable = false;
        warning = _mergeWarning(
          warning,
          'Knowledge Scope targeting could not be determined.',
        );
      } else {
        scopes = scopeResult.data!;
      }
    }

    final rows = page.items
        .map((source) {
          final row = Map<String, dynamic>.from(source);
          final profileId = row.id ?? '';
          final profileIngress = ingressAssignments
              .where((item) => _text(item['ServiceProfileId']) == profileId)
              .toList(growable: false);
          final profileProducts = subscriptionAssignments
              .where((item) => _text(item['ServiceProfileId']) == profileId)
              .toList(growable: false);
          final profileScopes = scopes
              .where((item) => _text(item['ServiceProfileId']) == profileId)
              .toList(growable: false);
          final activeIngress = profileIngress
              .where((assignment) {
                final binding = bindings[_text(assignment['IngressBindingId'])];
                return assignment['IsActive'] == true &&
                    binding?['IsActive'] == true;
              })
              .toList(growable: false);
          final activeProducts = profileProducts
              .where((assignment) => _lower(assignment['Status']) == 'active')
              .toList(growable: false);
          row.addAll(<String, dynamic>{
            'Readiness': serviceProfileReadiness(
              profile: row,
              assignments: profileIngress,
              bindings: bindings,
              statusAvailable: ingressAvailable,
            ),
            'ActiveIngressCount': ingressAvailable
                ? activeIngress.length
                : 'Unavailable',
            'ActiveProductCount': productAvailable
                ? activeProducts.length
                : 'Unavailable',
            'IngressSummary': !channelOrchestrationEnabled
                ? 'Channel Orchestration is unavailable.'
                : !ingressAvailable
                ? 'Status unavailable.'
                : profileIngress.isEmpty
                ? 'No ingress endpoints assigned.'
                : profileIngress
                      .map((item) {
                        final binding =
                            bindings[_text(item['IngressBindingId'])];
                        final route = _text(binding?['ServiceRouteKey']);
                        return '${_endpointLabel(binding)}${route.isEmpty ? '' : ' · Route: $route'} — ${serviceProfileIngressAssignmentState(assignment: item, binding: binding)}';
                      })
                      .join('\n'),
            'ProductSummary': !billingEnabled
                ? 'Billing is unavailable.'
                : !productAvailable
                ? 'Status unavailable.'
                : profileProducts.isEmpty
                ? 'No Products assigned.'
                : profileProducts
                      .map(
                        (item) =>
                            '${_text(item['ProductCode']).isEmpty ? 'Product pending activation' : _text(item['ProductCode'])} — ${_text(item['Status'])}',
                      )
                      .join('\n'),
            'KnowledgeScopeSummary': !knowledgePackEnabled
                ? 'Knowledge Pack is unavailable.'
                : !scopesAvailable
                ? 'Status unavailable.'
                : profileScopes.isEmpty
                ? 'No Knowledge Scopes target this profile.'
                : '${profileScopes.length} Knowledge Scope${profileScopes.length == 1 ? '' : 's'} ${profileScopes.length == 1 ? 'targets' : 'target'} this profile.',
          });
          return row;
        })
        .toList(growable: false);
    return Result<AcpRowPage>.success(
      _copyPage(page, rows: rows, warning: warning),
    );
  }

  Future<Result<AcpRowPage>> _enrichIngressAssignments({
    required AcpRowPage page,
    required String? tenantId,
  }) async {
    final profileResult = await _fetchByIds(
      entitySet: 'ServiceProfiles',
      field: 'Id',
      ids: _fieldIds(page.items, 'ServiceProfileId'),
      tenantId: tenantId,
    );
    final bindingResult = await _fetchByIds(
      entitySet: 'IngressBindings',
      field: 'Id',
      ids: _fieldIds(page.items, 'IngressBindingId'),
      tenantId: tenantId,
    );
    if (profileResult.isFailure || bindingResult.isFailure) {
      return Result<AcpRowPage>.success(
        _copyPage(
          page,
          rows: page.items
              .map(
                (source) => <String, dynamic>{
                  ...source,
                  'AssignmentState': 'Status unavailable',
                },
              )
              .toList(growable: false),
          warning:
              'Ingress assignment context could not be determined. Refresh to retry.',
        ),
      );
    }
    final enrichedBindings = await _enrichBindingRows(
      bindingResult.data!,
      tenantId: tenantId,
    );
    final profiles = _byId(profileResult.data!);
    final bindings = _byId(enrichedBindings.rows);
    final rows = page.items
        .map((source) {
          final row = Map<String, dynamic>.from(source);
          final profile = profiles[_text(row['ServiceProfileId'])];
          final binding = bindings[_text(row['IngressBindingId'])];
          row.addAll(<String, dynamic>{
            'ServiceProfile': profile,
            'ServiceProfileLabel': _profileLabel(profile),
            'IngressBinding': binding,
            'EndpointLabel': _endpointLabel(binding),
            'PlatformChannel': binding?['PlatformChannel'] ?? 'Unavailable',
            'ClientProfileLabel':
                binding?['ClientProfileLabel'] ?? 'Not assigned',
            'ServiceRoute': binding?['ServiceRoute'] ?? 'Not assigned',
            'AssignmentState': serviceProfileIngressAssignmentState(
              assignment: row,
              binding: binding,
            ),
          });
          return row;
        })
        .toList(growable: false);
    return Result<AcpRowPage>.success(
      _copyPage(
        page,
        rows: rows,
        warning: _mergeWarning(page.referenceWarning, enrichedBindings.warning),
      ),
    );
  }

  Future<Result<AcpRowPage>> _enrichSubscriptionAssignments({
    required AcpRowPage page,
    required String? tenantId,
  }) async {
    final profileResult = await _fetchByIds(
      entitySet: 'ServiceProfiles',
      field: 'Id',
      ids: _fieldIds(page.items, 'ServiceProfileId'),
      tenantId: tenantId,
    );
    final subscriptionResult = await _fetchByIds(
      entitySet: 'BillingSubscriptions',
      field: 'Id',
      ids: _fieldIds(page.items, 'BillingSubscriptionId'),
      tenantId: tenantId,
      expansions: _billingSubscriptionExpansions,
    );
    final profiles = profileResult.isSuccess
        ? _byId(profileResult.data!)
        : <String, AcpRow>{};
    final subscriptions = subscriptionResult.isSuccess
        ? _byId(subscriptionResult.data!)
        : <String, AcpRow>{};
    final contextAvailable =
        profileResult.isSuccess && subscriptionResult.isSuccess;
    final rows = page.items
        .map((source) {
          final row = Map<String, dynamic>.from(source);
          final profile = profiles[_text(row['ServiceProfileId'])];
          final subscription =
              subscriptions[_text(row['BillingSubscriptionId'])];
          _annotateSubscriptionAssignment(
            row,
            profile: profile,
            subscription: subscription,
          );
          if (!contextAvailable) {
            row['AccessState'] = 'Status unavailable';
          }
          return row;
        })
        .toList(growable: false);
    return Result<AcpRowPage>.success(
      _copyPage(
        page,
        rows: rows,
        warning: contextAvailable
            ? page.referenceWarning
            : _mergeWarning(
                page.referenceWarning,
                'Commercial assignment context could not be determined. Refresh before activation.',
              ),
      ),
    );
  }

  Future<Result<AcpRowPage>> _enrichIngressSelector({
    required AcpRowPage page,
    required String? tenantId,
    required Map<String, dynamic> context,
  }) async {
    final enriched = await _enrichBindingRows(page.items, tenantId: tenantId);
    final assignmentsResult = await _fetchByIds(
      entitySet: 'ServiceProfileIngressBindings',
      field: 'IngressBindingId',
      ids: _ids(page.items),
      tenantId: tenantId,
      extraFilters: const <String>['IsActive eq true'],
    );
    final assignments = assignmentsResult.data ?? const <AcpRow>[];
    final profileResult = await _fetchByIds(
      entitySet: 'ServiceProfiles',
      field: 'Id',
      ids: _fieldIds(assignments, 'ServiceProfileId'),
      tenantId: tenantId,
    );
    final profiles = profileResult.data == null
        ? <String, AcpRow>{}
        : _byId(profileResult.data!);
    final selectedProfileId = _text(context['ServiceProfileId']);
    final rows = enriched.rows
        .map((source) {
          final row = Map<String, dynamic>.from(source);
          final assignment = assignments.cast<AcpRow?>().firstWhere(
            (item) => _text(item?['IngressBindingId']) == row.id,
            orElse: () => null,
          );
          var blocked = '';
          if (assignment != null) {
            final assignedProfileId = _text(assignment['ServiceProfileId']);
            blocked = assignedProfileId == selectedProfileId
                ? 'Already assigned to the selected profile.'
                : 'Actively assigned to ${_profileLabel(profiles[assignedProfileId])}.';
          }
          row.addAll(<String, dynamic>{
            'SelectionBlockedReason': blocked,
            'AssignmentAvailability': blocked.isEmpty
                ? 'Available for assignment'
                : blocked,
          });
          return row;
        })
        .toList(growable: false);
    final warning = assignmentsResult.isFailure || profileResult.isFailure
        ? 'Existing endpoint assignments could not be determined reliably.'
        : enriched.warning;
    return Result<AcpRowPage>.success(
      _copyPage(page, rows: rows, warning: warning),
    );
  }

  Future<Result<AcpRowPage>> _enrichSubscriptionSelector({
    required AcpRowPage page,
    required String? tenantId,
    required Map<String, dynamic> context,
  }) async {
    final subscriptionIds = _ids(page.items);
    final selectedProfileId = _text(context['ServiceProfileId']);
    final exactResult = await _fetchByIds(
      entitySet: 'ServiceProfileSubscriptions',
      field: 'BillingSubscriptionId',
      ids: subscriptionIds,
      tenantId: tenantId,
      extraFilters: const <String>["Status eq 'active'"],
    );
    var activeAssignments = exactResult.data ?? <AcpRow>[];
    if (selectedProfileId.isNotEmpty) {
      final profileResult = await _fetchAll(
        descriptor: _descriptor('ServiceProfileSubscriptions'),
        tenantId: tenantId,
        extraFilters: <String>[
          "ServiceProfileId eq guid'$selectedProfileId'",
          "Status eq 'active'",
        ],
      );
      if (profileResult.isSuccess) {
        activeAssignments = _uniqueRows(<AcpRow>[
          ...activeAssignments,
          ...profileResult.data!,
        ]);
      }
    }
    final profileResult = await _fetchByIds(
      entitySet: 'ServiceProfiles',
      field: 'Id',
      ids: _fieldIds(activeAssignments, 'ServiceProfileId'),
      tenantId: tenantId,
    );
    final profiles = profileResult.data == null
        ? <String, AcpRow>{}
        : _byId(profileResult.data!);
    final rows = page.items
        .map((source) {
          final row = Map<String, dynamic>.from(source);
          final product = _map(_map(row['Price'])?['Product']);
          final productCode = _lower(product?['Code']);
          final exactAssignment = activeAssignments.cast<AcpRow?>().firstWhere(
            (item) => _text(item?['BillingSubscriptionId']) == row.id,
            orElse: () => null,
          );
          final duplicateProduct =
              selectedProfileId.isEmpty || productCode.isEmpty
              ? null
              : activeAssignments.cast<AcpRow?>().firstWhere(
                  (item) =>
                      _text(item?['ServiceProfileId']) == selectedProfileId &&
                      _lower(item?['ProductCode']) == productCode,
                  orElse: () => null,
                );
          var blocked = '';
          if (exactAssignment != null) {
            final profileId = _text(exactAssignment['ServiceProfileId']);
            blocked = profileId == selectedProfileId
                ? 'This Subscription is already assigned to the selected profile.'
                : 'This Subscription is assigned to ${_profileLabel(profiles[profileId])}.';
          } else if (duplicateProduct != null) {
            blocked =
                'The selected profile already has an active assignment for this Product.';
          }
          final draft = <String, dynamic>{
            'Status': 'draft',
            'TenantId': tenantId,
          };
          final readiness = serviceProfileSubscriptionAccessState(
            assignment: draft,
            subscription: row,
          );
          _annotateSubscriptionReference(row);
          row.addAll(<String, dynamic>{
            'SelectionBlockedReason': blocked,
            'AssignmentAvailability': blocked.isNotEmpty
                ? blocked
                : readiness == 'Draft assignment'
                ? 'Available for draft assignment'
                : '$readiness; activation is unavailable until resolved.',
          });
          return row;
        })
        .toList(growable: false);
    final warning = exactResult.isFailure || profileResult.isFailure
        ? 'Existing Product assignments could not be determined reliably.'
        : page.referenceWarning;
    return Result<AcpRowPage>.success(
      _copyPage(page, rows: rows, warning: warning),
    );
  }

  Future<({List<AcpRow> rows, String? warning})> _enrichBindingRows(
    List<AcpRow> sources, {
    required String? tenantId,
  }) async {
    final profileResult = await _fetchByIds(
      entitySet: 'ChannelProfiles',
      field: 'Id',
      ids: _fieldIds(sources, 'ChannelProfileId'),
      tenantId: tenantId,
    );
    final channelProfiles = profileResult.data == null
        ? <String, AcpRow>{}
        : _byId(profileResult.data!);
    final clientResult = await _fetchByIds(
      entitySet: 'MessagingClientProfiles',
      field: 'Id',
      ids: _fieldIds(channelProfiles.values.toList(), 'ClientProfileId'),
      tenantId: tenantId,
    );
    final clients = clientResult.data == null
        ? <String, AcpRow>{}
        : _byId(clientResult.data!);
    final rows = sources
        .map((source) {
          final row = Map<String, dynamic>.from(source);
          final channelProfile =
              channelProfiles[_text(row['ChannelProfileId'])];
          final client = clients[_text(channelProfile?['ClientProfileId'])];
          final channel = _firstText(<Object?>[
            row['ChannelKey'],
            channelProfile?['ChannelKey'],
          ]);
          final platform = _firstText(<Object?>[
            client?['PlatformKey'],
            channelProfile?['ChannelKey'],
            channel,
          ]);
          final platformChannel = platform.isEmpty || platform == channel
              ? channel
              : '$platform / $channel';
          final clientLabel = _firstText(<Object?>[
            client?['DisplayName'],
            client?['ProfileKey'],
            channelProfile?['DisplayName'],
          ]);
          final route = _firstText(<Object?>[
            row['ServiceRouteKey'],
            channelProfile?['ServiceRouteDefaultKey'],
            channelProfile?['RouteDefaultKey'],
          ]);
          row.addAll(<String, dynamic>{
            'ChannelProfile': channelProfile,
            'ClientProfile': client,
            'EndpointLabel': _endpointLabel(row),
            'PlatformChannel': platformChannel.isEmpty
                ? 'Unavailable'
                : platformChannel,
            'ClientProfileLabel': clientLabel.isEmpty
                ? 'Not assigned'
                : clientLabel,
            'ServiceRoute': route.isEmpty ? 'Not assigned' : route,
            'EndpointContext': <String>[
              if (platformChannel.isNotEmpty) platformChannel,
              if (clientLabel.isNotEmpty) clientLabel,
              if (route.isNotEmpty) 'Route: $route',
            ].join('  |  '),
          });
          return row;
        })
        .toList(growable: false);
    return (
      rows: rows,
      warning: profileResult.isFailure || clientResult.isFailure
          ? 'Some endpoint channel or client context is unavailable.'
          : null,
    );
  }

  void _annotateSubscriptionAssignment(
    AcpRow row, {
    required AcpRow? profile,
    required AcpRow? subscription,
  }) {
    _annotateSubscriptionReference(subscription);
    final account = _map(subscription?['Account']);
    final price = _map(subscription?['Price']);
    final product = _map(price?['Product']);
    row.addAll(<String, dynamic>{
      'ServiceProfile': profile,
      'ServiceProfileLabel': _profileLabel(profile),
      'BillingSubscription': subscription,
      'SubscriptionLabel': _subscriptionLabel(subscription),
      'ProductLabel': _productLabel(product),
      'PriceLabel': _priceLabel(price),
      'AccountLabel': _accountLabel(account),
      '_AccountId': account?['Id'],
      '_PriceId': price?['Id'],
      '_ProductId': product?['Id'],
      'SubscriptionStatus': subscription?['Status'] ?? 'Unavailable',
      'AccessState': serviceProfileSubscriptionAccessState(
        assignment: row,
        subscription: subscription,
      ),
      'CurrentPeriod': serviceProfileCurrentPeriod(subscription),
    });
  }

  void _annotateSubscriptionReference(AcpRow? row) {
    if (row == null) {
      return;
    }
    final account = _map(row['Account']);
    final price = _map(row['Price']);
    final product = _map(price?['Product']);
    row.addAll(<String, dynamic>{
      'SubscriptionLabel': _subscriptionLabel(row),
      'SubscriptionContext':
          <String>[
                _accountLabel(account),
                _productLabel(product),
                _priceLabel(price),
                _text(row['Status']),
                serviceProfileCurrentPeriod(row),
              ]
              .where((value) => value.isNotEmpty && value != 'Unavailable')
              .join('  |  '),
    });
  }

  Future<Result<List<AcpRow>>> _fetchByIds({
    required String entitySet,
    required String field,
    required Set<String> ids,
    required String? tenantId,
    List<String> extraFilters = const <String>[],
    List<AcpExpandDescriptor> expansions = const <AcpExpandDescriptor>[],
  }) {
    if (ids.isEmpty) {
      return Future<Result<List<AcpRow>>>.value(
        const Result<List<AcpRow>>.success(<AcpRow>[]),
      );
    }
    final idFilter = ids.map((id) => "$field eq guid'$id'").join(' or ');
    return _fetchAll(
      descriptor: _descriptor(entitySet, expansions: expansions),
      tenantId: tenantId,
      extraFilters: <String>['($idFilter)', ...extraFilters],
    );
  }

  Future<Result<List<AcpRow>>> _fetchAll({
    required AcpResourceDescriptor descriptor,
    required String? tenantId,
    required List<String> extraFilters,
  }) async {
    const pageSize = 500;
    final rows = <AcpRow>[];
    var page = 1;
    while (true) {
      final result = await delegate.listRows(
        descriptor: descriptor,
        pageRequest: PageRequest(page: page, pageSize: pageSize),
        tenantId: tenantId,
        extraFilters: extraFilters,
      );
      if (result.isFailure) {
        return Result<List<AcpRow>>.failure(result.failure!);
      }
      rows.addAll(result.data!.items);
      if (rows.length >= result.data!.total || result.data!.items.isEmpty) {
        return Result<List<AcpRow>>.success(rows);
      }
      page += 1;
    }
  }

  AcpResourceDescriptor _descriptor(
    String entitySet, {
    List<AcpExpandDescriptor> expansions = const <AcpExpandDescriptor>[],
  }) {
    return AcpResourceDescriptor(
      key: 'service-profile-related-$entitySet',
      title: entitySet,
      entitySet: entitySet,
      scopeMode: _globalEntitySets.contains(entitySet)
          ? AcpScopeMode.none
          : AcpScopeMode.required,
      keyLiteralType: AcpFilterLiteralType.guid,
      columns: const <AcpColumnDescriptor>[],
      pageSize: 500,
      expansions: expansions,
    );
  }

  @override
  Future<Result<Object?>> createRow({
    required AcpResourceDescriptor descriptor,
    required Map<String, dynamic> values,
    String? tenantId,
  }) => delegate.createRow(
    descriptor: descriptor,
    values: values,
    tenantId: tenantId,
  );

  @override
  Future<Result<Object?>> updateRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) => delegate.updateRow(
    descriptor: descriptor,
    rowId: rowId,
    values: values,
    tenantId: tenantId,
    rowVersion: rowVersion,
  );

  @override
  Future<Result<void>> deleteRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) => delegate.deleteRow(
    descriptor: descriptor,
    rowId: rowId,
    tenantId: tenantId,
    rowVersion: rowVersion,
  );

  @override
  Future<Result<void>> restoreRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) => delegate.restoreRow(
    descriptor: descriptor,
    rowId: rowId,
    tenantId: tenantId,
    rowVersion: rowVersion,
  );

  @override
  Future<Result<Object?>> runCollectionAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
    String? tenantId,
  }) => delegate.runCollectionAction(
    descriptor: descriptor,
    action: action,
    values: values,
    tenantId: tenantId,
  );

  @override
  Future<Result<Object?>> runEntityAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) => delegate.runEntityAction(
    descriptor: descriptor,
    action: action,
    rowId: rowId,
    values: values,
    tenantId: tenantId,
    rowVersion: rowVersion,
  );
}

const List<AcpExpandDescriptor> _billingSubscriptionExpansions =
    <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'Account',
        selectFields: <String>[
          'Id',
          'TenantId',
          'DisplayName',
          'Code',
          'DeletedAt',
        ],
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
    ];

const Set<String> _globalEntitySets = <String>{
  'BillingPrices',
  'BillingProducts',
};

const Set<String> _customReferenceEntitySets = <String>{
  'ServiceProfileIngressBindings',
  'ServiceProfileSubscriptions',
};

AcpRowPage _copyPage(
  AcpRowPage source, {
  required List<AcpRow> rows,
  String? warning,
}) {
  return AcpRowPage(
    items: rows,
    total: source.total,
    page: source.page,
    pageSize: source.pageSize,
    referenceWarning: _mergeWarning(source.referenceWarning, warning),
  );
}

Map<String, AcpRow> _byId(Iterable<AcpRow> rows) => <String, AcpRow>{
  for (final row in rows)
    if ((row.id ?? '').isNotEmpty) row.id!: row,
};

Set<String> _ids(Iterable<AcpRow> rows) => rows
    .map((row) => row.id)
    .whereType<String>()
    .where((id) => id.isNotEmpty)
    .toSet();

Set<String> _fieldIds(Iterable<AcpRow> rows, String field) =>
    rows.map((row) => _text(row[field])).where((id) => id.isNotEmpty).toSet();

List<AcpRow> _uniqueRows(Iterable<AcpRow> rows) {
  final seen = <String>{};
  return rows
      .where((row) => seen.add(row.id ?? row.toString()))
      .toList(growable: false);
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

String _profileLabel(AcpRow? profile) {
  if (profile == null) {
    return 'Unavailable profile';
  }
  final displayName = _text(profile['DisplayName']);
  final key = _text(profile['Key']);
  if (displayName.isEmpty) {
    return key.isEmpty ? 'Unnamed profile' : key;
  }
  return key.isEmpty ? displayName : '$displayName ($key)';
}

String _endpointLabel(AcpRow? binding) {
  if (binding == null) {
    return 'Unavailable endpoint';
  }
  final channel = _text(binding['ChannelKey']);
  final type = _text(binding['IdentifierType']);
  final value = _text(binding['IdentifierValue']);
  final identifier = <String>[
    if (type.isNotEmpty) type,
    if (value.isNotEmpty) value,
  ].join(': ');
  return <String>[
    if (channel.isNotEmpty) channel,
    if (identifier.isNotEmpty) identifier,
  ].join(' · ');
}

String _subscriptionLabel(AcpRow? subscription) {
  if (subscription == null) {
    return 'Unavailable Subscription';
  }
  final externalRef = _text(subscription['ExternalRef']);
  final account = _accountLabel(_map(subscription['Account']));
  final product = _productLabel(_map(_map(subscription['Price'])?['Product']));
  if (externalRef.isNotEmpty) {
    return externalRef;
  }
  final label = <String>[
    if (account != 'Unavailable') account,
    if (product != 'Unavailable') product,
  ].join(' · ');
  return label.isEmpty ? _text(subscription['Id']) : label;
}

String _accountLabel(AcpRow? account) {
  if (account == null) {
    return 'Unavailable';
  }
  return _firstText(<Object?>[
    account['DisplayName'],
    account['Code'],
    account['Id'],
  ]);
}

String _priceLabel(AcpRow? price) {
  if (price == null) {
    return 'Unavailable';
  }
  final code = _text(price['Code']);
  final currency = _text(price['Currency']);
  return <String>[
    if (code.isNotEmpty) code,
    if (currency.isNotEmpty) currency,
  ].join(' · ');
}

String _productLabel(AcpRow? product) {
  if (product == null) {
    return 'Unavailable';
  }
  final name = _text(product['Name']);
  final code = _text(product['Code']);
  if (name.isEmpty) {
    return code;
  }
  return code.isEmpty ? name : '$name ($code)';
}

String _firstText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

String _text(Object? value) => value?.toString().trim() ?? '';
String _lower(Object? value) => _text(value).toLowerCase();

String? _mergeWarning(String? first, String? second) {
  final values = <String>{
    if (first?.trim().isNotEmpty == true) first!.trim(),
    if (second?.trim().isNotEmpty == true) second!.trim(),
  };
  return values.isEmpty ? null : values.join(' ');
}
