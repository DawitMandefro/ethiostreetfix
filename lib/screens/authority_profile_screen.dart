import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'authority_dashboard.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'login_screen.dart';
import 'audit_logs_screen.dart';

class AuthorityProfileScreen extends StatelessWidget {
  const AuthorityProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Authority Profile'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: AuthService().getCurrentUserProfile(),
        builder: (context, snapshot) {
          final profile =
              snapshot.data ??
              {
                'displayName': 'Authority',
                'email': 'authority@local',
                'photoUrl': null,
              };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 50,
                backgroundImage: profile['photoUrl'] != null
                    ? NetworkImage(profile['photoUrl'] as String)
                    : null,
                backgroundColor: Colors.grey.shade200,
                child: profile['photoUrl'] == null
                    ? Text(
                        (profile['displayName'] as String?)
                                ?.substring(0, 1)
                                .toUpperCase() ??
                            'A',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.green,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  profile['displayName'] as String? ?? 'Authority',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Center(
                child: Text(profile['email'] as String? ?? 'authority@local'),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Authority Dashboard'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthorityDashboard()),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Audit Log'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuditLogsScreen(
                      performedBy: profile['email'] as String?,
                    ),
                  ),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('App Settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & Feedback'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
              ),

              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Confirm logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  await AuthService().signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (r) => false,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
