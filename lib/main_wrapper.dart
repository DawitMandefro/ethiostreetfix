import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'main_navigation.dart';
import 'services/auth_service.dart';

// SRS Section 3.1: Authentication gate with role loading
class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChangesSafe(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // SRS Section 3.1: Load user role when authenticated
        if (snapshot.hasData) {
          // Wait for role to be loaded (with timeout) so we can route correctly
          return FutureBuilder<void>(
            future: AuthService().loadRoleForCurrentUser().timeout(
              const Duration(seconds: 5),
              onTimeout: () => null,
            ),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return const MainNavigation();
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}
