import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/runtime_admin/presentation/providers/runtime_admin_providers.dart';
import 'package:mugen_ui/features/runtime_admin/presentation/widgets/runtime_control_panel.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test('runtime admin providers expose descriptor-backed controller', () {
    final repositoryContainer = ProviderContainer();
    addTearDown(repositoryContainer.dispose);
    expect(
      repositoryContainer.read(runtimeAdminRepositoryProvider),
      isA<AcpAdminRepositoryImpl>(),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        runtimeAdminRepositoryProvider.overrideWithValue(
          FakeAcpAdminRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(runtimeAdminControllerProvider.notifier);
    expect(controller.descriptors, hasLength(4));
    expect(controller.descriptors.first.title, 'Messaging Client Profiles');
    expect(controller.descriptors[2].entityActions, hasLength(2));
    expect(controller.descriptors[2].allowCreate, isFalse);
    expect(
      controller.descriptors[2].collectionActions.single.showInRowMenu,
      isTrue,
    );
    expect(
      controller.descriptors[2].collectionActions.single.showInToolbar,
      isTrue,
    );
    expect(
      controller.descriptors[2].collectionActions.single.showAsRowButton,
      isTrue,
    );
    expect(controller.descriptors[2].actionsColumnLeading, isFalse);
    expect(controller.descriptors[2].columns[0].flex, 2);
    expect(controller.descriptors[2].columns[1].flex, 2);
    expect(controller.descriptors[2].columns[2].label, 'Key Provider');
    expect(controller.descriptors[2].columns[5].flex, 2);
    expect(
      controller.descriptors[2].collectionActions.single.fields[2].label,
      'Key Provider',
    );
    expect(
      controller.descriptors[2].collectionActions.single.fields[2].options,
      <String>['local', 'managed'],
    );
  });

  testWidgets('RuntimeControlPanel renders description and resource tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          runtimeAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: RuntimeControlPanel())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messaging Client Profiles'), findsOneWidget);
    expect(find.text('Runtime Config Profiles'), findsOneWidget);
    expect(find.text('Key References'), findsOneWidget);
    expect(find.text('System Flags'), findsOneWidget);
    expect(
      find.textContaining('Manage runtime client profiles'),
      findsOneWidget,
    );
  });

  testWidgets(
    'messaging client profile create form only requires universal fields before platform selection',
    (WidgetTester tester) async {
      final repository = _RecordingAcpAdminRepository();
      await _pumpRuntimeControlPanel(tester, repository);

      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Platform Key is required.'), findsOneWidget);
      expect(find.text('Profile Key is required.'), findsOneWidget);
      expect(find.text('Path Token is required.'), findsNothing);
      expect(find.text('Recipient User ID is required.'), findsNothing);
      expect(repository.createCalls, isEmpty);
    },
  );

  testWidgets(
    'messaging client profile create form applies platform-specific required fields',
    (WidgetTester tester) async {
      final repository = _RecordingAcpAdminRepository();
      await _pumpRuntimeControlPanel(tester, repository);

      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-PlatformKey')),
        'matrix',
      );
      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-ProfileKey')),
        'primary',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Recipient User ID is required.'), findsOneWidget);
      expect(find.text('Path Token is required.'), findsNothing);
      expect(find.text('Phone Number ID is required.'), findsNothing);
      expect(repository.createCalls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-RecipientUserId')),
        '@assistant:example.org',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, hasLength(1));
      expect(repository.createCalls.single['PlatformKey'], 'matrix');
      expect(repository.createCalls.single['ProfileKey'], 'primary');
      expect(
        repository.createCalls.single['RecipientUserId'],
        '@assistant:example.org',
      );
      expect(repository.createCalls.single.containsKey('DisplayName'), isFalse);
      expect(repository.createCalls.single.containsKey('PathToken'), isFalse);
      expect(
        repository.createCalls.single.containsKey('AccountNumber'),
        isFalse,
      );
      expect(
        repository.createCalls.single.containsKey('PhoneNumberId'),
        isFalse,
      );
      expect(repository.createCalls.single.containsKey('Provider'), isFalse);
    },
  );

  testWidgets(
    'runtime config profile create form only requires category and profile key',
    (WidgetTester tester) async {
      final repository = _RecordingAcpAdminRepository();
      await _pumpRuntimeControlPanel(tester, repository);

      await tester.tap(
        find.byKey(const Key('acp-admin-tab-runtime-config-profiles')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Category is required.'), findsOneWidget);
      expect(find.text('Profile Key is required.'), findsOneWidget);
      expect(find.text('Display Name is required.'), findsNothing);
      expect(repository.createCalls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-Category')),
        'messaging.platform_defaults',
      );
      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-ProfileKey')),
        'whatsapp',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, hasLength(1));
      expect(
        repository.createCalls.single['Category'],
        'messaging.platform_defaults',
      );
      expect(repository.createCalls.single['ProfileKey'], 'whatsapp');
      expect(repository.createCalls.single.containsKey('DisplayName'), isFalse);
    },
  );

  testWidgets(
    'key references use rotate from toolbar for create and from row actions for prefilled rotation',
    (WidgetTester tester) async {
      final repository = _KeyRefRecordingAcpAdminRepository();
      await _pumpRuntimeControlPanel(tester, repository);

      await tester.tap(find.byKey(const Key('acp-admin-tab-key-refs')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('acp-admin-create-button')), findsNothing);
      expect(
        find.byKey(const Key('acp-admin-collection-action-rotate')),
        findsOneWidget,
      );
      expect(find.text('Actions'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('acp-admin-collection-action-rotate')),
      );
      await tester.pumpAndSettle();

      var purposeField = tester.widget<TextFormField>(
        find.byKey(const Key('acp-dynamic-field-Purpose')),
      );
      var keyIdField = tester.widget<TextFormField>(
        find.byKey(const Key('acp-dynamic-field-KeyId')),
      );
      var providerField = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('acp-dynamic-field-Provider')),
      );
      var secretValueField = tester.widget<TextFormField>(
        find.byKey(const Key('acp-dynamic-field-SecretValue')),
      );
      var attributesField = tester.widget<TextField>(
        _jsonEditorTextField('Attributes'),
      );

      expect(purposeField.controller!.text, isEmpty);
      expect(keyIdField.controller!.text, isEmpty);
      expect(providerField.initialValue, 'local');
      expect(
        find.descendant(
          of: find.byKey(const Key('acp-dynamic-field-Provider')),
          matching: find.text('Key Provider'),
        ),
        findsOneWidget,
      );
      expect(secretValueField.controller!.text, isEmpty);
      expect(attributesField.controller!.text, anyOf(isEmpty, '{}'));

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Rotate'), findsOneWidget);
      await tester.tap(find.byTooltip('Rotate'));
      await tester.pumpAndSettle();

      purposeField = tester.widget<TextFormField>(
        find.byKey(const Key('acp-dynamic-field-Purpose')),
      );
      keyIdField = tester.widget<TextFormField>(
        find.byKey(const Key('acp-dynamic-field-KeyId')),
      );
      providerField = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('acp-dynamic-field-Provider')),
      );
      secretValueField = tester.widget<TextFormField>(
        find.byKey(const Key('acp-dynamic-field-SecretValue')),
      );
      attributesField = tester.widget<TextField>(
        _jsonEditorTextField('Attributes'),
      );

      expect(purposeField.controller!.text, 'signing');
      expect(keyIdField.controller!.text, 'app-primary');
      expect(providerField.initialValue, 'local');
      expect(secretValueField.controller!.text, isEmpty);
      expect(
        attributesField.controller!.text,
        contains('"region": "us-east-1"'),
      );

      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-SecretValue')),
        'next-secret',
      );
      await tester.tap(find.byKey(const Key('acp-dynamic-field-Provider')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('managed').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rotate'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rotate'));
      await tester.pumpAndSettle();

      expect(repository.collectionActionPayloads, hasLength(1));
      expect(repository.collectionActionPayloads.single['Purpose'], 'signing');
      expect(
        repository.collectionActionPayloads.single['KeyId'],
        'app-primary',
      );
      expect(repository.collectionActionPayloads.single['Provider'], 'managed');
      expect(
        repository.collectionActionPayloads.single['SecretValue'],
        'next-secret',
      );
      expect(
        repository.collectionActionPayloads.single['Attributes'],
        <String, Object?>{'region': 'us-east-1'},
      );
    },
  );

  testWidgets('key references expose clickable row menu actions', (
    WidgetTester tester,
  ) async {
    final repository = _KeyRefRecordingAcpAdminRepository();
    await _pumpRuntimeControlPanel(tester, repository);

    await tester.tap(find.byKey(const Key('acp-admin-tab-key-refs')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('acp-admin-row-more-actions')));
    await tester.pumpAndSettle();

    expect(find.text('Retire'), findsOneWidget);
    expect(find.text('Destroy'), findsOneWidget);
  });

  test('runtime admin refreshes auth on session expiry', () async {
    final repository = FakeAcpAdminRepository()
      ..collectionActionResult = const Result<Object?>.failure(
        SessionExpiredFailure(),
      );
    final authController = RecordingAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => authController),
        runtimeAdminRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(runtimeAdminControllerProvider.notifier);
    await controller.loadInitialData();
    await controller.selectResource('system-flags');
    final result = await controller.runCollectionAction(
      action: controller.activeDescriptor.collectionActions.single,
      values: const <String, dynamic>{},
    );

    expect(result.isFailure, isTrue);
    expect(authController.refreshCount, 1);
  });
}

Finder _jsonEditorTextField(String fieldKey) {
  return find.descendant(
    of: find.byKey(Key('acp-json-editor-text-$fieldKey')),
    matching: find.byType(TextField),
  );
}

Future<void> _pumpRuntimeControlPanel(
  WidgetTester tester,
  FakeAcpAdminRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        runtimeAdminRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: Scaffold(body: RuntimeControlPanel())),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingAcpAdminRepository extends FakeAcpAdminRepository {
  final List<Map<String, dynamic>> createCalls = <Map<String, dynamic>>[];

  @override
  Future<Result<Object?>> createRow({
    required AcpResourceDescriptor descriptor,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    createCalls.add(Map<String, dynamic>.from(values));
    return super.createRow(
      descriptor: descriptor,
      values: values,
      tenantId: tenantId,
    );
  }
}

class _KeyRefRecordingAcpAdminRepository extends FakeAcpAdminRepository {
  final List<Map<String, dynamic>> collectionActionPayloads =
      <Map<String, dynamic>>[];

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
  }) async {
    if (descriptor.key != 'key-refs') {
      return super.listRows(
        descriptor: descriptor,
        pageRequest: pageRequest,
        tenantId: tenantId,
        searchTerm: searchTerm,
        extraFilters: extraFilters,
      );
    }

    return const Result<AcpRowPage>.success(
      AcpRowPage(
        items: <AcpRow>[
          <String, Object?>{
            'Id': 'key-ref-1',
            'TenantId': 'global-id',
            'RowVersion': 2,
            'Purpose': 'signing',
            'KeyId': 'app-primary',
            'Provider': 'local',
            'Status': 'active',
            'Attributes': <String, Object?>{'region': 'us-east-1'},
          },
        ],
        total: 1,
        page: 1,
        pageSize: 15,
      ),
    );
  }

  @override
  Future<Result<Object?>> runCollectionAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    collectionActionPayloads.add(Map<String, dynamic>.from(values));
    return super.runCollectionAction(
      descriptor: descriptor,
      action: action,
      values: values,
      tenantId: tenantId,
    );
  }
}
