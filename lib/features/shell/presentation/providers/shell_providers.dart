import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:mugen_ui/app/providers.dart';

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
    final config = ref.watch(appConfigProvider);
    return ShellState(
      isDrawerCollapsed: false,
      showSettings: false,
      activeRoute: config.spaDefaultRoute,
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
    state = state.copyWith(activeRoute: route, showSettings: false);
  }
}
