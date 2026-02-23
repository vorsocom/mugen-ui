import 'package:flutter/material.dart';

class AppNavigator {
  AppNavigator() : _navigatorKey = GlobalKey<NavigatorState>();

  final GlobalKey<NavigatorState> _navigatorKey;

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  Future<void> navigateTo(String routeName) async {
    final navigatorState = _navigatorKey.currentState;
    if (navigatorState == null) {
      return;
    }

    await navigatorState.pushReplacementNamed(routeName);
  }

  Future<void> pushRoute(Route<dynamic> route) async {
    final navigatorState = _navigatorKey.currentState;
    if (navigatorState == null) {
      return;
    }

    await navigatorState.push(route);
  }

  void pop() {
    _navigatorKey.currentState?.pop();
  }

  String? currentRoute() {
    final navigatorState = _navigatorKey.currentState;
    if (navigatorState == null) {
      return null;
    }

    String? routeName;
    navigatorState.popUntil((route) {
      routeName = route.settings.name;
      return true;
    });

    return routeName;
  }

  BuildContext? currentContext() {
    return _navigatorKey.currentContext;
  }
}
