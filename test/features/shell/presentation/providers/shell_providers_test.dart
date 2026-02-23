import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/shell/presentation/providers/shell_providers.dart';

void main() {
  test('ShellState.copyWith keeps and overrides fields', () {
    const original = ShellState(
      isDrawerCollapsed: false,
      showSettings: false,
      activeRoute: 'chat',
    );

    final unchanged = original.copyWith();
    expect(unchanged.isDrawerCollapsed, isFalse);
    expect(unchanged.showSettings, isFalse);
    expect(unchanged.activeRoute, 'chat');

    final updated = original.copyWith(
      isDrawerCollapsed: true,
      showSettings: true,
      activeRoute: 'reports',
    );
    expect(updated.isDrawerCollapsed, isTrue);
    expect(updated.showSettings, isTrue);
    expect(updated.activeRoute, 'reports');
  });

  test('ShellController initializes from config and updates state', () {
    final config = AppConfig.defaults().merge(
      const AppConfigurationOverride(spaDefaultRoute: 'reports'),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWith((Ref ref) => config),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(shellControllerProvider.notifier);
    var state = container.read(shellControllerProvider);
    expect(state.activeRoute, 'reports');
    expect(state.isDrawerCollapsed, isFalse);
    expect(state.showSettings, isFalse);

    notifier.toggleCollapsed();
    state = container.read(shellControllerProvider);
    expect(state.isDrawerCollapsed, isTrue);

    notifier.toggleShowSettings();
    state = container.read(shellControllerProvider);
    expect(state.showSettings, isTrue);

    notifier.openSettings();
    state = container.read(shellControllerProvider);
    expect(state.showSettings, isTrue);

    notifier.setRoute('users');
    state = container.read(shellControllerProvider);
    expect(state.activeRoute, 'users');
    expect(state.showSettings, isFalse);

    notifier.openSettings();
    state = container.read(shellControllerProvider);
    expect(state.showSettings, isTrue);
  });
}
