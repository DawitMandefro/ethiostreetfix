import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main_navigation.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return const MainNavigation();
      },
    );
  }
}
