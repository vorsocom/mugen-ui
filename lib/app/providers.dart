import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/extension/configuration.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) {
  return AppConfig.defaults().merge(configurationOverride);
}

@Riverpod(keepAlive: true)
Logger appLogger(Ref ref) {
  return Logger('mugen-ui');
}

@Riverpod(keepAlive: true)
CookieStore cookieStore(Ref ref) {
  return createCookieStore();
}

@Riverpod(keepAlive: true)
HttpTransport httpTransport(Ref ref) {
  final transport = HttpClientTransport();
  ref.onDispose(transport.close);
  return transport;
}

@Riverpod(keepAlive: true)
AcpHttpClient acpHttpClient(Ref ref) {
  final config = ref.watch(appConfigProvider);
  return AcpHttpClient(
    baseUrl: config.api.baseUrl,
    transport: ref.watch(httpTransportProvider),
  );
}

@Riverpod(keepAlive: true)
AuthenticatedHttpClient authenticatedHttpClient(Ref ref) {
  final config = ref.watch(appConfigProvider);
  return AuthenticatedHttpClient(
    httpClient: ref.watch(acpHttpClientProvider),
    cookieStore: ref.watch(cookieStoreProvider),
    refreshPath: config.api.endpoints.authRefresh,
  );
}

@Riverpod(keepAlive: true)
AppNavigator appNavigator(Ref ref) {
  return AppNavigator();
}

@Riverpod(keepAlive: true)
SnackBarDispatcher snackBarDispatcher(Ref ref) {
  return const SnackBarDispatcher();
}
