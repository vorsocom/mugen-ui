import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/shell/application/shell_route_access.dart';

part 'shell_providers.g.dart';

class ShellState {
  const ShellState({
    required this.isDrawerCollapsed,
    required this.showSettings,
    required this.activeRoute,
  });

  final bool isDrawerCollapsed;
  final bool showSettings;
  final String activeRoute;

  ShellState copyWith({
    bool? isDrawerCollapsed,
    bool? showSettings,
    String? activeRoute,
  }) {
    return ShellState(
      isDrawerCollapsed: isDrawerCollapsed ?? this.isDrawerCollapsed,
      showSettings: showSettings ?? this.showSettings,
      activeRoute: activeRoute ?? this.activeRoute,
    );
  }
}

@Riverpod(keepAlive: true)
class ShellController extends _$ShellController {
  @override
  ShellState build() {
    final config = ref.read(appConfigProvider);
    final routeAccess = resolveShellRouteAccess(
      config: config,
      sessionRoles: _currentSessionRoles(),
      requestedRoute: config.spaDefaultRoute,
    );
    return ShellState(
      isDrawerCollapsed: false,
      showSettings: false,
      activeRoute: routeAccess.canonicalRouteId,
    );
  }

  void toggleCollapsed() {
    state = state.copyWith(isDrawerCollapsed: !state.isDrawerCollapsed);
  }

  void toggleShowSettings() {
    state = state.copyWith(showSettings: !state.showSettings);
  }

  void openSettings() {
    if (state.showSettings) {
      return;
    }
    state = state.copyWith(showSettings: true);
  }

  void setRoute(String route) {
    final routeAccess = _resolveRouteAccess(route);
    state = state.copyWith(
      activeRoute: routeAccess.canonicalRouteId,
      showSettings: false,
    );
  }

  bool revalidateRoute() {
    final routeAccess = _resolveRouteAccess(state.activeRoute);
    if (routeAccess.canonicalRouteId == state.activeRoute) {
      return false;
    }

    state = state.copyWith(activeRoute: routeAccess.canonicalRouteId);
    return true;
  }

  ShellRouteAccess _resolveRouteAccess(String route) {
    return resolveShellRouteAccess(
      config: ref.read(appConfigProvider),
      sessionRoles: _currentSessionRoles(),
      requestedRoute: route,
    );
  }

  List<String> _currentSessionRoles() {
    return ref.read(authControllerProvider).session?.roles ?? const <String>[];
  }
}
