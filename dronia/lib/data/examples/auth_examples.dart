// Example: How to use AuthService in login/register screens
//
// This file demonstrates the integration pattern for authentication
// Replace the current mock login with these patterns

import 'package:flutter/material.dart';
import '../services/services.dart';
import '../models/models.dart';

/// Example login handler
/// Use this pattern in your LoginScreen
Future<void> handleLogin({
  required BuildContext context,
  required String email,
  required String password,
  required Function(bool) setLoading,
  required Function(String) showError,
  required VoidCallback onSuccess,
}) async {
  setLoading(true);

  try {
    // Use the service locator to access auth service
    await services.auth.login(email, password);

    // Login successful - navigate to home
    onSuccess();
  } catch (e) {
    // Handle errors
    String message = 'Erreur de connexion';
    if (e.toString().contains('User not found')) {
      message = 'Utilisateur non trouvé';
    } else if (e.toString().contains('Invalid credentials')) {
      message = 'Email ou mot de passe incorrect';
    } else if (e.toString().contains('Network')) {
      message = 'Erreur réseau. Vérifiez votre connexion.';
    }
    showError(message);
  } finally {
    setLoading(false);
  }
}

/// Example register handler
/// Use this pattern in your RegisterScreen
Future<void> handleRegister({
  required BuildContext context,
  required String email,
  required String password,
  String? firstName,
  String? lastName,
  String? phone,
  Location? location,
  List<String>? plantTypes,
  String? profileImage,
  double? totalSurface,
  String? soilType,
  required Function(bool) setLoading,
  required Function(String) showError,
  required VoidCallback onSuccess,
}) async {
  setLoading(true);

  try {
    // VPS register no longer returns a token — only a French success message
    // ("Compte créé. Vérifiez votre e-mail..."). Treat any non-throwing call
    // as success and let the caller route the user to the email-verification step.
    await services.auth.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      location: location,
      plantTypes: plantTypes,
      profileImage: profileImage,
      totalSurface: totalSurface,
      soilType: soilType,
    );
    onSuccess();
  } catch (e) {
    String message = 'Erreur lors de l\'inscription';
    if (e.toString().contains('already')) {
      message = 'Cet email est déjà inscrit';
    } else if (e.toString().contains('timeout') ||
        e.toString().contains('503')) {
      message = 'Erreur de connexion à la base de données. Réessayez.';
    }
    showError(message);
  } finally {
    setLoading(false);
  }
}

/// Example auto-login check on app start
/// Use this in your SplashScreen
Future<bool> checkAutoLogin() async {
  try {
    final user = await services.auth.autoLogin();
    return user != null;
  } catch (e) {
    return false;
  }
}

/// Example logout handler
Future<void> handleLogout(BuildContext context) async {
  await services.auth.logout();
  // Clear caches
  services.clearCaches();
  // Navigate to login
  // Navigator.pushReplacementNamed(context, AppRoutes.login);
}

/// Example profile update
Future<void> updateProfile({
  String? firstName,
  String? lastName,
  String? phone,
  Location? location,
  List<String>? plantTypes,
  String? profileImage,
  double? totalSurface,
  String? soilType,
}) async {
  try {
    final updatedUser = await services.auth.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      location: location,
      plantTypes: plantTypes,
      profileImage: profileImage,
      totalSurface: totalSurface,
      soilType: soilType,
    );
    // User updated successfully
    print('Profile updated: ${updatedUser.fullName}');
  } catch (e) {
    print('Error updating profile: $e');
  }
}
