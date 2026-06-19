import 'package:web/web.dart' as web;

import 'package:mugen_ui/app/browser_chrome.dart';

BrowserChrome createBrowserChrome() => _BrowserChromeWeb();

class _BrowserChromeWeb implements BrowserChrome {
  @override
  void setFaviconHref(String? href) {
    final trimmedHref = href?.trim();
    if (trimmedHref == null || trimmedHref.isEmpty) {
      return;
    }

    final iconLink = _findOrCreateIconLink();
    if (iconLink == null) {
      return;
    }

    iconLink
      ..href = trimmedHref
      ..type = _mimeTypeFor(trimmedHref);
  }

  web.HTMLLinkElement? _findOrCreateIconLink() {
    final existingLink = web.document.querySelector('link[rel~="icon"]');
    if (existingLink != null) {
      return existingLink as web.HTMLLinkElement;
    }

    final head = web.document.head;
    if (head == null) {
      return null;
    }

    final iconLink = web.HTMLLinkElement()..rel = 'icon';
    head.append(iconLink);
    return iconLink;
  }

  String _mimeTypeFor(String href) {
    final normalized = href.toLowerCase().split('?').first.split('#').first;
    if (normalized.endsWith('.svg')) {
      return 'image/svg+xml';
    }
    if (normalized.endsWith('.ico')) {
      return 'image/x-icon';
    }
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/png';
  }
}
