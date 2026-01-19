import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/citizen_profile_screen.dart';
import 'screens/citizen_notifications_screen.dart';
import 'screens/authority_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/report_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/authority_profile_screen.dart';
import 'services/auth_service.dart';
import 'models/user_role.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// SRS Section 3.1: RBAC-based navigation
class MainNavigation extends StatefulWidget {
  final UserRole? initialRole;
  const MainNavigation({super.key, this.initialRole});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final _storage = const FlutterSecureStorage();
  static const _kStorageKey = 'main_navigation_index';

  @override
  void initState() {
    super.initState();
    _restoreIndex();

    // If a role was provided by the navigation flow, cache it and ensure
    // we start on the Home tab so authority users land on their dashboard
    // immediately even on first-run.
    if (widget.initialRole != null) {
      AuthService.cacheRole(widget.initialRole!);
      if (mounted) setState(() => _currentIndex = 0);
    }
  }

  Future<void> _restoreIndex() async {
    try {
      final v = await _storage.read(key: _kStorageKey);
      if (v != null) {
        final idx = int.tryParse(v);
        if (idx != null && mounted) setState(() => _currentIndex = idx);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to restore navigation index: $e');
    }
  }

  Future<void> _setIndex(int index) async {
    setState(() => _currentIndex = index);
    try {
      await _storage.write(key: _kStorageKey, value: index.toString());
    } catch (e) {
      // ignore: avoid_print
      print('Failed to persist navigation index: $e');
    }
  }

  Widget _getHomeScreen() {
    final role = AuthService.currentUserRole();
    // SRS Section 3.1: Role-based dashboard routing
    switch (role) {
      case UserRole.administrator:
        return const AdminDashboard();
      case UserRole.authority:
        return const AuthorityDashboard();
      case UserRole.citizen:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService.currentUserRole();

    Widget body;
    if (_currentIndex == 0) {
      body = SafeArea(child: _getHomeScreen());
    } else if (_currentIndex == 1) {
      // Role-specific notifications screen
      if (role == UserRole.authority) {
        body = SafeArea(child: const NotificationsScreen());
      } else {
        body = SafeArea(child: const CitizenNotificationsScreen());
      }
    } else {
      // Show different profile screens depending on role
      if (role == UserRole.authority) {
        body = SafeArea(child: const AuthorityProfileScreen());
      } else {
        body = SafeArea(child: const CitizenProfileScreen());
      }
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _setIndex(index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
