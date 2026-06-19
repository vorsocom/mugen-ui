import 'package:mugen_ui/app/browser_chrome_stub.dart'
    if (dart.library.html) 'package:mugen_ui/app/browser_chrome_web.dart'
    as browser_chrome_impl;

abstract class BrowserChrome {
  void setFaviconHref(String? href);
}

BrowserChrome createBrowserChrome() =>
    browser_chrome_impl.createBrowserChrome();
