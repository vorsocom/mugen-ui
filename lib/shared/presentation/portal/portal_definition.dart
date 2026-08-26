import 'package:flutter/foundation.dart';

import 'package:mugen_ui/shared/presentation/portal/portal_theme_tokens.dart';

@immutable
class PortalDefinition {
  const PortalDefinition({
    required this.logoAssetPath,
    required this.logoSemanticLabel,
    required this.technicalPatternAssetPath,
    required this.theme,
    required this.footer,
    required this.landing,
    required this.login,
    required this.terms,
    required this.privacy,
  });

  final String logoAssetPath;
  final String logoSemanticLabel;
  final String technicalPatternAssetPath;
  final PortalThemeTokens theme;
  final PortalFooterContent footer;
  final PortalLandingContent landing;
  final PortalLoginContent login;
  final PortalDocumentContent terms;
  final PortalDocumentContent privacy;

  PortalDefinition copyWith({
    String? logoAssetPath,
    String? logoSemanticLabel,
    String? technicalPatternAssetPath,
    PortalThemeTokens? theme,
    PortalFooterContent? footer,
    PortalLandingContent? landing,
    PortalLoginContent? login,
    PortalDocumentContent? terms,
    PortalDocumentContent? privacy,
  }) {
    return PortalDefinition(
      logoAssetPath: logoAssetPath ?? this.logoAssetPath,
      logoSemanticLabel: logoSemanticLabel ?? this.logoSemanticLabel,
      technicalPatternAssetPath:
          technicalPatternAssetPath ?? this.technicalPatternAssetPath,
      theme: theme ?? this.theme,
      footer: footer ?? this.footer,
      landing: landing ?? this.landing,
      login: login ?? this.login,
      terms: terms ?? this.terms,
      privacy: privacy ?? this.privacy,
    );
  }
}

@immutable
class PortalFooterContent {
  const PortalFooterContent({
    required this.companyName,
    required this.termsLabel,
    required this.privacyLabel,
    required this.slogan,
  });

  final String companyName;
  final String termsLabel;
  final String privacyLabel;
  final String slogan;

  PortalFooterContent copyWith({
    String? companyName,
    String? termsLabel,
    String? privacyLabel,
    String? slogan,
  }) {
    return PortalFooterContent(
      companyName: companyName ?? this.companyName,
      termsLabel: termsLabel ?? this.termsLabel,
      privacyLabel: privacyLabel ?? this.privacyLabel,
      slogan: slogan ?? this.slogan,
    );
  }
}

@immutable
class PortalLandingContent {
  const PortalLandingContent({
    required this.title,
    required this.subtitleWithWhatsApp,
    required this.subtitleWithoutWhatsApp,
    required this.signInEyebrow,
    required this.signInTitle,
    required this.signInDescription,
    required this.whatsAppEyebrow,
    required this.whatsAppTitle,
    required this.whatsAppDescription,
    required this.securityNote,
  });

  final String title;
  final String subtitleWithWhatsApp;
  final String subtitleWithoutWhatsApp;
  final String signInEyebrow;
  final String signInTitle;
  final String signInDescription;
  final String whatsAppEyebrow;
  final String whatsAppTitle;
  final String whatsAppDescription;
  final String securityNote;

  PortalLandingContent copyWith({
    String? title,
    String? subtitleWithWhatsApp,
    String? subtitleWithoutWhatsApp,
    String? signInEyebrow,
    String? signInTitle,
    String? signInDescription,
    String? whatsAppEyebrow,
    String? whatsAppTitle,
    String? whatsAppDescription,
    String? securityNote,
  }) {
    return PortalLandingContent(
      title: title ?? this.title,
      subtitleWithWhatsApp: subtitleWithWhatsApp ?? this.subtitleWithWhatsApp,
      subtitleWithoutWhatsApp:
          subtitleWithoutWhatsApp ?? this.subtitleWithoutWhatsApp,
      signInEyebrow: signInEyebrow ?? this.signInEyebrow,
      signInTitle: signInTitle ?? this.signInTitle,
      signInDescription: signInDescription ?? this.signInDescription,
      whatsAppEyebrow: whatsAppEyebrow ?? this.whatsAppEyebrow,
      whatsAppTitle: whatsAppTitle ?? this.whatsAppTitle,
      whatsAppDescription: whatsAppDescription ?? this.whatsAppDescription,
      securityNote: securityNote ?? this.securityNote,
    );
  }
}

@immutable
class PortalLoginContent {
  const PortalLoginContent({
    required this.storyKicker,
    required this.storyTitle,
    required this.storyDescription,
    required this.accessPoints,
    required this.accountKicker,
    required this.title,
    required this.description,
    required this.status,
  });

  final String storyKicker;
  final String storyTitle;
  final String storyDescription;
  final List<String> accessPoints;
  final String accountKicker;
  final String title;
  final String description;
  final String status;

  PortalLoginContent copyWith({
    String? storyKicker,
    String? storyTitle,
    String? storyDescription,
    List<String>? accessPoints,
    String? accountKicker,
    String? title,
    String? description,
    String? status,
  }) {
    return PortalLoginContent(
      storyKicker: storyKicker ?? this.storyKicker,
      storyTitle: storyTitle ?? this.storyTitle,
      storyDescription: storyDescription ?? this.storyDescription,
      accessPoints: accessPoints ?? this.accessPoints,
      accountKicker: accountKicker ?? this.accountKicker,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
    );
  }
}

@immutable
class PortalDocumentContent {
  const PortalDocumentContent({
    required this.title,
    required this.lastUpdated,
    required this.summary,
    required this.sections,
  });

  final String title;
  final String lastUpdated;
  final String summary;
  final List<PortalDocumentSection> sections;

  PortalDocumentContent copyWith({
    String? title,
    String? lastUpdated,
    String? summary,
    List<PortalDocumentSection>? sections,
  }) {
    return PortalDocumentContent(
      title: title ?? this.title,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      summary: summary ?? this.summary,
      sections: sections ?? this.sections,
    );
  }
}

@immutable
class PortalDocumentSection {
  const PortalDocumentSection({required this.title, required this.body});

  final String title;
  final String body;

  PortalDocumentSection copyWith({String? title, String? body}) {
    return PortalDocumentSection(
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }
}

const PortalDefinition defaultPortalDefinition = PortalDefinition(
  logoAssetPath: 'assets/branding/mugen-logotype.png',
  logoSemanticLabel: 'muGen home',
  technicalPatternAssetPath: 'assets/branding/tech-infrastructure-pattern.png',
  theme: PortalThemeTokens.defaults,
  footer: PortalFooterContent(
    companyName: 'Vorso Computing, Inc.',
    termsLabel: 'Terms of Use',
    privacyLabel: 'Privacy Policy',
    slogan: 'Built for the connected business',
  ),
  landing: PortalLandingContent(
    title: 'Choose where to begin.',
    subtitleWithWhatsApp:
        'Sign in to continue, or connect your WhatsApp Business account to get started.',
    subtitleWithoutWhatsApp:
        'Sign in to access your workspace, settings, and connected services.',
    signInEyebrow: 'Returning users',
    signInTitle: 'Sign in to your account',
    signInDescription:
        'Access your workspace, settings, and connected services.',
    whatsAppEyebrow: 'Business setup',
    whatsAppTitle: 'Connect WhatsApp',
    whatsAppDescription:
        'Use Meta’s secure embedded signup to connect a WhatsApp Business account.',
    securityNote: 'Secure access powered by muGen',
  ),
  login: PortalLoginContent(
    storyKicker: 'Connected operations',
    storyTitle: 'One access point. Every conversation.',
    storyDescription:
        'Manage the services and messaging channels that keep your business moving.',
    accessPoints: <String>[
      'One workspace for connected services',
      'Secure account and channel controls',
      'Built for business messaging operations',
    ],
    accountKicker: 'Account access',
    title: 'Welcome back.',
    description: 'Enter your credentials to continue to muGen.',
    status: 'Secure access · Activity may be audited',
  ),
  terms: PortalDocumentContent(
    title: 'Terms of Use.',
    lastUpdated: 'Last updated August 26, 2026',
    summary:
        'These mock terms provide a practical starting point for the muGen portal. They are not a final legal agreement and should be reviewed by qualified counsel before use.',
    sections: <PortalDocumentSection>[
      PortalDocumentSection(
        title: '1. Acceptance of these terms',
        body:
            'By accessing or using the muGen portal and related services, you agree to these Terms of Use. If you use the service for an organization, you confirm that you are authorized to accept these terms on its behalf.',
      ),
      PortalDocumentSection(
        title: '2. The service',
        body:
            'muGen provides access to connected business tools, including account access and integrations with third-party messaging services. Features may change as the service evolves, and some features may be offered as previews or limited releases.',
      ),
      PortalDocumentSection(
        title: '3. Accounts and access',
        body:
            'You are responsible for safeguarding your credentials, maintaining accurate account information, and promptly reporting suspected unauthorized use. You may not share access in a way that bypasses account or security controls.',
      ),
      PortalDocumentSection(
        title: '4. Acceptable use',
        body:
            'You may not use the service to break the law, send unlawful or abusive communications, interfere with the service, probe security controls, introduce malicious code, or violate the rights of another person or organization.',
      ),
      PortalDocumentSection(
        title: '5. Third-party services',
        body:
            'Connections to services such as WhatsApp and Meta are also governed by those providers’ terms and policies. Vorso Computing does not control third-party availability, approval processes, or policy changes.',
      ),
      PortalDocumentSection(
        title: '6. Content and intellectual property',
        body:
            'You retain rights in content you provide. You grant us the limited rights needed to host, transmit, process, and display that content to operate the service. The muGen service, branding, and underlying technology remain the property of their respective owners.',
      ),
      PortalDocumentSection(
        title: '7. Availability and changes',
        body:
            'We work to keep the service reliable, but access may occasionally be interrupted for maintenance, security, provider outages, or other operational reasons. We may update or discontinue features with reasonable notice when practicable.',
      ),
      PortalDocumentSection(
        title: '8. Disclaimers and liability',
        body:
            'This draft describes an intended commercial framework only. Final warranty disclaimers, liability limits, indemnities, governing law, and dispute terms must be reviewed and approved by legal counsel before publication.',
      ),
      PortalDocumentSection(
        title: '9. Termination and contact',
        body:
            'Access may be suspended or terminated for misuse, security risk, or material breach. Contact details and the process for formal legal notices will be added to the final version.',
      ),
    ],
  ),
  privacy: PortalDocumentContent(
    title: 'Privacy Policy.',
    lastUpdated: 'Last updated August 26, 2026',
    summary:
        'Your privacy matters. This draft explains how personal data may be collected, used, and protected across the muGen portal and opted-in WhatsApp communications.',
    sections: <PortalDocumentSection>[
      PortalDocumentSection(
        title: '1. Data we collect',
        body:
            'When you opt in to receive messages through a Vorso Computing WhatsApp profile, we may collect your name and phone number. The muGen portal may also process account credentials, service configuration, and basic technical information needed to secure and operate the service.',
      ),
      PortalDocumentSection(
        title: '2. How we use your data',
        body:
            'We use personal data to provide account access, connect requested messaging services, deliver opted-in communications about products, services, solutions, and promotions, respond to requests, maintain security, and improve service reliability.',
      ),
      PortalDocumentSection(
        title: '3. WhatsApp and connected services',
        body:
            'If you connect WhatsApp or another third-party service, information may be processed by that provider under its own privacy terms. We only request the access needed for the connection and features you choose to use.',
      ),
      PortalDocumentSection(
        title: '4. Data sharing',
        body:
            'We do not sell your personal data. We do not share or transfer it to another entity except where needed to operate a service you request, to comply with law, to protect rights or security, or when you direct or consent to the disclosure.',
      ),
      PortalDocumentSection(
        title: '5. Retention and opting out',
        body:
            'Messaging contact data is retained while you remain subscribed. If you opt out, we will remove it following the applicable opt-out process, subject to legal, security, and recordkeeping requirements. Other account data is kept only as long as needed for the purposes described here.',
      ),
      PortalDocumentSection(
        title: '6. Your privacy rights',
        body:
            'Depending on your location, you may request access, correction, deletion, restriction, objection, or a portable copy of your data; withdraw consent; and lodge a complaint with a relevant authority. Exercising your rights will not result in unlawful discrimination.',
      ),
      PortalDocumentSection(
        title: '7. Security and incident notice',
        body:
            'We use reasonable administrative, technical, and organizational safeguards designed to protect personal data. If a breach requires notice under applicable law, we will notify affected people and relevant authorities within the required timeframe.',
      ),
      PortalDocumentSection(
        title: '8. International processing and children',
        body:
            'Connected services may process information in multiple countries. Appropriate safeguards will be used where required. The service is intended for business users and is not directed to children.',
      ),
      PortalDocumentSection(
        title: '9. Contact us',
        body:
            'Questions or privacy-rights requests may be sent to privacy@vorsocomputing.com. We may update this policy as the portal and its connected services evolve.',
      ),
    ],
  ),
);
