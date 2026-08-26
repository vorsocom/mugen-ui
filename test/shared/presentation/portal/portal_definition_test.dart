import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/shared/presentation/portal/portal_definition.dart';
import 'package:mugen_ui/shared/presentation/portal/portal_theme_tokens.dart';

void main() {
  test('portal definition content supports typed downstream overrides', () {
    final theme = PortalThemeTokens.defaults.copyWith(
      background: Colors.black,
      ink: Colors.white,
      titleInk: Colors.red,
      muted: Colors.grey,
      surface: Colors.blue,
      line: Colors.cyan,
      indigo: Colors.indigo,
      indigoDark: Colors.indigoAccent,
      whatsApp: Colors.green,
      graphite: Colors.blueGrey,
      onGraphite: Colors.yellow,
      onGraphiteMuted: Colors.orange,
      grid: Colors.purple,
      shadow: Colors.brown,
      displayFontFamily: 'Display',
      bodyFontFamily: 'Body',
    );
    final footer = defaultPortalDefinition.footer.copyWith(
      companyName: 'Company',
      termsLabel: 'Terms',
      privacyLabel: 'Privacy',
      slogan: 'Slogan',
    );
    final landing = defaultPortalDefinition.landing.copyWith(
      title: 'Title',
      subtitleWithWhatsApp: 'Enabled',
      subtitleWithoutWhatsApp: 'Disabled',
      signInEyebrow: 'Sign eyebrow',
      signInTitle: 'Sign title',
      signInDescription: 'Sign description',
      whatsAppEyebrow: 'WhatsApp eyebrow',
      whatsAppTitle: 'WhatsApp title',
      whatsAppDescription: 'WhatsApp description',
      securityNote: 'Secure',
    );
    final login = defaultPortalDefinition.login.copyWith(
      storyKicker: 'Story kicker',
      storyTitle: 'Story title',
      storyDescription: 'Story description',
      accessPoints: const <String>['Access'],
      accountKicker: 'Account',
      title: 'Login',
      description: 'Login description',
      status: 'Status',
    );
    final section = defaultPortalDefinition.terms.sections.first.copyWith(
      title: 'Section',
      body: 'Body',
    );
    final terms = defaultPortalDefinition.terms.copyWith(
      title: 'Custom terms',
      lastUpdated: 'Today',
      summary: 'Summary',
      sections: <PortalDocumentSection>[section],
    );
    final definition = defaultPortalDefinition.copyWith(
      logoAssetPath: 'logo.png',
      logoSemanticLabel: 'Logo',
      technicalPatternAssetPath: 'pattern.png',
      theme: theme,
      footer: footer,
      landing: landing,
      login: login,
      terms: terms,
      privacy: terms,
    );

    expect(definition.logoAssetPath, 'logo.png');
    expect(definition.logoSemanticLabel, 'Logo');
    expect(definition.technicalPatternAssetPath, 'pattern.png');
    expect(definition.theme.displayFontFamily, 'Display');
    expect(definition.theme.bodyFontFamily, 'Body');
    expect(definition.theme.background, Colors.black);
    expect(definition.theme.shadow, Colors.brown);
    expect(definition.footer.companyName, 'Company');
    expect(definition.footer.slogan, 'Slogan');
    expect(definition.landing.title, 'Title');
    expect(definition.landing.subtitleWithWhatsApp, 'Enabled');
    expect(definition.landing.whatsAppDescription, 'WhatsApp description');
    expect(definition.login.storyKicker, 'Story kicker');
    expect(definition.login.accessPoints, const <String>['Access']);
    expect(definition.login.status, 'Status');
    expect(definition.terms.title, 'Custom terms');
    expect(definition.terms.sections.single.title, 'Section');
    expect(definition.privacy.sections.single.body, 'Body');
  });

  test('portal copyWith methods retain omitted values', () {
    expect(
      defaultPortalDefinition.copyWith().logoAssetPath,
      defaultPortalDefinition.logoAssetPath,
    );
    expect(
      defaultPortalDefinition.footer.copyWith().termsLabel,
      defaultPortalDefinition.footer.termsLabel,
    );
    expect(
      defaultPortalDefinition.landing.copyWith().signInTitle,
      defaultPortalDefinition.landing.signInTitle,
    );
    expect(
      defaultPortalDefinition.login.copyWith().title,
      defaultPortalDefinition.login.title,
    );
    expect(
      defaultPortalDefinition.privacy.copyWith().summary,
      defaultPortalDefinition.privacy.summary,
    );
    expect(
      defaultPortalDefinition.privacy.sections.first.copyWith().body,
      defaultPortalDefinition.privacy.sections.first.body,
    );
    expect(
      PortalThemeTokens.defaults.copyWith().indigo,
      PortalThemeTokens.defaults.indigo,
    );
  });
}
