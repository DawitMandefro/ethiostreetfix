import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ethio_street_fix/screens/profile_screen.dart';
import 'package:ethio_street_fix/services/auth_service.dart';

void main() {
  testWidgets('ProfileScreen updates when profile changed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );

    // initial display name
    expect(find.text('User Name'), findsOneWidget);

    await AuthService().updateProfile(displayName: 'NewTester');

    // Rebuild UI by re-pumping the widget so the FutureBuilder fetches the latest
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('NewTester'), findsOneWidget);
  });
}
