import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/config/app_config.dart';

typedef TopLevelRouteWidgetBuilder =
    Widget Function(BuildContext context, TopLevelRouteMatch match);
typedef TopLevelRouteMatcher = TopLevelRouteMatch? Function(String? routeName);
typedef ParsedTopLevelRouteParser<T> = T? Function(String? routeName);
typedef ParsedTopLevelRouteLocationBuilder<T> = String Function(T data);
typedef ParsedTopLevelRouteWidgetBuilder<T> =
    Widget Function(BuildContext context, T data);

class TopLevelRouteMatch {
  const TopLevelRouteMatch({required this.location, this.data});

  final String location;
  final Object? data;
}

class TopLevelRouteDefinition {
  TopLevelRouteDefinition({
    required this.id,
    required this.match,
    required this.builder,
    this.exactPath,
  });

  factory TopLevelRouteDefinition.exact({
    required String id,
    required String path,
    required WidgetBuilder builder,
  }) {
    return TopLevelRouteDefinition(
      id: id,
      exactPath: path,
      match: (routeName) {
        if (routeName == path) {
          return TopLevelRouteMatch(location: path);
        }
        return null;
      },
      builder: (context, match) => builder(context),
    );
  }

  static TopLevelRouteDefinition parsed<T>({
    required String id,
    required ParsedTopLevelRouteParser<T> parse,
    required ParsedTopLevelRouteLocationBuilder<T> canonicalLocation,
    required ParsedTopLevelRouteWidgetBuilder<T> builder,
  }) {
    return TopLevelRouteDefinition(
      id: id,
      match: (routeName) {
        final data = parse(routeName);
        if (data == null) {
          return null;
        }
        return TopLevelRouteMatch(
          location: canonicalLocation(data),
          data: data,
        );
      },
      builder: (context, match) => builder(context, match.data! as T),
    );
  }

  final String id;
  final TopLevelRouteMatcher match;
  final TopLevelRouteWidgetBuilder builder;
  final String? exactPath;
}

class ShellRouteDefinition {
  const ShellRouteDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    this.section,
    this.requiredRoles = const <String>[],
    this.showInDrawer = true,
  });

  final String id;
  final String title;
  final IconData icon;
  final String? section;
  final List<String> requiredRoles;
  final bool showInDrawer;
  final WidgetBuilder builder;
}

class SettingsPanelDefinition {
  const SettingsPanelDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    this.requiredRoles = const <String>[],
    this.maxWidth = 760,
    this.maxHeight = 640,
    this.showHeader = true,
    this.expandBody = true,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<String> requiredRoles;
  final WidgetBuilder builder;
  final double maxWidth;
  final double maxHeight;
  final bool showHeader;
  final bool expandBody;
}

class MugenUiModule {
  const MugenUiModule({
    required this.id,
    this.shellRoutes = const <ShellRouteDefinition>[],
    this.settingsPanels = const <SettingsPanelDefinition>[],
    this.topLevelRoutes = const <TopLevelRouteDefinition>[],
    this.providerOverrides = const <Override>[],
  });

  final String id;
  final List<ShellRouteDefinition> shellRoutes;
  final List<SettingsPanelDefinition> settingsPanels;
  final List<TopLevelRouteDefinition> topLevelRoutes;
  final List<Override> providerOverrides;
}

class MugenUiAppDefinition {
  MugenUiAppDefinition({
    required this.config,
    required this.defaultShellRouteId,
    required List<MugenUiModule> modules,
  }) : modules = List<MugenUiModule>.unmodifiable(modules) {
    _validateUniqueModuleIds(this.modules);
    _validateUniqueShellRouteIds(shellRoutes);
    _validateUniqueSettingsPanelIds(settingsPanels);
    _validateUniqueTopLevelRouteIds(topLevelRoutes);
    _validateUniqueExactPaths(topLevelRoutes);
    _validateDefaultShellRoute(
      shellRoutes: shellRoutes,
      defaultShellRouteId: defaultShellRouteId,
    );
  }

  final AppConfig config;
  final String defaultShellRouteId;
  final List<MugenUiModule> modules;

  List<ShellRouteDefinition> get shellRoutes {
    return List<ShellRouteDefinition>.unmodifiable(
      modules.expand((module) => module.shellRoutes),
    );
  }

  List<SettingsPanelDefinition> get settingsPanels {
    return List<SettingsPanelDefinition>.unmodifiable(
      modules.expand((module) => module.settingsPanels),
    );
  }

  List<TopLevelRouteDefinition> get topLevelRoutes {
    return List<TopLevelRouteDefinition>.unmodifiable(
      modules.expand((module) => module.topLevelRoutes),
    );
  }

  List<Override> get providerOverrides {
    return List<Override>.unmodifiable(
      modules.expand((module) => module.providerOverrides),
    );
  }
}

void _validateUniqueModuleIds(List<MugenUiModule> modules) {
  final seen = <String>{};
  for (final module in modules) {
    if (!seen.add(module.id)) {
      throw ArgumentError.value(
        module.id,
        'modules',
        'Duplicate module id is not allowed.',
      );
    }
  }
}

void _validateUniqueShellRouteIds(List<ShellRouteDefinition> routes) {
  final seen = <String>{};
  for (final route in routes) {
    if (!seen.add(route.id)) {
      throw ArgumentError.value(
        route.id,
        'shellRoutes',
        'Duplicate shell route id is not allowed.',
      );
    }
  }
}

void _validateUniqueSettingsPanelIds(List<SettingsPanelDefinition> panels) {
  final seen = <String>{};
  for (final panel in panels) {
    if (!seen.add(panel.id)) {
      throw ArgumentError.value(
        panel.id,
        'settingsPanels',
        'Duplicate settings panel id is not allowed.',
      );
    }
  }
}

void _validateUniqueTopLevelRouteIds(List<TopLevelRouteDefinition> routes) {
  final seen = <String>{};
  for (final route in routes) {
    if (!seen.add(route.id)) {
      throw ArgumentError.value(
        route.id,
        'topLevelRoutes',
        'Duplicate top-level route id is not allowed.',
      );
    }
  }
}

void _validateUniqueExactPaths(List<TopLevelRouteDefinition> routes) {
  final seen = <String>{};
  for (final route in routes) {
    final exactPath = route.exactPath;
    if (exactPath == null) {
      continue;
    }
    if (!seen.add(exactPath)) {
      throw ArgumentError.value(
        exactPath,
        'topLevelRoutes',
        'Duplicate exact top-level path is not allowed.',
      );
    }
  }
}

void _validateDefaultShellRoute({
  required List<ShellRouteDefinition> shellRoutes,
  required String defaultShellRouteId,
}) {
  final hasDefault = shellRoutes.any(
    (route) => route.id == defaultShellRouteId,
  );
  if (!hasDefault) {
    throw ArgumentError.value(
      defaultShellRouteId,
      'defaultShellRouteId',
      'defaultShellRouteId must match a registered shell route.',
    );
  }
}
