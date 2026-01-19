import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  Future<void> _sendReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email available for this account.')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending reset email: $e')));
    }
  }

  Future<void> _changePassword() async {
    if (_new.text.trim().length < 8) {
      _showError('New password must be at least 8 characters.');
      return;
    }
    if (_new.text.trim() != _confirm.text.trim()) {
      _showError('New password and confirmation do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _showError('No authenticated user found.');
        return;
      }

      // Reauthenticate using current password
      final reauthUser = await AuthService().signIn(
        user.email!,
        _current.text.trim(),
      );
      if (reauthUser == null) {
        _showError(
          'Re-authentication failed. Enter current password or use reset.',
        );
        return;
      }

      await user.updatePassword(_new.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Unable to change password.');
    } catch (e) {
      _showError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Change password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Change your password (requires current password).'),
            const SizedBox(height: 12),
            TextField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _new,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _changePassword,
                          child: const Text('Change password'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _sendReset,
                        child: const Text('Send reset email'),
                      ),
                    ],
                  ),
            const SizedBox(height: 12),
            if (kIsWeb)
              const Text(
                'Tip: on web you can also use the password-reset email flow if reauthentication fails.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
