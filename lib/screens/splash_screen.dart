import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  /// If [skipNavigation] is true the splash will not navigate away — useful for tests.
  const SplashScreen({super.key, this.skipNavigation = false});

  final bool skipNavigation;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.skipNavigation) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/logo.svg',
              width: 96,
              height: 96,
              placeholderBuilder: (context) => const Icon(
                Icons.construction_outlined,
                size: 96,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'EthioStreetFix',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Together we build safer streets',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
