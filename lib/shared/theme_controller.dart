import 'package:flutter/material.dart';
import '../services/security_service.dart';

/// Small app-wide theme controller. Persists selection using
/// `SecurityService` (already included in the project) so no new
/// dependency is required.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._mode);

  static const _storageKey = 'ethio_theme_mode_v1';
  static ThemeController? _instance;

  /// Singleton instance — call [initialize] before using in `main()`.
  static ThemeController get instance =>
      _instance ??= ThemeController._(ThemeMode.system);

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  // Keep this simple — the framework handles `ThemeMode.system` at the
  // MaterialApp level. Avoid reading the global window (deprecated).
  bool get isDark => _mode == ThemeMode.dark;

  /// Initialize from persistent storage. Safe to call multiple times.
  static Future<void> initialize() async {
    final controller = instance;
    try {
      final v = await SecurityService.getSecureData(_storageKey);
      if (v == null) return;
      switch (v) {
        case 'dark':
          controller._mode = ThemeMode.dark;
          break;
        case 'light':
          controller._mode = ThemeMode.light;
          break;
        default:
          controller._mode = ThemeMode.system;
      }
      controller.notifyListeners();
    } catch (e) {
      // non-fatal — keep system default
      debugPrint('ThemeController.initialize error: $e');
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final value = mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
          ? 'light'
          : 'system';
      await SecurityService.storeSecureData(_storageKey, value);
    } catch (e) {
      debugPrint('ThemeController: failed to persist theme mode: $e');
    }
  }

  Future<void> toggleDarkLight() async {
    await setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
