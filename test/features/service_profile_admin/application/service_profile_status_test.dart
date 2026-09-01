import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/service_profile_admin/application/service_profile_status.dart';

void main() {
  group('profile readiness', () {
    test('distinguishes lifecycle and ingress states', () {
      expect(
        serviceProfileReadiness(
          profile: <String, dynamic>{'Status': 'draft'},
          assignments: const <Map<String, dynamic>>[],
          bindings: const <String, Map<String, dynamic>>{},
          statusAvailable: true,
        ),
        'Draft profile',
      );
      expect(
        serviceProfileReadiness(
          profile: <String, dynamic>{'Status': 'disabled'},
          assignments: const <Map<String, dynamic>>[],
          bindings: const <String, Map<String, dynamic>>{},
          statusAvailable: true,
        ),
        'Disabled',
      );
      expect(
        serviceProfileReadiness(
          profile: <String, dynamic>{'Status': 'active'},
          assignments: const <Map<String, dynamic>>[],
          bindings: const <String, Map<String, dynamic>>{},
          statusAvailable: false,
        ),
        'Status unavailable',
      );
      expect(
        serviceProfileReadiness(
          profile: <String, dynamic>{'Status': 'active'},
          assignments: const <Map<String, dynamic>>[],
          bindings: const <String, Map<String, dynamic>>{},
          statusAvailable: true,
        ),
        'Missing active ingress',
      );
      expect(
        serviceProfileReadiness(
          profile: <String, dynamic>{'Status': 'active'},
          assignments: const <Map<String, dynamic>>[
            <String, dynamic>{'IngressBindingId': 'binding', 'IsActive': false},
          ],
          bindings: const <String, Map<String, dynamic>>{
            'binding': <String, dynamic>{'IsActive': true},
          },
          statusAvailable: true,
        ),
        'Inactive ingress assignment',
      );
      expect(
        serviceProfileReadiness(
          profile: <String, dynamic>{'Status': 'active'},
          assignments: const <Map<String, dynamic>>[
            <String, dynamic>{'IngressBindingId': 'binding', 'IsActive': true},
          ],
          bindings: const <String, Map<String, dynamic>>{
            'binding': <String, dynamic>{'IsActive': true},
          },
          statusAvailable: true,
        ),
        'Active and routable',
      );
    });
  });

  group('Product access readiness', () {
    final readySubscription = <String, dynamic>{
      'TenantId': 'tenant',
      'Status': 'active',
      'CurrentPeriodStart': '2026-01-01T00:00:00Z',
      'CurrentPeriodEnd': '2027-01-01T00:00:00Z',
      'Account': <String, dynamic>{'TenantId': 'tenant'},
      'Price': <String, dynamic>{
        'Product': <String, dynamic>{'Code': 'product'},
      },
    };

    test('shows assignment lifecycle states', () {
      expect(
        serviceProfileSubscriptionAccessState(
          assignment: <String, dynamic>{'Status': 'disabled'},
          subscription: null,
        ),
        'Disabled',
      );
      expect(
        serviceProfileSubscriptionAccessState(
          assignment: <String, dynamic>{'Status': 'active'},
          subscription: null,
        ),
        'Status unavailable',
      );
      expect(
        serviceProfileSubscriptionAccessState(
          assignment: <String, dynamic>{
            'Status': 'draft',
            'TenantId': 'tenant',
          },
          subscription: readySubscription,
          now: DateTime.utc(2026, 6),
        ),
        'Draft assignment',
      );
      expect(
        serviceProfileSubscriptionAccessState(
          assignment: <String, dynamic>{
            'Status': 'active',
            'TenantId': 'tenant',
            'ProductCode': 'product',
          },
          subscription: readySubscription,
          now: DateTime.utc(2026, 6),
        ),
        'Active Product access',
      );
    });

    test('shows each commercial failure distinctly', () {
      String state(
        Map<String, dynamic> subscription, {
        String productCode = 'product',
      }) => serviceProfileSubscriptionAccessState(
        assignment: <String, dynamic>{
          'Status': 'active',
          'TenantId': 'tenant',
          'ProductCode': productCode,
        },
        subscription: subscription,
        now: DateTime.utc(2026, 6),
      );

      expect(
        state(<String, dynamic>{...readySubscription, 'Account': null}),
        'Billing Account mismatch',
      );
      expect(
        state(<String, dynamic>{
          ...readySubscription,
          'Account': <String, dynamic>{'TenantId': 'other'},
        }),
        'Billing Account mismatch',
      );
      expect(
        state(<String, dynamic>{...readySubscription, 'Price': null}),
        'Missing Price',
      );
      expect(
        state(<String, dynamic>{
          ...readySubscription,
          'Price': <String, dynamic>{'Product': null},
        }),
        'Missing Product',
      );
      expect(
        state(readySubscription, productCode: 'old'),
        'Product catalog drift',
      );
      for (final status in <String>['paused', 'cancelled', 'canceled']) {
        expect(
          state(<String, dynamic>{...readySubscription, 'Status': status}),
          'Subscription paused or cancelled',
        );
      }
      expect(
        state(<String, dynamic>{...readySubscription, 'Status': 'expired'}),
        'Subscription expired',
      );
      expect(
        state(<String, dynamic>{
          ...readySubscription,
          'CurrentPeriodEnd': '2026-01-01T00:00:00Z',
        }),
        'Subscription expired',
      );
      expect(
        state(<String, dynamic>{
          ...readySubscription,
          'EndedAt': '2026-01-01T00:00:00Z',
        }),
        'Subscription expired',
      );
      expect(
        serviceProfileSubscriptionAccessState(
          assignment: <String, dynamic>{
            'Status': 'unknown',
            'TenantId': 'tenant',
          },
          subscription: readySubscription,
          now: DateTime.utc(2026, 6),
        ),
        'Status unavailable',
      );
    });
  });

  test('ingress assignment and period labels stay actionable', () {
    expect(
      serviceProfileIngressAssignmentState(
        assignment: <String, dynamic>{'IsActive': false},
        binding: null,
      ),
      'Inactive ingress assignment',
    );
    expect(
      serviceProfileIngressAssignmentState(
        assignment: <String, dynamic>{'IsActive': true},
        binding: null,
      ),
      'Status unavailable',
    );
    expect(
      serviceProfileIngressAssignmentState(
        assignment: <String, dynamic>{'IsActive': true},
        binding: <String, dynamic>{'IsActive': true},
      ),
      'Active endpoint assignment',
    );
    expect(serviceProfileCurrentPeriod(null), 'Unavailable');
    expect(serviceProfileCurrentPeriod(<String, dynamic>{}), 'Not set');
    expect(
      serviceProfileCurrentPeriod(<String, dynamic>{'CurrentPeriodEnd': 'end'}),
      'Until end',
    );
    expect(
      serviceProfileCurrentPeriod(<String, dynamic>{
        'CurrentPeriodStart': 'start',
      }),
      'From start',
    );
    expect(
      serviceProfileCurrentPeriod(<String, dynamic>{
        'CurrentPeriodStart': 'start',
        'CurrentPeriodEnd': 'end',
      }),
      'start — end',
    );
  });
}
