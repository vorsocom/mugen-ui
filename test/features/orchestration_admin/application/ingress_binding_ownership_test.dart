import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/orchestration_admin/application/ingress_binding_ownership.dart';
import 'package:mugen_ui/features/orchestration_admin/application/orchestration_admin_resources.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/providers/orchestration_admin_providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test(
    'messaging forms require matching active profiles and client identifiers',
    () {
      final descriptor = orchestrationAdminResources.firstWhere(
        (item) => item.entitySet == 'IngressBindings',
      );
      for (final fields in [descriptor.createFields, descriptor.updateFields]) {
        final profile = fields.firstWhere(
          (field) => field.key == 'ChannelProfileId',
        );
        expect(
          profile.requiredWhenEquals['ChannelKey'],
          ingressMessagingChannels,
        );
        expect(profile.reference!.extraFilters, ['IsActive eq true']);
        expect(profile.reference!.filterFieldsFromForm, {
          'ChannelKey': 'ChannelKey',
        });
        expect(profile.reference!.retainHistoricalSelection, isTrue);
        final identifier = fields.firstWhere(
          (field) => field.key == 'IdentifierType',
        );
        for (final channel in ingressMessagingChannels) {
          expect(identifier.optionsBuilder!({'ChannelKey': channel}), isEmpty);
          expect(identifier.options, isNot(contains('tenant_slug')));
        }
        expect(identifier.optionsBuilder!({'ChannelKey': 'custom'}), [
          'tenant_slug',
        ]);
        expect(identifier.allowCustomOption, isTrue);
      }
    },
  );

  test(
    'invalid identifiers and missing messaging profiles fail before lookup',
    () async {
      final repository = _OwnershipRepository();
      for (final values in <AcpRow>[
        {},
        {...repository.binding, 'IdentifierValue': ' '},
        {...repository.binding, 'ChannelProfileId': null},
        {...repository.binding, 'IdentifierType': 'tenant_slug'},
        {...repository.binding, 'IdentifierType': 'custom_identifier'},
      ]) {
        final result = await validateIngressBindingOwnership(
          repository: repository,
          values: values,
          tenantId: 'tenant-1',
        );
        expect(result.failure, isA<ValidationFailure>());
      }
      expect(repository.lookups, isEmpty);
    },
  );

  test('all six channels accept every owned client identifier', () async {
    for (final channel in ingressMessagingChannels) {
      for (final identifier in ingressClientIdentifierFields.entries) {
        final repository = _OwnershipRepository()
          ..profile['ChannelKey'] = channel
          ..client['PlatformKey'] = channel
          ..client[identifier.value] = 'Owned-ID';
        final result = await validateIngressBindingOwnership(
          repository: repository,
          values: {
            ...repository.binding,
            'ChannelKey': channel.toUpperCase(),
            'IdentifierType': identifier.key.toUpperCase(),
            'IdentifierValue': ' owned-id ',
          },
          tenantId: 'tenant-1',
        );
        expect(result.isSuccess, isTrue);
        expect(repository.lookups, [
          'ChannelProfiles:tenant-1:profile-1',
          'MessagingClientProfiles:tenant-1:client-1',
        ]);
      }
    }
  });

  test(
    'custom channels may omit a profile and use custom identifiers',
    () async {
      final repository = _OwnershipRepository();
      final values = {
        'ChannelKey': 'custom',
        'IdentifierType': 'tenant_slug',
        'IdentifierValue': 'tenant-one',
      };
      expect(
        (await validateIngressBindingOwnership(
          repository: repository,
          values: values,
          tenantId: 'tenant-1',
        )).isSuccess,
        isTrue,
      );
      expect(repository.lookups, isEmpty);
      repository.profile['ChannelKey'] = 'custom';
      expect(
        (await validateIngressBindingOwnership(
          repository: repository,
          values: {...values, 'ChannelProfileId': 'profile-1'},
          tenantId: 'tenant-1',
        )).isSuccess,
        isTrue,
      );
      expect(repository.lookups, ['ChannelProfiles:tenant-1:profile-1']);
    },
  );

  test(
    'inactive, foreign and mismatched profiles or clients cannot own ingress',
    () async {
      for (final change in <AcpRow>[
        {'IsActive': false},
        {'TenantId': 'tenant-2'},
        {'ChannelKey': 'telegram'},
        {'ClientProfileId': null},
      ]) {
        final repository = _OwnershipRepository()..profile.addAll(change);
        final result = await validateIngressBindingOwnership(
          repository: repository,
          values: repository.binding,
          tenantId: 'tenant-1',
        );
        expect(result.failure, isA<ValidationFailure>());
        expect(repository.lookups, hasLength(1));
      }
      for (final change in <AcpRow>[
        {'IsActive': false},
        {'TenantId': 'tenant-2'},
        {'PlatformKey': 'telegram'},
        {'PhoneNumberId': null},
        {'PhoneNumberId': 'somebody-else'},
      ]) {
        final repository = _OwnershipRepository()..client.addAll(change);
        final result = await validateIngressBindingOwnership(
          repository: repository,
          values: repository.binding,
          tenantId: 'tenant-1',
        );
        expect(result.failure, isA<ValidationFailure>());
        expect(repository.lookups, hasLength(2));
      }
    },
  );

  test('lookup failures retain their API and session semantics', () async {
    for (final entitySet in ['ChannelProfiles', 'MessagingClientProfiles']) {
      final repository = _OwnershipRepository()..failingEntitySet = entitySet;
      final result = await validateIngressBindingOwnership(
        repository: repository,
        values: repository.binding,
        tenantId: 'tenant-1',
      );
      expect(result.failure, isA<SessionExpiredFailure>());
    }
  });

  test(
    'controller validates create and partial updates while preserving tenant and row version',
    () async {
      final repository = _OwnershipRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(
        orchestrationAdminControllerProvider.notifier,
      );
      await controller.loadInitialData();
      await controller.selectTenant('tenant-1');
      await controller.selectResource('ingress-bindings');
      expect(
        (await controller.createRow(repository.binding)).isSuccess,
        isTrue,
      );
      expect(repository.createPayloads.single, repository.binding);
      expect(
        (await controller.updateRow(
          rowId: 'binding-1',
          values: {'ServiceRouteKey': 'next'},
          tenantIdOverride: 'tenant-1',
          useTenantIdOverride: true,
          rowVersion: 7,
        )).isSuccess,
        isTrue,
      );
      expect(repository.updatePayloads.single, {'ServiceRouteKey': 'next'});
      expect(repository.updateRowVersions.single, 7);
      expect(
        (await controller.updateRow(
          rowId: 'binding-1',
          values: {'IdentifierValue': 'unowned'},
        )).failure,
        isA<ValidationFailure>(),
      );
      expect(repository.updatePayloads, hasLength(1));
      expect(controller.errorMessage, contains('PhoneNumberId'));
      expect(
        (await controller.createRow({
          ...repository.binding,
          'ChannelProfileId': null,
        })).failure,
        isA<ValidationFailure>(),
      );
      expect(repository.createPayloads, hasLength(1));
      await controller.selectResource('channel-profiles');
      expect(
        (await controller.updateRow(
          rowId: 'profile-1',
          values: {'DisplayName': 'New'},
        )).isSuccess,
        isTrue,
      );
    },
  );

  test(
    'controller refreshes expired ownership lookups and blocks failed binding reads',
    () async {
      final repository = _OwnershipRepository();
      final auth = RecordingAuthController();
      final container = _container(repository, auth: auth);
      addTearDown(container.dispose);
      final controller = container.read(
        orchestrationAdminControllerProvider.notifier,
      );
      await controller.loadInitialData();
      await controller.selectTenant('tenant-1');
      await controller.selectResource('ingress-bindings');
      repository.failingEntitySet = 'ChannelProfiles';
      expect(
        (await controller.createRow(repository.binding)).failure,
        isA<SessionExpiredFailure>(),
      );
      repository.failingEntitySet = 'IngressBindings';
      expect(
        (await controller.updateRow(
          rowId: 'binding-1',
          values: {'ServiceRouteKey': 'next'},
        )).failure,
        isA<SessionExpiredFailure>(),
      );
      expect(auth.refreshCount, 2);
      expect(repository.createPayloads, isEmpty);
      expect(repository.updatePayloads, isEmpty);
    },
  );

  for (final selectionChange in ['tenant', 'resource']) {
    for (final operation in ['create', 'update']) {
      test(
        '$operation does not mutate a different $selectionChange after ownership lookup',
        () async {
          final repository = _OwnershipRepository()
            ..delayedEntitySet = 'MessagingClientProfiles'
            ..lookupGate = Completer<void>();
          final container = _container(repository);
          addTearDown(container.dispose);
          final controller = container.read(
            orchestrationAdminControllerProvider.notifier,
          );
          await controller.loadInitialData();
          await controller.selectTenant('tenant-1');
          await controller.selectResource('ingress-bindings');

          final mutation = operation == 'create'
              ? controller.createRow(repository.binding)
              : controller.updateRow(
                  rowId: 'binding-1',
                  values: {'ServiceRouteKey': 'next'},
                  tenantIdOverride: 'tenant-1',
                  useTenantIdOverride: true,
                  rowVersion: 7,
                );
          await Future<void>.delayed(Duration.zero);
          expect(
            repository.lookups.last,
            'MessagingClientProfiles:tenant-1:client-1',
          );

          if (selectionChange == 'tenant') {
            await controller.selectTenant('global-id');
          } else {
            await controller.selectResource('channel-profiles');
          }
          repository.lookupGate!.complete();

          final result = await mutation;
          expect(result.failure, isA<ValidationFailure>());
          expect(
            result.failure?.message,
            contains('selected tenant or resource'),
          );
          expect(repository.createPayloads, isEmpty);
          expect(repository.updatePayloads, isEmpty);
          expect(controller.state.isMutating, isFalse);
        },
      );
    }
  }
}

ProviderContainer _container(
  _OwnershipRepository repository, {
  RecordingAuthController? auth,
}) => ProviderContainer(
  overrides: [
    orchestrationAdminRepositoryProvider.overrideWithValue(repository),
    authControllerProvider.overrideWith(
      () => auth ?? RecordingAuthController(),
    ),
  ],
);

class _OwnershipRepository extends FakeAcpAdminRepository {
  final binding = <String, dynamic>{
    'ChannelKey': 'whatsapp',
    'ChannelProfileId': 'profile-1',
    'IdentifierType': 'phone_number_id',
    'IdentifierValue': '12345',
  };
  final profile = <String, dynamic>{
    'Id': 'profile-1',
    'TenantId': 'tenant-1',
    'IsActive': true,
    'ChannelKey': 'whatsapp',
    'ClientProfileId': 'client-1',
  };
  final client = <String, dynamic>{
    'Id': 'client-1',
    'TenantId': 'tenant-1',
    'IsActive': true,
    'PlatformKey': 'whatsapp',
    'PhoneNumberId': '12345',
  };
  final lookups = <String>[];
  String? failingEntitySet;
  String? delayedEntitySet;
  Completer<void>? lookupGate;

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    lookups.add('${descriptor.entitySet}:$tenantId:$rowId');
    if (descriptor.entitySet == delayedEntitySet) {
      await lookupGate!.future;
    }
    if (descriptor.entitySet == failingEntitySet) {
      return const Result<AcpRow>.failure(SessionExpiredFailure());
    }
    return Result<AcpRow>.success(switch (descriptor.entitySet) {
      'ChannelProfiles' => profile,
      'MessagingClientProfiles' => client,
      _ => binding,
    });
  }
}
