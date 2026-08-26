import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/portal/application/portal_whatsapp_signup_launcher.dart';
import 'package:mugen_ui/features/portal/presentation/pages/portal_document_page.dart';
import 'package:mugen_ui/features/portal/presentation/pages/portal_landing_page.dart';
import 'package:mugen_ui/features/portal/presentation/providers/portal_providers.dart';
import 'package:mugen_ui/features/portal/presentation/widgets/portal_page_shell.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';
import 'package:mugen_ui/shared/presentation/portal/portal_definition.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';

void main() {
  testWidgets('landing hides WhatsApp and uses fail-closed copy by default', (
    WidgetTester tester,
  ) async {
    await _pumpPortal(tester, child: const PortalLandingPage());

    expect(find.byKey(const Key('portal-sign-in-card')), findsOneWidget);
    expect(find.byKey(const Key('portal-whatsapp-card')), findsNothing);
    expect(
      find.text(
        'Sign in to access your workspace, settings, and connected services.',
      ),
      findsOneWidget,
    );
    final logoTop = tester.getTopLeft(
      find.byKey(const Key('portal-logo-link')),
    );
    final titleTop = tester.getTopLeft(
      find.byKey(const Key('portal-landing-title')),
    );
    expect(logoTop.dy, greaterThanOrEqualTo(0));
    expect(titleTop.dy, greaterThan(logoTop.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landing reveals WhatsApp and shows the shared placeholder', (
    WidgetTester tester,
  ) async {
    await _pumpPortal(
      tester,
      child: const PortalLandingPage(),
      whatsappEnabled: true,
    );

    expect(find.byKey(const Key('portal-whatsapp-card')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('portal-logo-link'))).dy,
      greaterThanOrEqualTo(0),
    );
    await tester.tap(find.byKey(const Key('portal-whatsapp-card')));
    await tester.pumpAndSettle();

    expect(find.byType(AppFormDialog), findsOneWidget);
    expect(
      find.text('WhatsApp Embedded Signup is not connected in this UI yet.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('portal-whatsapp-dialog-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AppFormDialog), findsNothing);
  });

  testWidgets('downstream WhatsApp launcher override receives the action', (
    WidgetTester tester,
  ) async {
    final launcher = _TestWhatsAppLauncher(
      result: const Result<void>.success(null),
    );
    await _pumpPortal(
      tester,
      child: const PortalLandingPage(),
      whatsappEnabled: true,
      launcher: launcher,
    );

    await tester.tap(find.byKey(const Key('portal-whatsapp-card')));
    await tester.pumpAndSettle();

    expect(launcher.callCount, 1);
    expect(find.byType(AppFormDialog), findsNothing);
  });

  testWidgets('downstream WhatsApp launcher failures use an error alert', (
    WidgetTester tester,
  ) async {
    final launcher = _TestWhatsAppLauncher(
      result: const Result<void>.failure(
        UnexpectedFailure('Meta connection is unavailable.'),
      ),
    );
    await _pumpPortal(
      tester,
      child: const PortalLandingPage(),
      whatsappEnabled: true,
      launcher: launcher,
    );

    await tester.tap(find.byKey(const Key('portal-whatsapp-card')));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorAlert), findsOneWidget);
    expect(find.text('Meta connection is unavailable.'), findsOneWidget);
  });

  testWidgets('unexpected WhatsApp launcher exceptions are contained', (
    WidgetTester tester,
  ) async {
    await _pumpPortal(
      tester,
      child: const PortalLandingPage(),
      whatsappEnabled: true,
      launcher: _ThrowingWhatsAppLauncher(),
    );

    await tester.tap(find.byKey(const Key('portal-whatsapp-card')));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorAlert), findsOneWidget);
    expect(
      find.text('WhatsApp Embedded Signup could not be started.'),
      findsOneWidget,
    );
  });

  testWidgets('landing and footer actions navigate to public destinations', (
    WidgetTester tester,
  ) async {
    final navigator = _FakeAppNavigator();
    await _pumpPortal(
      tester,
      child: const PortalLandingPage(),
      navigator: navigator,
    );

    await tester.tap(find.byKey(const Key('portal-sign-in-card')));
    expect(navigator.routes, <String>[AppRoutePaths.login]);

    await tester.tap(find.byKey(const Key('portal-terms-link')));
    await tester.tap(find.byKey(const Key('portal-privacy-link')));
    await tester.tap(find.byKey(const Key('portal-logo-link')));
    expect(navigator.routes, <String>[
      AppRoutePaths.login,
      AppRoutePaths.terms,
      AppRoutePaths.privacy,
      AppRoutePaths.portal,
    ]);
  });

  testWidgets('landing action is keyboard accessible and visibly focused', (
    WidgetTester tester,
  ) async {
    final navigator = _FakeAppNavigator();
    await _pumpPortal(
      tester,
      child: const PortalLandingPage(),
      navigator: navigator,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final card = find.byKey(const Key('portal-sign-in-card'));
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: card, matching: find.byType(InkWell)),
    );
    inkWell.onHover!(true);
    await tester.pump(const Duration(milliseconds: 160));

    final animatedContainer = tester.widget<AnimatedContainer>(
      find.descendant(of: card, matching: find.byType(AnimatedContainer)).first,
    );
    final decoration = animatedContainer.decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.width, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(navigator.routes, contains(AppRoutePaths.login));

    final semantics = tester.getSemantics(card);
    expect(semantics.label, contains('Sign in to your account'));
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  testWidgets('portal definition overrides brand assets and copy', (
    WidgetTester tester,
  ) async {
    final definition = defaultPortalDefinition.copyWith(
      logoSemanticLabel: 'Acme portal home',
      landing: defaultPortalDefinition.landing.copyWith(
        title: 'Operate with confidence.',
      ),
      footer: defaultPortalDefinition.footer.copyWith(
        companyName: 'Acme Operations, Inc.',
      ),
    );
    await _pumpPortal(
      tester,
      child: const PortalLandingPage(),
      definition: definition,
    );

    expect(find.text('OPERATE WITH CONFIDENCE.'), findsOneWidget);
    expect(find.textContaining('ACME OPERATIONS, INC.'), findsOneWidget);
    expect(find.bySemanticsLabel('Acme portal home'), findsOneWidget);
  });

  testWidgets('phone landing simplifies the footer without overflow', (
    WidgetTester tester,
  ) async {
    await _pumpPortal(
      tester,
      child: const PortalLandingPage(),
      size: const Size(390, 844),
    );

    expect(find.byKey(const Key('portal-footer-slogan')), findsNothing);
    expect(find.byKey(const Key('portal-legal-links')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legal pages retain supplied prose and scroll on phones', (
    WidgetTester tester,
  ) async {
    final navigator = _FakeAppNavigator();
    await _pumpPortal(
      tester,
      child: const PortalTermsPage(),
      size: const Size(390, 844),
      navigator: navigator,
    );

    expect(find.text('TERMS OF USE.'), findsOneWidget);
    expect(find.text('Last updated August 26, 2026'), findsOneWidget);
    expect(find.textContaining('These mock terms'), findsOneWidget);
    expect(find.textContaining('DRAFT', findRichText: true), findsNothing);

    await tester.tap(find.byKey(const Key('portal-back-link')));
    expect(navigator.routes, <String>[AppRoutePaths.portal]);

    final finalSection = find.text('9. Termination and contact');
    await tester.scrollUntilVisible(
      finalSection,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(finalSection, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legal sections switch between two and one columns', (
    WidgetTester tester,
  ) async {
    await _pumpPortal(
      tester,
      child: const PortalPrivacyPage(),
      size: const Size(1440, 900),
    );
    final desktopTitle = tester.getTopLeft(find.text('1. Data we collect'));
    final desktopBody = tester.getTopLeft(
      find.textContaining('When you opt in to receive messages'),
    );
    expect(desktopBody.dx, greaterThan(desktopTitle.dx));

    await _pumpPortal(
      tester,
      child: const PortalPrivacyPage(),
      size: const Size(390, 844),
    );
    final mobileTitle = tester.getTopLeft(find.text('1. Data we collect'));
    final mobileBody = tester.getTopLeft(
      find.textContaining('When you opt in to receive messages'),
    );
    expect(mobileBody.dy, greaterThan(mobileTitle.dy));
    expect(tester.takeException(), isNull);
  });

  test('PortalGridPainter only repaints when its color changes', () {
    const painter = PortalGridPainter(color: Colors.black);
    expect(
      painter.shouldRepaint(const PortalGridPainter(color: Colors.black)),
      isFalse,
    );
    expect(
      painter.shouldRepaint(const PortalGridPainter(color: Colors.white)),
      isTrue,
    );
  });
}

Future<void> _pumpPortal(
  WidgetTester tester, {
  required Widget child,
  bool whatsappEnabled = false,
  Size size = const Size(1440, 900),
  _FakeAppNavigator? navigator,
  PortalWhatsAppSignupLauncher? launcher,
  PortalDefinition? definition,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final config = AppConfig.defaults().merge(
    AppConfigurationOverride(whatsappEmbeddedSignupEnabled: whatsappEnabled),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWith((ref) => config),
        appNavigatorProvider.overrideWith(
          (ref) => navigator ?? _FakeAppNavigator(),
        ),
        if (launcher != null)
          portalWhatsAppSignupLauncherProvider.overrideWithValue(launcher),
        if (definition != null)
          portalDefinitionProvider.overrideWithValue(definition),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAppNavigator extends AppNavigator {
  final List<String> routes = <String>[];

  @override
  Future<void> navigateTo(String routeName) async {
    routes.add(routeName);
  }
}

class _TestWhatsAppLauncher implements PortalWhatsAppSignupLauncher {
  _TestWhatsAppLauncher({required this.result});

  final Result<void> result;
  int callCount = 0;

  @override
  Future<Result<void>> launch() async {
    callCount += 1;
    return result;
  }
}

class _ThrowingWhatsAppLauncher implements PortalWhatsAppSignupLauncher {
  @override
  Future<Result<void>> launch() {
    throw StateError('launcher failed');
  }
}
