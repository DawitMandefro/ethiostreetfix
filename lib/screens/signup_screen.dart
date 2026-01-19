import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/navigation_service.dart';
import '../services/auth_service.dart';
import '../models/user_role.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  // SRS Section 4.1: Registration Logic
  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    // Validate password strength before attempting sign-up
    final password = _passwordController.text.trim();
    if (!_isValidPassword(password)) {
      _showError(
        "Password must be at least 8 characters and include one uppercase letter, one number, and one special character.",
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Create user in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: password,
          );

      // 2. Set display name on Auth profile and create User Document in Firestore
      final fullName = _fullNameController.text.trim();
      final username = _usernameController.text.trim();

      // Prefer username as the public display name, fall back to full name
      try {
        final authDisplayName = username.isNotEmpty
            ? username
            : (fullName.isNotEmpty ? fullName : null);
        if (authDisplayName != null) {
          await userCredential.user?.updateDisplayName(authDisplayName);
        }
      } catch (_) {}

      // Every new user starts as a 'citizen' by default
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'email': _emailController.text.trim(),
            'role': 'citizen',
            if (fullName.isNotEmpty) 'displayName': fullName,
            if (username.isNotEmpty) 'username': username,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // After creating the account, load the role and navigate if the user is
      // an authority so they land directly on the Authority Dashboard.
      try {
        await AuthService().loadRoleForCurrentUser().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
        final role = AuthService.currentUserRole();
        if (!mounted) return;
        // Navigate everyone to the main app shell after sign-up (home page)
        await NavigationService.navigateToRoleHome(context, role);
        return;
      } catch (e) {
        // ignore: avoid_print
        print('Warning: failed to load role after sign-up: $e');
      }

      if (mounted) {
        Navigator.pop(context); // Fallback: Go back to Login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account Created! Please Login.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  bool _isValidPassword(String p) {
    // At least one uppercase, one digit, one special char, and minimum length 8
    final regex = RegExp(r'(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%^&*]).{8,}');
    return regex.hasMatch(p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text("Create Account"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: "Full name"),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _signUp,
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
