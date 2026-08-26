import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/presentation/forms/app_searchable_select_field.dart';

void main() {
  test('AppSearchableSelectField rejects blank field guidance', () {
    expect(
      () => AppSearchableSelectField<String>(
        fieldKey: const Key('blank-help-field'),
        optionKeyPrefix: 'blank-help-option',
        labelText: 'Tenant',
        helpText: '',
        options: const <String>[],
        selectedOptionKey: null,
        optionKey: (option) => option,
        optionTitle: (option) => option,
        optionSubtitle: (option) => option,
        optionSearchText: (option) => option,
        onSelected: (_) {},
      ),
      throwsAssertionError,
    );
  });

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

      await tester.enterText(
        find.byKey(const Key('searchable-field')),
        'alpha',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('searchable-option-one')), findsOneWidget);
      expect(find.byKey(const Key('searchable-option-two')), findsNothing);
      await tester.tapAt(const Offset(760, 500));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('searchable-option-results')), findsNothing);

      final closedFieldHeight = tester
          .getSize(find.byType(AppSearchableSelectField<_SearchOption>))
          .height;

      await tester.tap(find.byKey(const Key('searchable-field')));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byType(AppSearchableSelectField<_SearchOption>))
            .height,
        closedFieldHeight,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('searchable-option-results')))
            .width,
        tester.getSize(find.byKey(const Key('searchable-field'))).width,
      );
      expect(find.byKey(const Key('searchable-option-one')), findsOneWidget);
      expect(find.byKey(const Key('searchable-option-two')), findsOneWidget);
      final firstOption = find.byKey(const Key('searchable-option-one'));
      final firstOptionTitle = tester.widget<Text>(
        find.descendant(of: firstOption, matching: find.text('Alpha One')),
      );
      final firstOptionSubtitle = tester.widget<Text>(
        find.descendant(of: firstOption, matching: find.text('First option')),
      );
      expect(firstOptionTitle.maxLines, 1);
      expect(firstOptionTitle.overflow, TextOverflow.ellipsis);
      expect(firstOptionSubtitle.maxLines, 1);
      expect(firstOptionSubtitle.overflow, TextOverflow.ellipsis);
      expect(find.byTooltip('Alpha One\nFirst option'), findsOneWidget);

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

      await tester.tap(find.byKey(const Key('searchable-field')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('searchable-field')),
        'temporary search',
      );
      await tester.tapAt(const Offset(760, 500));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('searchable-option-results')), findsNothing);
      expect(field.controller!.text, 'Beta Two');
    },
  );

  testWidgets('AppSearchableSelectField bounds and scrolls long option lists', (
    WidgetTester tester,
  ) async {
    final options = List<_SearchOption>.generate(
      20,
      (index) =>
          _SearchOption('option-$index', 'Option $index', 'Description $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              child: AppSearchableSelectField<_SearchOption>(
                fieldKey: const Key('long-searchable-field'),
                optionKeyPrefix: 'long-searchable-option',
                labelText: 'Tenant',
                helpText: 'Tenant to select from the bounded result list.',
                options: options,
                selectedOptionKey: null,
                optionKey: (option) => option.id,
                optionTitle: (option) => option.title,
                optionSubtitle: (option) => option.subtitle,
                optionSearchText: (option) => option.title,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('long-searchable-field')));
    await tester.pumpAndSettle();

    final results = find.byKey(const Key('long-searchable-option-results'));
    expect(tester.getSize(results).height, lessThanOrEqualTo(264));
    expect(
      find.descendant(of: results, matching: find.byType(Scrollable)),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Show Tenant options'));
    await tester.pumpAndSettle();
    expect(results, findsNothing);

    await tester.tap(find.byTooltip('Show Tenant options'));
    await tester.pumpAndSettle();
    expect(results, findsOneWidget);
  });

  testWidgets(
    'AppSearchableSelectField supports remote results and incremental loading',
    (WidgetTester tester) async {
      var options = <_SearchOption>[];
      var isLoading = true;
      var hasMore = false;
      var loadMoreCalls = 0;
      var openedCalls = 0;
      final queries = <String>[];
      late StateSetter setFixtureState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setFixtureState = setState;
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 360,
                    child: AppSearchableSelectField<_SearchOption>(
                      fieldKey: const Key('remote-searchable-field'),
                      optionKeyPrefix: 'remote-searchable-option',
                      labelText: 'Tenant',
                      helpText: 'Search all tenants from the backend.',
                      options: options,
                      selectedOptionKey: 'selected',
                      selectedOptionTitle: 'Selected tenant',
                      optionKey: (option) => option.id,
                      optionTitle: (option) => option.title,
                      optionSubtitle: (option) => option.subtitle,
                      optionSearchText: (option) => option.title,
                      onSearchChanged: queries.add,
                      onOpened: () {
                        openedCalls += 1;
                      },
                      isLoading: isLoading,
                      hasMoreOptions: hasMore,
                      onLoadMore: () {
                        loadMoreCalls += 1;
                      },
                      onSelected: (_) {},
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      final field = find.byKey(const Key('remote-searchable-field'));
      final fieldSize = tester.getSize(field);
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        'Selected tenant',
      );

      await tester.tap(field);
      await tester.pump(const Duration(milliseconds: 500));
      expect(openedCalls, 1);
      expect(queries, contains(''));
      expect(
        find.byKey(const Key('app-searchable-select-loading')),
        findsOneWidget,
      );

      await tester.enterText(field, 'remote');
      await tester.pump();
      expect(openedCalls, 1);
      expect(queries.last, 'remote');

      setFixtureState(() {
        options = const <_SearchOption>[
          _SearchOption('remote', 'Remote tenant', 'Backend result'),
        ];
        hasMore = true;
      });
      await tester.pump();
      expect(tester.widget<TextFormField>(field).controller!.text, 'remote');
      expect(
        find.byKey(const Key('app-searchable-select-loading-more')),
        findsOneWidget,
      );

      setFixtureState(() {
        isLoading = false;
      });
      await tester.pump();
      expect(tester.getSize(field), fieldSize);
      await tester.tap(
        find.byKey(const Key('remote-searchable-option-load-more')),
      );
      expect(loadMoreCalls, 1);

      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(queries.last, '');
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        'Selected tenant',
      );
    },
  );
}

class _SearchOption {
  const _SearchOption(this.id, this.title, this.subtitle);

  final String id;
  final String title;
  final String subtitle;
}
