import 'package:flutter/material.dart';

/// Global navigator key for navigation from outside widget tree (e.g., notifications)
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Get the navigator state
  NavigatorState? get navigator => navigatorKey.currentState;

  /// Get the current context
  BuildContext? get context => navigatorKey.currentContext;

  /// Navigate to a named route
  Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  /// Navigate and replace the current route
  Future<dynamic> navigateReplacementTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  /// Navigate and clear the stack
  Future<dynamic> navigateAndClearStack(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Go back
  void goBack() {
    return navigatorKey.currentState!.pop();
  }

  /// Check if we can go back
  bool canGoBack() {
    return navigatorKey.currentState!.canPop();
  }
}
