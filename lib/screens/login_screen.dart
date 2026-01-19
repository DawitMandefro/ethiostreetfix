import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'signup_screen.dart';
import '../services/auth_service.dart';
import '../models/user_role.dart';
import '../services/navigation_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().signInWithGoogle();
      if (user == null) {
        _showError('Google sign-in cancelled or failed.');
        return;
      }

      // Ensure role is loaded before navigating so we land on the correct home
      try {
        await AuthService().loadRoleForCurrentUser().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint('Warning: failed to load role after Google sign-in: $e');
      }

      // Navigate after role is loaded (or timed out) directly to role home
      if (!mounted) return;
      final role = AuthService.currentUserRole();
      // Use centralized navigation so behavior is consistent across flows
      await NavigationService.navigateToRoleHome(context, role);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FIXED AUTH LOGIC (Updated for 2025 Security Standards)
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = cred.user;
      if (user == null) {
        _showError('Sign-in succeeded but no user returned. Please try again.');
        return;
      }

      // Ensure role is loaded before navigating so we land on the correct home
      try {
        await AuthService().loadRoleForCurrentUser().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint('Warning: failed to load role after sign-in: $e');
      }

      // Navigate after role is loaded (or timed out) directly to role home
      if (!mounted) return;
      final role = AuthService.currentUserRole();
      await NavigationService.navigateToRoleHome(context, role);

      // show a non-blocking confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // FIX: Handle the consolidated 'invalid-credential' error code
      String message = "An unexpected error occurred.";

      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
        message = "Invalid email or password. Please try again.";
      } else if (e.code == 'too-many-requests') {
        message = "Too many failed attempts. Try again later.";
      } else if (e.code == 'network-request-failed') {
        message = "Check your internet connection.";
      }

      _showError(message);
    } catch (e, st) {
      debugPrint('Unexpected login error: $e\n$st');
      _showError('Unable to sign in at the moment.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.construction_outlined,
                size: 100,
                color: Colors.green,
              ),
              const SizedBox(height: 10),
              const Text(
                "EthioStreetFix",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Text("Building safer streets together"),
              const SizedBox(height: 24),

              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email Address",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _login,
                      child: const Text(
                        "LOGIN",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Image.asset(
                  'assets/google.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (c, e, s) =>
                      const Icon(Icons.login, color: Colors.red),
                ),
                label: const Text(
                  'Continue with Google',
                  style: TextStyle(fontSize: 16),
                ),
                onPressed: _signInWithGoogle,
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("New user?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Create an Account",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
