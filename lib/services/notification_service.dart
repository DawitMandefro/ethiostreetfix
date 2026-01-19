import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';

// SRS Section 3.3: Secure notification delivery for status updates
class NotificationService {
  // Avoid accessing Firebase at construction time — resolve Firestore lazily
  FirebaseFirestore? _firestore;

  FirebaseFirestore? get _safeFirestore {
    _firestore ??= _tryGetFirestore();
    return _firestore;
  }

  static FirebaseFirestore? _tryGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // SRS Section 3.3: Initialize notification service (called by app lifecycle)
  Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission for notifications
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      } else {
        print('User declined notification permission');
      }

      // Get FCM token for this device
      String? token = await messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen(_saveTokenToFirestore);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    } catch (e) {
      // Firebase not available in tests or offline mode — log and continue
      print('NotificationService.initialize: Firebase unavailable: $e');
    }
  }

  // SRS Section 3.3: Save FCM token to Firestore for user
  Future<void> _saveTokenToFirestore(String token) async {
    final firestore = _safeFirestore;
    if (firestore == null) return; // Not available in tests/offline
    try {
      await firestore.collection('fcm_tokens').doc(token).set({
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // SRS Section 3.3: Handle foreground notifications
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message received: ${message.notification?.title}');
    // In a real app, you'd show a local notification or update UI
  }

  // SRS Section 3.3: Handle background notifications
  void _handleBackgroundMessage(RemoteMessage message) {
    print('Background message received: ${message.notification?.title}');
  }

  // SRS Section 3.3: Send notification for status update
  Future<void> notifyStatusUpdate({
    required String reportId,
    required String userEmail,
    required ReportStatus newStatus,
    String? note,
  }) async {
    try {
      // Create notification document
      final firestore = _safeFirestore;
      if (firestore == null) return; // no-op in tests/offline
      await firestore.collection('notifications').add({
        'reportId': reportId,
        'userEmail': userEmail,
        'type': 'STATUS_UPDATE',
        'status': newStatus.name,
        'message': _getStatusMessage(newStatus, note),
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // In a production app, you would send a push notification via Cloud Functions
      // This would trigger a Cloud Function that sends FCM messages to the user's device
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  String _getStatusMessage(ReportStatus status, String? note) {
    switch (status) {
      case ReportStatus.inProgress:
        return 'Your report is now being addressed. ${note ?? ''}';
      case ReportStatus.fixed:
        return 'Great news! Your reported issue has been resolved. ${note ?? ''}';
      case ReportStatus.rejected:
        return 'Your report was reviewed but could not be processed. ${note ?? ''}';
      case ReportStatus.pending:
        return 'Your report has been received and is pending review.';
    }
  }

  // SRS Section 3.3: Get notifications for current user
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userEmail) {
    final firestore = _safeFirestore;
    if (firestore == null) {
      // Not available in test/offline mode: return an empty stream
      return Stream<List<Map<String, dynamic>>>.value([]);
    }

    // Avoid requiring composite indexes by querying by userEmail alone
    // and sorting client-side. This is tolerant for moderate result sizes.
    return firestore
        .collection('notifications')
        .where('userEmail', isEqualTo: userEmail)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              'id': doc.id,
              'reportId': data['reportId'],
              'type': data['type'],
              'message': data['message'],
              'read': data['read'] ?? false,
              'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
            };
          }).toList();

          // Sort descending by timestamp (null-safe)
          list.sort((a, b) {
            final aTs = a['timestamp'] as DateTime?;
            final bTs = b['timestamp'] as DateTime?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

          // Limit to most recent 50
          if (list.length > 50) return list.sublist(0, 50);
          return list;
        });
  }

  // SRS Section 3.3: Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final firestore = _safeFirestore;
      if (firestore == null) return;
      await firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // SRS Section 3.3: Mark all notifications as read
  Future<void> markAllAsRead(String userEmail) async {
    try {
      final firestore = _safeFirestore;
      if (firestore == null) return;
      final batch = firestore.batch();
      final notifications = await firestore
          .collection('notifications')
          .where('userEmail', isEqualTo: userEmail)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
}

// SRS Section 3.3: Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
}
