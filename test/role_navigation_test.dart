import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ethio_street_fix/services/navigation_service.dart';
import 'package:ethio_street_fix/models/user_role.dart';
import 'package:ethio_street_fix/main_navigation.dart';
import 'package:ethio_street_fix/screens/dashboard_screen.dart';
import 'package:ethio_street_fix/screens/authority_dashboard.dart';

void main() {
  testWidgets('NavigationService routes authority to AuthorityDashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            // Trigger navigation immediately
            WidgetsBinding.instance.addPostFrameCallback((_) {
              NavigationService.navigateToRoleHome(context, UserRole.authority);
            });
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MainNavigation), findsOneWidget);
    // With the provided role we should land on the Authority dashboard
    // inside the app shell.
    expect(find.byType(AuthorityDashboard), findsOneWidget);
  });

  testWidgets('NavigationService routes citizen to DashboardScreen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              NavigationService.navigateToRoleHome(context, UserRole.citizen);
            });
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MainNavigation), findsOneWidget);
    // Citizens should land on the regular dashboard.
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
