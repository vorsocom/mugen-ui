import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_operations_resources.dart';
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

  testWidgets(
    'money fields use selected currency precision and omit helper metadata',
    (WidgetTester tester) async {
      final repository = _ReferenceAcpAdminRepository();
      await _pumpPanel(
        tester,
        repository: repository,
        descriptors: const <AcpResourceDescriptor>[
          AcpResourceDescriptor(
            key: 'payments',
            title: 'Payments',
            entitySet: 'Payments',
            scopeMode: AcpScopeMode.none,
            columns: <AcpColumnDescriptor>[
              AcpColumnDescriptor(key: 'Amount', label: 'Amount', money: true),
            ],
            createFields: <AcpFieldDescriptor>[
              AcpFieldDescriptor(
                key: 'CurrencyDefinitionId',
                label: 'Currency',
                required: true,
                reference: AcpFieldReferenceDescriptor(
                  entitySet: 'BillingCurrencyDefinitions',
                  scopeMode: AcpScopeMode.none,
                  title: 'Currencies',
                  extraFilters: <String>['IsActive eq true'],
                  copyFieldsFromSelection: <String, String>{
                    'MinorUnit': '_CurrencyMinorUnit',
                    'Code': '_CurrencyCode',
                  },
                ),
              ),
              AcpFieldDescriptor(
                key: '_CurrencyMinorUnit',
                label: 'Minor Unit',
                hidden: true,
                includeInPayload: false,
              ),
              AcpFieldDescriptor(
                key: '_CurrencyCode',
                label: 'Currency Code',
                hidden: true,
                includeInPayload: false,
              ),
              AcpFieldDescriptor(
                key: 'Amount',
                label: 'Amount',
                kind: AcpFieldKind.money,
                required: true,
                minorUnitFieldKey: '_CurrencyMinorUnit',
                currencyCodeFieldKey: '_CurrencyCode',
              ),
            ],
            allowCreate: true,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('acp-reference-search-CurrencyDefinitionId')),
        'KWD',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key('acp-reference-option-CurrencyDefinitionId-currency-kwd'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-Amount')),
        '12.3456',
      );
      await tester.tap(_dialogButton(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 decimal places'), findsWidgets);
      expect(repository.createPayloads, isEmpty);

      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-Amount')),
        '12.345',
      );
      await tester.tap(_dialogButton(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(repository.createPayloads.single, <String, Object?>{
        'CurrencyDefinitionId': 'currency-kwd',
        'Amount': 12345,
      });
      expect(repository.referenceFilters, contains('IsActive eq true'));
    },
  );

  testWidgets(
    'money fields never assume two decimals when precision is unavailable',
    (WidgetTester tester) async {
      final repository = _UnresolvedMoneyAcpAdminRepository();
      await _pumpPanel(
        tester,
        repository: repository,
        descriptors: const <AcpResourceDescriptor>[
          AcpResourceDescriptor(
            key: 'payments',
            title: 'Payments',
            entitySet: 'Payments',
            scopeMode: AcpScopeMode.none,
            columns: <AcpColumnDescriptor>[
              AcpColumnDescriptor(key: 'Amount', label: 'Amount', money: true),
            ],
            createFields: <AcpFieldDescriptor>[
              AcpFieldDescriptor(
                key: '_CurrencyMinorUnit',
                label: 'Minor Unit',
                hidden: true,
                includeInPayload: false,
              ),
              AcpFieldDescriptor(
                key: 'Amount',
                label: 'Amount',
                kind: AcpFieldKind.money,
                required: true,
                minorUnitFieldKey: '_CurrencyMinorUnit',
              ),
            ],
            allowCreate: true,
          ),
        ],
      );

      expect(
        find.text('KWD 12345 minor units (currency precision unavailable)'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-Amount')),
        '12.34',
      );
      await tester.tap(_dialogButton(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Currency precision is unavailable'),
        findsWidgets,
      );
      expect(repository.createPayloads, isEmpty);
    },
  );

  testWidgets('conditional references clear stale values and preview impacts', (
    WidgetTester tester,
  ) async {
    final repository = _ReferenceAcpAdminRepository();
    await _pumpPanel(
      tester,
      repository: repository,
      descriptors: <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'prices',
          title: 'Prices',
          entitySet: 'Prices',
          scopeMode: AcpScopeMode.none,
          columns: const <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'PriceType', label: 'Type'),
          ],
          createFields: <AcpFieldDescriptor>[
            const AcpFieldDescriptor(
              key: 'PriceType',
              label: 'Price Type',
              initialValue: 'metered',
              options: <String>['metered', 'recurring'],
            ),
            const AcpFieldDescriptor(
              key: 'MeterDefinitionId',
              label: 'Meter',
              visibleWhenEquals: <String, List<Object>>{
                'PriceType': <Object>['metered'],
              },
              clearWhenHidden: true,
              submitNullWhenHidden: true,
              reference: AcpFieldReferenceDescriptor(
                entitySet: 'BillingMeterDefinitions',
                scopeMode: AcpScopeMode.none,
                title: 'Meters',
              ),
            ),
            const AcpFieldDescriptor(
              key: 'QuantityDelta',
              label: 'Quantity Delta',
              kind: AcpFieldKind.integer,
            ),
            AcpFieldDescriptor(
              key: 'Impact',
              label: 'Impact',
              kind: AcpFieldKind.computed,
              readOnly: true,
              includeInPayload: false,
              computedValueBuilder: (values) =>
                  'Result: ${values['QuantityDelta'] ?? '0'}',
            ),
          ],
          allowCreate: true,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('acp-reference-search-MeterDefinitionId')),
      'api',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('acp-reference-option-MeterDefinitionId-meter-api')),
    );
    await tester.enterText(
      find.byKey(const Key('acp-dynamic-field-QuantityDelta')),
      '8',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('acp-dynamic-field-Impact')),
        matching: find.text('Result: 8'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('acp-dynamic-field-PriceType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('recurring').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('acp-reference-search-MeterDefinitionId')),
      findsNothing,
    );
    await tester.tap(_dialogButton(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(repository.createPayloads.single, <String, Object?>{
      'PriceType': 'recurring',
      'MeterDefinitionId': null,
      'QuantityDelta': 8,
    });
  });

  testWidgets('archived lifecycle view offers restore without archive', (
    WidgetTester tester,
  ) async {
    final repository = _ArchivedAcpAdminRepository();
    await _pumpPanel(
      tester,
      repository: repository,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'products',
          title: 'Products',
          entitySet: 'Products',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Code', label: 'Code'),
          ],
          entityActions: <AcpActionDescriptor>[
            AcpActionDescriptor(
              name: 'archive',
              label: 'Archive',
              target: AcpActionTarget.entity,
              includeRowVersion: true,
            ),
          ],
          allowRestore: true,
          deletedViews: <AcpDeletedView>[
            AcpDeletedView.active,
            AcpDeletedView.archived,
          ],
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('acp-admin-deleted-view-products')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archived').last);
    await tester.pumpAndSettle();

    expect(repository.deletedView, AcpDeletedView.archived);
    expect(find.byTooltip('Restore row'), findsOneWidget);
    expect(find.byTooltip('More actions'), findsNothing);
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

  testWidgets(
    'subscription references render accessible labels and preserve raw IDs',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      final semantics = tester.ensureSemantics();
      final descriptor = billingOperationsResources.singleWhere(
        (resource) => resource.key == 'billing-subscriptions',
      );

      await _pumpPanel(
        tester,
        descriptors: <AcpResourceDescriptor>[descriptor],
        repository: _SubscriptionReferenceRepository(),
      );

      expect(find.text('Example Company · valet-primary'), findsOneWidget);
      expect(
        find.text(
          'valet-customer-inbox-standard-monthly-usd-v1 · recurring · USD',
        ),
        findsOneWidget,
      );
      expect(find.text('missing-account-uuid'), findsOneWidget);
      expect(find.text('missing-price-uuid'), findsOneWidget);
      expect(find.text('Not assigned'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('Account: Example Company · valet-primary'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Price: valet-customer-inbox-standard-monthly-usd-v1 · recurring · USD',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('View row').first);
      await tester.pumpAndSettle();
      expect(find.text('account-uuid'), findsOneWidget);
      expect(find.text('price-uuid'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(700, 900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Example Company · valet-primary'), findsOneWidget);
      expect(find.text('account-uuid'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'searchable and multi-select options submit stable payload values',
    (WidgetTester tester) async {
      final repository = await _pumpPanel(
        tester,
        descriptors: <AcpResourceDescriptor>[
          AcpResourceDescriptor(
            key: 'option-resource',
            title: 'Option Resource',
            entitySet: 'OptionResources',
            scopeMode: AcpScopeMode.none,
            columns: const <AcpColumnDescriptor>[
              AcpColumnDescriptor(key: 'Timezone', label: 'Timezone'),
            ],
            createFields: <AcpFieldDescriptor>[
              const AcpFieldDescriptor(
                key: 'Timezone',
                label: 'Timezone',
                required: true,
                options: <String>['America/Guyana', 'UTC'],
                optionLabels: <String, String>{'America/Guyana': 'Guyana time'},
                searchableOptions: true,
              ),
              AcpFieldDescriptor(
                key: 'CapabilityName',
                label: 'Capability',
                required: true,
                optionsBuilder: (_) => <String>['ping'],
                searchableOptions: true,
                allowCustomOption: true,
              ),
              const AcpFieldDescriptor(
                key: 'Capabilities',
                label: 'Capabilities',
                kind: AcpFieldKind.stringList,
                required: true,
                options: <String>['read', 'write'],
                multiSelectOptions: true,
                allowCustomOption: true,
              ),
              const AcpFieldDescriptor(
                key: 'BusinessDays',
                label: 'Business Days',
                kind: AcpFieldKind.integerList,
                options: <String>['1', '2'],
                optionLabels: <String, String>{'1': 'Monday', '2': 'Tuesday'},
                multiSelectOptions: true,
              ),
            ],
            allowCreate: true,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('acp-searchable-option-Timezone')),
        'invalid-zone',
      );
      await tester.tap(_dialogButton(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      expect(find.text('Select a valid timezone.'), findsOneWidget);
      expect(repository.createPayloads, isEmpty);

      await tester.enterText(
        find.byKey(const Key('acp-searchable-option-Timezone')),
        'Guyana',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guyana time').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('acp-searchable-option-CapabilityName')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ping').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('acp-option-Capabilities-read')));
      await tester.enterText(
        find.byKey(const Key('acp-custom-option-entry-Capabilities')),
        'custom.read',
      );
      await tester.ensureVisible(
        find.byKey(const Key('acp-custom-option-entry-Capabilities')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('acp-custom-option-entry-Capabilities')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('acp-custom-option-Capabilities-custom.read')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('acp-option-BusinessDays-1')));
      await tester.pumpAndSettle();

      await tester.tap(_dialogButton(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(repository.createPayloads.single, <String, Object?>{
        'Timezone': 'America/Guyana',
        'CapabilityName': 'ping',
        'Capabilities': <String>['read', 'custom.read'],
        'BusinessDays': <int>[1],
      });
    },
  );
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
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
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

class _ReferenceAcpAdminRepository extends FakeAcpAdminRepository {
  final List<String> referenceFilters = <String>[];

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
    referenceFilters.addAll(extraFilters);
    final rows = switch (descriptor.entitySet) {
      'BillingCurrencyDefinitions' => const <AcpRow>[
        <String, Object?>{
          'Id': 'currency-kwd',
          'Code': 'KWD',
          'DisplayName': 'Kuwaiti dinar',
          'MinorUnit': 3,
          'IsActive': true,
        },
      ],
      'BillingMeterDefinitions' => const <AcpRow>[
        <String, Object?>{
          'Id': 'meter-api',
          'Code': 'api_calls',
          'Unit': 'unit',
          'IsActive': true,
        },
      ],
      _ => const <AcpRow>[
        <String, Object?>{'Id': 'row-1', 'RowVersion': 1},
      ],
    };
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: rows,
        total: rows.length,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }
}

class _UnresolvedMoneyAcpAdminRepository extends FakeAcpAdminRepository {
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
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: const <AcpRow>[
          <String, Object?>{
            'Id': 'payment-1',
            'Currency': 'KWD',
            'Amount': 12345,
            'RowVersion': 1,
          },
        ],
        total: 1,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }
}

class _ArchivedAcpAdminRepository extends FakeAcpAdminRepository {
  AcpDeletedView deletedView = AcpDeletedView.active;

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
    this.deletedView = deletedView;
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: <AcpRow>[
          <String, Object?>{
            'Id': 'product-1',
            'Code': 'PRO',
            'DeletedAt': deletedView == AcpDeletedView.archived
                ? '2026-08-27T00:00:00Z'
                : null,
            'RowVersion': 2,
          },
        ],
        total: 1,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }
}

class _SubscriptionReferenceRepository extends FakeAcpAdminRepository {
  static const rows = <AcpRow>[
    <String, Object?>{
      'Id': 'subscription-1',
      'TenantId': 'global-id',
      'AccountId': 'account-uuid',
      'PriceId': 'price-uuid',
      'Status': 'active',
      'RowVersion': 1,
      'Account': <String, Object?>{
        'DisplayName': 'Example Company',
        'Code': 'valet-primary',
      },
      'Price': <String, Object?>{
        'Code': 'valet-customer-inbox-standard-monthly-usd-v1',
        'PriceType': 'recurring',
        'Currency': 'USD',
        'DeletedAt': '2026-07-31T00:00:00Z',
      },
    },
    <String, Object?>{
      'Id': 'subscription-2',
      'TenantId': 'global-id',
      'AccountId': 'missing-account-uuid',
      'PriceId': 'missing-price-uuid',
      'Status': 'active',
      'RowVersion': 1,
    },
    <String, Object?>{
      'Id': 'subscription-3',
      'TenantId': 'global-id',
      'AccountId': null,
      'PriceId': null,
      'Status': 'draft',
      'RowVersion': 1,
    },
  ];

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
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: rows,
        total: rows.length,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
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
