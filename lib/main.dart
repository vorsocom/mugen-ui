// Flutter libraries.
import 'package:flutter_web_plugins/url_strategy.dart';

// App libraries.
import 'package:mugen_ui/app/bootstrap.dart';

void main() {
  /// Remove leading hash from URLs.
  usePathUrlStrategy();

  runMugenApp();
}
