import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/report_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'citizen_notifications_screen.dart';

class CitizenProfileScreen extends StatelessWidget {
  const CitizenProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportSvc = ReportService();
    final notifSvc = NotificationService();
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'demo@local';

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Main profile details (reuse existing ProfileScreen)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: ProfileScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
