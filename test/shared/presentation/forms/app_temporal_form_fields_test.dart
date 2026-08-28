import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/presentation/forms/app_temporal_form_fields.dart';

void main() {
  test('temporal fields reject blank guidance', () {
    expect(
      () => AppDateTimeFormField(
        labelText: 'When',
        helpText: '',
        value: null,
        onChanged: (_) {},
      ),
      throwsAssertionError,
    );
    expect(
      () => AppTimeOfDayFormField(
        labelText: 'When',
        helpText: '',
        value: null,
        onChanged: (_) {},
      ),
      throwsAssertionError,
    );
    expect(
      () => AppDateListFormField(
        labelText: 'Dates',
        helpText: '',
        values: const <DateTime>[],
        onChanged: (_) {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets('empty temporal fields separate floated labels from hints', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TemporalTestApp(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDateTimeFormField(
              key: const Key('empty-date-time'),
              labelText: 'Started At',
              hintText: 'Select a UTC date and time',
              helpText: 'Choose the start timestamp.',
              value: null,
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            AppTimeOfDayFormField(
              key: const Key('empty-time'),
              labelText: 'Business Start',
              hintText: 'Select a 24-hour time',
              helpText: 'Choose the business start time.',
              value: null,
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            AppDateListFormField(
              key: const Key('empty-date-list'),
              labelText: 'Holiday Dates',
              hintText: 'Select one or more calendar dates',
              helpText: 'Choose holiday dates.',
              values: const <DateTime>[],
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    for (final entry in <({Key key, String label, String hint})>[
      (
        key: const Key('empty-date-time'),
        label: 'Started At',
        hint: 'Select a UTC date and time',
      ),
      (
        key: const Key('empty-time'),
        label: 'Business Start',
        hint: 'Select a 24-hour time',
      ),
      (
        key: const Key('empty-date-list'),
        label: 'Holiday Dates',
        hint: 'Select one or more calendar dates',
      ),
    ]) {
      final decorator = tester.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(entry.key),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(decorator.child, isNull);
      expect(decorator.decoration.hintText, entry.hint);
      expect(
        decorator.decoration.floatingLabelBehavior,
        FloatingLabelBehavior.always,
      );
      expect(
        tester.getRect(find.text(entry.label)).bottom,
        lessThanOrEqualTo(tester.getRect(find.text(entry.hint)).top),
      );
    }
  });

  testWidgets(
    'date-time field selects UTC minutes, preserves diagnostics, and clears',
    (tester) async {
      DateTime? value = DateTime.utc(2026, 5, 19, 12, 34, 56, 789);
      late StateSetter setFixtureState;

      await tester.pumpWidget(
        _TemporalTestApp(
          child: StatefulBuilder(
            builder: (context, setState) {
              setFixtureState = setState;
              return AppDateTimeFormField(
                key: const Key('date-time-field'),
                pickerButtonKey: const Key('date-time-picker'),
                clearButtonKey: const Key('date-time-clear'),
                labelText: 'Effective At',
                helpText: 'Choose the effective timestamp.',
                value: value,
                onChanged: (next) => setState(() => value = next),
              );
            },
          ),
        ),
      );

      expect(find.text('2026-05-19 12:34 UTC'), findsOneWidget);
      expect(find.byTooltip('2026-05-19T12:34:56.789Z'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.byKey(const Key('date-time-picker')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(
        MediaQuery.of(
          tester.element(find.byType(TimePickerDialog)),
        ).alwaysUse24HourFormat,
        isTrue,
      );
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pumpAndSettle();

      expect(value, DateTime.utc(2026, 5, 19, 12, 34));
      expect(find.byTooltip('2026-05-19T12:34:00.000Z'), findsOneWidget);

      await tester.tap(find.byKey(const Key('date-time-clear')));
      await tester.pump();
      expect(find.text('Select a UTC date and time'), findsOneWidget);

      setFixtureState(() => value = DateTime.utc(2027, 1, 2, 3, 4, 5));
      await tester.pumpAndSettle();
      expect(find.text('2027-01-02 03:04 UTC'), findsOneWidget);
    },
  );

  testWidgets('date-time picker cancellation and bounds keep the value', (
    tester,
  ) async {
    var value = DateTime.utc(1800, 1, 1, 1, 2, 3);
    await tester.pumpWidget(
      _TemporalTestApp(
        child: AppDateTimeFormField(
          key: const Key('bounded-date-time-field'),
          pickerButtonKey: const Key('bounded-date-time-picker'),
          labelText: 'Bounded',
          helpText: 'Choose a bounded timestamp.',
          value: value,
          firstDate: DateTime.utc(2020),
          lastDate: DateTime.utc(2030, 12, 31),
          onChanged: (next) => value = next!,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('bounded-date-time-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(value, DateTime.utc(1800, 1, 1, 1, 2, 3));

    await tester.tap(find.byKey(const Key('bounded-date-time-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(value, DateTime.utc(1800, 1, 1, 1, 2, 3));
  });

  testWidgets(
    'date-time field validates and respects required/read-only state',
    (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _TemporalTestApp(
          child: Form(
            key: formKey,
            child: AppDateTimeFormField(
              key: const Key('required-date-time'),
              pickerButtonKey: const Key('required-date-time-picker'),
              clearButtonKey: const Key('required-date-time-clear'),
              labelText: 'Required',
              helpText: 'Required timestamp.',
              value: null,
              required: true,
              readOnly: true,
              validator: (value) =>
                  value == null ? 'Choose a timestamp.' : null,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Choose a timestamp.'), findsOneWidget);
      expect(find.byKey(const Key('required-date-time-clear')), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('required-date-time-picker')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('date-time field opens from keyboard activation', (tester) async {
    await tester.pumpWidget(
      _TemporalTestApp(
        child: AppDateTimeFormField(
          key: const Key('keyboard-date-time'),
          labelText: 'Keyboard',
          helpText: 'Keyboard-accessible timestamp.',
          value: null,
          onChanged: (_) {},
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('time field selects, cancels, clears, and syncs externally', (
    tester,
  ) async {
    TimeOfDay? value = const TimeOfDay(hour: 17, minute: 30);
    late StateSetter setFixtureState;
    await tester.pumpWidget(
      _TemporalTestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            setFixtureState = setState;
            return AppTimeOfDayFormField(
              key: const Key('time-field'),
              pickerButtonKey: const Key('time-picker'),
              clearButtonKey: const Key('time-clear'),
              labelText: 'Business Start',
              helpText: 'Choose the business start time.',
              value: value,
              diagnosticValue: '17:30:45',
              onChanged: (next) => setState(() => value = next),
            );
          },
        ),
      ),
    );

    expect(find.text('17:30'), findsOneWidget);
    expect(find.byTooltip('17:30:45'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('time-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(value, const TimeOfDay(hour: 17, minute: 30));

    await tester.tap(find.byKey(const Key('time-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    expect(value, const TimeOfDay(hour: 17, minute: 30));

    await tester.tap(find.byKey(const Key('time-clear')));
    await tester.pump();
    expect(find.text('Select a time'), findsOneWidget);

    setFixtureState(() => value = const TimeOfDay(hour: 8, minute: 5));
    await tester.pumpAndSettle();
    expect(find.text('08:05'), findsOneWidget);
  });

  testWidgets('time field validates required and disabled states', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      _TemporalTestApp(
        child: Form(
          key: formKey,
          child: AppTimeOfDayFormField(
            pickerButtonKey: const Key('disabled-time-picker'),
            clearButtonKey: const Key('disabled-time-clear'),
            labelText: 'Required time',
            helpText: 'Required time help.',
            value: const TimeOfDay(hour: 9, minute: 0),
            required: true,
            enabled: false,
            validator: (_) => 'Time error.',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Time error.'), findsOneWidget);
    expect(find.byKey(const Key('disabled-time-clear')), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('disabled-time-picker')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('date list normalizes, adds, removes, clears, and syncs', (
    tester,
  ) async {
    var values = <DateTime>[
      DateTime.utc(2026, 1, 3),
      DateTime.utc(2026, 1, 2),
      DateTime.utc(2026, 1, 3, 20),
    ];
    late StateSetter setFixtureState;
    await tester.pumpWidget(
      _TemporalTestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            setFixtureState = setState;
            return AppDateListFormField(
              key: const Key('date-list-field'),
              pickerButtonKey: const Key('date-list-picker'),
              clearButtonKey: const Key('date-list-clear'),
              labelText: 'Holiday Dates',
              helpText: 'Choose holiday dates.',
              values: values,
              onChanged: (next) => setState(() => values = next),
            );
          },
        ),
      ),
    );

    expect(find.byKey(const Key('app-date-list-chip-2026-01-02')), findsOne);
    expect(find.byKey(const Key('app-date-list-chip-2026-01-03')), findsOne);
    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.byTooltip('2026-01-02, 2026-01-03'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('date-list-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    expect(values, hasLength(2));

    final firstChip = find.byKey(const Key('app-date-list-chip-2026-01-02'));
    tester.widget<InputChip>(firstChip).onDeleted!();
    await tester.pump();
    expect(values.map((value) => value.day), <int>[3]);

    await tester.tap(find.byKey(const Key('date-list-clear')));
    await tester.pump();
    expect(values, isEmpty);
    expect(find.text('Add one or more dates'), findsOneWidget);

    setFixtureState(() => values = <DateTime>[DateTime.utc(2028, 4, 5)]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-date-list-chip-2028-04-05')), findsOne);
  });

  testWidgets('date list validates and respects read-only bounds', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      _TemporalTestApp(
        child: Form(
          key: formKey,
          child: AppDateListFormField(
            pickerButtonKey: const Key('readonly-date-list-picker'),
            clearButtonKey: const Key('readonly-date-list-clear'),
            labelText: 'Required dates',
            helpText: 'Required dates help.',
            values: const <DateTime>[],
            firstDate: DateTime.utc(2020),
            lastDate: DateTime.utc(2030),
            required: true,
            readOnly: true,
            validator: (value) => value == null || value.isEmpty
                ? 'Choose at least one date.'
                : null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Choose at least one date.'), findsOneWidget);
    expect(find.byKey(const Key('readonly-date-list-clear')), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('readonly-date-list-picker')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('required date list retains its final date and handles cancel', (
    tester,
  ) async {
    var values = <DateTime>[DateTime.utc(2026, 7, 1)];
    await tester.pumpWidget(
      _TemporalTestApp(
        child: AppDateListFormField(
          pickerButtonKey: const Key('required-date-list-picker'),
          clearButtonKey: const Key('required-date-list-clear'),
          labelText: 'Required dates',
          helpText: 'Choose required dates.',
          values: values,
          required: true,
          onChanged: (next) => values = next,
        ),
      ),
    );

    expect(
      tester
          .widget<InputChip>(
            find.byKey(const Key('app-date-list-chip-2026-07-01')),
          )
          .onDeleted,
      isNull,
    );
    expect(find.byKey(const Key('required-date-list-clear')), findsNothing);

    await tester.tap(find.byKey(const Key('required-date-list-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(values, <DateTime>[DateTime.utc(2026, 7, 1)]);
  });
}

class _TemporalTestApp extends StatelessWidget {
  const _TemporalTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 520, child: child)),
      ),
    );
  }
}
