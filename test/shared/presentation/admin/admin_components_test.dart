import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';

const String _billingSubtitle =
    'Define the global Products and Prices offered by the platform. '
    'This catalog never follows tenant selection.';

void main() {
  testWidgets('AdminPageHeader copy fills space beside a wide-layout action', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminPageHeader(
            title: 'Billing Catalog',
            subtitle: _billingSubtitle,
            primaryAction: SizedBox(
              key: Key('primary-action'),
              width: 140,
              height: 40,
            ),
          ),
        ),
      ),
    );

    final subtitleSize = tester.getSize(find.text(_billingSubtitle));
    expect(subtitleSize.width, greaterThan(1200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminPageHeader stacks its action on narrow layouts', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminPageHeader(
            title: 'Billing Catalog',
            subtitle: _billingSubtitle,
            primaryAction: SizedBox(
              key: Key('primary-action'),
              width: 140,
              height: 40,
            ),
          ),
        ),
      ),
    );

    final subtitleBottom = tester.getBottomLeft(find.text(_billingSubtitle)).dy;
    final actionTop = tester
        .getTopLeft(find.byKey(const Key('primary-action')))
        .dy;
    expect(actionTop, greaterThan(subtitleBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminTabs hides overflow controls when every tab fits', (
    WidgetTester tester,
  ) async {
    await _pumpTabs(
      tester,
      width: 600,
      labels: const <String>['Accounts', 'Subscriptions', 'Invoices'],
    );

    expect(find.byKey(const Key('admin-tabs-scroll-backward')), findsNothing);
    expect(find.byKey(const Key('admin-tabs-scroll-forward')), findsNothing);
  });

  testWidgets('AdminTabs buttons reveal tabs in both directions', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpTabs(
      tester,
      width: 320,
      labels: List<String>.generate(
        8,
        (index) => 'Administration resource ${index + 1}',
      ),
    );
    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('admin-tabs-scroll-view')),
    );
    final controller = scrollView.controller!;

    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(find.byTooltip('Show more tabs'), findsOneWidget);
    expect(find.bySemanticsLabel('Show more tabs'), findsOneWidget);
    expect(find.byTooltip('Show previous tabs'), findsNothing);

    await tester.tap(find.byKey(const Key('admin-tabs-scroll-forward')));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    expect(find.byTooltip('Show previous tabs'), findsOneWidget);
    expect(find.bySemanticsLabel('Show previous tabs'), findsOneWidget);
    expect(find.byTooltip('Show more tabs'), findsOneWidget);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(find.byTooltip('Show previous tabs'), findsOneWidget);
    expect(find.byTooltip('Show more tabs'), findsNothing);

    await tester.tap(find.byKey(const Key('admin-tabs-scroll-backward')));
    await tester.pumpAndSettle();

    expect(controller.offset, lessThan(controller.position.maxScrollExtent));
    expect(find.byTooltip('Show more tabs'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('AdminTabs removes overflow controls after a wider resize', (
    WidgetTester tester,
  ) async {
    const labels = <String>[
      'Accounts',
      'Subscriptions',
      'Invoices',
      'Payments',
    ];
    await _pumpTabs(tester, width: 260, labels: labels);
    expect(find.byKey(const Key('admin-tabs-scroll-forward')), findsOneWidget);

    await _pumpTabs(tester, width: 900, labels: labels);

    expect(find.byKey(const Key('admin-tabs-scroll-backward')), findsNothing);
    expect(find.byKey(const Key('admin-tabs-scroll-forward')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpTabs(
  WidgetTester tester, {
  required double width,
  required List<String> labels,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: AdminTabs(
              items: <AdminTabItem>[
                for (var index = 0; index < labels.length; index += 1)
                  AdminTabItem(
                    key: Key('tab-$index'),
                    label: labels[index],
                    selected: index == 0,
                    onSelected: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
