import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_role.dart';
import '../main_navigation.dart';
import 'auth_service.dart';

class NavigationService {
  /// Navigates to the app's main navigation shell so the bottom navigation
  /// is always present after sign-in or sign-up flows. This also resets the
  /// persisted selected tab to the home tab (index 0) to ensure users land
  /// on the Home page after sign-in/sign-up.
  static Future<void> navigateToRoleHome(
    BuildContext context,
    UserRole role,
  ) async {
    try {
      // Cache the expected role locally so UI can immediately render the
      // role-specific home. Don't persist (use cacheRole) to avoid
      // unintentionally overwriting server state during sign-in flows.
      AuthService.cacheRole(role);
      // Attempt to refresh the authoritative role from backend but don't
      // block navigation for long (short timeout).
      try {
        await AuthService().loadRoleForCurrentUser().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
      } catch (_) {
        // ignore errors — we already cached the expected role
      }
    } catch (e) {
      // ignore: avoid_print
      print('NavigationService: failed to refresh role cache: $e');
    }

    try {
      final storage = const FlutterSecureStorage();
      // Use a short timeout to avoid hanging tests where platform channels
      // for secure storage aren't available. Don't await this in tests —
      // fire-and-forget so the navigation isn't blocked by platform channels.
      storage
          .write(key: 'main_navigation_index', value: '0')
          .timeout(const Duration(milliseconds: 200), onTimeout: () {})
          .catchError((_) {});
    } catch (e) {
      // ignore: avoid_print
      print('NavigationService: failed to reset navigation index: $e');
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainNavigation(initialRole: role)),
      (route) => false,
    );
  }
}
