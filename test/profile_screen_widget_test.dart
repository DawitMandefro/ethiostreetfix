import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ethio_street_fix/screens/profile_screen.dart';
import 'package:ethio_street_fix/screens/Dashboard_screen.dart';
import 'package:ethio_street_fix/screens/settings_screen.dart';
import 'package:ethio_street_fix/screens/help_screen.dart';

void main() {
  testWidgets('ProfileScreen navigation options work', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: const Scaffold(body: ProfileScreen())),
    );

    // My Reports
    expect(find.text('My Reports'), findsOneWidget);
    await tester.tap(find.text('My Reports'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Back
    await tester.pageBack();
    await tester.pumpAndSettle();

    // App Settings
    await tester.tap(find.text('App Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Help & Feedback
    await tester.tap(find.text('Help & Feedback'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
  });
}
