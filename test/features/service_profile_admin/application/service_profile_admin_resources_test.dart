import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/service_profile_admin/application/service_profile_admin_resources.dart';

void main() {
  test('capabilities gate ingress, billing, and Knowledge Scope links', () {
    final profilesOnly = buildServiceProfileAdminResources(
      channelOrchestrationEnabled: false,
      billingEnabled: false,
      knowledgePackEnabled: false,
    );
    expect(profilesOnly.map((item) => item.entitySet), <String>[
      'ServiceProfiles',
    ]);
    expect(
      profilesOnly.single.detailSections.expand((item) => item.links),
      isEmpty,
    );

    final all = buildServiceProfileAdminResources(
      channelOrchestrationEnabled: true,
      billingEnabled: true,
      knowledgePackEnabled: true,
    );
    expect(all.map((item) => item.entitySet), <String>[
      'ServiceProfiles',
      'ServiceProfileIngressBindings',
      'ServiceProfileSubscriptions',
    ]);
    expect(
      all.first.detailSections
          .expand((item) => item.links)
          .map((item) => item.targetResourceKey),
      containsAll(<String>[
        'service-profile-ingress-bindings',
        'service-profile-subscriptions',
        'knowledge-scopes',
      ]),
    );
  });

  test(
    'profile descriptor preserves immutable identity and managed actions',
    () {
      final descriptor = buildServiceProfileAdminResources(
        channelOrchestrationEnabled: true,
        billingEnabled: true,
        knowledgePackEnabled: true,
      ).first;
      expect(descriptor.allowCreate, isTrue);
      expect(descriptor.allowUpdate, isTrue);
      expect(descriptor.allowDelete, isFalse);
      expect(
        descriptor.columns.map((item) => item.key),
        containsAll(<String>[
          'Key',
          'DisplayName',
          'Status',
          'Readiness',
          'ActiveIngressCount',
          'ActiveProductCount',
          'ActivatedAt',
          'DisabledAt',
          'UpdatedAt',
        ]),
      );
      final key = descriptor.updateFields.firstWhere(
        (field) => field.key == 'Key',
      );
      expect(key.readOnly, isTrue);
      expect(key.includeInPayload, isFalse);
      expect(descriptor.entityActions.map((item) => item.name), <String>[
        'activate',
        'disable',
      ]);
      for (final action in descriptor.entityActions) {
        expect(action.includeRowVersion, isTrue);
        expect(action.confirmMessage, isNotEmpty);
      }
      expect(
        descriptor.entityActions.first.isVisibleFor(<String, dynamic>{
          'Status': 'draft',
        }),
        isTrue,
      );
      expect(
        descriptor.entityActions.last.isVisibleFor(<String, dynamic>{
          'Status': 'active',
        }),
        isTrue,
      );
    },
  );

  test(
    'assignment descriptors expose scoped context without mutable identity',
    () {
      final descriptors = buildServiceProfileAdminResources(
        channelOrchestrationEnabled: true,
        billingEnabled: true,
        knowledgePackEnabled: false,
      );
      final ingress = descriptors[1];
      final subscription = descriptors[2];

      expect(ingress.allowDelete, isFalse);
      expect(subscription.allowDelete, isFalse);
      expect(
        ingress.createFields
            .firstWhere((item) => item.key == 'IngressBindingId')
            .reference
            ?.disabledReasonField,
        'SelectionBlockedReason',
      );
      expect(
        ingress.filters
            .firstWhere((item) => item.key == 'ServiceProfileId')
            .reference
            ?.entitySet,
        'ServiceProfiles',
      );
      expect(subscription.createFields.map((item) => item.key), <String>[
        'ServiceProfileId',
        'BillingSubscriptionId',
        'Attributes',
      ]);
      final subscriptionReference = subscription.createFields
          .firstWhere((item) => item.key == 'BillingSubscriptionId')
          .reference!;
      expect(subscriptionReference.expansions, hasLength(2));
      expect(subscriptionReference.contextFieldsFromForm, <String, String>{
        'ServiceProfileId': 'ServiceProfileId',
      });
      expect(
        subscriptionReference.disabledReasonField,
        'SelectionBlockedReason',
      );
      expect(
        subscription.updateFields
            .where((item) => item.key != 'Attributes')
            .every((item) => item.readOnly && !item.includeInPayload),
        isTrue,
      );
      expect(subscription.entityActions.map((item) => item.name), <String>[
        'activate',
        'disable',
      ]);
      expect(
        subscription.description,
        'The Billing Account owns the Subscription. This assignment enables its Product for one Service Profile.',
      );
    },
  );

  test('Attributes validation accepts metadata and rejects unsafe keys', () {
    expect(validateServiceProfileAttributes(<String, dynamic>{}), isNull);
    expect(
      validateServiceProfileAttributes(<String, dynamic>{
        'Attributes': <String, dynamic>{
          'region': 'north',
          'labels': <Object>[
            <String, Object>{'priority': 1},
          ],
        },
      }),
      isNull,
    );
    expect(
      validateServiceProfileAttributes(<String, dynamic>{
        'Attributes': 'not-an-object',
      }),
      'Attributes must be a JSON object.',
    );
    expect(
      validateServiceProfileAttributes(<String, dynamic>{
        'Attributes': <String, dynamic>{
          'nested': <String, Object>{'api_token': 'unsafe'},
        },
      }),
      contains('nested.api_token'),
    );
  });

  test('descriptors stay upstream-generic', () {
    final descriptors = buildServiceProfileAdminResources(
      channelOrchestrationEnabled: true,
      billingEnabled: true,
      knowledgePackEnabled: true,
    );
    final text = <Object?>[
      for (final descriptor in descriptors) ...<Object?>[
        descriptor.title,
        descriptor.description,
        ...descriptor.columns.map((item) => item.label),
        ...descriptor.createFields.map((item) => item.label),
        ...descriptor.updateFields.map((item) => item.label),
        ...descriptor.entityActions.map((item) => item.confirmMessage),
      ],
    ].join(' ').toLowerCase();
    for (final forbidden in <String>[
      'valet',
      'customer inbox',
      'waba',
      'customer-facing',
      'staff-facing',
      'facing type',
    ]) {
      expect(text, isNot(contains(forbidden)));
    }
  });
}
