import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ethio_street_fix/shared/theme_controller.dart';
import 'package:ethio_street_fix/screens/settings_screen.dart';

void main() {
  setUp(() async {
    // Set in-memory mode; persistence may throw in test environment (plugin
    // not registered), so swallow persistence errors.
    try {
      await ThemeController.instance.setMode(ThemeMode.light);
    } catch (_) {}
  });

  testWidgets('SettingsScreen: theme dropdown updates ThemeController', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    // starting state is light (in-memory)
    expect(ThemeController.instance.mode, ThemeMode.light);

    // open dropdown and choose Dark
    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    expect(ThemeController.instance.mode, ThemeMode.dark);
  });

  testWidgets('SettingsScreen: analytics toggle and export dialog', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    // analytics toggle should be present and togglable
    final analyticsFinder = find.byType(SwitchListTile);
    expect(analyticsFinder, findsOneWidget);

    // toggle analytics on
    await tester.tap(analyticsFinder);
    await tester.pump(const Duration(milliseconds: 200));

    // Export: tapping should complete quickly (copy to clipboard + save).
    await tester.tap(find.text('Export my reports (JSON)'));

    // wait up to 3s for the export to complete in test env (polling)
    var waited = 0;
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
        waited < 3000) {
      await tester.pump(const Duration(milliseconds: 200));
      waited += 200;
    }

    // export should have finished (no long-running progress indicator)
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('SettingsScreen: navigates to ChangePasswordScreen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    // the title exists in both the list item and the pushed AppBar; assert AppBar exists
    expect(find.widgetWithText(AppBar, 'Change password'), findsOneWidget);
  });
}
