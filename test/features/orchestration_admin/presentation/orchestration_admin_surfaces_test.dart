import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/orchestration_admin/application/orchestration_admin_resources.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/providers/orchestration_admin_providers.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/widgets/channel_orchestration_panel.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test('orchestration admin providers expose descriptor-backed controller', () {
    final repositoryContainer = ProviderContainer();
    addTearDown(repositoryContainer.dispose);
    expect(
      repositoryContainer.read(orchestrationAdminRepositoryProvider),
      isA<AcpAdminRepositoryImpl>(),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        orchestrationAdminRepositoryProvider.overrideWithValue(
          FakeAcpAdminRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      orchestrationAdminControllerProvider.notifier,
    );
    expect(controller.descriptors, hasLength(10));
    expect(controller.descriptors.first.title, 'Channel Profiles');
    expect(controller.descriptors.last.title, 'Events');
    expect(controller.descriptors[6].collectionActions, hasLength(2));
  });

  testWidgets('ChannelOrchestrationPanel renders description and tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          orchestrationAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChannelOrchestrationPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Channel Profiles'), findsOneWidget);
    expect(find.text('Ingress Bindings'), findsOneWidget);
    expect(find.text('Conversation State'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(
      find.textContaining('Configure channel intake, routing, throttling'),
      findsOneWidget,
    );
  });

  test(
    'channel profile create requirements match backend validation surface',
    () {
      final descriptor = orchestrationAdminResources.firstWhere(
        (resource) => resource.entitySet == 'ChannelProfiles',
      );

      expect(descriptor.createFields.map((field) => field.key), <String>[
        'ClientProfileId',
        'ChannelKey',
        'ProfileKey',
        'ServiceRouteDefaultKey',
      ]);
      expect(descriptor.updateFields.first.key, 'ClientProfileId');
      expect(_requiredFieldKeys(descriptor.createFields), <String>[
        'ChannelKey',
        'ProfileKey',
      ]);
      final clientProfileField = descriptor.createFields.firstWhere(
        (field) => field.key == 'ClientProfileId',
      );
      expect(
        clientProfileField.reference?.entitySet,
        'MessagingClientProfiles',
      );

      final ingressDescriptor = orchestrationAdminResources.firstWhere(
        (resource) => resource.entitySet == 'IngressBindings',
      );
      final channelProfileField = ingressDescriptor.createFields.firstWhere(
        (field) => field.key == 'ChannelProfileId',
      );
      expect(channelProfileField.reference?.entitySet, 'ChannelProfiles');
      expect(channelProfileField.reference?.scopeMode, AcpScopeMode.required);
    },
  );

  testWidgets('orchestration create forms select references from same tenant', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final repository = _ClientProfileReferenceRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          orchestrationAdminRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChannelOrchestrationPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('acp-admin-tenant-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenant One (tenant-one)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-ChannelKey')),
      'whatsapp',
    );
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-ProfileKey')),
      'default',
    );
    await tester.enterText(
      find.byKey(const Key('acp-reference-search-ClientProfileId')),
      'default',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.clientProfileTenantId, 'tenant-1');
    expect(repository.clientProfileSearchTerm, 'default');
    expect(find.text('WhatsApp Default'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const Key('acp-reference-option-ClientProfileId-client-profile-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('acp-reference-selected-ClientProfileId')),
      findsOneWidget,
    );

    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(repository.createPayloads, hasLength(1));
    expect(
      repository.createPayloads.single['ClientProfileId'],
      'client-profile-1',
    );

    await tester.tap(find.byKey(const Key('acp-admin-tab-ingress-bindings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-ChannelKey')),
      'whatsapp',
    );
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-IdentifierType')),
      'phone_number_id',
    );
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-IdentifierValue')),
      '1234567890',
    );
    await tester.enterText(
      find.byKey(const Key('acp-reference-search-ChannelProfileId')),
      'whatsapp',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.channelProfileTenantId, 'tenant-1');
    expect(repository.channelProfileSearchTerm, 'whatsapp');
    expect(find.text('WhatsApp Channel'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const Key('acp-reference-option-ChannelProfileId-channel-profile-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('acp-reference-selected-ChannelProfileId')),
      findsOneWidget,
    );

    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(repository.createPayloads, hasLength(2));
    expect(
      repository.createPayloads.last['ChannelProfileId'],
      'channel-profile-1',
    );
  });

  test('orchestration admin refreshes auth on session expiry', () async {
    final repository = FakeAcpAdminRepository()
      ..collectionActionResult = const Result<Object?>.failure(
        SessionExpiredFailure(),
      );
    final authController = RecordingAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => authController),
        orchestrationAdminRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      orchestrationAdminControllerProvider.notifier,
    );
    await controller.loadInitialData();
    await controller.selectResource('blocklist-entries');
    final result = await controller.runCollectionAction(
      action: controller.activeDescriptor.collectionActions.first,
      values: const <String, dynamic>{},
    );

    expect(result.isFailure, isTrue);
    expect(authController.refreshCount, 1);
  });
}

List<String> _requiredFieldKeys(List<AcpFieldDescriptor> fields) {
  return fields
      .where((field) => field.required)
      .map((field) => field.key)
      .toList(growable: false);
}

Finder _dialogButton(Type buttonType, String label) {
  return find.descendant(
    of: find.byType(Dialog),
    matching: find.widgetWithText(buttonType, label),
  );
}

class _ClientProfileReferenceRepository extends FakeAcpAdminRepository {
  String? clientProfileTenantId;
  String? clientProfileSearchTerm;
  String? channelProfileTenantId;
  String? channelProfileSearchTerm;

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
  }) async {
    if (descriptor.entitySet == 'ChannelProfiles') {
      if ((searchTerm ?? '').trim().isNotEmpty) {
        channelProfileTenantId = tenantId;
        channelProfileSearchTerm = searchTerm;
      }
      return Result<AcpRowPage>.success(
        AcpRowPage(
          items: const <AcpRow>[
            <String, Object?>{
              'Id': 'channel-profile-1',
              'TenantId': 'tenant-1',
              'ChannelKey': 'whatsapp',
              'ProfileKey': 'default',
              'DisplayName': 'WhatsApp Channel',
              'ServiceRouteDefaultKey': 'default',
            },
          ],
          total: 1,
          page: pageRequest.page,
          pageSize: pageRequest.pageSize,
        ),
      );
    }

    if (descriptor.entitySet != 'MessagingClientProfiles') {
      return super.listRows(
        descriptor: descriptor,
        pageRequest: pageRequest,
        tenantId: tenantId,
        searchTerm: searchTerm,
        extraFilters: extraFilters,
      );
    }

    clientProfileTenantId = tenantId;
    clientProfileSearchTerm = searchTerm;
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: const <AcpRow>[
          <String, Object?>{
            'Id': 'client-profile-1',
            'TenantId': 'tenant-1',
            'PlatformKey': 'whatsapp',
            'ProfileKey': 'default',
            'DisplayName': 'WhatsApp Default',
            'Provider': 'meta',
          },
        ],
        total: 1,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }
}
