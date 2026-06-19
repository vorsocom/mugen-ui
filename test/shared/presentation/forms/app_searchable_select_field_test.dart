import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/presentation/forms/app_searchable_select_field.dart';

void main() {
  testWidgets(
    'AppSearchableSelectField filters, empties, and selects options',
    (WidgetTester tester) async {
      final options = <_SearchOption>[
        const _SearchOption('one', 'Alpha One', 'First option'),
        const _SearchOption('two', 'Beta Two', 'Second option'),
      ];
      _SearchOption? selected;
      String? selectedId;

      Future<void> pumpField() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppSearchableSelectField<_SearchOption>(
                fieldKey: const Key('searchable-field'),
                optionKeyPrefix: 'searchable-option',
                labelText: 'Searchable',
                hintText: 'Search options',
                helpText: 'Choose an option.',
                options: options,
                selectedOptionKey: selectedId,
                optionKey: (option) => option.id,
                optionTitle: (option) => option.title,
                optionSubtitle: (option) => option.subtitle,
                optionSearchText: (option) =>
                    '${option.title} ${option.subtitle} ${option.id}',
                onSelected: (option) {
                  selected = option;
                  selectedId = option.id;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpField();

      await tester.tap(find.byKey(const Key('searchable-field')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('searchable-option-one')), findsOneWidget);
      expect(find.byKey(const Key('searchable-option-two')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('searchable-field')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matching options found.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('searchable-field')), '');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('searchable-option-one')), findsOneWidget);
      expect(find.byKey(const Key('searchable-option-two')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('searchable-field')),
        'beta second',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('searchable-option-one')), findsNothing);
      expect(find.byKey(const Key('searchable-option-two')), findsOneWidget);

      await tester.tap(find.byKey(const Key('searchable-option-two')));
      await tester.pumpAndSettle();
      expect(selected?.id, 'two');

      await pumpField();
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('searchable-field')),
      );
      expect(field.controller!.text, 'Beta Two');
    },
  );
}

class _SearchOption {
  const _SearchOption(this.id, this.title, this.subtitle);

  final String id;
  final String title;
  final String subtitle;
}
