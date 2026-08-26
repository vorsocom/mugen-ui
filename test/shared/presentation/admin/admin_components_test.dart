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
}
