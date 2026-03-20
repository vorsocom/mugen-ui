import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  test('core providers resolve expected service types', () {
    final endpointsOverride = ApiEndpointsOverride();
    expect(endpointsOverride.authLogin, isNull);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appDefinitionProvider), isA<MugenUiAppDefinition>());
    expect(container.read(appConfigProvider), isA<AppConfig>());
    expect(
      container.read(shellRouteDefinitionsProvider),
      isA<List<ShellRouteDefinition>>(),
    );
    expect(
      container.read(settingsPanelDefinitionsProvider),
      isA<List<SettingsPanelDefinition>>(),
    );
    expect(container.read(appLoggerProvider), isA<Logger>());
    expect(container.read(cookieStoreProvider), isA<CookieStore>());
    expect(container.read(httpTransportProvider), isA<HttpTransport>());
    expect(container.read(acpHttpClientProvider), isA<AcpHttpClient>());
    expect(
      container.read(authenticatedHttpClientProvider),
      isA<AuthenticatedHttpClient>(),
    );
    expect(container.read(appNavigatorProvider), isA<AppNavigator>());
    expect(
      container.read(snackBarDispatcherProvider),
      isA<SnackBarDispatcher>(),
    );
  });
}
