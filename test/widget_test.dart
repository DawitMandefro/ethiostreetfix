// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ethio_street_fix/screens/splash_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  testWidgets('SplashScreen renders', (WidgetTester tester) async {
    // Avoid initializing Firebase in tests — exercise SplashScreen in isolation
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(skipNavigation: true)),
    );
    await tester.pump();

    // Splash now uses the app SVG logo and a short proverb
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('EthioStreetFix'), findsOneWidget);
    expect(find.text('Together we build safer streets'), findsOneWidget);
  });
}
