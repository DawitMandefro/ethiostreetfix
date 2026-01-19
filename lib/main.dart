import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'shared/app_theme.dart';
import 'shared/theme_controller.dart';

// SRS Section 3.3: Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // keep lightweight and observable in logs
  print('Handling background message: ${message.messageId}');
}

/// Entrypoint: add global error handlers so web shows a readable error
Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Route all Flutter framework errors to the current zone so runZonedGuarded catches them
      FlutterError.onError = (FlutterErrorDetails details) {
        // still dump to console for CI / logs
        FlutterError.presentError(details);
        Zone.current.handleUncaughtError(
          details.exception,
          details.stack ?? StackTrace.current,
        );
      };

      try {
        // SRS Section 6.2: Initialize Firebase with secure connection
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // SRS Section 3.3: Initialize notification service (with error handling)
        try {
          FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler,
          );
          final notificationService = NotificationService();
          await notificationService.initialize();
        } catch (e, st) {
          // non-fatal for app startup — surface to logs
          debugPrint(
            'Warning: Notification service initialization failed: $e\n$st',
          );
        }
      } catch (e, st) {
        // Surface Firebase/init problems but keep the app running for better dev experience
        debugPrint('Error initializing Firebase: $e\n$st');
      }

      // small, always-visible debug trace so the app cannot render a silent white screen
      debugPrint('Starting EthioStreetFixApp — kIsWeb=$kIsWeb');

      // load persisted theme preference (non-blocking if it fails)
      await Future.wait([
        // ThemeController reads secure storage and will notify listeners
        // once ready — this keeps the startup deterministic for tests.
        Future.microtask(() => ThemeController.initialize()),
      ]);

      runApp(const EthioStreetFixApp());
    },
    (error, stack) {
      // Caught by Zone: surface to console and show a browser alert for immediate visibility
      // (alert is only for developer convenience — it won't crash the app)
      // ignore: avoid_print
      print('Uncaught error in zone: $error\n$stack');
    },
  );
}

class EthioStreetFixApp extends StatelessWidget {
  const EthioStreetFixApp({super.key});

  static Widget _errorScreen(Object error, StackTrace? stack) {
    final message = error.toString() ?? 'Unknown error';
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            color: Colors.red.shade50,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'An error occurred while starting the app',
                    style: ThemeData.light().textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    message,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 10,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload app (dev)'),
                    onPressed: () {
                      // portable fallback: instruct the developer to reload the page
                      debugPrint(
                        'Reload recommended: please refresh the browser to recover.',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // show a visible placeholder early so a truly blank/white render is unlikely
    final placeholder = Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Text(
          'Ethio Street Fix — starting...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.mode,
          home: const SplashScreen(),
          builder: (context, child) {
            // Global widget error UI (visible in debug & release to avoid white screens)
            ErrorWidget.builder = (FlutterErrorDetails details) {
              // show simplified error screen and also log full details
              // ignore: avoid_print
              print(
                'Flutter framework error: ${details.exception}\n${details.stack}',
              );
              return _errorScreen(details.exception, details.stack);
            };

            // No debug banner — show child or placeholder directly
            final decorated = child ?? placeholder;

            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: decorated,
            );
          },
        );
      },
    );
  }
}
