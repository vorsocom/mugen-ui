import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';

import '../../../test_support/fake_acp_admin_repository.dart';

void main() {
  testWidgets('New Row dialog shrink-wraps short ACP forms', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await _pumpPanel(
      tester,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'short-resource',
          title: 'Short Resource',
          description: 'Short resource rows for compact form layout checks.',
          entitySet: 'ShortResources',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Name', label: 'Name'),
          ],
          createFields: <AcpFieldDescriptor>[
            AcpFieldDescriptor(key: 'Name', label: 'Name'),
          ],
          allowCreate: true,
        ),
        AcpResourceDescriptor(
          key: 'hover-resource',
          title: 'Hover Resource',
          description: 'Hover-only tab help text.',
          entitySet: 'HoverResources',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Name', label: 'Name'),
          ],
        ),
      ],
    );

    expect(find.text('Short Resource'), findsWidgets);
    expect(find.text('Hover Resource'), findsOneWidget);
    expect(
      find.text('Short resource rows for compact form layout checks.'),
      findsOneWidget,
    );
    expect(find.text('Hover-only tab help text.'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('acp-admin-tab-hover-resource'))),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Hover-only tab help text.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create Short Resource'), findsOneWidget);
    final fieldHelp = tester.widget<Tooltip>(
      find.byKey(const Key('acp-dynamic-field-help-Name')),
    );
    expect(fieldHelp.message, contains('Stable human-readable identifier'));
    final dialogPanel = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(AppFormPanel),
    );
    expect(tester.getSize(dialogPanel).height, lessThan(360));
  });

  testWidgets('page-level description renders in the page header', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      description: 'Screen-level Platform Configuration guidance.',
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'notice-resource',
          title: 'Notice Resource',
          entitySet: 'NoticeResources',
          scopeMode: AcpScopeMode.optional,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Name', label: 'Name'),
          ],
          searchFields: <String>['Name'],
        ),
      ],
    );

    expect(
      find.text('Screen-level Platform Configuration guidance.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('acp-admin-page-description')), findsNothing);
    expect(find.byKey(const Key('acp-admin-scope-selector')), findsOneWidget);
  });

  testWidgets(
    'JSON fields render the ACP JSON editor fallback in widget tests',
    (WidgetTester tester) async {
      await _pumpPanel(
        tester,
        descriptors: <AcpResourceDescriptor>[_jsonResourceDescriptor()],
      );

      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('acp-dynamic-field-Attributes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('acp-json-editor-text-Attributes')),
        findsOneWidget,
      );
      final fieldHelp = tester.widget<Tooltip>(
        find.byKey(const Key('acp-dynamic-field-help-Attributes')),
      );
      expect(fieldHelp.message, contains('JSON extension metadata'));
      expect(find.byTooltip('Undo JSON edit'), findsOneWidget);
      expect(find.byTooltip('Redo JSON edit'), findsOneWidget);
      expect(find.byTooltip('Format JSON'), findsOneWidget);
      expect(find.byTooltip('Compact JSON'), findsOneWidget);

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('app-form-dialog-body-scroll')),
      );

      expect(scrollView.padding, const EdgeInsets.all(20));
      expect(
        find.byKey(const Key('app-form-dialog-header-divider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('app-form-dialog-footer-divider')),
        findsOneWidget,
      );
    },
  );

  testWidgets('form field help uses ACP resource context', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'messaging-client-profiles',
          title: 'Messaging Client Profiles',
          entitySet: 'MessagingClientProfiles',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Provider', label: 'Provider'),
          ],
          createFields: <AcpFieldDescriptor>[
            AcpFieldDescriptor(key: 'Provider', label: 'Provider'),
          ],
          allowCreate: true,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();

    final fieldHelp = tester.widget<Tooltip>(
      find.byKey(const Key('acp-dynamic-field-help-Provider')),
    );
    expect(fieldHelp.message, contains('transport-specific metadata'));
    expect(fieldHelp.message, isNot(contains('Key provider used')));
  });

  testWidgets('form dialogs display the active ACP scope context', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await _pumpPanel(
      tester,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'tenant-resource',
          title: 'Tenant Resource',
          entitySet: 'TenantResources',
          scopeMode: AcpScopeMode.optional,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Name', label: 'Name'),
          ],
          createFields: <AcpFieldDescriptor>[
            AcpFieldDescriptor(key: 'Name', label: 'Name'),
          ],
          allowCreate: true,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Scope: Global'),
      ),
      findsOneWidget,
    );

    await tester.tap(_dialogButton(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acp-admin-scope-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenant').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acp-admin-tenant-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acp-admin-tenant-option-tenant-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Tenant: Tenant One (tenant-one)'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('update dialog displays the row tenant context', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final repository = _TenantRowAcpAdminRepository();
    await _pumpPanel(
      tester,
      repository: repository,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'tenant-resource',
          title: 'Tenant Resource',
          entitySet: 'TenantResources',
          scopeMode: AcpScopeMode.optional,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Name', label: 'Name'),
          ],
          updateFields: <AcpFieldDescriptor>[
            AcpFieldDescriptor(key: 'Name', label: 'Name'),
          ],
          allowUpdate: true,
        ),
      ],
    );

    await tester.tap(find.byTooltip('Edit row'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Tenant: Tenant One (tenant-one)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Scope: Global'),
      ),
      findsNothing,
    );

    await tester.tap(_dialogButton(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.updateTenantId, 'tenant-1');
  });

  testWidgets(
    'read-only update fields display values without submitting them',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final repository = _TenantRowAcpAdminRepository();
      await _pumpPanel(
        tester,
        repository: repository,
        descriptors: const <AcpResourceDescriptor>[
          AcpResourceDescriptor(
            key: 'tenant-resource',
            title: 'Tenant Resource',
            entitySet: 'TenantResources',
            scopeMode: AcpScopeMode.optional,
            columns: <AcpColumnDescriptor>[
              AcpColumnDescriptor(key: 'Name', label: 'Name'),
            ],
            updateFields: <AcpFieldDescriptor>[
              AcpFieldDescriptor(
                key: 'IdentityKey',
                label: 'Identity Key',
                readOnly: true,
              ),
              AcpFieldDescriptor(key: 'Name', label: 'Name'),
            ],
            allowUpdate: true,
          ),
        ],
      );

      await tester.tap(find.byTooltip('Edit row'));
      await tester.pumpAndSettle();

      final identityField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('acp-dynamic-field-IdentityKey')),
          matching: find.byType(EditableText),
        ),
      );
      expect(identityField.readOnly, isTrue);
      expect(identityField.controller.text, 'locked-key');

      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-Name')),
        'Updated row',
      );
      await tester.tap(_dialogButton(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.updateValues, <String, dynamic>{'Name': 'Updated row'});
    },
  );

  testWidgets('JSON validation blocks invalid payload submission', (
    WidgetTester tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = Map<Object?, Object?>.from(
            call.arguments as Map<Object?, Object?>,
          );
          copiedText = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final repository = await _pumpPanel(
      tester,
      descriptors: <AcpResourceDescriptor>[_jsonResourceDescriptor()],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(_jsonTextField(), '{');
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Enter valid JSON.'), findsOneWidget);
    expect(find.text('Attributes: Enter valid JSON.'), findsOneWidget);
    expect(
      find.byKey(const Key('acp-dynamic-form-error-alert')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('acp-dynamic-form-error-copy-button')),
    );
    await tester.pump();

    expect(copiedText, 'Attributes: Enter valid JSON.');
    expect(repository.createPayloads, isEmpty);
  });

  testWidgets('JSON fields submit decoded payload values', (
    WidgetTester tester,
  ) async {
    final repository = await _pumpPanel(
      tester,
      descriptors: <AcpResourceDescriptor>[_jsonResourceDescriptor()],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(_jsonTextField(), '{"enabled":true}');
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(repository.createPayloads, hasLength(1));
    expect(repository.createPayloads.single['Attributes'], <String, Object?>{
      'enabled': true,
    });
  });

  testWidgets('JSON toolbar formats and compacts editor text', (
    WidgetTester tester,
  ) async {
    await _pumpPanel(
      tester,
      descriptors: <AcpResourceDescriptor>[_jsonResourceDescriptor()],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(_jsonTextField(), '{"b":2,"a":[1]}');
    await tester.tap(find.byTooltip('Format JSON'));
    await tester.pumpAndSettle();

    var textField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('acp-json-editor-text-Attributes')),
        matching: find.byType(TextField),
      ),
    );
    expect(textField.controller!.text, contains('\n  "b": 2,'));
    expect(textField.controller!.text, contains('\n  "a": ['));

    await tester.tap(find.byTooltip('Compact JSON'));
    await tester.pumpAndSettle();

    textField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('acp-json-editor-text-Attributes')),
        matching: find.byType(TextField),
      ),
    );
    expect(textField.controller!.text, '{"b":2,"a":[1]}');
  });

  testWidgets('server failures retain operator input for retry', (
    WidgetTester tester,
  ) async {
    final repository = FakeAcpAdminRepository()
      ..createResult = const Result<Object?>.failure(
        ApiFailure(422, 'Name is already in use.'),
      );
    await _pumpPanel(
      tester,
      repository: repository,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'retained-input',
          title: 'Retained Input',
          entitySet: 'RetainedInputs',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Name', label: 'Name'),
          ],
          createFields: <AcpFieldDescriptor>[
            AcpFieldDescriptor(key: 'Name', label: 'Name', required: true),
          ],
          allowCreate: true,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-Name')),
      'operator value',
    );
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Name is already in use.'), findsWidgets);
    expect(find.text('Create Retained Input'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('acp-dynamic-field-Name')),
          )
          .controller!
          .text,
      'operator value',
    );

    repository.createResult = const Result<Object?>.success(<String, Object?>{
      'Id': 'created',
      'RowVersion': 1,
    });
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('Create Retained Input'), findsNothing);
  });

  testWidgets('timezone validation rejects naive timestamps', (
    WidgetTester tester,
  ) async {
    final repository = await _pumpPanel(
      tester,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'windows',
          title: 'Windows',
          entitySet: 'Windows',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'WindowStart', label: 'Window Start'),
          ],
          createFields: <AcpFieldDescriptor>[
            AcpFieldDescriptor(
              key: 'WindowStart',
              label: 'Window Start',
              kind: AcpFieldKind.dateTime,
              required: true,
            ),
          ],
          allowCreate: true,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-WindowStart')),
      '2026-08-26T12:00:00',
    );
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.textContaining('with a timezone'), findsWidgets);
    expect(repository.createPayloads, isEmpty);

    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-WindowStart')),
      '2026-08-26T12:00:00-04:00',
    );
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(
      repository.createPayloads.single['WindowStart'],
      '2026-08-26T16:00:00.000Z',
    );
  });

  testWidgets('integer-list validation enforces configured bounds', (
    WidgetTester tester,
  ) async {
    final repository = await _pumpPanel(
      tester,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'calendars',
          title: 'Calendar',
          entitySet: 'Calendars',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'BusinessDays', label: 'Business Days'),
          ],
          createFields: <AcpFieldDescriptor>[
            AcpFieldDescriptor(
              key: 'BusinessDays',
              label: 'Business Days',
              kind: AcpFieldKind.integerList,
              minimumValue: 1,
              maximumValue: 7,
            ),
          ],
          allowCreate: true,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-BusinessDays')),
      '0, 3',
    );
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter values of at least 1.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-BusinessDays')),
      '[2, 8]',
    );
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter values no greater than 7.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-BusinessDays')),
      '1, 3, 7',
    );
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(repository.createPayloads.single['BusinessDays'], <int>[1, 3, 7]);
  });

  testWidgets('row detail dialog copies object ID to the clipboard', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = Map<String, dynamic>.from(
          call.arguments as Map<dynamic, dynamic>,
        );
        copiedText = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpPanel(
      tester,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'copy-resource',
          title: 'Copy Resource',
          entitySet: 'CopyResources',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Name', label: 'Name'),
          ],
        ),
      ],
    );

    await tester.tap(find.byTooltip('View row'));
    await tester.pumpAndSettle();

    expect(find.text('Copy Resource'), findsWidgets);
    expect(find.text('Copy ID'), findsOneWidget);

    await tester.tap(find.byKey(const Key('acp-row-copy-object-id-button')));
    await tester.pumpAndSettle();

    expect(copiedText, 'CopyResources-1');
    expect(find.text('Object ID copied.'), findsOneWidget);
  });
}

Finder _dialogButton(Type buttonType, String label) {
  return find.descendant(
    of: find.byType(Dialog),
    matching: find.widgetWithText(buttonType, label),
  );
}

Finder _jsonTextField() {
  return find.descendant(
    of: find.byKey(const Key('acp-json-editor-text-Attributes')),
    matching: find.byType(TextField),
  );
}

AcpResourceDescriptor _jsonResourceDescriptor() {
  return const AcpResourceDescriptor(
    key: 'json-resource',
    title: 'JSON Resource',
    entitySet: 'JsonResources',
    scopeMode: AcpScopeMode.none,
    columns: <AcpColumnDescriptor>[
      AcpColumnDescriptor(key: 'Name', label: 'Name'),
    ],
    createFields: <AcpFieldDescriptor>[
      AcpFieldDescriptor(
        key: 'Attributes',
        label: 'Attributes',
        kind: AcpFieldKind.json,
      ),
    ],
    allowCreate: true,
  );
}

class _TenantRowAcpAdminRepository extends FakeAcpAdminRepository {
  String? updateTenantId;
  Map<String, dynamic>? updateValues;

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
  }) async {
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: <AcpRow>[
          <String, Object?>{
            'Id': 'tenant-row-1',
            'TenantId': 'tenant-1',
            'RowVersion': 1,
            'IdentityKey': 'locked-key',
            'Name': 'Tenant scoped row',
          },
        ],
        total: 1,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<Object?>> updateRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    updateTenantId = tenantId;
    updateValues = Map<String, dynamic>.from(values);
    return updateResult;
  }
}

Future<FakeAcpAdminRepository> _pumpPanel(
  WidgetTester tester, {
  required List<AcpResourceDescriptor> descriptors,
  FakeAcpAdminRepository? repository,
  String? description,
}) async {
  final fakeRepository = repository ?? FakeAcpAdminRepository();
  final controllerProvider =
      StateNotifierProvider<AcpAdminController, AcpAdminState>((ref) {
        return AcpAdminController(
          repository: fakeRepository,
          descriptors: descriptors,
          onSessionExpired: () {},
        );
      });

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: AcpAdminPanel<AcpAdminController>(
            controllerProvider: controllerProvider,
            description: description,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakeRepository;
}
