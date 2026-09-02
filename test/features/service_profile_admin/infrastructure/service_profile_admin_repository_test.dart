import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/service_profile_admin/application/service_profile_admin_resources.dart';
import 'package:mugen_ui/features/service_profile_admin/infrastructure/service_profile_admin_repository.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

import '../../../test_support/fake_acp_admin_repository.dart';

void main() {
  late _FixtureRepository delegate;
  late ServiceProfileAdminRepository repository;
  late List<AcpResourceDescriptor> descriptors;

  setUp(() {
    delegate = _FixtureRepository();
    repository = ServiceProfileAdminRepository(
      delegate: delegate,
      channelOrchestrationEnabled: true,
      billingEnabled: true,
      knowledgePackEnabled: true,
    );
    descriptors = buildServiceProfileAdminResources(
      channelOrchestrationEnabled: true,
      billingEnabled: true,
      knowledgePackEnabled: true,
    );
  });

  test('profiles receive batched readiness, counts, and summaries', () async {
    final result = await repository.listRows(
      descriptor: descriptors[0],
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: _tenant,
    );
    expect(result.isSuccess, isTrue);
    final profile = result.data!.items.firstWhere(
      (row) => row['Id'] == _profileOne,
    );
    expect(profile['Readiness'], 'Active and routable');
    expect(profile['ActiveIngressCount'], 1);
    expect(profile['ActiveProductCount'], 1);
    expect(profile['IngressSummary'], contains('route.one'));
    expect(profile['ProductSummary'], contains('product'));
    expect(
      profile['KnowledgeScopeSummary'],
      '1 Knowledge Scope targets this profile.',
    );
    expect(
      delegate.requestedEntitySets,
      containsAll(<String>[
        'ServiceProfiles',
        'ServiceProfileIngressBindings',
        'IngressBindings',
        'ServiceProfileSubscriptions',
        'KnowledgeScopes',
      ]),
    );
  });

  test('profile enrichment exposes every readiness state', () async {
    final result = await repository.listRows(
      descriptor: descriptors[0],
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: _tenant,
    );
    final byId = <String, AcpRow>{
      for (final row in result.data!.items) row['Id'].toString(): row,
    };
    expect(byId[_profileTwo]?['Readiness'], 'Draft profile');
    expect(byId[_profileThree]?['Readiness'], 'Disabled');

    delegate.rows['ServiceProfiles'] = <AcpRow>[
      _profile(_profileMissing, 'active'),
    ];
    delegate.rows['ServiceProfileIngressBindings'] = const <AcpRow>[];
    final missing = await repository.listRows(
      descriptor: descriptors[0],
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: _tenant,
    );
    expect(missing.data!.items.single['Readiness'], 'Missing active ingress');

    delegate.rows['ServiceProfileIngressBindings'] = <AcpRow>[
      _ingressAssignment('inactive', _profileMissing, _bindingTwo, false),
    ];
    final inactive = await repository.listRows(
      descriptor: descriptors[0],
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: _tenant,
    );
    expect(
      inactive.data!.items.single['Readiness'],
      'Inactive ingress assignment',
    );
  });

  test(
    'ingress rows and selector include endpoint context and conflicts',
    () async {
      final assignments = await repository.listRows(
        descriptor: descriptors[1],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );
      final active = assignments.data!.items.firstWhere(
        (row) => row['Id'] == _ingressOne,
      );
      expect(active['ServiceProfileLabel'], 'Primary (primary)');
      expect(active['PlatformChannel'], 'generic / channel');
      expect(active['ClientProfileLabel'], 'Client One');
      expect(active['ServiceRoute'], 'route.one');
      expect(active['AssignmentState'], 'Active endpoint assignment');
      expect(active['IngressBinding'], isA<Map>());

      final selector = await repository.listRows(
        descriptor: AcpResourceDescriptor(
          key: 'selector',
          title: 'Ingress',
          entitySet: 'IngressBindings',
          scopeMode: AcpScopeMode.required,
          columns: const <AcpColumnDescriptor>[],
          referenceContext: const <String, dynamic>{
            'ServiceProfileId': _profileTwo,
          },
        ),
        pageRequest: const PageRequest(page: 1, pageSize: 20),
        tenantId: _tenant,
      );
      final assigned = selector.data!.items.firstWhere(
        (row) => row['Id'] == _bindingOne,
      );
      expect(assigned['EndpointLabel'], contains('endpoint-one'));
      expect(
        assigned['SelectionBlockedReason'],
        'Actively assigned to Primary (primary).',
      );
      expect(assigned['AssignmentAvailability'], contains('Actively assigned'));

      final sameProfileSelector = await repository.listRows(
        descriptor: AcpResourceDescriptor(
          key: 'selector',
          title: 'Ingress',
          entitySet: 'IngressBindings',
          scopeMode: AcpScopeMode.required,
          columns: const <AcpColumnDescriptor>[],
          referenceContext: const <String, dynamic>{
            'ServiceProfileId': _profileOne,
          },
        ),
        pageRequest: const PageRequest(page: 1, pageSize: 20),
        tenantId: _tenant,
      );
      expect(
        sameProfileSelector.data!.items.firstWhere(
          (row) => row['Id'] == _bindingOne,
        )['SelectionBlockedReason'],
        'Already assigned to the selected profile.',
      );
    },
  );

  test(
    'Subscription rows expose commercial references and failure states',
    () async {
      final result = await repository.listRows(
        descriptor: descriptors[2],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
        deletedView: AcpDeletedView.all,
      );
      final active = result.data!.items.firstWhere(
        (row) => row['Id'] == _assignmentOne,
      );
      expect(active['AccessState'], 'Active Product access');
      expect(active['SubscriptionStatus'], 'active');
      expect(active['AccountLabel'], 'Account One');
      expect(active['PriceLabel'], 'price-one · USD');
      expect(active['ProductLabel'], 'Product One (product)');
      expect(active['_AccountId'], _accountOne);
      expect(active['_PriceId'], _priceOne);
      expect(active['_ProductId'], _productOne);
      expect(active['CurrentPeriod'], contains('2027'));
      expect(active['BillingSubscription'], isA<Map>());
    },
  );

  test(
    'Subscription selector identifies assignment and Product conflicts',
    () async {
      final selectorDescriptor = AcpResourceDescriptor(
        key: 'subscription-selector',
        title: 'Subscriptions',
        entitySet: 'BillingSubscriptions',
        scopeMode: AcpScopeMode.required,
        columns: const <AcpColumnDescriptor>[],
        referenceContext: const <String, dynamic>{
          'ServiceProfileId': _profileOne,
        },
      );
      final result = await repository.listRows(
        descriptor: selectorDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 20),
        tenantId: _tenant,
      );
      final byId = <String, AcpRow>{
        for (final row in result.data!.items) row['Id'].toString(): row,
      };
      expect(
        byId[_subscriptionOne]?['SelectionBlockedReason'],
        'This Subscription is already assigned to the selected profile.',
      );
      expect(
        byId[_subscriptionTwo]?['SelectionBlockedReason'],
        'The selected profile already has an active assignment for this Product.',
      );
      expect(
        byId[_subscriptionThree]?['AssignmentAvailability'],
        contains('Subscription paused or cancelled'),
      );
      expect(
        byId[_subscriptionFour]?['SelectionBlockedReason'],
        'This Subscription is assigned to Draft (draft).',
      );
      expect(byId[_subscriptionThree]?['SubscriptionLabel'], isNotEmpty);
      expect(
        byId[_subscriptionThree]?['SubscriptionContext'],
        contains('paused'),
      );
    },
  );

  test(
    'related failures preserve usable rows with explicit warnings',
    () async {
      delegate.failEntitySets.addAll(<String>{
        'ServiceProfileIngressBindings',
        'ServiceProfileSubscriptions',
        'KnowledgeScopes',
      });
      final profiles = await repository.listRows(
        descriptor: descriptors[0],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );
      expect(profiles.isSuccess, isTrue);
      expect(profiles.data!.referenceWarning, contains('Ingress readiness'));
      expect(profiles.data!.referenceWarning, contains('Product access'));
      expect(profiles.data!.referenceWarning, contains('Knowledge Scope'));
      expect(
        profiles.data!.items.firstWhere(
          (row) => row['Id'] == _profileOne,
        )['Readiness'],
        'Status unavailable',
      );

      delegate.failEntitySets
        ..clear()
        ..add('IngressBindings');
      final ingress = await repository.listRows(
        descriptor: descriptors[1],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );
      expect(
        ingress.data!.referenceWarning,
        contains('could not be determined'),
      );
      expect(
        ingress.data!.items.first['AssignmentState'],
        'Status unavailable',
      );

      delegate.failEntitySets
        ..clear()
        ..add('BillingSubscriptions');
      final subscriptions = await repository.listRows(
        descriptor: descriptors[2],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );
      expect(subscriptions.data!.referenceWarning, contains('Commercial'));
      expect(
        subscriptions.data!.items.first['AccessState'],
        'Status unavailable',
      );
    },
  );

  test(
    'relationship hydration uses supported active views without generic warnings',
    () async {
      delegate
        ..rejectHistoricalEntitySets.addAll(<String>{
          'ServiceProfiles',
          'ServiceProfileSubscriptions',
          'BillingSubscriptions',
        })
        ..emitGenericReferenceWarning = true;

      final profiles = await repository.listRows(
        descriptor: descriptors[0],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );
      final ingress = await repository.listRows(
        descriptor: descriptors[1],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );
      final subscriptions = await repository.listRows(
        descriptor: descriptors[2],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );

      expect(profiles.data!.items.first['ActiveProductCount'], 1);
      expect(
        ingress.data!.items.first['ServiceProfileLabel'],
        'Primary (primary)',
      );
      expect(
        subscriptions.data!.items.first['ProductLabel'],
        'Product One (product)',
      );
      expect(ingress.data!.referenceWarning, isNull);
      expect(subscriptions.data!.referenceWarning, isNull);
      expect(
        delegate.requestedDeletedViews.entries
            .where(
              (entry) =>
                  delegate.rejectHistoricalEntitySets.contains(entry.key),
            )
            .expand((entry) => entry.value),
        everyElement(AcpDeletedView.active),
      );
    },
  );

  test('fetch and mutations retain the ACP repository contract', () async {
    expect((await repository.fetchTenants(top: 25)).data, hasLength(2));

    final fetched = await repository.fetchRow(
      descriptor: descriptors[0],
      rowId: _profileOne,
      tenantId: _tenant,
    );
    expect(fetched.data?['Readiness'], 'Active and routable');

    delegate.fetchFailures.add('ServiceProfiles');
    expect(
      (await repository.fetchRow(
        descriptor: descriptors[0],
        rowId: _profileOne,
        tenantId: _tenant,
      )).isFailure,
      isTrue,
    );
    delegate.fetchFailures.clear();

    await repository.createRow(
      descriptor: descriptors[0],
      values: <String, dynamic>{'Key': 'new'},
      tenantId: _tenant,
    );
    await repository.updateRow(
      descriptor: descriptors[0],
      rowId: _profileOne,
      values: <String, dynamic>{'DisplayName': 'Updated'},
      tenantId: _tenant,
      rowVersion: 2,
    );
    await repository.deleteRow(
      descriptor: descriptors[0],
      rowId: _profileOne,
      tenantId: _tenant,
      rowVersion: 2,
    );
    await repository.restoreRow(
      descriptor: descriptors[0],
      rowId: _profileOne,
      tenantId: _tenant,
      rowVersion: 2,
    );
    await repository.runCollectionAction(
      descriptor: descriptors[0],
      action: const AcpActionDescriptor(
        name: 'noop',
        label: 'Noop',
        target: AcpActionTarget.collection,
      ),
      values: const <String, dynamic>{},
      tenantId: _tenant,
    );
    await repository.runEntityAction(
      descriptor: descriptors[0],
      action: descriptors[0].entityActions.first,
      rowId: _profileOne,
      values: const <String, dynamic>{},
      tenantId: _tenant,
      rowVersion: 2,
    );
    expect(delegate.createPayloads, isNotEmpty);
    expect(delegate.updatePayloads, isNotEmpty);
    expect(delegate.entityActionNames, contains('activate'));
  });

  test(
    'disabled optional capabilities do not query unavailable resources',
    () async {
      final limited = ServiceProfileAdminRepository(
        delegate: delegate,
        channelOrchestrationEnabled: false,
        billingEnabled: false,
        knowledgePackEnabled: false,
      );
      final result = await limited.listRows(
        descriptor: buildServiceProfileAdminResources(
          channelOrchestrationEnabled: false,
          billingEnabled: false,
          knowledgePackEnabled: false,
        ).single,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );
      final profile = result.data!.items.first;
      expect(profile['IngressSummary'], contains('unavailable'));
      expect(profile['ProductSummary'], contains('unavailable'));
      expect(profile['KnowledgeScopeSummary'], contains('unavailable'));
    },
  );

  test('base list failures are returned unchanged', () async {
    delegate.failEntitySets.add('ServiceProfiles');
    final result = await repository.listRows(
      descriptor: descriptors[0],
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: _tenant,
    );
    expect(result.isFailure, isTrue);
  });

  test('empty and unrelated pages pass through without enrichment', () async {
    delegate.rows['ServiceProfiles'] = const <AcpRow>[];
    final empty = await repository.listRows(
      descriptor: descriptors[0],
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: _tenant,
    );
    expect(empty.data!.items, isEmpty);

    delegate.rows['OtherResources'] = <AcpRow>[
      <String, dynamic>{'Id': 'other-1'},
    ];
    final unrelated = await repository.listRows(
      descriptor: const AcpResourceDescriptor(
        key: 'other',
        title: 'Other',
        entitySet: 'OtherResources',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[],
      ),
      pageRequest: const PageRequest(page: 1, pageSize: 15),
    );
    expect(unrelated.data!.items.single['Id'], 'other-1');
  });

  test(
    'profile endpoint lookup failures remain explicitly unavailable',
    () async {
      delegate.failEntitySets.add('IngressBindings');
      final result = await repository.listRows(
        descriptor: descriptors[0],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );
      expect(result.data!.referenceWarning, contains('endpoint status'));
      expect(result.data!.items.first['Readiness'], 'Status unavailable');
    },
  );

  test(
    'assignment and selector relationship failures are diagnosable',
    () async {
      delegate.failEntitySets.add('ServiceProfiles');
      final subscriptions = await repository.listRows(
        descriptor: descriptors[2],
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: _tenant,
      );
      expect(subscriptions.data!.referenceWarning, contains('Commercial'));
      expect(
        subscriptions.data!.items.first['ServiceProfileLabel'],
        'Unavailable profile',
      );

      final ingressSelector = await repository.listRows(
        descriptor: const AcpResourceDescriptor(
          key: 'ingress-selector',
          title: 'Ingress',
          entitySet: 'IngressBindings',
          scopeMode: AcpScopeMode.required,
          columns: <AcpColumnDescriptor>[],
        ),
        pageRequest: const PageRequest(page: 1, pageSize: 20),
        tenantId: _tenant,
      );
      expect(ingressSelector.data!.referenceWarning, contains('reliably'));
      expect(
        ingressSelector.data!.items.firstWhere(
          (row) => row['Id'] == _bindingThree,
        )['SelectionBlockedReason'],
        isEmpty,
      );

      final subscriptionSelector = await repository.listRows(
        descriptor: const AcpResourceDescriptor(
          key: 'subscription-selector',
          title: 'Subscriptions',
          entitySet: 'BillingSubscriptions',
          scopeMode: AcpScopeMode.required,
          columns: <AcpColumnDescriptor>[],
          referenceContext: <String, dynamic>{'ServiceProfileId': _profileOne},
        ),
        pageRequest: const PageRequest(page: 1, pageSize: 20),
        tenantId: _tenant,
      );
      expect(subscriptionSelector.data!.referenceWarning, contains('reliably'));
    },
  );

  test('endpoint context failures retain safe fallback presentation', () async {
    delegate.failEntitySets.addAll(<String>{
      'ChannelProfiles',
      'MessagingClientProfiles',
    });
    final selector = await repository.listRows(
      descriptor: const AcpResourceDescriptor(
        key: 'ingress-selector',
        title: 'Ingress',
        entitySet: 'IngressBindings',
        scopeMode: AcpScopeMode.required,
        columns: <AcpColumnDescriptor>[],
      ),
      pageRequest: const PageRequest(page: 1, pageSize: 20),
      tenantId: _tenant,
    );
    expect(selector.data!.referenceWarning, contains('context is unavailable'));
    expect(selector.data!.items.first['ClientProfileLabel'], 'Not assigned');

    delegate.failEntitySets
      ..clear()
      ..add('MessagingClientProfiles');
    final clientFailure = await repository.listRows(
      descriptor: const AcpResourceDescriptor(
        key: 'ingress-selector',
        title: 'Ingress',
        entitySet: 'IngressBindings',
        scopeMode: AcpScopeMode.required,
        columns: <AcpColumnDescriptor>[],
      ),
      pageRequest: const PageRequest(page: 1, pageSize: 20),
      tenantId: _tenant,
    );
    expect(
      clientFailure.data!.referenceWarning,
      contains('context is unavailable'),
    );
  });

  test('fallback labels and multi-page related lookups are stable', () async {
    delegate.rows['ServiceProfiles'] = <AcpRow>[
      <String, dynamic>{
        'Id': _profileOne,
        'TenantId': _tenant,
        'Status': 'active',
      },
    ];
    delegate.rows['BillingSubscriptions'] = <AcpRow>[
      <String, dynamic>{
        'Id': _subscriptionOne,
        'TenantId': _tenant,
        'Status': 'active',
      },
    ];
    delegate.rows['ServiceProfileSubscriptions'] = <AcpRow>[
      <String, dynamic>{
        'Id': _assignmentOne,
        'TenantId': _tenant,
        'ServiceProfileId': _profileOne,
        'BillingSubscriptionId': _subscriptionOne,
        'Status': 'active',
      },
    ];
    final result = await repository.listRows(
      descriptor: descriptors[2],
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: _tenant,
    );
    expect(result.data!.items.single['ServiceProfileLabel'], 'Unnamed profile');
    expect(result.data!.items.single['SubscriptionLabel'], _subscriptionOne);

    delegate.simulateMultiplePages = true;
    await repository.listRows(
      descriptor: const AcpResourceDescriptor(
        key: 'subscription-selector',
        title: 'Subscriptions',
        entitySet: 'BillingSubscriptions',
        scopeMode: AcpScopeMode.required,
        columns: <AcpColumnDescriptor>[],
        referenceContext: <String, dynamic>{'ServiceProfileId': _profileOne},
      ),
      pageRequest: const PageRequest(page: 1, pageSize: 20),
      tenantId: _tenant,
    );
    expect(delegate.requestedPages, contains(2));
  });
}

class _FixtureRepository extends FakeAcpAdminRepository {
  _FixtureRepository() {
    rows.addAll(<String, List<AcpRow>>{
      'ServiceProfiles': <AcpRow>[
        _profile(_profileOne, 'active'),
        _profile(_profileTwo, 'draft'),
        _profile(_profileThree, 'disabled'),
      ],
      'ServiceProfileIngressBindings': <AcpRow>[
        _ingressAssignment(_ingressOne, _profileOne, _bindingOne, true),
        _ingressAssignment(_ingressTwo, _profileOne, _bindingTwo, false),
      ],
      'IngressBindings': <AcpRow>[
        <String, dynamic>{
          'Id': _bindingOne,
          'TenantId': _tenant,
          'ChannelProfileId': _channelProfile,
          'ChannelKey': 'channel',
          'IdentifierType': 'address',
          'IdentifierValue': 'endpoint-one',
          'ServiceRouteKey': 'route.one',
          'IsActive': true,
        },
        <String, dynamic>{
          'Id': _bindingTwo,
          'TenantId': _tenant,
          'ChannelKey': 'channel',
          'IdentifierType': 'address',
          'IdentifierValue': 'endpoint-two',
          'IsActive': false,
        },
        <String, dynamic>{
          'Id': _bindingThree,
          'TenantId': _tenant,
          'ChannelKey': 'channel',
          'IdentifierValue': 'endpoint-three',
          'IsActive': true,
        },
      ],
      'ChannelProfiles': <AcpRow>[
        <String, dynamic>{
          'Id': _channelProfile,
          'TenantId': _tenant,
          'ChannelKey': 'channel',
          'ClientProfileId': _clientProfile,
          'DisplayName': 'Channel Profile',
          'ServiceRouteDefaultKey': 'route.default',
        },
      ],
      'MessagingClientProfiles': <AcpRow>[
        <String, dynamic>{
          'Id': _clientProfile,
          'TenantId': _tenant,
          'PlatformKey': 'generic',
          'ProfileKey': 'client-one',
          'DisplayName': 'Client One',
        },
      ],
      'ServiceProfileSubscriptions': <AcpRow>[
        <String, dynamic>{
          'Id': _assignmentOne,
          'TenantId': _tenant,
          'ServiceProfileId': _profileOne,
          'BillingSubscriptionId': _subscriptionOne,
          'ProductCode': 'product',
          'Status': 'active',
        },
        <String, dynamic>{
          'Id': _assignmentTwo,
          'TenantId': _tenant,
          'ServiceProfileId': _profileTwo,
          'BillingSubscriptionId': _subscriptionFour,
          'ProductCode': 'other',
          'Status': 'active',
        },
      ],
      'BillingSubscriptions': <AcpRow>[
        _subscription(_subscriptionOne, 'active', 'product'),
        _subscription(_subscriptionTwo, 'active', 'product'),
        _subscription(_subscriptionThree, 'paused', 'other-two'),
        _subscription(_subscriptionFour, 'active', 'other'),
      ],
      'KnowledgeScopes': <AcpRow>[
        <String, dynamic>{
          'Id': 'scope-one',
          'TenantId': _tenant,
          'ServiceProfileId': _profileOne,
        },
      ],
    });
  }

  final Map<String, List<AcpRow>> rows = <String, List<AcpRow>>{};
  final Set<String> failEntitySets = <String>{};
  final Set<String> fetchFailures = <String>{};
  final Set<String> rejectHistoricalEntitySets = <String>{};
  final List<String> requestedEntitySets = <String>[];
  final List<int> requestedPages = <int>[];
  final Map<String, List<AcpDeletedView>> requestedDeletedViews =
      <String, List<AcpDeletedView>>{};
  bool emitGenericReferenceWarning = false;
  bool simulateMultiplePages = false;

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
    requestedEntitySets.add(descriptor.entitySet);
    requestedPages.add(pageRequest.page);
    requestedDeletedViews
        .putIfAbsent(descriptor.entitySet, () => <AcpDeletedView>[])
        .add(deletedView);
    if (failEntitySets.contains(descriptor.entitySet)) {
      return const Result<AcpRowPage>.failure(
        ApiFailure(503, 'related unavailable'),
      );
    }
    if (deletedView != AcpDeletedView.active &&
        rejectHistoricalEntitySets.contains(descriptor.entitySet)) {
      return const Result<AcpRowPage>.failure(
        ApiFailure(400, r'$deleted is not supported for this entity set.'),
      );
    }
    var matching = List<AcpRow>.from(
      rows[descriptor.entitySet] ?? const <AcpRow>[],
    );
    matching = _applyFilters(matching, extraFilters);
    if (simulateMultiplePages &&
        descriptor.entitySet == 'ServiceProfileSubscriptions' &&
        pageRequest.page == 1) {
      return Result<AcpRowPage>.success(
        AcpRowPage(
          items: matching,
          total: matching.length + 1,
          page: 1,
          pageSize: pageRequest.pageSize,
        ),
      );
    }
    if (simulateMultiplePages &&
        descriptor.entitySet == 'ServiceProfileSubscriptions' &&
        pageRequest.page == 2) {
      return Result<AcpRowPage>.success(
        AcpRowPage(
          items: const <AcpRow>[],
          total: matching.length + 1,
          page: 2,
          pageSize: pageRequest.pageSize,
        ),
      );
    }
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: matching,
        total: matching.length,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
        referenceWarning:
            emitGenericReferenceWarning &&
                enrichReferences &&
                const <String>{
                  'ServiceProfileIngressBindings',
                  'ServiceProfileSubscriptions',
                }.contains(descriptor.entitySet)
            ? 'Some reference labels could not be resolved.'
            : null,
      ),
    );
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    if (fetchFailures.contains(descriptor.entitySet)) {
      return const Result<AcpRow>.failure(ApiFailure(404, 'not found'));
    }
    final row = rows[descriptor.entitySet]?.firstWhere(
      (item) => item['Id'] == rowId,
    );
    return Result<AcpRow>.success(Map<String, dynamic>.from(row!));
  }
}

List<AcpRow> _applyFilters(List<AcpRow> rows, List<String> filters) {
  var matching = rows;
  for (final filter in filters) {
    final guidMatches = RegExp(
      r"(\w+) eq guid'([^']+)'",
    ).allMatches(filter).toList(growable: false);
    final fields = guidMatches.map((item) => item.group(1)!).toSet();
    for (final field in fields) {
      final values = guidMatches
          .where((item) => item.group(1) == field)
          .map((item) => item.group(2))
          .toSet();
      matching = matching
          .where((row) => values.contains(row[field]?.toString()))
          .toList(growable: false);
    }
    final stringMatch = RegExp(r"(\w+) eq '([^']+)'").firstMatch(filter);
    if (stringMatch != null) {
      matching = matching
          .where(
            (row) =>
                row[stringMatch.group(1)]?.toString() == stringMatch.group(2),
          )
          .toList(growable: false);
    }
  }
  return matching;
}

AcpRow _profile(String id, String status) => <String, dynamic>{
  'Id': id,
  'TenantId': _tenant,
  'Key': id == _profileOne ? 'primary' : status,
  'DisplayName': id == _profileOne ? 'Primary' : _capitalize(status),
  'Status': status,
  'RowVersion': 1,
};

AcpRow _ingressAssignment(
  String id,
  String profileId,
  String bindingId,
  bool active,
) => <String, dynamic>{
  'Id': id,
  'TenantId': _tenant,
  'ServiceProfileId': profileId,
  'IngressBindingId': bindingId,
  'IsActive': active,
};

AcpRow _subscription(String id, String status, String productCode) {
  final suffix = id.split('-').last;
  return <String, dynamic>{
    'Id': id,
    'TenantId': _tenant,
    'ExternalRef': 'subscription-$suffix',
    'Status': status,
    'CurrentPeriodStart': '2026-01-01T00:00:00Z',
    'CurrentPeriodEnd': '2027-01-01T00:00:00Z',
    'Account': <String, dynamic>{
      'Id': _accountOne,
      'TenantId': _tenant,
      'DisplayName': 'Account One',
      'Code': 'account-one',
    },
    'Price': <String, dynamic>{
      'Id': id == _subscriptionOne ? _priceOne : 'price-$suffix',
      'Code': id == _subscriptionOne ? 'price-one' : 'price-$suffix',
      'Currency': 'USD',
      'PriceType': 'recurring',
      'Product': <String, dynamic>{
        'Id': id == _subscriptionOne ? _productOne : 'product-$suffix',
        'Code': productCode,
        'Name': id == _subscriptionOne ? 'Product One' : 'Product $suffix',
      },
    },
  };
}

String _capitalize(String value) =>
    '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';

const String _tenant = '00000000-0000-0000-0000-000000000001';
const String _profileOne = '00000000-0000-0000-0000-000000000011';
const String _profileTwo = '00000000-0000-0000-0000-000000000012';
const String _profileThree = '00000000-0000-0000-0000-000000000013';
const String _profileMissing = '00000000-0000-0000-0000-000000000014';
const String _bindingOne = '00000000-0000-0000-0000-000000000021';
const String _bindingTwo = '00000000-0000-0000-0000-000000000022';
const String _bindingThree = '00000000-0000-0000-0000-000000000023';
const String _ingressOne = '00000000-0000-0000-0000-000000000031';
const String _ingressTwo = '00000000-0000-0000-0000-000000000032';
const String _channelProfile = '00000000-0000-0000-0000-000000000041';
const String _clientProfile = '00000000-0000-0000-0000-000000000051';
const String _assignmentOne = '00000000-0000-0000-0000-000000000061';
const String _assignmentTwo = '00000000-0000-0000-0000-000000000062';
const String _subscriptionOne = '00000000-0000-0000-0000-000000000071';
const String _subscriptionTwo = '00000000-0000-0000-0000-000000000072';
const String _subscriptionThree = '00000000-0000-0000-0000-000000000073';
const String _subscriptionFour = '00000000-0000-0000-0000-000000000074';
const String _accountOne = '00000000-0000-0000-0000-000000000081';
const String _priceOne = '00000000-0000-0000-0000-000000000091';
const String _productOne = '00000000-0000-0000-0000-000000000101';
