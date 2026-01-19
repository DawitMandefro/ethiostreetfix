import 'package:flutter/material.dart';
import 'notifications_screen.dart';

class CitizenNotificationsScreen extends StatelessWidget {
  const CitizenNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Notifications')),
      body: const NotificationsScreen(),
    );
  }
}
