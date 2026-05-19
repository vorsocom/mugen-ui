import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
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
      ],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create Short Resource'), findsOneWidget);
    final dialogPanel = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(AppFormPanel),
    );
    expect(tester.getSize(dialogPanel).height, lessThan(360));
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
      expect(find.byTooltip('Undo JSON edit'), findsOneWidget);
      expect(find.byTooltip('Redo JSON edit'), findsOneWidget);
      expect(find.byTooltip('Format JSON'), findsOneWidget);
      expect(find.byTooltip('Compact JSON'), findsOneWidget);
    },
  );

  testWidgets('JSON validation blocks invalid payload submission', (
    WidgetTester tester,
  ) async {
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

    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('Copy ID')),
      findsOneWidget,
    );

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

Future<FakeAcpAdminRepository> _pumpPanel(
  WidgetTester tester, {
  required List<AcpResourceDescriptor> descriptors,
}) async {
  final repository = FakeAcpAdminRepository();
  final controllerProvider =
      StateNotifierProvider<AcpAdminController, AcpAdminState>((ref) {
        return AcpAdminController(
          repository: repository,
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
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}
